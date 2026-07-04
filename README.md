# global-ci

Reusable CI checks and pipelines shared across **all** Luxodd repositories. Scanners live under `scanners/`, deploy tooling under `scripts/`, and each has a corresponding reusable workflow in `.github/workflows/`.

## Game deploy pipeline (`unity-webgl-deploy.yml`)

Push-to-ship pipeline for Unity WebGL game repos: every push to `main` builds
via [GameCI](https://game.ci) and auto-deploys the zip to **staging**. To ship
prod, run the workflow manually (Actions → Build & Deploy → Run workflow) with
the **promote** box checked — one run builds, stages, and promotes the same
artifact. PRs get a validation build only.

> Environment required-reviewers would make prod a true approval gate, but
> that needs GitHub Team for private repos. If the org upgrades, reviewers on
> each repo's `production` environment start enforcing automatically.

Deploys talk to the game server's `/api/games/{gameID}/deploy/initiate` +
`/deploy/complete` endpoints (signed-URL upload to GCS, then a version bump
that publishes to the kiosk manifest). See `scripts/deploy-game.sh`.

### Onboarding a game repo

1. Add `.github/workflows/build-deploy.yml`:

   ```yaml
   name: Build & Deploy
   on:
     push:
       branches: [main]
     pull_request:
       branches: [main]
     workflow_dispatch:
       inputs:
         promote:
           description: "Also deploy to PRODUCTION"
           type: boolean
           default: false

   permissions:
     contents: read

   concurrency:
     group: deploy-${{ github.ref }}
     cancel-in-progress: true

   jobs:
     pipeline:
       uses: luxodd/global-ci/.github/workflows/unity-webgl-deploy.yml@main
       with:
         deploy: ${{ github.event_name != 'pull_request' }}
         promote-production: ${{ github.event_name == 'workflow_dispatch' && inputs.promote }}
         game-id-staging: ${{ vars.LUXODD_GAME_ID_STAGING }}
         game-id-production: ${{ vars.LUXODD_GAME_ID_PROD }}
         # project-path: My-Nested-Project   # if the Unity project isn't at repo root
       secrets: inherit
   ```

2. Set repository **variables** `LUXODD_GAME_ID_STAGING` and
   `LUXODD_GAME_ID_PROD` to the game's UUID in each environment's DB (from
   the admin console games list).
3. Environments `staging` and `production` are auto-created on first run.
   On a GitHub Team plan, add required reviewers to `production` for a true
   approval gate; on the free plan the gate is the manual promote dispatch.
4. Org-level secrets used (already shared with all repos): `UNITY_EMAIL`,
   `UNITY_PASSWORD`, `UNITY_LICENSE` (+ `UNITY_SERIAL` for Pro),
   `GAME_DEPLOY_API_KEY_STAGING`, `GAME_DEPLOY_API_KEY_PROD`.

## Available Scanners

## Available Scanners

| Scanner | Workflow | Description |
|---------|----------|-------------|
| [PolinRider](scanners/polinrider/) | `polinrider-scan.yml` | Detects DPRK PolinRider malware (fonts, auto-tasks, obfuscated payloads) |

## How to add a scanner to your repo

Add this to your repo's `.github/workflows/ci.yml` (or any workflow that runs on PRs):

```yaml
jobs:
  polinrider:
    uses: luxodd/global-ci/.github/workflows/polinrider-scan.yml@main
```

To make it a **required check** for merging to main:
1. Go to your repo → Settings → Branches → Branch protection rules
2. Edit the `main` branch rule
3. Under "Require status checks to pass before merging", add `PolinRider Malware Scan`

## Adding a new scanner

1. Create `scanners/<name>/` with the scanner script and its README
2. Create `.github/workflows/<name>-scan.yml` as a reusable `workflow_call`
3. Add it to the table above
4. Update this README

## Local usage

Any scanner can be run locally:
```bash
./scanners/polinrider/polinrider-scanner.sh
```
