#!/usr/bin/env bash
set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=test-helper.sh
source "${NEO_ROOT}/test/test-helper.sh"
# shellcheck source=../lib/neo-core.sh
source "${NEO_ROOT}/lib/neo-core.sh"
# shellcheck source=../lib/neo-mission-state.sh
source "${NEO_ROOT}/lib/neo-mission-state.sh"

tmp="$(mktemp -d /tmp/neo-mission-state.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf -- "${tmp}"' EXIT

assert_true 'mission initialized' neo_mission_init test-box 10.10.10.10 "${tmp}"
[[ "$(neo_mission_current_state)" == preflight ]] && pass 'initial state is preflight' || fail 'wrong initial state'
assert_false 'invalid phase jump rejected' neo_mission_transition privileged 'illegal jump'
assert_true 'preflight to recon' neo_mission_transition recon 'VPN and target checks complete'
assert_false 'invalid try_transition rejected' neo_mission_try_transition privileged 'bad jump'
assert_true 'try_transition idempotent at recon' neo_mission_try_transition recon 'noop'
assert_true 'recon to operator recon' neo_mission_transition operator_recon 'automated recon complete'
assert_true 'operator recon to triage' neo_mission_transition triage 'operator evidence saved'
assert_true 'triage to Borg offer' neo_mission_transition borg_offer 'initial dossier ready'
assert_true 'Borg skip to foothold planning' neo_mission_transition foothold_planning 'operator skipped assimilation'
assert_true 'handler plan recorded' neo_mission_record_handler_plan 10.10.14.2 4444 linux/x64/meterpreter/reverse_tcp msf
[[ "$(jq -r '.handler_plan.lhost' "${NEO_MISSION_FILE}")" == 10.10.14.2 ]] \
    && pass 'handler plan lhost saved' || fail 'handler plan missing'
assert_true 'to foothold attempt' neo_mission_transition foothold_attempt 'test try'
assert_true 'to session established' neo_mission_transition session_established 'shell obtained'
assert_true 'ssh session recorded' neo_mission_record_session ssh www-data 10.10.10.10 bash
[[ "$(jq -r '.session.transport' "${NEO_MISSION_FILE}")" == ssh ]] \
    && pass 'ssh transport saved' || fail 'ssh session'
assert_true 'msf session recorded' neo_mission_record_msf_session 7 msf_meterpreter linux/x64/meterpreter/reverse_tcp
[[ "$(jq -r '.session.msf_session_id' "${NEO_MISSION_FILE}")" == "7" ]] \
    && pass 'msf session id in record_msf' || fail 'msf session id'
[[ "$(jq '.history|length' "${NEO_MISSION_FILE}")" -eq 8 ]] && pass 'transition history appended' || fail 'history length mismatch'

finish_tests
