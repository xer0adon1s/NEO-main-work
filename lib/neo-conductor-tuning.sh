#!/usr/bin/env bash
# neo-conductor-tuning.sh — assisted/guided tuning profiles (loop caps, enum AI, workbench waits).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"

neo_conductor_tuning_notes_setup() {
    local project="$1"
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || \
        source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || true
}

neo_conductor_tuning_is_assisted() {
    local project="$1" mode engagement
    case "${NEO_CONDUCTOR_MODE:-}" in
        assisted|aggressive) return 0 ;;
    esac
    neo_conductor_tuning_notes_setup "${project}"
    mode="$(meta_get conductor_mode 2>/dev/null || true)"
    case "${mode}" in
        assisted|aggressive) return 0 ;;
    esac
    engagement="$(meta_get engagement_mode 2>/dev/null || true)"
    [[ -n "${engagement}" ]] || engagement="${NEO_ENGAGEMENT_MODE:-educational}"
    [[ "${engagement}" == professional ]]
}

neo_conductor_loop_max_for_phase() {
    local project="$1" phase="${2:-foothold}" meta_max
    if [[ -n "${NEO_CONDUCTOR_MAX_LOOPS:-}" && "${NEO_CONDUCTOR_MAX_LOOPS}" =~ ^[0-9]+$ ]]; then
        printf '%s' "${NEO_CONDUCTOR_MAX_LOOPS}"
        return 0
    fi
    neo_conductor_tuning_notes_setup "${project}"
    meta_max="$(meta_get conductor_max_loops 2>/dev/null || true)"
    if [[ -n "${meta_max}" && "${meta_max}" =~ ^[0-9]+$ ]]; then
        printf '%s' "${meta_max}"
        return 0
    fi
    case "${phase}" in
        foothold) printf '3' ;;
        privesc) printf '4' ;;
        *) printf '%s' "${NEO_CONDUCTOR_MAX_LOOPS_DEFAULT:-5}" ;;
    esac
}

neo_conductor_enum_ai_policy() {
    local project="$1" policy
    case "${NEO_ENUM_AI:-}" in
        auto|prompt|off)
            printf '%s' "${NEO_ENUM_AI}"
            return 0
            ;;
    esac
    if neo_conductor_tuning_is_assisted "${project}"; then
        printf 'auto'
    else
        printf 'prompt'
    fi
}

neo_conductor_enum_ai_prompt_default_y() {
    local project="$1"
    neo_conductor_tuning_is_assisted "${project}"
}

neo_conductor_auto_try_enabled() {
    local project="$1"
    neo_conductor_tuning_is_assisted "${project}"
}

neo_conductor_auto_analyze_enabled() {
    local project="$1"
    neo_conductor_tuning_is_assisted "${project}"
}

neo_conductor_workbench_wait_sec() {
    local transport="$1" assisted="${2:-false}"
    case "${transport}" in
        operator_pane)
            [[ "${assisted}" == true ]] && printf '60' || printf '0'
            ;;
        local_safe)
            [[ "${assisted}" == true ]] && printf '8' || printf '0'
            ;;
        *)
            printf '0'
            ;;
    esac
}

neo_conductor_handler_split_pct() {
    printf '%s' "${NEO_HANDLER_PANE_SPLIT_PCT:-25}"
}

neo_conductor_handler_capture_lines() {
    printf '%s' "${NEO_HANDLER_CAPTURE_LINES:-400}"
}
