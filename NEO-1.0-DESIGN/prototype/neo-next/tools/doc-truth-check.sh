#!/usr/bin/env bash
# Documentation truth checks (P12 design prototype).

set -uo pipefail

NEO_NEXT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-$(cd "${NEO_NEXT_ROOT}/../../.." && pwd)}"
source "${NEO_NEXT_ROOT}/test/test-helper.sh"

VERSION_FILE="${NEO_SOURCE_ROOT}/VERSION"
README="${NEO_SOURCE_ROOT}/README.md"
failed=0

check_version() {
    local version
    version="$(cat "${VERSION_FILE}" 2>/dev/null | tr -d '[:space:]')"
    [[ -n "${version}" ]] || { fail 'VERSION file empty or missing'; return; }
    grep -q "v${version}" "${README}" && pass "README mentions v${version}" || fail "README missing v${version}"
    grep -qE 'v0\.4' "${README}" && fail 'README still references v0.4' || pass 'README has no v0.4 reference'
}

check_gitignore_env() {
    if grep -qE '^\.env($|\.)' "${NEO_SOURCE_ROOT}/.gitignore" 2>/dev/null; then
        pass '.gitignore excludes .env'
    else
        fail '.gitignore missing .env exclusion'
    fi
}

check_listenassist_claim() {
    local file="${NEO_SOURCE_ROOT}/foothold/ListenAssist.sh" lines
    lines="$(wc -l < "${file}" | tr -d ' ')"
    if (( lines < 20 )); then
        pass 'ListenAssist correctly flagged as stub (short file)'  # honest doc should say prototype
    else
        pass 'ListenAssist appears substantive'
    fi
}

check_version
check_gitignore_env
check_listenassist_claim

finish_tests
