#!/usr/bin/env bash
# doc-truth-check.sh — documentation and release truth checks (P12 / Tier 3).

set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-${NEO_ROOT}}"
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
    grep -qE 'NEO_VERSION|/VERSION' "${NEO_SOURCE_ROOT}/neo.sh" 2>/dev/null \
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

check_eli5_documented() {
    grep -q '\[e\]' "${AGENTS}" 2>/dev/null \
        && pass 'AGENTS.md documents [e] ELI5' \
        || fail 'AGENTS.md missing [e] ELI5'
    grep -q 'SECTION:ELI5' "${NEO_SOURCE_ROOT}/templates/investigation-notes.md" 2>/dev/null \
        && pass 'template ELI5 section' \
        || fail 'template missing ELI5 section'
    [[ -f "${NEO_SOURCE_ROOT}/lib/neo-eli5.sh" ]] && pass 'lib/neo-eli5.sh present' \
        || fail 'lib/neo-eli5.sh missing'
}

check_pipeline_hooks() {
    grep -q 'neo_pipeline_offer_plan_enum' "${NEO_SOURCE_ROOT}/neo.sh" 2>/dev/null \
        && pass 'neo.sh plan-enum hook wired' \
        || fail 'neo.sh missing plan-enum hook'
    [[ -f "${NEO_SOURCE_ROOT}/lib/neo-pipeline-hooks.sh" ]] \
        && pass 'neo-pipeline-hooks present' \
        || fail 'neo-pipeline-hooks missing'
}

check_final_report() {
    grep -q 'SECTION:REPORT' "${NEO_SOURCE_ROOT}/templates/investigation-notes.md" 2>/dev/null \
        && pass 'template REPORT section' \
        || fail 'template missing REPORT section'
    [[ -f "${NEO_SOURCE_ROOT}/lib/neo-report.sh" ]] \
        && pass 'lib/neo-report.sh present (prototyped, v0.6 — not implemented)' \
        || fail 'lib/neo-report.sh missing'
    [[ -f "${NEO_SOURCE_ROOT}/tools/neo-report.sh" ]] && pass 'tools/neo-report.sh present' \
        || fail 'tools/neo-report.sh missing'
    grep -q 'final-report' "${NEO_SOURCE_ROOT}/lib/neo-menu.sh" 2>/dev/null \
        && pass 'menu [f] final-report routed' \
        || fail 'menu missing final-report'
}

check_borg_library() {
    [[ -f "${NEO_SOURCE_ROOT}/tools/borg-library-ingest.sh" ]] \
        && pass 'borg-library-ingest.sh present' \
        || fail 'borg-library-ingest.sh missing'
    [[ -f "${NEO_SOURCE_ROOT}/schemas/library-walkthrough.schema.json" ]] \
        && pass 'library-walkthrough schema' \
        || fail 'library-walkthrough schema missing'
    [[ -f "${NEO_SOURCE_ROOT}/knowledge/library/INDEX.yaml" ]] \
        && pass 'knowledge/library/INDEX.yaml' \
        || fail 'library INDEX missing'
    [[ -f "${NEO_SOURCE_ROOT}/lib/neo-borg-library-ai.sh" ]] \
        && pass 'neo-borg-library-ai.sh present (prototyped, v0.6)' \
        || fail 'neo-borg-library-ai.sh missing'
    [[ -f "${NEO_SOURCE_ROOT}/tools/borg-library-harvest.sh" ]] \
        && pass 'borg-library-harvest.sh present (prototyped, v0.6)' \
        || fail 'borg-library-harvest.sh missing'
    grep -q 'neo_scope_sync_project_meta' "${NEO_SOURCE_ROOT}/lib/neo-scope.sh" 2>/dev/null \
        && pass 'scope syncs engagement_mode to meta' \
        || fail 'neo_scope_sync_project_meta missing'
}

check_conductor_documented() {
    [[ -f "${NEO_SOURCE_ROOT}/NEO-1.0-DESIGN/AI-CONDUCTOR.md" ]] \
        && pass 'AI-CONDUCTOR.md present' \
        || fail 'AI-CONDUCTOR.md missing'
    [[ -f "${NEO_SOURCE_ROOT}/lib/neo-conductor.sh" ]] \
        && pass 'neo-conductor.sh present (prototyped, v0.6)' \
        || fail 'neo-conductor.sh missing'
    grep -q 'NEO_CONDUCTOR' "${AGENTS}" 2>/dev/null \
        && pass 'AGENTS.md documents NEO_CONDUCTOR' \
        || fail 'AGENTS.md missing NEO_CONDUCTOR'
}

check_feature_status_board() {
    local board="${NEO_SOURCE_ROOT}/NEO-1.0-DESIGN/FEATURE-STATUS.md"
    [[ -f "${board}" ]] && pass 'FEATURE-STATUS.md present' \
        || fail 'FEATURE-STATUS.md missing (canonical status board)'
    grep -q 'prototyped, v0.6' "${board}" 2>/dev/null \
        && pass 'FEATURE-STATUS labels prototyped v0.6' \
        || fail 'FEATURE-STATUS missing prototyped v0.6 labels'
    local lib
    for lib in neo-conductor.sh neo-feedback.sh neo-report.sh neo-handler-pane.sh \
               neo-conductor-loop.sh neo-borg-library-ai.sh; do
        grep -q "${lib}" "${board}" 2>/dev/null \
            && pass "FEATURE-STATUS lists ${lib}" \
            || fail "FEATURE-STATUS missing ${lib}"
    done
}

check_no_false_implemented_claims() {
    local bad=0
    if grep -qE 'Waves 1–5 \*\*implemented\*\*' "${NEO_SOURCE_ROOT}/NEO-1.0-DESIGN/TIER-B-PLAN.md" 2>/dev/null; then
        fail 'TIER-B-PLAN still claims Waves implemented without prototyped label'
        bad=1
    else
        pass 'TIER-B-PLAN does not overclaim implemented'
    fi
    if grep -q 'Tier A implemented' "${NEO_SOURCE_ROOT}/NEO-1.0-DESIGN/AI-CONDUCTOR.md" 2>/dev/null; then
        fail 'AI-CONDUCTOR still claims Tier A implemented'
        bad=1
    else
        pass 'AI-CONDUCTOR does not overclaim Tier A implemented'
    fi
    return "${bad}"
}

check_version_file
check_gitignore_env
check_no_stubs
check_workbench_documented
check_workbench_libs
check_tier3_tools
check_eli5_documented
check_pipeline_hooks
check_final_report
check_borg_library
check_conductor_documented
check_feature_status_board
check_no_false_implemented_claims

finish_tests
