#!/usr/bin/env bash
# conductor-automation-test.sh — Tier B playbook state + mode resolution (offline).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_NEO="${NEO_ROOT}"
TESTDIR="$(mktemp -d /tmp/neo-conductor-auto-test.XXXXXX)"
export NEO_HOME="${TESTDIR}"
export NEO_DIR="${NEO_HOME}"
export NEO_STATE_ROOT="${TESTDIR}/state"
export NEO_CONDUCTOR=1
export NEO_TEST_NONINTERACTIVE=1

trap 'rm -rf "${TESTDIR}"' EXIT

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'conductor-automation-test.sh\n\n'

mkdir -p "${NEO_HOME}/templates"
cp "${REAL_NEO}/templates/investigation-notes.md" "${NEO_HOME}/templates/"

# shellcheck source=../lib/notes-lib.sh
source "${REAL_NEO}/lib/notes-lib.sh"
# shellcheck source=../lib/neo-mission-state.sh
source "${REAL_NEO}/lib/neo-mission-state.sh"
# shellcheck source=../lib/neo-conductor.sh
source "${REAL_NEO}/lib/neo-conductor.sh"

OUTDIR="${NEO_HOME}/projects/auto-proj"
notes_init "auto-proj" "10.10.10.9" "${OUTDIR}"

mode="$(neo_conductor_resolve_mode auto-proj)"
[[ "${mode}" == "guided" ]] && ok "default mode guided (no engagement_mode)" || bad "default guided got ${mode}"

meta_set engagement_mode professional 2>/dev/null || true
mode="$(neo_conductor_resolve_mode auto-proj)"
[[ "${mode}" == "assisted" ]] && ok "professional → assisted" || bad "professional mode got ${mode}"

meta_set engagement_mode educational 2>/dev/null || true
mode="$(neo_conductor_resolve_mode auto-proj)"
[[ "${mode}" == "guided" ]] && ok "educational → guided" || bad "educational mode got ${mode}"

meta_set conductor_mode assisted 2>/dev/null || true
mode="$(neo_conductor_resolve_mode auto-proj)"
[[ "${mode}" == "assisted" ]] && ok "meta conductor_mode override" || bad "override failed"

neo_mission_init auto-proj "10.10.10.9" "${NEO_STATE_ROOT}/projects" || bad "mission init"
neo_mission_open auto-proj "${NEO_STATE_ROOT}/projects" || bad "mission open"
neo_mission_conductor_patch mode assisted
neo_mission_conductor_patch_int max_loops 5
neo_mission_conductor_patch_int loop_count 2
got="$(neo_mission_conductor_get max_loops 0)"
[[ "${got}" == "5" ]] && ok "conductor max_loops in mission.json" || bad "max_loops ${got}"
got="$(neo_mission_conductor_get loop_count 0)"
[[ "${got}" == "2" ]] && ok "conductor loop_count" || bad "loop_count ${got}"

batch="$(neo_conductor_build_bundle auto-proj foothold analyze-failures-batch)"
[[ "${batch}" == *"mission bundle"* ]] && ok "analyze-failures-batch intent" || bad "batch bundle"

priv="$(neo_conductor_build_bundle auto-proj privesc privesc-triage)"
[[ "${priv}" == *"SUDO"* || "${priv}" == *"mission bundle"* ]] && ok "privesc-triage intent" || bad "privesc bundle"

[[ "$(neo_conductor_loop_default_max auto-proj foothold)" == "3" ]] && ok "foothold default max loops 3" || bad "foothold max"
[[ "$(neo_conductor_loop_default_max auto-proj privesc)" == "4" ]] && ok "privesc default max loops 4" || bad "privesc max"

core="$(neo_conductor_mission_core_bundle auto-proj recon)"
[[ "${core}" == *"SERVICES"* && "${core}" == *"mission.json"* ]] \
    && ok "expanded mission core bundle" || bad "mission core sections"

# shellcheck source=../lib/neo-conductor-loop.sh
source "${REAL_NEO}/lib/neo-conductor-loop.sh"
meta_set engagement_mode professional 2>/dev/null || true
neo_conductor_assisted_loop_enabled auto-proj && ok "assisted loop enabled (professional)" || bad "assisted loop"
meta_set engagement_mode educational 2>/dev/null || true
neo_conductor_assisted_loop_enabled auto-proj && bad "assisted loop should be off for guided" || ok "guided skips assisted loop"

export NEO_TEST_NONINTERACTIVE=1
neo_conductor_on_phase_entry auto-proj recon >/dev/null && ok "phase entry recon no-op" || bad "phase entry recon"
neo_conductor_on_phase_entry auto-proj foothold >/dev/null && ok "phase entry foothold noninteractive" || bad "phase entry foothold"

# shellcheck source=../lib/neo-adaptive-scan.sh
source "${REAL_NEO}/lib/neo-adaptive-scan.sh"
notes_set_section PORTS $'```text\n22/tcp open ssh\n80/tcp open http\n```' 2>/dev/null || true
targets="$(neo_adaptive_scan_build_targets_file auto-proj 2>/dev/null || true)"
[[ -n "${targets}" && -f "${targets}" ]] && ok "adaptive deep-targets file" || bad "adaptive targets"

export NEO_CONDUCTOR_MODE=aggressive
mode="$(neo_conductor_resolve_mode auto-proj)"
[[ "${mode}" == "assisted" ]] && ok "aggressive falls back to assisted" || bad "aggressive fallback got ${mode}"
unset NEO_CONDUCTOR_MODE

bash -n "${REAL_NEO}/lib/neo-adaptive-scan.sh" && ok "syntax neo-adaptive-scan.sh" || bad "syntax adaptive"
bash -n "${REAL_NEO}/lib/neo-operator-recon-ai.sh" && ok "syntax neo-operator-recon-ai.sh" || bad "syntax op-recon-ai"
bash -n "${REAL_NEO}/recon/babysteps.sh" && ok "syntax babysteps.sh" || bad "syntax babysteps"
bash -n "${REAL_NEO}/lib/neo-conductor-privesc.sh" && ok "syntax neo-conductor-privesc.sh" || bad "syntax privesc"
bash -n "${REAL_NEO}/lib/neo-handler-pane.sh" && ok "syntax neo-handler-pane.sh" || bad "syntax handler"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
