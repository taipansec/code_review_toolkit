# PHP Laravel Security Review Scripts

A small bundle of self-contained shell scripts for performing a fast, repeatable
static security review of a Laravel / PHP application. No network access
required — everything runs locally against the project tree.

The scripts are deliberately simple (`grep` / `find` / `unzip` / a couple of
inline Python blocks) so they're easy to read, modify, and run anywhere with a
POSIX shell, Python 3, and standard CLI tools.

## What this is good for

- A quick first-pass review of an unfamiliar Laravel application.
- An incident-response triage on a production tree (especially if you suspect
  information disclosure).
- Building blocks for a CI security gate.
- Pre-deployment sanity checks.

## What this is not

- A replacement for `composer audit`, `npm audit`, SAST tools (Psalm/Phan/PHPStan
  with security rules), or a real code review.
- A dynamic / runtime test. Everything is static analysis of files on disk.
- Comprehensive. The scripts target the most common findings, not every
  possible CWE.

## Requirements

- Bash, `grep` (GNU or BSD), `find`, `unzip`, `awk`, `sed`
- Python 3 (used by `05_dep_audit.sh` and `07_email_alerts_audit.sh`)
- Node.js + npm (only if you want to use `build_report.js` to generate a Word
  report)

## Usage

```bash
cd /path/to/your/laravel/project

bash security_review_scripts/01_recon.sh .                              | tee 01_recon.txt
bash security_review_scripts/02_backdoor_hunt.sh .                      | tee 02_backdoor.txt
bash security_review_scripts/03_web_vuln_scan.sh .                      | tee 03_webvuln.txt
bash security_review_scripts/04_secrets.sh .                            | tee 04_secrets.txt
bash security_review_scripts/05_dep_audit.sh .                          | tee 05_deps.txt
bash security_review_scripts/06_log_triage.sh .                         | tee 06_logs.txt
bash security_review_scripts/07_email_alerts_audit.sh . example.com     | tee 07_alerts.txt
bash security_review_scripts/08_email_search.sh . someone@example.com   | tee 08_email.txt
```

To build the (optional) Word report:

```bash
cd security_review_scripts
npm install docx
node build_report.js
```

## What each script does

| Script | Purpose |
|---|---|
| `01_recon.sh` | Project layout, root-level artifacts, `.env` / `.git` / large logs, web-root indicators, deployment hints from `.bat` / `.sh` / `.conf` files. |
| `02_backdoor_hunt.sh` | Greps PHP for `eval`, `assert`, `base64_decode + exec`, `shell_exec`, `popen`, `proc_open`, `passthru`, `preg_replace /e`, dynamic `$$variable` use, suspicious files at the web root. |
| `03_web_vuln_scan.sh` | SQLi (`DB::raw`, `whereRaw`, `orderByRaw`, raw `DB::select`/`statement`), Blade XSS (`{!! !!}`), unrestricted file upload patterns, mass assignment, `$_POST` / `$_FILES` iteration, unauth API routes, IDOR-shaped `::find($id)` calls, `file_get_contents` on user-influenced URLs (SSRF). |
| `04_secrets.sh` | Lists `.env` keys (values redacted), scans for hardcoded API keys (AWS, Stripe, GitHub PAT, Slack, Google), Gmail App Password format, generic credential patterns; reports `.gitignore` coverage and whether `.env` was ever committed. |
| `05_dep_audit.sh` | Reads `composer.lock` and `package-lock.json`, prints versions, flags any package pinned to `dev-master` / `dev-main` / `@dev`. Includes a small hardcoded list of recent vulnerable versions you can extend; for live advisories run `composer audit` / `npm audit`. |
| `06_log_triage.sh` | Sizes and content-profile every `*.log` and `storage/logs/*.log`. Counts ERROR / Exception lines, lists distinct email recipients, scans for credentials / Bearer tokens / Gmail App Password format leaking into logs. |
| `07_email_alerts_audit.sh` | If your app logs `email_alerts` row dumps to `storage/logs/`, this extracts the recipient sets, dedups per alert id, flags any alert where the same address appears in TO + CC + BCC simultaneously, flags external / personal mailbox recipients vs. the corporate domains you pass on the command line. |
| `08_email_search.sh` | Exhaustive search for a specific email address across source, logs, CSVs, and inside `.xlsx` archives (`xl/sharedStrings.xml`). Also checks base64 and URL-encoded forms. |
| `build_report.js` | Node.js generator that builds a Word security review (uses [`docx`](https://www.npmjs.com/package/docx)). Edit the findings array to match your own audit. |

## Configuration

A few scripts take environment variables:

- `06_log_triage.sh` — `MAX_BYTES=...` caps the per-file content scan (default
  200 MB). Useful on multi-GB log files.
- `08_email_search.sh` — `MAX_XLSX=N` caps the number of `.xlsx` archives walked
  (default 100,000).

`07_email_alerts_audit.sh` takes one or more internal corporate domains as
positional arguments after the project root, so it can flag external
recipients, e.g. `bash 07_email_alerts_audit.sh . acme.com acme.co.uk`.

## Notes

- All scripts are read-only. They never modify the codebase, the database, or
  any log file.
- The dependency check in `05_dep_audit.sh` does not call out to the network.
  The list of known-vulnerable versions is intentionally small and hardcoded —
  treat it as a starter, not as authoritative. Run `composer audit` and
  `npm audit` for current advisories.
- These scripts target Laravel conventions (routing, Blade, `DB::` facade,
  `storage/logs/laravel.log`). They will still produce some signal on plain
  PHP applications, but the assumptions in `03_web_vuln_scan.sh` and
  `07_email_alerts_audit.sh` are Laravel-specific.

## License

MIT — do whatever you want with this. No warranty.
