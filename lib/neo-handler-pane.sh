#!/usr/bin/env bash
# neo-handler-pane.sh — tmux pane C (handler/msf) helpers (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"

neo_handler_pane_available() {
    command -v tmux >/dev/null 2>&1
}

neo_handler_pane_focus() {
    local _project="$1"
    neo_handler_pane_available || return 1
    printf '[*] Handler pane (C) focus stub — wire msfconsole pane when integrated.\n'
    return 0
}

neo_handler_pane_send() {
    local _cmd="$1"
    return 1
}
