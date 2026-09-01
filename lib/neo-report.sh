#!/usr/bin/env bash
# neo-report.sh — final mission report helpers (Tier A/B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-borg-disclosure.sh
source "${NEO_LIB_DIR}/neo-borg-disclosure.sh"
# shellcheck source=notes-lib.sh
source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || true

neo_report_ai_available() {
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then return 0; fi
    command -v claude >/dev/null 2>&1
}

neo_report_menu_visible() {
    local phase="$1"
    [[ "${phase}" == post ]]
}

neo_report_menu_fragment() {
    local _phase="$1"
    printf ' / [f]write report'
}

neo_report_build_bundle() {
    local project="$1" bundle ports
    # shellcheck source=notes-lib.sh
    source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || return 1
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    ports="$(notes_get_section PORTS 2>/dev/null || true)"
    bundle="$(cat <<EOF
# Final report bundle
Project: ${project}

$(neo_borg_disclosure_ai_rules "${project}")

## Ports
${ports:-_none_}
EOF
)"
    printf '%s' "${bundle}"
}

neo_report_system_prompt() {
    local _project="$1"
    case "${NEO_ENGAGEMENT_MODE:-educational}" in
        professional)
            printf 'Write a client-deliverable penetration test report with executive summary and findings.'
            ;;
        *)
            printf 'Write a learning report (book report style) explaining what was tried and what was learned.'
            ;;
    esac
}

neo_report_at_pause() {
    local _project="$1" _phase="$2"
    return 0
}

neo_report_offer_mission_complete() {
    local _project="$1"
    printf '[*] Final report: press [f] at post phase or run: neo.sh %s --report\n' "${_project}"
    return 0
}

neo_report_generate() {
    local project="$1"
    printf '[*] Report generation stub — bundle ready for AI (project=%s).\n' "${project}"
    neo_report_build_bundle "${project}" >/dev/null || return 1
    return 0
}
