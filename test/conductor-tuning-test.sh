#!/usr/bin/env bash
# conductor-tuning-test.sh — offline defaults for conductor / enum-AI / workbench tuning.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTDIR="$(mktemp -d /tmp/neo-conductor-tuning-test.XXXXXX)"
export NEO_HOME="${TESTDIR}"
export NEO_DIR="${NEO_HOME}"
export NEO_STATE_ROOT="${TESTDIR}/state"
export NEO_TEST_NONINTERACTIVE=1

trap 'rm -rf "${TESTDIR}"' EXIT

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'conductor-tuning-test.sh\n\n'

mkdir -p "${NEO_HOME}/templates"
cp "${NEO_ROOT}/templates/investigation-notes.md" "${NEO_HOME}/templates/"

# shellcheck source=../lib/notes-lib.sh
source "${NEO_ROOT}/lib/notes-lib.sh"
# shellcheck source=../lib/neo-conductor.sh
source "${NEO_ROOT}/lib/neo-conductor.sh"
# shellcheck source=../lib/neo-conductor-tuning.sh
source "${NEO_ROOT}/lib/neo-conductor-tuning.sh"

OUTDIR="${NEO_HOME}/projects/tune-proj"
notes_init "tune-proj" "10.10.10.7" "${OUTDIR}"

[[ "$(neo_conductor_loop_max_for_phase tune-proj foothold)" == "3" ]] \
    && ok "foothold default max loops 3" || bad "foothold max"
[[ "$(neo_conductor_loop_max_for_phase tune-proj privesc)" == "4" ]] \
    && ok "privesc default max loops 4" || bad "privesc max"

export NEO_CONDUCTOR_MAX_LOOPS=7
[[ "$(neo_conductor_loop_max_for_phase tune-proj foothold)" == "7" ]] \
    && ok "NEO_CONDUCTOR_MAX_LOOPS env override" || bad "env max loops"
unset NEO_CONDUCTOR_MAX_LOOPS

meta_set conductor_max_loops 6 2>/dev/null || true
[[ "$(neo_conductor_loop_max_for_phase tune-proj foothold)" == "6" ]] \
    && ok "meta conductor_max_loops" || bad "meta max"

meta_set engagement_mode professional 2>/dev/null || true
[[ "$(neo_conductor_enum_ai_policy tune-proj)" == "auto" ]] \
    && ok "professional/assisted enum AI auto" || bad "enum auto"
neo_conductor_auto_try_enabled tune-proj && ok "auto try assisted" || bad "auto try"

meta_set engagement_mode educational 2>/dev/null || true
[[ "$(neo_conductor_enum_ai_policy tune-proj)" == "prompt" ]] \
    && ok "educational enum AI prompt" || bad "enum prompt"

export NEO_ENUM_AI=auto
[[ "$(neo_conductor_enum_ai_policy tune-proj)" == "auto" ]] \
    && ok "NEO_ENUM_AI=auto override" || bad "enum env override"
unset NEO_ENUM_AI

[[ "$(neo_conductor_workbench_wait_sec operator_pane true)" == "60" ]] \
    && ok "operator pane wait 60s" || bad "operator wait"
[[ "$(neo_conductor_workbench_wait_sec local_safe true)" == "8" ]] \
    && ok "local_safe wait 8s" || bad "local wait"

bash -n "${NEO_ROOT}/lib/neo-conductor-tuning.sh" && ok "syntax tuning" || bad "syntax"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
