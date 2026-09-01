#!/usr/bin/env bash
# Offline scope JSON validation (Tier 2).
set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=test-helper.sh
source "${NEO_ROOT}/test/test-helper.sh"
# shellcheck source=../lib/neo-core.sh
source "${NEO_ROOT}/lib/neo-core.sh"
# shellcheck source=../lib/neo-scope.sh
source "${NEO_ROOT}/lib/neo-scope.sh"

tmp="$(mktemp -d /tmp/neo-scope-test.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf -- "${tmp}"' EXIT
export NEO_STATE_ROOT="${tmp}/state"

scope_file="${NEO_STATE_ROOT}/projects/labbox/engagement-scope.json"
neo_core_secure_dir "$(dirname "${scope_file}")"
jq -n \
    --arg project labbox --arg now "$(neo_core_iso_timestamp)" \
    '{
      schema_version: 1, mode: "educational", created_at: $now, project: "labbox",
      platform: "htb", purpose: "Tier 2 test box",
      attestation: {phrase: "authorized-lab", confirmed_at: $now},
      in_scope: {hosts: ["10.10.10.5"], networks: ["10.10.10.0/23"], domains: [], ports: ["1-65535"]},
      exclusions: [], authorization: null, pending_targets: [], expansions: []
    }' > "${scope_file}"

assert_true 'scope loads' neo_scope_load labbox "${NEO_STATE_ROOT}/projects"
assert_true 'target in scope' neo_scope_target_allowed '10.10.10.5'
assert_false 'OOS host blocked' neo_scope_target_allowed '192.168.1.1'

[[ -f "${NEO_ROOT}/tools/scope-intake.sh" ]] && pass 'scope-intake.sh present' || fail 'scope-intake.sh missing'
[[ -f "${NEO_ROOT}/tools/scope-import.sh" ]] && pass 'scope-import.sh present' || fail 'scope-import.sh missing'
bash -n "${NEO_ROOT}/foothold/ListenAssist.sh" && pass 'ListenAssist.sh syntax' || fail 'ListenAssist syntax'
bash -n "${NEO_ROOT}/privesc/run-findprivs.sh" && pass 'run-findprivs.sh syntax' || fail 'run-findprivs syntax'

bs_lines="$(wc -l < "${NEO_ROOT}/foothold/ListenAssist.sh" | tr -d ' ')"
(( bs_lines >= 40 )) && pass "ListenAssist substantive (${bs_lines} lines)" || fail "ListenAssist too short (${bs_lines})"

finish_tests
