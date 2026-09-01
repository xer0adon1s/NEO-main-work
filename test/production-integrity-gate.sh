#!/usr/bin/env bash
# Release gate for the production source tree. Expected to fail until Wave 3 stubs are replaced.
set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-${NEO_ROOT}}"
# shellcheck source=test-helper.sh
source "${NEO_ROOT}/test/test-helper.sh"

require_substantive_script() {
    local rel="$1" min_lines="$2" required_pattern="$3" count
    local file="${NEO_SOURCE_ROOT}/${rel}"
    if [[ ! -f "${file}" ]]; then fail "production file missing: ${rel}"; return; fi
    count="$(wc -l < "${file}" | tr -d ' ')"
    (( count >= min_lines )) && pass "${rel} has substantive length" || fail "${rel} is only ${count} lines; expected >=${min_lines}"
    grep -qE "${required_pattern}" "${file}" && pass "${rel} contains required behavior marker" \
        || fail "${rel} lacks required behavior marker: ${required_pattern}"
    grep -qiE 'smoke stub|Smoke privesc path|stub — real script' "${file}" \
        && fail "${rel} contains smoke/stub content" || pass "${rel} contains no smoke/stub marker"
}

require_substantive_script foothold/ListenAssist.sh 40 'ncat|socat|nc '
require_substantive_script privesc/run-findprivs.sh 30 'ssh|ingest|FindPrivs.sh'
require_substantive_script recon/babysteps.sh 300 'nmap.*-sC.*-sV'

if grep -qE '^\.env($|\.)|^\.env\*' "${NEO_SOURCE_ROOT}/.gitignore"; then
    pass '.gitignore excludes repository .env files'
else
    fail '.gitignore does not exclude repository .env files'
fi

if grep -E 'ANTHROPIC_API_KEY|OPENAI_API_KEY|GEMINI_API_KEY' \
    "${NEO_SOURCE_ROOT}/lib/neo-tmux.sh" >/dev/null 2>&1; then
    fail 'API key is listed for tmux command forwarding'
else
    pass 'API key is not forwarded through tmux command construction'
fi

if grep -R -n -E '(^|[^A-Za-z])eval[[:space:]]' \
    "${NEO_SOURCE_ROOT}/lib/neo-borg.sh" "${NEO_SOURCE_ROOT}/lib/neo-payload.sh" \
    "${NEO_SOURCE_ROOT}/lib/neo-windup-actions.sh" >/dev/null 2>&1; then
    fail 'eval still present in Borg/payload/wind-up libs'
else
    pass 'no eval in Borg/payload/wind-up libs'
fi

if grep -E 'bash -c|sh -c' "${NEO_SOURCE_ROOT}/lib/neo-borg.sh" >/dev/null 2>&1; then
    fail 'bash -c still present in neo-borg.sh'
else
    pass 'no bash -c in neo-borg.sh'
fi

[[ -f "${NEO_SOURCE_ROOT}/tools/neo-secret.sh" ]] && pass 'tools/neo-secret.sh present' \
    || fail 'tools/neo-secret.sh missing'

[[ -f "${NEO_SOURCE_ROOT}/tools/scope-intake.sh" ]] && pass 'tools/scope-intake.sh present' \
    || fail 'tools/scope-intake.sh missing'

[[ -f "${NEO_SOURCE_ROOT}/borg/borg-v2.sh" ]] && pass 'borg/borg-v2.sh present' \
    || fail 'borg/borg-v2.sh missing'

[[ -f "${NEO_SOURCE_ROOT}/lib/neo-vpn-consent.sh" ]] && pass 'neo-vpn-consent.sh present' \
    || fail 'neo-vpn-consent.sh missing'

for lib in neo-core.sh neo-secrets.sh neo-evidence.sh neo-actions.sh neo-mission-state.sh neo-scope.sh neo-provider.sh neo-1.0-bootstrap.sh neo-windup-actions.sh neo-vpn-consent.sh neo-operator-pane.sh neo-workbench.sh neo-toolkit.sh neo-exploit-framework.sh neo-pipeline-hooks.sh neo-eli5.sh neo-conductor.sh; do
    [[ -f "${NEO_SOURCE_ROOT}/lib/${lib}" ]] && pass "core lib present: ${lib}" || fail "core lib missing: ${lib}"
done

[[ -f "${NEO_SOURCE_ROOT}/schemas/action-policy.json" ]] && pass 'schemas/action-policy.json present' \
    || fail 'schemas/action-policy.json missing'

[[ -f "${NEO_SOURCE_ROOT}/tools/doc-truth-check.sh" ]] && pass 'tools/doc-truth-check.sh present' \
    || fail 'tools/doc-truth-check.sh missing'

[[ -f "${NEO_SOURCE_ROOT}/tools/neo-vendor.sh" ]] && pass 'tools/neo-vendor.sh present' \
    || fail 'tools/neo-vendor.sh missing'

[[ -f "${NEO_SOURCE_ROOT}/recon/review-plan.sh" ]] && pass 'recon/review-plan.sh present' \
    || fail 'recon/review-plan.sh missing'

finish_tests
