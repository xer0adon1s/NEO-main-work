#!/usr/bin/env bash
# neo-feedback.sh — operator ack telemetry for pause-menu actions (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

neo_feedback_enabled() {
    [[ "${NEO_FEEDBACK:-1}" != "0" ]]
}

neo_feedback_action_title() {
    local action="$1"
    case "${action}" in
        assimilate|borg) printf '[b] Borg research' ;;
        payload-suggest|payload) printf '[p] Payload suggestion' ;;
        analyze-failures|diagnose) printf '[z] Diagnose failure' ;;
        try-command) printf '[t] Try command' ;;
        analyze-output) printf '[t] Analyze output' ;;
        open-operator) printf '[o] Operator pane' ;;
        eli5) printf '[e] ELI5 explain' ;;
        ask-claude) printf '[a] Ask AI' ;;
        final-report) printf '[f] Write report' ;;
        deep-enum) printf '[d] Deep enum' ;;
        *) printf '[?] %s' "${action}" ;;
    esac
}

neo_feedback_ack_action() {
    local action="${1:-}" detail="${2:-}"
    neo_feedback_enabled || return 0
    printf '[NEO] %s…\n' "$(neo_feedback_action_title "${action}")" >&2
    [[ -n "${NEO_FEEDBACK_TRACE:-}" ]] && \
        printf '[feedback] ack %s %s\n' "${action}" "${detail}" >&2 || true
    return 0
}

neo_feedback_done() {
    local action="${1:-}" rc="${2:-0}"
    neo_feedback_enabled || return 0
    if [[ "${rc}" == "0" ]]; then
        printf '[NEO] %s done.\n' "$(neo_feedback_action_title "${action}")" >&2
    else
        printf '[NEO] %s failed (exit %s).\n' "$(neo_feedback_action_title "${action}")" "${rc}" >&2
    fi
    [[ -n "${NEO_FEEDBACK_TRACE:-}" ]] && \
        printf '[feedback] done %s rc=%s\n' "${action}" "${rc}" >&2 || true
    return 0
}
