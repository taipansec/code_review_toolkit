#!/usr/bin/env bash
# dep_audit.sh — composer.lock + package-lock.json audit (offline)
# Usage: bash dep_audit.sh [project_root]
set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "ERR: cannot cd $ROOT"; exit 1; }

echo "=== DEP AUDIT @ $(date -u) — root=$(pwd) ==="
echo

if [ ! -f composer.lock ]; then
  echo "  no composer.lock at $ROOT — run 'composer install' first if you need versions"
else
  echo "--- composer.lock present ---"
  python3 - <<'PY'
import json, re, sys
KNOWN_VULNERABLE = [
  # name, vulnerable_max_inclusive, fixed_min, advisory
  ("livewire/livewire",          "v3.6.3",   "v3.6.4",   "CVE-2025-54068 (CVSS 9.2 — unauth RCE during property hydration)"),
  ("phpoffice/phpspreadsheet",   "1.29.9",   "1.30.0",   "CVE-2025-54370 (SSRF in Drawing::setPath)"),
  ("symfony/http-foundation",    "v6.4.28",  "v6.4.29",  "CVE-2025-64500 (PATH_INFO authz bypass)"),
  # add more as published
]
def vle(a, b):
  norm = lambda v: [int(p) if p.isdigit() else p for p in re.split(r'[.\\-]', v.lstrip('vV'))]
  return norm(a) <= norm(b)
data = json.load(open('composer.lock'))
pkgs = {p['name']: p['version'] for p in data.get('packages', [])}
print(f"  packages in composer.lock: {len(pkgs)}")
print()
print("  -- known-vulnerable check (extend the KNOWN_VULNERABLE list as needed)")
hit = False
for name, vmax, fix, adv in KNOWN_VULNERABLE:
  v = pkgs.get(name)
  if v is None:
    continue
  if vle(v, vmax):
    print(f"    VULNERABLE: {name}@{v}  →  fix to {fix} (advisory: {adv})")
    hit = True
  else:
    print(f"    ok:         {name}@{v}  (>= {fix})")
if not hit:
  print("  no hardcoded-known matches; still run 'composer audit' for new advisories")
print()
print("  -- dev-master / dev-main / @dev pins (supply-chain footgun)")
flagged = False
for name, ver in pkgs.items():
  if 'dev-' in ver or ver.startswith('dev'):
    print(f"    {name}@{ver}")
    flagged = True
if not flagged:
  print("  none")
PY
fi

echo
if [ -f package-lock.json ]; then
  echo "--- package-lock.json — top-level direct deps ---"
  python3 - <<'PY'
import json
data = json.load(open('package-lock.json'))
deps = data.get('packages', {}).get('', {}).get('dependencies', {})
ddeps = data.get('packages', {}).get('', {}).get('devDependencies', {})
for kind, src in [('dep', deps), ('dev', ddeps)]:
  for k, v in src.items():
    print(f"  [{kind}] {k}@{v}")
PY
else
  echo "--- no package-lock.json ---"
fi

echo
echo "--- Reminder: run 'composer audit' and 'npm audit' for live CVE feeds ---"
echo "=== END DEP AUDIT ==="
