#!/usr/bin/env bash
set -uo pipefail

NEO_NEXT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${NEO_NEXT_ROOT}/test/test-helper.sh"
source "${NEO_NEXT_ROOT}/lib/neo-core.sh"
source "${NEO_NEXT_ROOT}/lib/neo-mission-state.sh"

tmp="$(mktemp -d /tmp/neo-next-state.XXXXXX)"
trap 'rm -rf -- "${tmp}"' EXIT

assert_true 'mission initialized' neo_mission_init test-box 10.10.10.10 "${tmp}"
[[ "$(neo_mission_current_state)" == preflight ]] && pass 'initial state is preflight' || fail 'wrong initial state'
assert_false 'invalid phase jump rejected' neo_mission_transition privileged 'illegal jump'
assert_true 'preflight to recon' neo_mission_transition recon 'VPN and target checks complete'
assert_true 'recon to operator recon' neo_mission_transition operator_recon 'automated recon complete'
assert_true 'operator recon to triage' neo_mission_transition triage 'operator evidence saved'
assert_true 'triage to Borg offer' neo_mission_transition borg_offer 'initial dossier ready'
assert_true 'Borg skip to foothold planning' neo_mission_transition foothold_planning 'operator skipped assimilation'
[[ "$(jq '.history|length' "${NEO_MISSION_FILE}")" -eq 6 ]] && pass 'transition history appended' || fail 'history length mismatch'

finish_tests
