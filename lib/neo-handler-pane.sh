#!/usr/bin/env bash
# neo-handler-pane.sh — tmux pane C (handler/msf) helpers (Tier B prototype).
#
# Long-running listeners (msfconsole, nc) run here so the conductor pane keeps stdin.
# NEO captures this pane for failure analysis and workbench context.

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-tmux.sh
source "${NEO_LIB_DIR}/neo-tmux.sh"

NEO_HANDLER_PANE_TITLE="${NEO_HANDLER_PANE_TITLE:-neo-handler}"

neo_handler_pane_available() {
    [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1
}

neo_handler_pane_confirm_yn() {
    local prompt="$1" default="${2:-y}" choice
    [[ "${NEO_TEST_NONINTERACTIVE:-0}" == "1" || ! -t 0 ]] && return 1
    if [[ "${default}" == y ]]; then
        read -r -p "${prompt} [Y/n] " choice
        choice="${choice:-Y}"
        [[ "${choice}" =~ ^[Yy] ]]
    else
        read -r -p "${prompt} [y/N] " choice
        [[ "${choice}" =~ ^[Yy] ]]
    fi
}

neo_handler_pane_find() {
    local session="$1" pane title
    session="${session:-$(neo_tmux_current_session 2>/dev/null || true)}"
    [[ -n "${session}" ]] || return 1
    while IFS= read -r pane; do
        [[ -n "${pane}" ]] || continue
        title="$(tmux display-message -p -t "${pane}" '#{pane_title}' 2>/dev/null || true)"
        if [[ "${title}" == "${NEO_HANDLER_PANE_TITLE}" ]]; then
            printf '%s' "${pane}"
            return 0
        fi
    done < <(tmux list-panes -s -t "${session}" -F '#{pane_id}' 2>/dev/null || true)
    return 1
}

neo_handler_pane_ensure() {
    local session conductor pane split_pct
    # shellcheck source=neo-conductor-tuning.sh
    source "${NEO_LIB_DIR}/neo-conductor-tuning.sh" 2>/dev/null || true
    split_pct="$(neo_conductor_handler_split_pct 2>/dev/null || printf '25')"
    neo_handler_pane_available || {
        printf 'neo-handler: not inside tmux — launch NEO without NEO_TMUX_WRAP=0.\n' >&2
        return 1
    }
    session="$(neo_tmux_current_session)" || return 1
    if pane="$(neo_handler_pane_find "${session}")"; then
        printf '%s' "${pane}"
        return 0
    fi
    conductor="$(tmux display-message -p '#{pane_id}')"
    tmux split-window -v -p "${split_pct}" -c "$(pwd)" \
        || { printf 'neo-handler: could not split handler pane.\n' >&2; return 1; }
    pane="$(neo_handler_pane_find "${session}")" || \
        pane="$(tmux list-panes -s -t "${session}" -F '#{pane_id}' | tail -1)"
    tmux select-pane -t "${pane}" -T "${NEO_HANDLER_PANE_TITLE}"
    tmux select-pane -t "${conductor}"
    printf '%s' "${pane}"
}

neo_handler_pane_focus() {
    local pane
    pane="$(neo_handler_pane_ensure)" || return 1
    tmux select-pane -t "${pane}"
}

neo_handler_pane_send() {
    local cmd="$1" pane
    [[ -n "${cmd}" ]] || return 1
    pane="$(neo_handler_pane_ensure)" || return 1
    tmux send-keys -t "${pane}" -l -- "${cmd}"
    tmux send-keys -t "${pane}" Enter
}

neo_handler_pane_capture() {
    local lines="${1:-200}" pane body
    pane="$(neo_handler_pane_find)" || return 1
    body="$(tmux capture-pane -t "${pane}" -p -S "-${lines}" 2>/dev/null || true)"
    [[ -n "${body}" ]] || return 1
    printf '%s' "${body}"
}

neo_handler_pane_start_msf_listener() {
    local lhost="$1" lport="$2" payload="${3:-linux/x64/meterpreter/reverse_tcp}" cmd
    [[ -n "${lhost}" && -n "${lport}" ]] || return 1
    # shellcheck source=neo-exploit-framework.sh
    source "${NEO_LIB_DIR}/neo-exploit-framework.sh" 2>/dev/null || return 1
    cmd="$(neo_msf_handler_command "${lhost}" "${lport}" "${payload}")" || return 1
    neo_handler_pane_send "${cmd}"
    printf '[*] MSF handler sent to handler pane (pane C).\n'
    return 0
}

neo_handler_pane_start_argv_listener() {
    local cmd="$1"
    [[ -n "${cmd}" ]] || return 1
    neo_handler_pane_send "${cmd}"
    printf '[*] Listener command sent to handler pane (pane C).\n'
    return 0
}

neo_handler_pane_offer_msf() {
    local project="$1" lhost="$2" lport="$3" payload="${4:-linux/x64/meterpreter/reverse_tcp}"
    local mode assisted=false
    [[ -n "${lhost}" && -n "${lport}" ]] || return 1
    neo_handler_pane_available || return 1
    if declare -F neo_conductor_resolve_mode >/dev/null 2>&1; then
        # shellcheck source=neo-conductor.sh
        source "${NEO_LIB_DIR}/neo-conductor.sh" 2>/dev/null || true
        mode="$(neo_conductor_resolve_mode "${project}")"
        [[ "${mode}" == "assisted" ]] && assisted=true
    fi
    printf '\n[*] MSF handler belongs in tmux pane C (%s) — listener output is captured for AI review.\n' \
        "${NEO_HANDLER_PANE_TITLE}"
    if [[ "${assisted}" == true ]]; then
        neo_handler_pane_start_msf_listener "${lhost}" "${lport}" "${payload}"
        return $?
    fi
    if neo_handler_pane_confirm_yn 'Start MSF handler in handler pane (pane C)?' y; then
        neo_handler_pane_start_msf_listener "${lhost}" "${lport}" "${payload}"
        return $?
    fi
    return 0
}
