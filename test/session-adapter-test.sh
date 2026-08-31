#!/usr/bin/env bash
# session-adapter-test.sh — MSF session + operator pane session adapter (offline).
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_TEST_NONINTERACTIVE=1

# shellcheck source=test-helper.sh
source "${NEO_ROOT}/test/test-helper.sh"
# shellcheck source=../lib/neo-core.sh
source "${NEO_ROOT}/lib/neo-core.sh"
# shellcheck source=../lib/neo-mission-state.sh
source "${NEO_ROOT}/lib/neo-mission-state.sh"
# shellcheck source=../lib/neo-exploit-framework.sh
source "${NEO_ROOT}/lib/neo-exploit-framework.sh"
# shellcheck source=../lib/neo-operator-pane.sh
source "${NEO_ROOT}/lib/neo-operator-pane.sh"
# shellcheck source=../lib/neo-pipeline-hooks.sh
source "${NEO_ROOT}/lib/neo-pipeline-hooks.sh"

tmp="$(mktemp -d /tmp/neo-session-adapter.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf -- "${tmp}"' EXIT

printf 'session-adapter-test.sh\n\n'

export NEO_STATE_ROOT="${tmp}"

assert_true 'mission init' neo_mission_init adapter-box 10.10.10.5 "${NEO_STATE_ROOT}/projects"
assert_true 'to foothold planning' neo_mission_transition foothold_planning 'test setup'
assert_true 'handler plan' neo_mission_record_handler_plan 10.10.14.9 4444 linux/x64/meterpreter/reverse_tcp msf

assert_true 'record msf session' neo_mission_record_msf_session 3 msf_meterpreter linux/x64/meterpreter/reverse_tcp
[[ "$(jq -r '.session.msf_session_id' "${NEO_MISSION_FILE}")" == "3" ]] \
    && pass 'msf session id saved' || fail 'msf session id'
[[ "$(neo_mission_current_state)" == session_established ]] \
    && pass 'auto transition to session_established' || fail 'state after msf session'

search="$(neo_msf_search_command 'cve:2021' 2>/dev/null || true)"
[[ "${search}" == *search* && "${search}" == *cve:2021* ]] \
    && pass 'msf search command' || fail 'msf search command'

catalog="$(neo_msf_post_module_catalog | wc -l | tr -d ' ')"
(( catalog >= 4 )) && pass 'post module catalog' || fail 'post module catalog'

post_cmd="$(neo_msf_post_module_command 2 getuid 2>/dev/null || true)"
[[ "${post_cmd}" == *sessions\ -i\ 2* && "${post_cmd}" == *getuid* ]] \
    && pass 'post module with session id' || fail 'post module command'

neo_operator_pane_offer_session_connect adapter-box
pass 'session connect skipped non-interactive'

neo_pipeline_offer_msf_post adapter-box
pass 'msf post menu skipped non-interactive'

assert_true 'session context check' neo_pipeline_mission_has_session_context adapter-box

bash -n "${NEO_ROOT}/lib/neo-operator-pane.sh" && pass 'syntax operator-pane' || fail 'syntax operator-pane'

finish_tests
