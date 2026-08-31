#!/usr/bin/env bash
set -uo pipefail

NEO_NEXT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${NEO_NEXT_ROOT}/test/test-helper.sh"
source "${NEO_NEXT_ROOT}/lib/neo-core.sh"
source "${NEO_NEXT_ROOT}/lib/neo-actions.sh"

tmp="$(mktemp -d /tmp/neo-next-action.XXXXXX)"
trap 'rm -rf -- "${tmp}"' EXIT
service="${tmp}/service.json"
cat > "${service}" <<'JSON'
{"host":"10.10.10.10","port":443,"protocol":"tcp","service":"https","tls":true,"product":"nginx","version":null,"evidence_ref":"event-1"}
JSON

if bash "${NEO_NEXT_ROOT}/enumerators/plan-enum.sh" --service "${service}" --output-dir "${tmp}/plan" >/dev/null; then
    pass 'HTTPS enumeration plan generated'
else
    fail 'HTTPS enumeration plan generation failed'
fi
files=("${tmp}/plan"/*.json)
((${#files[@]} == 2)) && pass 'HTTPS planner emitted two focused actions' || fail "expected 2 actions, found ${#files[@]}"
for file in "${files[@]}"; do
    assert_true "action valid: $(basename "${file}")" neo_action_validate "${file}"
    [[ "$(jq -r '.execution.mode' "${file}")" == advisory ]] && pass 'generated action is advisory' || fail 'generated action not advisory'
done

grep -R -n -E '(^|[^A-Za-z])eval[[:space:]]' "${NEO_NEXT_ROOT}/lib" "${NEO_NEXT_ROOT}/enumerators" >/dev/null 2>&1 \
    && fail 'prototype contains eval execution' || pass 'prototype contains no eval execution'

finish_tests
