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
       # Only build when something that affects the build changes — skip
       # docs/CI-only commits so they don't burn ~16 min of runner time.
       # Nested projects: prefix with the project path, e.g. My-Project/Assets/**
       paths: ['Assets/**', 'Packages/**', 'ProjectSettings/**']
     pull_request:
       branches: [main]
       paths: ['Assets/**', 'Packages/**', 'ProjectSettings/**']
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
         runner: unity-8core                # 8-core hosted, ~6.7 min build (see Build performance)
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

### Build performance

All measured on helix-jump, warm (Library cache hit):

| Runner | Wall clock | Image pull | Unity compile | ~$/build |
|--------|-----------|-----------|---------------|----------|
| `ubuntu-latest` (2-core) | ~16 min | ~3.7 min | ~9.9 min | free tier / $0.008·min |
| **`unity-8core` (8-core)** | **~6.7 min** | ~2.6 min | ~2.8 min | ~$0.21 |
| self-hosted (warm) | ~3–4 min (est.) | 0 (cached) | ~2.8 min | ~0 marginal |

Cold (no Library cache) is ~99 min regardless — that's asset import from
scratch. The `Library` cache (~1.8GB, already wired in) is what avoids it;
GitHub evicts a cache after **7 days without a hit**, so a game untouched for a
week pays the cold cost once on its next build.

**Recommended: `unity-8core`.** It's the sweet spot — 2.4x faster than 2-core
for ~$0.21/build. The 8 cores collapse the parallel C++ compile (9.9 → 2.8
min); set it per repo in the caller:

```yaml
    with:
      runner: unity-8core   # org larger runner, Default group, all repos
      ...
```

**Don't go bigger than 8-core.** Once compile drops to ~2.8 min, the remaining
bottleneck is the ~2.6 min Unity Docker image pull, which is fixed and does
*not* shrink with cores. 16/32-core would bill 2–4x for maybe 1 min saved.

**The only way below ~6 min is a self-hosted runner** (`runner:` = a
self-hosted label). It keeps the ~8GB image and Library on local disk between
runs — no pull, no cache restore, no 7-day eviction — landing around 3–4 min at
near-zero marginal cost. The `runner` input already supports it and the
disk-cleanup step is guarded off for self-hosted. Trade-off is running and
patching a machine (spare box or ~$30–60/mo always-on VM); worth it only once
builds are frequent enough that the pull tax × frequency beats the ops burden.

Also in the template: **path filters** so docs/CI-only commits don't trigger a
build at all.

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
