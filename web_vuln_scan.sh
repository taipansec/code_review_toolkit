#!/usr/bin/env bash
# web_vuln_scan.sh — common Laravel/PHP web-app vulnerability patterns
# Usage: bash web_vuln_scan.sh [project_root]
set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "ERR: cannot cd $ROOT"; exit 1; }

echo "=== WEB VULN SCAN @ $(date -u) — root=$(pwd) ==="
echo
echo "--- SQLi candidates: DB::raw / whereRaw / orderByRaw / raw DB::select|statement ---"
grep -rEn "DB::raw\(|whereRaw\(|orderByRaw\(|selectRaw\(|DB::select\(|DB::statement\(" \
  app/ --include="*.php" 2>/dev/null | head -50
echo
echo "--- Raw concatenation into query strings ---"
grep -rEn "DB::(select|statement|insert|update|delete)\s*\([^)]*\\\$" \
  app/ --include="*.php" 2>/dev/null | head -30
echo
echo "--- Blade unescaped output (XSS via {!! !!}) — excluding common safe wrappers ---"
grep -rEn "\{!!" resources/views/ --include="*.blade.php" 2>/dev/null \
  | grep -vE "csrf_field|method_field|Form::|\\\\\$errors|xss_clean|__\(|trans\(|render|html|json_encode" \
  | head -30
echo
echo "--- Mass assignment risk: \$guarded = [], no \$fillable, ::create(\$request->all()) ---"
grep -rEn "guarded\s*=\s*\[\s*\]" app/Models/ --include="*.php" 2>/dev/null | head -20
for f in app/Models/*.php; do
  if [ -f "$f" ] && ! grep -qE "protected \\\$fillable|protected \\\$guarded" "$f"; then
    echo "  no fillable/guarded:  $f"
  fi
done
grep -rEn "::create\s*\(\s*\\\$request->all\s*\(\s*\)\s*\)|->fill\s*\(\s*\\\$request->all" \
  app/ --include="*.php" 2>/dev/null | head -20
echo
echo "--- File upload patterns: getClientOriginalExtension / hasFile / ->move( ---"
grep -rEn "getClientOriginalExtension|getClientOriginalName|->hasFile\(|->move\(" \
  app/ --include="*.php" 2>/dev/null | head -30
echo
echo "--- Looping over \$_FILES / \$_POST in controllers (often unbounded mass writes) ---"
grep -rEn "foreach\s*\(\s*\\\$_(POST|FILES)\b" app/ --include="*.php" 2>/dev/null | head -20
echo
echo "--- Exception handler reveals (debug) and APP_DEBUG default in config/app.php ---"
[ -f config/app.php ] && grep -nE "debug|env\('APP_(DEBUG|ENV)'" config/app.php
echo
echo "--- API routes: check which endpoints have auth middleware ---"
[ -f routes/api.php ] && cat routes/api.php
echo
echo "--- Web routes: groups WITHOUT 'auth' middleware (sample) ---"
grep -nE "Route::(group|get|post|match|any|put|patch|delete)\s*\(" routes/web.php 2>/dev/null \
  | grep -vE "auth|admin|guest|verified" | head -20
echo
echo "--- IDOR pattern: ::find(\$id) without ownership filter (informational) ---"
grep -rEn "::find\s*\(\s*\\\$id\s*\)" app/Http/Controllers/ --include="*.php" 2>/dev/null | head -30
echo
echo "--- response()->download() with DB-stored or user-influenced paths ---"
grep -rEn "response\(\)->download\(" app/Http/Controllers/ --include="*.php" 2>/dev/null | head -20
echo
echo "--- file_get_contents on user-influenced URLs (SSRF candidates) ---"
grep -rEn "file_get_contents\s*\(\s*\\\$" app/ --include="*.php" 2>/dev/null | head -20
echo
echo "=== END WEB VULN SCAN ==="
