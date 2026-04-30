#!/usr/bin/env bash
# email_alerts_audit.sh — extract email_alerts recipient sets from log dumps,
# flag any alert configured with the same address as TO + CC + BCC, flag external
# / personal mailboxes vs. internal corporate domains.
#
# Usage: bash email_alerts_audit.sh [project_root] [internal_domain ...]
# Example: bash email_alerts_audit.sh . example.com
set -u
ROOT="${1:-.}"; shift || true
INTERNAL_DOMAINS=("$@")
[ ${#INTERNAL_DOMAINS[@]} -eq 0 ] && INTERNAL_DOMAINS=()  # keep empty
cd "$ROOT" || { echo "ERR: cannot cd $ROOT"; exit 1; }

echo "=== EMAIL ALERTS AUDIT @ $(date -u) — root=$(pwd) ==="
echo "  internal_domains = ${INTERNAL_DOMAINS[*]:-<none configured>}"
echo

LOGS=$(find storage/logs -maxdepth 2 -type f -name "*.log" 2>/dev/null)
if [ -z "$LOGS" ]; then
  echo "  no logs in storage/logs — nothing to extract"
  exit 0
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Pull every alert-config log line that includes "id":N + "alert_name" + emails_to/cc/bcc
for L in $LOGS; do
  grep -aoE '\{"id":[0-9]+,"alert_name":"[^"]*"[^}]*"emails_to":"[^"]*"[^}]*"emails_cc":"[^"]*"[^}]*"emails_bcc":"[^"]*"[^}]*\}' "$L" 2>/dev/null
done | sort -u > "$TMP"

LINES=$(wc -l < "$TMP")
echo "  distinct alert-config rows captured in logs: $LINES"
echo

if [ "$LINES" -eq 0 ]; then
  echo "  (the app may not log full alert configs — see ReportController::checkSchedule)"
  exit 0
fi

echo "--- All alert recipients (deduped per id) ---"
python3 - "$TMP" "${INTERNAL_DOMAINS[@]}" <<'PY'
import sys, re, json
path = sys.argv[1]
internal = set(d.lower() for d in sys.argv[2:])

def addrs(s):
    return [a.lower() for a in re.findall(r'[A-Za-z0-9._+\-]+@[A-Za-z0-9.\-]+', s or "")]

seen = {}
for line in open(path):
    m = re.search(r'"id":(\d+)', line); aid = int(m.group(1)) if m else None
    n = re.search(r'"alert_name":"([^"]*)"', line); name = n.group(1) if n else ""
    to = re.search(r'"emails_to":"((?:\\"|[^"])*)"', line); to = to.group(1) if to else ""
    cc = re.search(r'"emails_cc":"((?:\\"|[^"])*)"', line); cc = cc.group(1) if cc else ""
    bc = re.search(r'"emails_bcc":"((?:\\"|[^"])*)"', line); bc = bc.group(1) if bc else ""
    if aid is None: continue
    seen.setdefault(aid, {"name": name, "to": set(), "cc": set(), "bcc": set()})
    seen[aid]["to"].update(addrs(to))
    seen[aid]["cc"].update(addrs(cc))
    seen[aid]["bcc"].update(addrs(bc))

flags = []
for aid, info in sorted(seen.items()):
    print(f"  id={aid}  name={info['name']!r}")
    for k in ("to","cc","bcc"):
        for a in sorted(info[k]):
            label = ""
            dom = a.rsplit("@",1)[-1]
            if internal and dom not in internal:
                label = "  [EXTERNAL]"
                if dom in ("gmail.com","yahoo.com","outlook.com","hotmail.com","proton.me","protonmail.com"):
                    label = "  [PERSONAL]"
            print(f"    {k.upper():3}  {a}{label}")
    overlap = (info["to"] & info["cc"] & info["bcc"])
    if overlap:
        flags.append((aid, info["name"], sorted(overlap)))
    print()
print()
if flags:
    print("=== UNUSUAL: same address in TO + CC + BCC simultaneously ===")
    for aid, name, addrs2 in flags:
        print(f"  alert id={aid}  name={name!r}  addresses={addrs2}")
PY

echo
echo "=== END EMAIL ALERTS AUDIT ==="
