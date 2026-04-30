#!/usr/bin/env bash
# email_search.sh — exhaustive search for an email across source, logs,
# CSVs, and inside-zip XLSX sharedStrings. Also checks base64 + URL-encoded forms.
#
# Usage: bash email_search.sh [project_root] <email_address>
# Env:   MAX_XLSX=N (cap xlsx scan; default 100000)
set -u
ROOT="${1:-.}"
EMAIL="${2:-}"
[ -z "$EMAIL" ] && { echo "Usage: $0 <project_root> <email>"; exit 1; }
cd "$ROOT" || { echo "ERR: cannot cd $ROOT"; exit 1; }
MAX_XLSX="${MAX_XLSX:-100000}"

echo "=== EMAIL SEARCH @ $(date -u) — root=$(pwd) — target=$EMAIL ==="
echo

USER="${EMAIL%%@*}"
DOM="${EMAIL##*@}"
B64=$(printf "%s" "$EMAIL" | base64 | tr -d '\n')
URLENC="${USER}%40${DOM}"

echo "  also searching for:"
echo "    base64       = $B64"
echo "    urlencoded   = $URLENC"
echo

echo "--- Plain-text matches (source + logs + CSVs + JSON + ENV + TXT + BAK + HTML + XML) ---"
grep -ranlH --binary-files=text "$EMAIL" \
  --include="*.php" --include="*.json" --include="*.sql" --include="*.txt" \
  --include="*.log" --include="*.csv" --include="*.bak" --include="*.html" \
  --include="*.xml" --include="*.env" --include=".env" --include="*.yml" \
  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -30

echo
echo "--- Username-only (substring '$USER') in source/logs (likely noisy) ---"
grep -ranlH --binary-files=text "$USER" \
  --include="*.php" --include="*.json" --include="*.txt" --include="*.log" \
  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -10

echo
echo "--- Encoded forms ---"
grep -ranl --binary-files=text "$B64"     --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head
grep -ranl --binary-files=text "$URLENC"  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head

echo
echo "--- Inside .xlsx (sharedStrings.xml) under storage/app/ — capped at $MAX_XLSX files ---"
HITS=0; SCAN=0
for f in $(find storage/app -type f -name "*.xlsx" 2>/dev/null); do
  SCAN=$((SCAN+1))
  if [ "$SCAN" -gt "$MAX_XLSX" ]; then break; fi
  if unzip -p "$f" xl/sharedStrings.xml 2>/dev/null | grep -q "$EMAIL"; then
    HITS=$((HITS+1)); echo "  MATCH-EMAIL: $f"
  fi
done
echo "  scanned $SCAN xlsx; exact-email matches: $HITS"

echo
echo "=== END EMAIL SEARCH ==="
