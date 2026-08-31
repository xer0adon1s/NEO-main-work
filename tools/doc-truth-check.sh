#!/usr/bin/env bash
# doc-truth-check.sh — documentation and release truth checks (P12 / Tier 3).

set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-${NEO_ROOT}"
# shellcheck source=../test/test-helper.sh
source "${NEO_ROOT}/test/test-helper.sh"

VERSION_FILE="${NEO_SOURCE_ROOT}/VERSION"
AGENTS="${NEO_SOURCE_ROOT}/AGENTS.md"
WORKBENCH_DOC="${NEO_SOURCE_ROOT}/NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md"

check_version_file() {
    local version
    [[ -f "${VERSION_FILE}" ]] || { fail 'VERSION file missing'; return; }
    version="$(tr -d '[:space:]' < "${VERSION_FILE}")"
    [[ -n "${version}" ]] || { fail 'VERSION file empty'; return; }
    pass "VERSION file present (${version})"
    grep -q "${version}" "${NEO_SOURCE_ROOT}/neo.sh" 2>/dev/null \
        && pass 'neo.sh references VERSION' \
        || fail 'neo.sh does not reference VERSION'
}

check_gitignore_env() {
    grep -qE '^\.env($|\.)' "${NEO_SOURCE_ROOT}/.gitignore" 2>/dev/null \
        && pass '.gitignore excludes .env' \
        || fail '.gitignore missing .env exclusion'
}

check_no_stubs() {
    local file="${NEO_SOURCE_ROOT}/foothold/ListenAssist.sh" lines
    [[ -f "${file}" ]] || { fail 'ListenAssist.sh missing'; return; }
    lines="$(wc -l < "${file}" | tr -d ' ')"
    (( lines >= 40 )) && pass 'ListenAssist is substantive' \
        || fail "ListenAssist still short (${lines} lines)"
    file="${NEO_SOURCE_ROOT}/privesc/run-findprivs.sh"
    lines="$(wc -l < "${file}" | tr -d ' ')"
    (( lines >= 30 )) && pass 'run-findprivs is substantive' \
        || fail "run-findprivs still short (${lines} lines)"
}

check_workbench_documented() {
    [[ -f "${WORKBENCH_DOC}" ]] && pass 'OPERATOR-WORKBENCH.md present' \
        || fail 'OPERATOR-WORKBENCH.md missing'
    grep -q '\[t\]' "${AGENTS}" 2>/dev/null \
        && pass 'AGENTS.md documents [t]ry workbench' \
        || fail 'AGENTS.md missing [t]ry workbench letter'
    grep -q 'WORKBENCH' "${AGENTS}" 2>/dev/null \
        && pass 'AGENTS.md documents WORKBENCH section' \
        || fail 'AGENTS.md missing WORKBENCH section ownership'
}

check_workbench_libs() {
    for lib in neo-operator-pane.sh neo-workbench.sh neo-toolkit.sh; do
        [[ -f "${NEO_SOURCE_ROOT}/lib/${lib}" ]] && pass "workbench/toolkit lib: ${lib}" \
            || fail "workbench/toolkit lib missing: ${lib}"
    done
    [[ -f "${NEO_SOURCE_ROOT}/schemas/workbench-attempt.schema.json" ]] \
        && pass 'workbench-attempt schema present' \
        || fail 'workbench-attempt schema missing'
}

check_tier3_tools() {
    for tool in doc-truth-check.sh neo-vendor.sh; do
        [[ -x "${NEO_SOURCE_ROOT}/tools/${tool}" || -f "${NEO_SOURCE_ROOT}/tools/${tool}" ]] \
            && pass "tools/${tool} present" || fail "tools/${tool} missing"
    done
    [[ -f "${NEO_SOURCE_ROOT}/recon/review-plan.sh" ]] && pass 'recon/review-plan.sh present' \
        || fail 'recon/review-plan.sh missing'
}

check_version_file
check_gitignore_env
check_no_stubs
check_workbench_documented
check_workbench_libs
check_tier3_tools

finish_tests
