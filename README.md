# global-ci

Reusable CI checks enforced across **all** Luxodd repositories. Each scanner lives in its own directory under `scanners/` and has a corresponding reusable workflow in `.github/workflows/`.

## Available Scanners

| Scanner | Workflow | Description |
|---------|----------|-------------|
| [PolinRider](scanners/polinrider/) | `polinrider-scan.yml` | Detects DPRK PolinRider malware (fonts, auto-tasks, obfuscated payloads) |

## How to add a scanner to your repo

Drop this in as `.github/workflows/polinrider.yml`. It runs on `pull_request_target` so the gate is evaluated from your base branch (a malicious PR cannot disable it), and it passes the PR head SHA as the required `ref` (the scan only reads the PR head, it never executes it):

```yaml
name: PolinRider Gate
on:
  pull_request_target:
    types: [opened, synchronize, reopened, ready_for_review]
permissions:
  contents: read
jobs:
  scan:
    uses: luxodd/global-ci/.github/workflows/polinrider-scan.yml@main
    with:
      ref: ${{ github.event.pull_request.head.sha }}
      fail-on-detection: true
```

Pin `@main` to a specific commit SHA (for example `@<sha> # v1.0.0`) so a change to global-ci cannot alter your gate.

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
