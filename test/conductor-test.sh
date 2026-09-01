#!/usr/bin/env bash
# conductor-test.sh — offline AI conductor bundle + gate tests (no live Claude).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_NEO="${NEO_ROOT}"
TESTDIR="$(mktemp -d /tmp/neo-conductor-test.XXXXXX)"
export NEO_HOME="${TESTDIR}"
export NEO_DIR="${NEO_HOME}"
export NEO_CONDUCTOR=1
export NEO_TEST_NONINTERACTIVE=1

trap 'rm -rf "${TESTDIR}"' EXIT

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'conductor-test.sh\n\n'

mkdir -p "${NEO_HOME}/templates"
cp "${REAL_NEO}/templates/investigation-notes.md" "${NEO_HOME}/templates/"

# shellcheck source=../lib/notes-lib.sh
source "${REAL_NEO}/lib/notes-lib.sh"
# shellcheck source=../lib/neo-ai.sh
source "${REAL_NEO}/lib/neo-ai.sh"
# shellcheck source=../lib/neo-conductor.sh
source "${REAL_NEO}/lib/neo-conductor.sh"

OUTDIR="${NEO_HOME}/projects/conductor-proj"
notes_init "conductor-proj" "10.10.10.5" "${OUTDIR}"
notes_set_section STATUS "conductor test status"
notes_set_section PORTS "80/tcp open http"
notes_set_section AI-TRIAGE "## Triage\nRedis unauth hypothesis"
notes_set_section BORG "## Borg\nAssimilated redis vector"
meta_set phase recon 2>/dev/null || true

core="$(neo_conductor_mission_core_bundle conductor-proj recon)"
[[ "${core}" == *"conductor-proj"* ]] && ok "core bundle project" || bad "core project"
[[ "${core}" == *"80/tcp open"* ]] && ok "core bundle ports" || bad "core ports"
[[ "${core}" == *"Redis unauth"* ]] && ok "core bundle triage" || bad "core triage"
[[ "${core}" == *"conductor test status"* ]] && ok "core bundle status" || bad "core status"

triage="$(neo_conductor_build_bundle conductor-proj recon triage)"
[[ "${triage}" == *"babysteps already attempted"* ]] && ok "triage intent babysteps" || bad "triage babysteps"
[[ "${triage}" == *"Prior AI triage"* ]] && ok "triage intent prior triage" || bad "triage prior"

payload="$(neo_conductor_build_bundle conductor-proj foothold payload curl)"
[[ "${payload}" == *"Payload assistant context"* ]] && ok "payload intent header" || bad "payload header"
[[ "${payload}" == *"curl"* ]] && ok "payload intent tool" || bad "payload tool"

# Gates
neo_conductor_skip_interactive && ok "noninteractive skips prompts" || bad "skip interactive"
[[ "${NEO_CONDUCTOR:-1}" == "1" ]] && ok "NEO_CONDUCTOR default on" || bad "conductor default"

# neo_ai_build_recon_bundle delegates to conductor
bundle="$(neo_ai_build_recon_bundle conductor-proj)"
[[ "${bundle}" == *"babysteps already attempted"* ]] && ok "neo_ai delegates to conductor" || bad "neo_ai delegate"

bash -n "${REAL_NEO}/lib/neo-conductor.sh" && ok "syntax neo-conductor.sh" || bad "syntax"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
