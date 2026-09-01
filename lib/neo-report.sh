#!/usr/bin/env bash
# neo-report.sh — final mission report helpers (Tier A/B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-borg-disclosure.sh
source "${NEO_LIB_DIR}/neo-borg-disclosure.sh" 2>/dev/null || true
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
    local project="$1" bundle ports attackpath lessons
    declare -F neo_borg_disclosure_ai_rules >/dev/null 2>&1 || return 1
    # shellcheck source=notes-lib.sh
    source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || return 1
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    ports="$(notes_get_section PORTS 2>/dev/null || true)"
    attackpath="$(notes_get_section ATTACKPATH 2>/dev/null | head -c 6000 || true)"
    lessons="$(notes_get_section LESSONS 2>/dev/null | head -c 4000 || true)"
    bundle="$(cat <<EOF
# Final report bundle
Project: ${project}

$(neo_borg_disclosure_ai_rules "${project}")

## Ports
${ports:-_none_}

## Attack path
${attackpath:-_none_}

## Lessons learned
${lessons:-_none_}

## AI triage (excerpt)
$(notes_get_section AI-TRIAGE 2>/dev/null | head -c 6000 || true)

## Privesc plan (excerpt)
$(notes_get_section PRIVESC-PLAN 2>/dev/null | head -c 4000 || true)
EOF
)"
    if ((${#bundle} > ${NEO_AI_BUNDLE_MAX:-28000})); then
        bundle="${bundle:0:${NEO_AI_BUNDLE_MAX:-28000}}"
    fi
    printf '%s' "${bundle}"
}

neo_report_system_prompt() {
    local project="$1"
    case "$(neo_borg_disclosure_mode "${project}")" in
        professional)
            printf '%s' 'Write a client-deliverable penetration test report with executive summary, scope, methodology, findings (severity-rated), and remediation recommendations. Use markdown headings. Do not include exploit recipes or credentials.'
            ;;
        *)
            printf '%s' 'Write a learning report (book report style) explaining what was tried, what worked, what failed, and key lessons. Use markdown headings. Teaching tone — help the operator understand the mission arc.'
            ;;
    esac
}

neo_report_at_pause() {
    local project="$1" _phase="$2"
    neo_report_generate "${project}"
}

neo_report_save() {
    local project="$1" response="$2" ts report_dir report_file
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=notes-lib.sh
    source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || return 1
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    notes_set_section REPORT "${response}" 2>/dev/null || return 1
    notes_append_section AI-TRIAGE "**Final report draft (${ts})**

${response}" 2>/dev/null || true
    report_dir="${OUTDIR}/artifacts"
    mkdir -p "${report_dir}"
    report_file="${report_dir}/final-report-${ts//[: ]/-}.md"
    printf '%s\n' "${response}" > "${report_file}"
    notes_log final-report "=== final report ${ts} ===
${response}" 2>/dev/null || true
    meta_set conductor_report_done 1 2>/dev/null || true
    printf '[*] Final report saved → REPORT section and %s\n' "${report_file}"
    return 0
}

neo_report_offer_mission_complete() {
    local _project="$1"
    printf '[*] Final report: press [f] at post phase or run: neo.sh %s --report\n' "${_project}"
    return 0
}

neo_report_generate() {
    local project="$1" bundle response
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || true
    [[ -f "${NOTES_FILE}" ]] || {
        printf '[!] No Investigation-Notes.md for %s.\n' "${project}" >&2
        return 1
    }

    if [[ "${NEO_TEST_NONINTERACTIVE:-0}" == "1" ]] && ! neo_report_ai_available; then
        printf '[*] Report generation skipped (noninteractive, no AI).\n' >&2
        return 0
    fi

    if ! neo_report_ai_available; then
        printf '[!] Report needs Claude Code (claude) or ANTHROPIC_API_KEY.\n' >&2
        return 1
    fi

    bundle="$(neo_report_build_bundle "${project}")" || return 1
    # shellcheck source=neo-payload.sh
    source "${NEO_LIB_DIR}/neo-payload.sh" 2>/dev/null || return 1
    neo_payload_init_colors 2>/dev/null || true
    printf '\n[*] Generating final report…\n\n'

    if ! response="$(neo_payload_call_ai "${bundle}" "$(neo_report_system_prompt "${project}")" "${project}")"; then
        return 1
    fi

    neo_report_save "${project}" "${response}"
    return 0
}
