#!/usr/bin/env bash
# Release gate for the real source tree. Expected to fail against the reviewed v0.5 snapshot.
set -uo pipefail

NEO_NEXT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-$(cd "${NEO_NEXT_ROOT}/../../.." && pwd)}"
source "${NEO_NEXT_ROOT}/test/test-helper.sh"

require_substantive_script() {
    local rel="$1" min_lines="$2" required_pattern="$3" file="${NEO_SOURCE_ROOT}/${rel}" count
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

finish_tests
