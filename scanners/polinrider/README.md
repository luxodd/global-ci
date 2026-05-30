# PolinRider Scanner

Cross-platform scanner that detects PolinRider malware indicators in any repository.

## What it checks

| # | Check | What it catches |
|---|-------|-----------------|
| 1 | `public/fonts/` directory | Camouflage font files planted alongside the malicious payload |
| 2 | `.vscode/settings.json` auto-tasks | `task.allowAutomaticTasks: true` — the VS Code infection vector |
| 3 | `.vscode/settings.json` folderOpen | Auto-run tasks that execute on workspace open |
| 4 | `.vscode/tasks.json` folderOpen | Same vector via tasks.json |
| 5 | `rmcej%otb%` signature | Unique PolinRider obfuscation seed string |
| 6 | `global['!']` marker | PolinRider global infection marker |
| 7 | `temp_auto_push.bat` / `config.bat` | Propagation and orchestration scripts |
| 8 | `.gitignore` injection | `config.bat` hidden via gitignore |
| 9 | Obfuscated JS in config files | `fromCharCode`, `eval(atob`, hex strings in postcss/tailwind/eslint/next configs |

## Usage

### Local (any OS with bash)
```bash
./scanners/polinrider/polinrider-scanner.sh
```

### CI (GitHub Actions)
Add to any repo's `.github/workflows/ci.yml`:
```yaml
jobs:
  polinrider:
    uses: luxodd/global-ci/.github/workflows/polinrider-scan.yml@main
```

## Exit codes
- `0` — Clean, no indicators found
- `1` — Infection indicators detected — **do not merge**

## References
- [OpenSourceMalware: PolinRider Attack Analysis](https://opensourcemalware.com/blog/polinrider-attack)
- [The Hacker News: VS Code Auto-Run Task Abuse](https://thehackernews.com/2026/03/north-korean-hackers-abuse-vs-code-auto.html)
