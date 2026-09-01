#!/usr/bin/env bash
# neo-operator-pane.sh — dedicated tmux pane for operator commands (P20 workbench).
#
# NEO's pause menu owns stdin in the conductor pane; suggested commands must run in a
# separate pane. This module creates/finds that pane and sends keys or captures output.

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-tmux.sh
source "${NEO_LIB_DIR}/neo-tmux.sh"

NEO_OPERATOR_PANE_TITLE="${NEO_OPERATOR_PANE_TITLE:-neo-operator}"

neo_operator_in_tmux() {
    [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1
}

neo_operator_pane_find() {
    local session="$1" pane title
    session="${session:-$(neo_tmux_current_session 2>/dev/null || true)}"
    [[ -n "${session}" ]] || return 1
    while IFS= read -r pane; do
        [[ -n "${pane}" ]] || continue
        title="$(tmux display-message -p -t "${pane}" '#{pane_title}' 2>/dev/null || true)"
        if [[ "${title}" == "${NEO_OPERATOR_PANE_TITLE}" ]]; then
            printf '%s' "${pane}"
            return 0
        fi
    done < <(tmux list-panes -s -t "${session}" -F '#{pane_id}' 2>/dev/null || true)
    return 1
}

neo_operator_pane_ensure() {
    local session conductor pane split_pct="${NEO_OPERATOR_SPLIT_PCT:-45}"
    neo_operator_in_tmux || {
        printf 'neo-workbench: not inside tmux — launch NEO without NEO_TMUX_WRAP=0 so a mission session exists.\n' >&2
        return 1
    }
    session="$(neo_tmux_current_session)" || return 1
    if pane="$(neo_operator_pane_find "${session}")"; then
        printf '%s' "${pane}"
        return 0
    fi
    conductor="$(tmux display-message -p '#{pane_id}')"
    tmux split-window -h -p "${split_pct}" -c "$(pwd)" \
        || { printf 'neo-workbench: could not split operator pane.\n' >&2; return 1; }
    pane="$(neo_operator_pane_find "${session}")" || pane="$(tmux list-panes -s -t "${session}" -F '#{pane_id}' | tail -1)"
    tmux select-pane -t "${pane}" -T "${NEO_OPERATOR_PANE_TITLE}"
    tmux select-pane -t "${conductor}"
    printf '%s' "${pane}"
}

neo_operator_pane_focus() {
    local pane
    pane="$(neo_operator_pane_ensure)" || return 1
    tmux select-pane -t "${pane}"
}

neo_operator_pane_send_command() {
    local cmd="$1" pane
    [[ -n "${cmd}" ]] || return 1
    pane="$(neo_operator_pane_ensure)" || return 1
    tmux send-keys -t "${pane}" -l -- "${cmd}"
    tmux send-keys -t "${pane}" Enter
}

neo_operator_pane_capture() {
    local lines="${1:-200}" pane body
    pane="$(neo_operator_pane_find)" || return 1
    body="$(tmux capture-pane -t "${pane}" -p -S "-${lines}" 2>/dev/null || true)"
    [[ -n "${body}" ]] || return 1
    printf '%s' "${body}"
}

neo_operator_pane_ssh_hint() {
    local project="$1" target="" user="" hint="" meta_file mission_file
    [[ -n "${project}" ]] || return 1
    meta_file="${NEO_HOME:-${NEO_DIR}}/projects/${project}/project.meta"
    mission_file="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}/projects/${project}/mission.json"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    if declare -F meta_get >/dev/null 2>&1 && [[ -f "${meta_file}" ]]; then
        target="$(meta_get target 2>/dev/null || true)"
        user="$(meta_get ssh_user 2>/dev/null || true)"
        [[ -z "${user}" ]] && user="$(meta_get ssh_target 2>/dev/null | cut -d@ -f1 || true)"
    fi
    if [[ -f "${mission_file}" ]] && command -v jq >/dev/null 2>&1; then
        [[ -z "${user}" ]] && user="$(jq -r '.session.user // empty' "${mission_file}" 2>/dev/null || true)"
        [[ -z "${target}" ]] && target="$(jq -r '.session.host // .target // empty' "${mission_file}" 2>/dev/null || true)"
    fi
    if [[ -z "${user}" || -z "${target}" ]] && [[ -f "${NEO_HOME}/projects/${project}/Investigation-Notes.md" ]]; then
        OUTDIR="${NEO_HOME}/projects/${project}"
        NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
        if declare -F notes_get_section >/dev/null 2>&1; then
            hint="$(notes_get_section FOOTHOLD 2>/dev/null | grep -Eo '[a-zA-Z0-9._-]+@[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1 || true)"
            [[ -n "${hint}" ]] && { printf '%s' "${hint}"; return 0; }
        fi
    fi
    [[ -n "${user}" && -n "${target}" ]] && { printf 'ssh %s@%s' "${user}" "${target}"; return 0; }
    [[ -n "${target}" ]] && { printf 'target %s (open shell manually)' "${target}"; return 0; }
    return 1
}

neo_operator_pane_confirm_yn() {
    local prompt="$1" default="${2:-n}" choice
    [[ "${NEO_TEST_NONINTERACTIVE:-0}" == "1" || ! -t 0 ]] && return 1
    if [[ "${default}" == y ]]; then
        read -r -p "${prompt} [Y/n]: " choice
        choice="${choice:-Y}"
        [[ "${choice}" =~ ^[Yy] ]]
    else
        read -r -p "${prompt} [y/N]: " choice
        [[ "${choice}" =~ ^[Yy] ]]
    fi
}

# Session adapter (Tier 4.5): offer SSH or MSF handler command in operator pane after foothold.
neo_operator_pane_offer_session_connect() {
    local project="$1" hint="" mission_file lhost lport payload backend cmd offered msf_id
    [[ -n "${project}" ]] || return 0
    [[ "${NEO_TEST_NONINTERACTIVE:-0}" == "1" || ! -t 0 ]] && return 0
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    offered="$(meta_get session_connect_offered 2>/dev/null || true)"
    [[ "${offered}" == "1" ]] && return 0

    if hint="$(neo_operator_pane_ssh_hint "${project}" 2>/dev/null || true)" && [[ "${hint}" == ssh* ]]; then
        printf '\n[*] Session adapter: %s\n' "${hint}"
        if neo_operator_pane_confirm_yn 'Send SSH command to operator pane?' y; then
            neo_operator_pane_send_command "${hint}" || true
            meta_set session_connect_offered 1 2>/dev/null || true
        fi
        return 0
    fi

    mission_file="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}/projects/${project}/mission.json"
    if [[ -f "${mission_file}" ]] && command -v jq >/dev/null 2>&1; then
        backend="$(jq -r '.handler_plan.backend // empty' "${mission_file}" 2>/dev/null || true)"
        if [[ "${backend}" == msf ]]; then
            lhost="$(jq -r '.handler_plan.lhost // empty' "${mission_file}")"
            lport="$(jq -r '.handler_plan.lport // empty' "${mission_file}")"
            payload="$(jq -r '.handler_plan.payload // empty' "${mission_file}")"
            # shellcheck source=neo-exploit-framework.sh
            source "${NEO_LIB_DIR}/neo-exploit-framework.sh"
            if cmd="$(neo_msf_handler_command "${lhost}" "${lport}" "${payload}" 2>/dev/null)"; then
                printf '\n[*] MSF handler → tmux pane C (neo-handler).\n'
                # shellcheck source=neo-handler-pane.sh
                source "${NEO_LIB_DIR}/neo-handler-pane.sh" 2>/dev/null || true
                if declare -F neo_handler_pane_offer_msf >/dev/null 2>&1 && \
                    neo_handler_pane_available 2>/dev/null; then
                    if neo_operator_pane_confirm_yn 'Start MSF handler in handler pane (pane C)?' y; then
                        neo_handler_pane_start_msf_listener "${lhost}" "${lport}" "${payload}" || true
                        meta_set session_connect_offered 1 2>/dev/null || true
                    fi
                elif neo_operator_pane_confirm_yn 'Send MSF handler command to operator pane?' y; then
                    neo_operator_pane_send_command "${cmd}" || true
                    meta_set session_connect_offered 1 2>/dev/null || true
                fi
            fi
        fi
        msf_id="$(jq -r '.session.msf_session_id // empty' "${mission_file}" 2>/dev/null || true)"
        if [[ -z "${msf_id}" ]] && neo_operator_pane_confirm_yn 'Record Metasploit session ID for this mission?' n; then
            read -r -p 'MSF session id (from sessions -l): ' msf_id
            if [[ "${msf_id}" =~ ^[0-9]+$ ]]; then
                # shellcheck source=neo-mission-state.sh
                source "${NEO_LIB_DIR}/neo-mission-state.sh"
                neo_mission_open "${project}" 2>/dev/null && \
                    neo_mission_record_msf_session "${msf_id}" msf_meterpreter "${payload:-}" 2>/dev/null || true
            fi
        fi
    fi
}

neo_operator_pane_open_shell() {
    local project="${1:-}" pane hint
    pane="$(neo_operator_pane_ensure)" || return 1
    tmux select-pane -t "${pane}" -T "${NEO_OPERATOR_PANE_TITLE}"
    printf '\n%s[*]%s Operator pane ready (%s). Run suggested commands here — NEO pause menu stays in the other pane.\n' \
        "${C_CYAN:-}" "${C_RESET:-}" "${pane}"
    if hint="$(neo_operator_pane_ssh_hint "${project}" 2>/dev/null || true)"; then
        [[ "${hint}" == ssh* ]] && printf '  Session hint: %s\n' "${hint}"
        [[ "${hint}" == target* ]] && printf '  %s\n' "${hint}"
    fi
    tmux select-pane -t "$(tmux display-message -p '#{pane_id}')"
    return 0
}
