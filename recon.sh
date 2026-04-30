#!/usr/bin/env bash
# recon.sh — project layout reconnaissance for a Laravel application
# Usage: bash recon.sh [project_root]
set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "ERR: cannot cd $ROOT"; exit 1; }

echo "=== RECON @ $(date -u) — root=$(pwd) ==="
echo
echo "--- Top-level layout ---"
ls -la 2>/dev/null | head -60
echo
echo "--- Root-level files that should NOT be at the web root ---"
for f in .env .env.* .git composer.json composer.lock package.json package-lock.json \
         phpunit.xml README.md test.php test*.php phpinfo.php info.php \
         schedule.log schedule_output.log run_scheduler.bat .DS_Store; do
  if [ -e "$f" ]; then
    SZ=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)
    echo "  PRESENT: $f  ($SZ bytes)"
  fi
done
echo
echo "--- Is there an index.php at the project root? (Laravel anti-pattern) ---"
if [ -f index.php ]; then
  echo "  YES — project root is likely the web root. This exposes everything."
  head -5 index.php
else
  echo "  no — good"
fi
echo
echo "--- Root .htaccess content ---"
[ -f .htaccess ] && cat .htaccess || echo "  no root .htaccess"
echo
echo "--- public/.htaccess content (compare; should have mod_rewrite block) ---"
[ -f public/.htaccess ] && cat public/.htaccess || echo "  no public/.htaccess"
echo
echo "--- .env exposure check ---"
if [ -f .env ]; then
  LINES=$(wc -l < .env)
  echo "  PRESENT: .env ($LINES lines)"
  echo "  Keys (values redacted):"
  awk -F= '/^[A-Za-z_]+[A-Za-z0-9_]*=/{print "    " $1 "=…"}' .env
fi
echo
echo "--- .git directory (if present, web-readable when project root is web root) ---"
if [ -d .git ]; then
  echo "  .git/ present"
  cat .git/HEAD 2>/dev/null
  grep -E "url|remote" .git/config 2>/dev/null
fi
echo
echo "--- Storage / log files (size profile) ---"
find . -maxdepth 4 -type f \( -name "*.log" -o -path "*/storage/logs/*" \) 2>/dev/null \
  | xargs -I{} sh -c 'SZ=$(stat -c%s "{}" 2>/dev/null || stat -f%z "{}"); echo "  $SZ bytes  {}"' \
  | sort -rn | head -20
echo
echo "--- Public uploads / sub-directories ---"
find public -maxdepth 2 -type d 2>/dev/null | head -20
echo
echo "--- Deployment hints (paths in .bat / .sh / Dockerfile / nginx) ---"
grep -rEn "(htdocs|/var/www|D:\\\\|nginx|apache|DocumentRoot)" \
  --include="*.bat" --include="*.sh" --include="Dockerfile" --include="*.conf" \
  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -10
echo
echo "=== END RECON ==="
