#!/usr/bin/env bash
# Deploy a built game zip to a Luxodd environment.
#
# The server mints a version + signed GCS PUT URL (initiate), we upload the
# zip straight to GCS, then publish (complete) — the server validates the
# archive (index.html at root) and bumps games.version, which is what makes
# kiosks pick it up from the manifest.
#
# Required env:
#   SERVER_URL   e.g. https://staging-app.luxodd.com
#   GAME_ID      game UUID in that environment's DB
#   DEPLOY_KEY   GAME_DEPLOY_API_KEY for that environment
#   ZIP_PATH     path to game.zip
# Optional env:
#   COMMIT, REPO   traceability metadata, logged server-side
set -euo pipefail

: "${SERVER_URL:?SERVER_URL is required}"
: "${GAME_ID:?GAME_ID is required}"
: "${DEPLOY_KEY:?DEPLOY_KEY is required}"
: "${ZIP_PATH:?ZIP_PATH is required}"

if [[ ! -s "$ZIP_PATH" ]]; then
  echo "::error::zip not found or empty: $ZIP_PATH" >&2
  exit 1
fi

meta=$(jq -n --arg commit "${COMMIT:-}" --arg repo "${REPO:-}" '{commit: $commit, repo: $repo}')

echo "Initiating deploy of $(du -h "$ZIP_PATH" | cut -f1) to $SERVER_URL (game $GAME_ID)"
init=$(curl -fsS -X POST "$SERVER_URL/api/games/$GAME_ID/deploy/initiate" \
  -H "X-Api-Key: $DEPLOY_KEY" \
  -H 'Content-Type: application/json' \
  -d "$meta")

upload_url=$(jq -re '.upload_url' <<<"$init")
version=$(jq -re '.version' <<<"$init")
echo "Minted version $version — uploading to GCS"

# shell redirect, not `-o /dev/null`: the latter + --retry exits 23 on some
# curl builds (observed on mingw curl 8.19)
curl -fsS --retry 3 --retry-all-errors -X PUT "$upload_url" \
  -H 'Content-Type: application/zip' \
  --upload-file "$ZIP_PATH" >/dev/null

echo "Upload done — publishing"
complete=$(jq -n --arg v "$version" --arg commit "${COMMIT:-}" --arg repo "${REPO:-}" \
  '{version: $v, commit: $commit, repo: $repo}' | \
  curl -fsS -X POST "$SERVER_URL/api/games/$GAME_ID/deploy/complete" \
    -H "X-Api-Key: $DEPLOY_KEY" \
    -H 'Content-Type: application/json' \
    -d @-)

echo "$complete" | jq .
size=$(jq -r '.zip_size' <<<"$complete")
files=$(jq -r '.file_count' <<<"$complete")

{
  echo "### Deployed game \`$GAME_ID\` → $SERVER_URL"
  echo ""
  echo "| version | zip size | files |"
  echo "|---|---|---|"
  echo "| $version | $size bytes | $files |"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
