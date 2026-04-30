#!/usr/bin/env bash
# backdoor_hunt.sh — search for PHP backdoor / RCE primitives
# Usage: bash backdoor_hunt.sh [project_root]
set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "ERR: cannot cd $ROOT"; exit 1; }

echo "=== BACKDOOR HUNT @ $(date -u) — root=$(pwd) ==="
echo
echo "--- Dangerous primitives in app/ + routes/ + public/*.php ---"
grep -rEn "\b(eval|assert|exec|system|shell_exec|passthru|popen|proc_open|create_function)\s*\(" \
  app/ routes/ public/ --include="*.php" 2>/dev/null | head -40
echo
echo "--- preg_replace with /e modifier (deprecated but still RCE) ---"
grep -rEn "preg_replace\s*\([^,]*/e['\"]" --include="*.php" \
  --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -20
echo
echo "--- Encoded-payload patterns (base64_decode + eval/exec, gzinflate, str_rot13) ---"
grep -rEn "base64_decode\s*\(\s*\\\$_(GET|POST|REQUEST|COOKIE)|\
gzinflate\s*\(\s*base64_decode|\
str_rot13\s*\(\s*base64_decode|\
eval\s*\(\s*\\\$_(GET|POST|REQUEST|COOKIE)|\
assert\s*\(\s*\\\$_(GET|POST|REQUEST|COOKIE)" \
  --include="*.php" --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -20
echo
echo "--- Variable-variable / dynamic dispatch (\$\$var, call_user_func with user input) ---"
grep -rEn "call_user_func[^(]*\(\s*\\\$_(GET|POST|REQUEST)|\
\\\${\\\$" --include="*.php" --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null | head -20
echo
echo "--- Suspicious extensions and odd files anywhere (.phtml/.phps/.bak/shell.* etc) ---"
find . -type f \( -name "*.phtml" -o -name "*.phps" -o -name "*.bak" -o -name "*.swp" \
  -o -name "shell*.php" -o -name "c99*.php" -o -name "r57*.php" -o -name "wso*.php" \
  -o -name "uploader*.php" -o -name "phpinfo*.php" \) 2>/dev/null | head -30
echo
echo "--- PHP files at the web root (should be just index.php) ---"
ls *.php 2>/dev/null
echo
echo "--- Files with raw \$_GET/\$_POST/\$_REQUEST/\$_COOKIE access in app/routes ---"
grep -rEn "\\\$_(GET|POST|REQUEST|COOKIE)\b" app/ routes/ public/index.php --include="*.php" 2>/dev/null | head -30
echo
echo "--- CSRF excludes / 'install' / setup routes to review for unauth admin paths ---"
[ -f app/Http/Middleware/VerifyCsrfToken.php ] && cat app/Http/Middleware/VerifyCsrfToken.php
grep -rEn "Route::(any|match|get|post)\s*\(\s*['\"]install\b|setup|admin" routes/ 2>/dev/null | head -10
echo
echo "--- Vendor eval sites (legitimate uses are common; review only unfamiliar packages) ---"
grep -rEn "\beval\s*\(" vendor/ --include="*.php" 2>/dev/null | head -20
echo
echo "=== END BACKDOOR HUNT ==="
