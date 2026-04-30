#!/usr/bin/env bash
# secrets.sh — hardcoded credential / secret scan
# Usage: bash secrets.sh [project_root]
set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "ERR: cannot cd $ROOT"; exit 1; }

echo "=== SECRETS SCAN @ $(date -u) — root=$(pwd) ==="
echo
echo "--- .env keys present (values redacted) ---"
if [ -f .env ]; then
  awk -F= '/^[A-Za-z_]+[A-Za-z0-9_]*=/{
    key=$1
    val=$0; sub(/^[^=]+=/,"",val)
    n=length(val); if(n>0){flag=" [SET]"} else {flag=" [empty]"}
    print "  " key flag
  }' .env
else
  echo "  no .env"
fi
echo
echo "--- Gmail App Password format anywhere (4 groups of 4 lowercase letters) ---"
grep -rEnH "['\"][a-z]{4}\s+[a-z]{4}\s+[a-z]{4}\s+[a-z]{4}['\"]" \
  --include="*.php" --include="*.env" --include=".env" --include="*.json" \
  --include="*.txt" --include="*.bak" --include="*.html" --include="*.xml" \
  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -20
echo
echo "--- AWS-style keys ---"
grep -rEn "AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}" \
  --include="*.php" --include="*.env" --include=".env" --include="*.json" \
  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -10
echo
echo "--- Google API keys, GitHub PATs, Stripe live keys, Slack tokens ---"
grep -rEnH "AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36}|ghu_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|sk_live_[A-Za-z0-9]{20,}|pk_live_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}" \
  --include="*.php" --include="*.env" --include=".env" --include="*.json" \
  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -20
echo
echo "--- Hardcoded credential patterns in source ---"
grep -rEn "(password|secret|api[_-]?key|token)\s*[:=]\s*['\"][^'\"\\\$]{12,}['\"]" \
  --include="*.php" --include="*.json" \
  --exclude-dir=vendor --exclude-dir=node_modules \
  app/ config/ database/ routes/ 2>/dev/null \
  | grep -vE "env\(|getenv\(|config\(|placeholder|example|Hash::" | head -20
echo
echo "--- Mail config — does the From address differ from authenticated From? ---"
if [ -f .env ]; then
  grep -E "^(MAIL_USERNAME|MAIL_FROM_ADDRESS|MAIL_HOST)=" .env
fi
echo
echo "--- All distinct @gmail.com addresses anywhere in the project (excluding vendor/node_modules) ---"
grep -arhoiE "[a-z0-9._+-]+@gmail\.com" --include="*.php" --include="*.env" --include=".env" \
  --include="*.json" --include="*.txt" --include="*.bak" --include="*.html" --include="*.xml" \
  --include="*.log" --include="*.csv" \
  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null \
  | tr '[:upper:]' '[:lower:]' | sort -u | head -30
echo
echo "--- .gitignore present? Does it ignore .env / vendor / storage logs? ---"
if [ -f .gitignore ]; then
  for pat in '\.env' 'vendor' 'storage/logs' 'node_modules' '\.idea' '\.vscode'; do
    if grep -qE "$pat" .gitignore; then echo "  IGNORED: $pat"; else echo "  NOT IGNORED: $pat"; fi
  done
else
  echo "  NO .gitignore at repo root"
fi
echo
echo "--- Has .env ever been committed to git? ---"
if [ -d .git ]; then
  IN_GIT=$(git log --all --diff-filter=A --name-only -- .env 2>/dev/null | grep -c "^.env")
  if [ "${IN_GIT:-0}" -gt 0 ]; then
    echo "  YES — .env appears in git history. Rotate every credential it contains."
    git log --all --oneline -- .env 2>/dev/null | head -5
  else
    echo "  no — not in git history"
  fi
fi
echo
echo "=== END SECRETS SCAN ==="
