#!/usr/bin/env bash
# neo-handler-pane.sh — tmux pane C (handler/msf) helpers (Tier B prototype).
#
# Long-running listeners (msfconsole, nc) run here so the conductor pane keeps stdin.

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-tmux.sh
source "${NEO_LIB_DIR}/neo-tmux.sh"

NEO_HANDLER_PANE_TITLE="${NEO_HANDLER_PANE_TITLE:-neo-handler}"

neo_handler_pane_available() {
    [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1
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
    local session conductor pane split_pct="${NEO_HANDLER_SPLIT_PCT:-30}"
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
