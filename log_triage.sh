#!/usr/bin/env bash
# log_triage.sh — size + content profile of Laravel logs
# Usage: bash log_triage.sh [project_root]
# Env:   MAX_BYTES=200000000 (default cap on grep input — 200 MB)
set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "ERR: cannot cd $ROOT"; exit 1; }
MAX_BYTES="${MAX_BYTES:-200000000}"

echo "=== LOG TRIAGE @ $(date -u) — root=$(pwd) ==="
echo "(content scans bounded to first $MAX_BYTES bytes per file)"
echo

LOGS=$(find . -maxdepth 4 -type f \( -name "laravel*.log" -o -path "*/storage/logs/*.log" \
       -o -name "schedule.log" -o -name "schedule_output.log" -o -name "error*.log" \) 2>/dev/null)

if [ -z "$LOGS" ]; then
  echo "  no candidate log files"
  exit 0
fi

for L in $LOGS; do
  SZ=$(stat -c%s "$L" 2>/dev/null || stat -f%z "$L" 2>/dev/null)
  echo "================================================================"
  echo "FILE: $L  ($SZ bytes)"
  echo "================================================================"
  echo "--- first 5 lines ---"
  head -n 5 "$L" 2>/dev/null
  echo "--- last 5 lines ---"
  tail -n 5 "$L" 2>/dev/null
  echo "--- ERROR / Exception line count ---"
  ERR=$(head -c "$MAX_BYTES" "$L" | grep -ac "ERROR\|Exception\|SQLSTATE" 2>/dev/null)
  echo "  $ERR"
  echo "--- distinct exception types ---"
  head -c "$MAX_BYTES" "$L" | grep -aoE "[A-Z][a-zA-Z]+Exception" 2>/dev/null | sort -u | head -10
  echo "--- distinct email addresses appearing as recipients ---"
  head -c "$MAX_BYTES" "$L" \
    | grep -aoiE '"emails_(to|cc|bcc)":"[^"]*"' 2>/dev/null \
    | grep -aoiE '[a-z0-9._+-]+@[a-z0-9.-]+\.[a-z]{2,}' \
    | tr '[:upper:]' '[:lower:]' | sort -u | head -30
  echo "--- credential / token leakage scan ---"
  for pat in "DB_PASSWORD" "MAIL_PASSWORD" "APP_KEY" "Bearer " "Authorization" \
             "AKIA[0-9A-Z]{16}" "AIza[0-9A-Za-z_-]{35}" \
             "[a-z]{4} [a-z]{4} [a-z]{4} [a-z]{4}"; do
    H=$(head -c "$MAX_BYTES" "$L" | grep -aciE "$pat" 2>/dev/null)
    if [ "${H:-0}" -gt 0 ]; then echo "  HIT  $pat   ($H)"; fi
  done
  echo
done
echo "=== END LOG TRIAGE ==="
