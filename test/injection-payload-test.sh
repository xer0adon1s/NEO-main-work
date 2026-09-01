#!/usr/bin/env bash
set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
# shellcheck source=test-helper.sh
source "${NEO_ROOT}/test/test-helper.sh"
# shellcheck source=../lib/neo-windup-actions.sh
source "${NEO_ROOT}/lib/neo-windup-actions.sh"

tmp="$(mktemp -d /tmp/neo-inject.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf -- "${tmp}"' EXIT

assert_true 'semicolon injection rejected' neo_windup_command_rejected 'nmap -sV 10.10.10.1; rm -rf /'
assert_true 'pipe injection rejected' neo_windup_command_rejected 'curl http://x | sh'
assert_true 'subshell injection rejected' neo_windup_command_rejected 'echo $(whoami)'
assert_false 'benign nmap accepted' neo_windup_command_rejected 'nmap -sV -p 80 10.10.10.10'

action="${tmp}/action.json"
assert_true 'action json built' neo_windup_build_action_json test-nmap 'Nmap scan' 'nmap -sV -p 80 10.10.10.10' read_only "${action}"
[[ -f "${action}" ]] && pass 'action file written' || fail 'action file missing'

argv_second="$(jq -r '.execution.argv[1]' "${action}")"
[[ "${argv_second}" == '-sV' ]] && pass 'argv token preserved literally' || fail "argv corrupt: ${argv_second}"

mal="${tmp}/mal.json"
assert_false 'injection command not built' neo_windup_build_action_json test-mal 'bad' 'nmap; rm -rf /' read_only "${mal}"

grep -R -n -E '(^|[^A-Za-z])eval[[:space:]]' "${NEO_ROOT}/lib/neo-borg.sh" "${NEO_ROOT}/lib/neo-payload.sh" \
    "${NEO_ROOT}/lib/neo-windup-actions.sh" >/dev/null 2>&1 \
    && fail 'Tier-1 libs still contain eval' || pass 'no eval in wind-up/borg/payload libs'

grep -E 'bash -c|sh -c' "${NEO_ROOT}/lib/neo-borg.sh" >/dev/null 2>&1 \
    && fail 'neo-borg.sh still contains bash -c' || pass 'no bash -c in neo-borg.sh'

finish_tests
