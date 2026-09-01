#!/usr/bin/env bash
# interact-test.sh — pre-foothold web detector (neo-interact.sh), offline.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/notes-lib.sh
source "${NEO_DIR}/lib/notes-lib.sh"
# shellcheck source=../lib/neo-interact.sh
source "${NEO_DIR}/lib/neo-interact.sh"

pass=0
fail=0
WORKDIR="$(mktemp -d /tmp/neo-interact-test.XXXXXX)"
trap 'rm -rf "${WORKDIR}"' EXIT

ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

PROJECT="interact-test-box"
OUTDIR="${WORKDIR}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
mkdir -p "${OUTDIR}"
notes_init "${PROJECT}" "10.0.0.1" "${OUTDIR}"

printf 'interact-test.sh\n\n'

# Template-only notes — no web signal
neo_interact_detect_web && bad "template-only notes should not detect web" \
    || ok "no false positive on empty template ports"

notes_set_section PORTS $'22/tcp open ssh' || bad "set PORTS"
neo_interact_detect_web && bad "ssh-only should not detect web" \
    || ok "no false positive on ssh-only"

notes_set_section PORTS $'22/tcp open ssh\n3000/tcp open unknown' || bad "set PORTS 3000"
neo_interact_detect_web && ok "detects unusual web port :3000" \
    || bad "missed :3000 in PORTS"

notes_set_section SERVICES $'### Web — http://10.0.0.1:3000\n_Discovered: test_' || bad "set SERVICES"
neo_interact_detect_web && ok "detects ### Web — URL in SERVICES" \
    || bad "missed SERVICES web header"

# Regression: nmap prints "Starting Nmap ... ( https://nmap.org )" and a
# "https://nmap.org/submit/" line in its banner/comment text on every single scan,
# unconditionally — an earlier detector version matched a bare https?:// URL against
# NMAP+LOG combined, which meant it false-positived as "web server found" on every
# mission ever run, including SSH-only boxes with zero web services.
notes_set_section PORTS $'22/tcp open ssh' || bad "reset PORTS to ssh-only"
notes_set_section SERVICES '' || bad "reset SERVICES"
notes_set_section NMAP "$(cat <<'EOF'
Starting Nmap 7.991 ( https://nmap.org ) at 2026-08-30 20:55 -0400
Nmap scan report for 10.0.0.1
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.2p1
Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
EOF
)" || bad "set NMAP banner-only"
neo_interact_detect_web && bad "false positive: nmap's own banner URL should not trigger web detection" \
    || ok "no false positive on nmap's own banner/comment URLs"

# Regression: babysteps' real log line is literally "HTTP(S) service confirmed..." with
# unescaped parens — an earlier detector regex (`HTTP(S)? service confirmed`, parens as
# unescaped grouping) never actually matched this string; only worked by accident via the
# broader (now-removed) generic URL/keyword check.
notes_set_section PORTS $'22/tcp open ssh' || bad "reset PORTS for log-marker test"
notes_set_section LOG 'HTTP(S) service confirmed on port 3000 (http)' || bad "set LOG marker"
neo_interact_detect_web && ok "detects babysteps' literal HTTP(S) service confirmed log line" \
    || bad "log-marker regex still does not match babysteps' real output string"

bash -n "${NEO_DIR}/lib/neo-interact.sh" && ok "syntax: lib/neo-interact.sh" || bad "syntax: lib/neo-interact.sh"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
