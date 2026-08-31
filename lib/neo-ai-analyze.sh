#!/usr/bin/env bash
# neo-ai-analyze.sh — Claude wait timer, terminal brief, tool checks for AI triage.

NEO_AI_WAIT_TIMER_SEC="${NEO_AI_WAIT_TIMER_SEC:-90}"

NEO_AI_TIMER_PID=""
NEO_AI_TIMER_FILE=""

neo_ai_analyze_init_colors() {
    C_RESET="${C_RESET:-$'\033[0m'}"
    C_GREEN="${C_GREEN:-$'\033[0;32m'}"
    C_DIM="${C_DIM:-$'\033[2;32m'}"
    C_BRIGHT="${C_BRIGHT:-$'\033[1;32m'}"
    C_CYAN="${C_CYAN:-$'\033[0;36m'}"
    C_YELLOW="${C_YELLOW:-$'\033[0;33m'}"
    C_MAGENTA="${C_MAGENTA:-$'\033[0;35m'}"
    C_BLUE="${C_BLUE:-$'\033[0;34m'}"
}

neo_ai_timer_stop() {
    if [[ -n "${NEO_AI_TIMER_PID}" ]]; then
        [[ -n "${NEO_AI_TIMER_FILE}" ]] && rm -f "${NEO_AI_TIMER_FILE}"
        kill "${NEO_AI_TIMER_PID}" 2>/dev/null || true
        wait "${NEO_AI_TIMER_PID}" 2>/dev/null || true
        NEO_AI_TIMER_PID=""
        NEO_AI_TIMER_FILE=""
        printf '\r%-72s\r' ' ' >&2
    fi
}

neo_ai_timer_start() {
    local seconds="${1:-${NEO_AI_WAIT_TIMER_SEC}}"
    [[ "${NEO_AI_TIMER:-1}" != "0" ]] || return 0
    [[ -t 2 ]] || return 0

    neo_ai_timer_stop
    neo_ai_analyze_init_colors
    NEO_AI_TIMER_FILE="$(mktemp)"
    (
        local sec="${seconds}"
        while (( sec > 0 )) && [[ -f "${NEO_AI_TIMER_FILE}" ]]; do
            printf '\r  %s[*]%s claude working… %2ds remaining (may finish sooner)   ' \
                "${C_BLUE}" "${C_RESET}" "${sec}" >&2
            sleep 1
            sec=$((sec - 1))
        done
        printf '\r%-72s\r' ' ' >&2
    ) &
    NEO_AI_TIMER_PID=$!
}

# Stream claude/API output to the terminal; capture only stdout to a file (that capture
# becomes the persisted AI-TRIAGE/PAYLOAD/Borg-dossier content). stderr is deliberately
# NOT merged in here — it still reaches the terminal live (inherited, not redirected), but
# any stray warning/progress line claude -p or the API path ever prints to stderr must never
# silently end up saved into a case file's markdown as if it were part of Claude's answer.
neo_ai_run_visible_with_timer_to_file() {
    local out_file="$1"
    shift
    neo_ai_timer_start
    set +e
    if [[ -t 1 ]]; then
        "$@" | tee "${out_file}"
        local rc=${PIPESTATUS[0]}
    else
        "$@" > "${out_file}"
        local rc=$?
    fi
    set -e
    neo_ai_timer_stop
    return "${rc}"
}

# Back-compat name — payload/cli/analyze-recon call this.
neo_ai_run_with_analyze_hud_to_file() {
    neo_ai_run_visible_with_timer_to_file "$@"
}

neo_ai_call_claude_with_hud() {
    local tmp out rc
    tmp="$(mktemp)"
    if neo_ai_run_visible_with_timer_to_file "${tmp}" neo_ai_call_claude "$@"; then
        out="$(cat "${tmp}")"
        rm -f "${tmp}"
        printf '%s' "${out}"
        return 0
    fi
    rc=$?
    rm -f "${tmp}"
    return "${rc}"
}

neo_ai_extract_section() {
    local response="$1" heading="$2"
    awk -v h="${heading}" '
        BEGIN { found=0; hl="## " h }
        index($0, hl) == 1 { found=1; next }
        found && index($0, "## ") == 1 { exit }
        found { print }
    ' <<< "${response}" | sed '/^[[:space:]]*$/d'
}

neo_ai_extract_tools_from_response() {
    local response="$1"
    printf '%s\n' "${response}" | grep -oE '\[TOOL:[a-zA-Z0-9._+-]+\]' \
        | sed 's/^\[TOOL://;s/\]$//' | sort -u
}

neo_ai_tool_to_package() {
    case "$1" in
        smbclient) echo "samba" ;;
        *)         echo "$1" ;;
    esac
}

neo_ai_print_triage_brief() {
    local response="$1"
    local tech steps
    [[ -t 1 || -t 2 ]] || return 0

    tech="$(neo_ai_extract_section "${response}" "Technical observations")"
    steps="$(neo_ai_extract_section "${response}" "Operator next steps")"
    [[ -z "${steps}" ]] && steps="$(neo_ai_extract_section "${response}" "Recommended next steps")"

    neo_ai_analyze_init_colors
    printf '\n'
    printf '%s%s%s\n' "${C_BRIGHT}" \
        '  ═══════════════════════════════════════════════════════════' "${C_RESET}"
    printf '%s%s  AI TRIAGE — TERMINAL BRIEF%s\n' "${C_GREEN}" "${C_BRIGHT}" "${C_RESET}"
    printf '%s%s%s\n\n' "${C_BRIGHT}" \
        '  ═══════════════════════════════════════════════════════════' "${C_RESET}"

    if [[ -n "${tech}" ]]; then
        printf '%s  ▸ TECHNICAL OBSERVATIONS%s\n' "${C_CYAN}" "${C_RESET}"
        while IFS= read -r line; do
            [[ -n "${line}" ]] && printf '    %s\n' "${line}"
        done <<< "${tech}"
        printf '\n'
    fi

    if [[ -n "${steps}" ]]; then
        printf '%s  ▸ YOUR NEXT STEPS%s\n' "${C_YELLOW}" "${C_RESET}"
        while IFS= read -r line; do
            [[ -n "${line}" ]] && printf '    %s\n' "${line}"
        done <<< "${steps}"
        printf '\n'
    fi

    printf '%s  Full analysis saved → Investigation-Notes.md · AI Triage%s\n\n' \
        "${C_DIM}" "${C_RESET}"
}

neo_ai_process_tool_requests() {
    local response="$1"
    [[ -t 0 ]] || return 0
    # shellcheck source=neo-toolkit.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-toolkit.sh"
    neo_toolkit_offer_after_suggest "${response}" "${PROJECT_NAME:-}"
}
