#!/usr/bin/env bash
# neo-menu.sh — single source of truth for pause-menu letter routing and display.
#
# Both of neo.sh's menu loops dispatch on neo_menu_classify()'s canonical action name.
# Letter labels and compose order live here so pause menus stay consistent with the
# AI conductor nudges (same letters, same meanings).

# Globals set by neo_menu_compose_pause_extras:
#   NEO_PAUSE_HAS_CLAUDE, NEO_PAUSE_HAS_BORG, NEO_PAUSE_HAS_PAYLOAD,
#   NEO_PAUSE_HAS_DIAGNOSE, NEO_PAUSE_HAS_WORKBENCH, NEO_PAUSE_HAS_ELI5,
#   NEO_PAUSE_HAS_REPORT, NEO_PAUSE_EXTRA

neo_menu_feedback_ack() {
    local action="$1" detail="${2:-}"
    # shellcheck source=neo-feedback.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-feedback.sh" 2>/dev/null || return 0
    declare -F neo_feedback_ack_action >/dev/null 2>&1 && \
        neo_feedback_ack_action "${action}" "${detail}"
}

neo_menu_feedback_done() {
    local action="${1:-}" rc="${2:-0}"
    # shellcheck source=neo-feedback.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-feedback.sh" 2>/dev/null || return 0
    declare -F neo_feedback_done >/dev/null 2>&1 && neo_feedback_done "${action}" "${rc}"
}

neo_menu_classify() {
    local choice="$1"
    case "${choice}" in
        c|C) echo continue ;;
        a|A) echo ask-claude ;;
        b|B) echo assimilate ;;
        p|P) echo payload-suggest ;;
        z|Z) echo analyze-failures ;;
        d|D) echo deep-enum ;;
        r|R) echo repeat ;;
        s|S) echo skip-to-step ;;
        k|K) echo skip-phase ;;
        t|T) echo try-command ;;
        o|O) echo open-operator ;;
        e|E) echo eli5 ;;
        f|F) echo final-report ;;
        q|Q) echo quit ;;
        *) echo unmatched ;;
    esac
}

# Human-readable one-line legend (for docs / --help).
neo_menu_letter_legend() {
    cat <<'EOF'
Pause letters (case-insensitive — one meaning each):
  Navigation:  [c]ontinue  [r]epeat  [s]kip to step  [k] skip phase  [q]uit  [d]eep enum (recon)
  Plan (AI):   [b]org research  [p]ayload suggestion  [a]sk AI  [e]xplain (ELI5)
  Run:         [t]ry it  [o]perator pane  [z]diagnose failure (foothold, after attempt)
  Deliver:     [f]write report (post phase)
EOF
}

neo_menu_primary_prompt() {
    local phase="$1"
    case "${phase}" in
        recon) printf '[c]ontinue / [r]epeat / [d]eep enum / [s]kip to step / [q]uit' ;;
        *)     printf '[c]ontinue / [r]epeat / [s]kip to step / [q]uit' ;;
    esac
}

# Append a menu group if non-empty (leading " — " between groups).
neo_menu_append_group() {
    local label="$1" items="$2"
    [[ -n "${items//[[:space:]]/}" ]] || return 0
    if [[ -n "${NEO_PAUSE_EXTRA}" ]]; then
        NEO_PAUSE_EXTRA="${NEO_PAUSE_EXTRA} — ${label}: ${items}"
    else
        NEO_PAUSE_EXTRA=" — ${label}: ${items}"
    fi
}

# Build NEO_PAUSE_EXTRA in workflow order: plan → run → learn → deliver.
neo_menu_compose_pause_extras() {
    local phase="$1" project="${2:-${PROJECT_NAME:-}}"
    local plan="" run="" learn="" deliver=""

    NEO_PAUSE_HAS_CLAUDE=false
    NEO_PAUSE_HAS_BORG=false
    NEO_PAUSE_HAS_PAYLOAD=false
    NEO_PAUSE_HAS_DIAGNOSE=false
    NEO_PAUSE_HAS_WORKBENCH=false
    NEO_PAUSE_HAS_ELI5=false
    NEO_PAUSE_HAS_REPORT=false
    NEO_PAUSE_EXTRA=""

    # shellcheck source=neo-borg.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-borg.sh" 2>/dev/null || true
    # shellcheck source=neo-payload.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-payload.sh" 2>/dev/null || true
    # shellcheck source=neo-workbench.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-workbench.sh" 2>/dev/null || true
    # shellcheck source=neo-eli5.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-eli5.sh" 2>/dev/null || true
    # shellcheck source=neo-report.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-report.sh" 2>/dev/null || true

    command -v claude >/dev/null 2>&1 && NEO_PAUSE_HAS_CLAUDE=true

    if declare -F neo_borg_ai_available_for_menu >/dev/null 2>&1 \
        && neo_borg_ai_available_for_menu "${project}"; then
        NEO_PAUSE_HAS_BORG=true
        plan="${plan}$(neo_borg_menu_fragment "${project}")"
    fi

    if declare -F neo_payload_ai_available >/dev/null 2>&1 \
        && neo_payload_ai_available \
        && declare -F neo_payload_suggest_visible >/dev/null 2>&1 \
        && neo_payload_suggest_visible "${phase}"; then
        NEO_PAUSE_HAS_PAYLOAD=true
        plan="${plan}$(neo_payload_suggest_menu_fragment)"
    fi

    if ${NEO_PAUSE_HAS_CLAUDE}; then
        plan="${plan} / [a]sk AI"
    fi

    if declare -F neo_workbench_visible_phase >/dev/null 2>&1 \
        && neo_workbench_visible_phase "${phase}"; then
        NEO_PAUSE_HAS_WORKBENCH=true
        run="${run}$(neo_workbench_menu_fragment)"
    fi

    if declare -F neo_payload_analyze_failures_visible >/dev/null 2>&1 \
        && neo_payload_analyze_failures_visible "${phase}" "${project}"; then
        NEO_PAUSE_HAS_DIAGNOSE=true
        run="${run}$(neo_payload_diagnose_menu_fragment)"
    fi

    if declare -F neo_eli5_ai_available >/dev/null 2>&1 && neo_eli5_ai_available; then
        NEO_PAUSE_HAS_ELI5=true
        learn="$(neo_eli5_menu_fragment)"
    fi

    if declare -F neo_report_ai_available >/dev/null 2>&1 \
        && neo_report_ai_available \
        && declare -F neo_report_menu_visible >/dev/null 2>&1 \
        && neo_report_menu_visible "${phase}"; then
        NEO_PAUSE_HAS_REPORT=true
        deliver="$(neo_report_menu_fragment "${phase}")"
    fi

    neo_menu_append_group "plan" "${plan}"
    neo_menu_append_group "run" "${run}"
    [[ -n "${learn}" ]] && neo_menu_append_group "learn" "${learn}"
    [[ -n "${deliver}" ]] && neo_menu_append_group "deliver" "${deliver}"
}

# Compact nudge for conductor — only letters visible this phase (no group labels).
neo_menu_conductor_nudge() {
    local phase="$1" project="${2:-}"
    local parts=() pending=0

    # shellcheck source=neo-borg.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-borg.sh" 2>/dev/null || true
    # shellcheck source=neo-payload.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-payload.sh" 2>/dev/null || true
    # shellcheck source=neo-workbench.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-workbench.sh" 2>/dev/null || true
    # shellcheck source=neo-report.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-report.sh" 2>/dev/null || true

    if declare -F neo_borg_ai_available_for_menu >/dev/null 2>&1 \
        && neo_borg_ai_available_for_menu "${project}"; then
        pending="$(neo_borg_pending_count "${project}" 2>/dev/null || echo 0)"
        if (( pending > 0 )); then
            parts+=("[b]org research (${pending})")
        else
            parts+=("[b]org research")
        fi
    fi

    if declare -F neo_payload_suggest_visible >/dev/null 2>&1 \
        && neo_payload_suggest_visible "${phase}" \
        && declare -F neo_payload_ai_available >/dev/null 2>&1 \
        && neo_payload_ai_available; then
        parts+=("[p]ayload suggestion")
    fi

    if declare -F neo_workbench_visible_phase >/dev/null 2>&1 \
        && neo_workbench_visible_phase "${phase}"; then
        parts+=("[t]ry it")
    fi

    if declare -F neo_payload_analyze_failures_visible >/dev/null 2>&1 \
        && neo_payload_analyze_failures_visible "${phase}" "${project}"; then
        parts+=("[z]diagnose")
    fi

    if [[ "${phase}" == "post" ]] \
        && declare -F neo_report_menu_visible >/dev/null 2>&1 \
        && neo_report_menu_visible "${phase}" \
        && declare -F neo_report_ai_available >/dev/null 2>&1 \
        && neo_report_ai_available; then
        parts+=("[f]write report")
    fi

    ((${#parts[@]} == 0)) && return 0
    local joined="" item
    for item in "${parts[@]}"; do
        [[ -n "${joined}" ]] && joined="${joined} → "
        joined="${joined}${item}"
    done
    printf '%s' "${joined}"
}
