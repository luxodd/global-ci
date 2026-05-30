#!/usr/bin/env bash
# polinrider-scanner.sh — Detects PolinRider malware indicators in a repository
# Exit 0 = clean, Exit 1 = infection found
set -euo pipefail

FAILURES=0
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILURES=$((FAILURES + 1)); }

echo "=== PolinRider Scanner ==="
echo "Repository: $(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo ""

# ── Check 1: Malicious font directory ──────────────────────────────────
if [ -d "public/fonts" ]; then
  fail "public/fonts/ directory exists — PolinRider camouflage files present"
else
  pass "No public/fonts/ directory"
fi

# ── Check 2: VS Code auto-tasks enabled ────────────────────────────────
if [ -f ".vscode/settings.json" ]; then
  if grep -q 'task.allowAutomaticTasks.*true' .vscode/settings.json 2>/dev/null; then
    fail "task.allowAutomaticTasks is TRUE in .vscode/settings.json"
  else
    pass "task.allowAutomaticTasks not enabled"
  fi
  if grep -q 'runOn.*folderOpen' .vscode/settings.json 2>/dev/null; then
    fail "Auto-run task on folderOpen in .vscode/settings.json"
  else
    pass "No folderOpen auto-run tasks"
  fi
else
  pass "No .vscode/settings.json"
fi

# ── Check 3: VS Code tasks.json with auto-run ──────────────────────────
if [ -f ".vscode/tasks.json" ]; then
  if grep -q 'runOn.*folderOpen' .vscode/tasks.json 2>/dev/null; then
    fail "Auto-run task on folderOpen in .vscode/tasks.json"
  else
    pass "No folderOpen tasks in tasks.json"
  fi
fi

# ── Check 4: PolinRider obfuscation signature ──────────────────────────
if git grep -q 'rmcej%otb%' HEAD 2>/dev/null; then
  fail "PolinRider signature 'rmcej%otb%' found in tracked files"
  git grep -l 'rmcej%otb%' HEAD 2>/dev/null | while read -r f; do
    echo "       -> $f"
  done
else
  pass "No PolinRider signature in tracked files"
fi

# ── Check 5: PolinRider global marker ──────────────────────────────────
if git grep -q "global\['!'\]" HEAD 2>/dev/null; then
  fail "PolinRider global marker found in tracked files"
  git grep -l "global\['!'\]" HEAD 2>/dev/null | while read -r f; do
    echo "       -> $f"
  done
else
  pass "No PolinRider global marker"
fi

# ── Check 6: Propagation scripts ───────────────────────────────────────
for script in temp_auto_push.bat config.bat; do
  if [ -f "$script" ]; then
    fail "$script found — PolinRider propagation script"
  fi
done
pass "No propagation scripts"

# ── Check 7: .gitignore injection ──────────────────────────────────────
if [ -f ".gitignore" ]; then
  if grep -q 'config\.bat' .gitignore 2>/dev/null; then
    fail ".gitignore contains config.bat — PolinRider hiding mechanism"
  else
    pass ".gitignore clean"
  fi
fi

# ── Check 8: Obfuscated JS in config files ─────────────────────────────
CONFIG_FILES=$(find . -maxdepth 3 \( \
  -name "postcss.config.mjs" -o -name "postcss.config.js" -o \
  -name "tailwind.config.js" -o -name "tailwind.config.mjs" -o \
  -name "eslint.config.mjs" -o -name "next.config.mjs" -o \
  -name "next.config.js" -o -name "babel.config.js" \
\) -not -path "*/node_modules/*" -not -path "*/.next/*" 2>/dev/null)

for f in $CONFIG_FILES; do
  if grep -q 'fromCharCode\|eval.*atob\|Function.*0x[0-9a-fA-F]\{20,\}' "$f" 2>/dev/null; then
    fail "Obfuscated code in $f"
  fi
done

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "=== Scan Complete ==="
if [ "$FAILURES" -gt 0 ]; then
  echo -e "${RED}${FAILURES} PolinRider indicator(s) found — REPO MAY BE INFECTED${NC}"
  exit 1
else
  echo -e "${GREEN}All checks passed — no PolinRider indicators detected${NC}"
  exit 0
fi
