#!/usr/bin/env bash
# neo-vpn.sh — OpenVPN helpers shared by neo.sh boot flow and connect/ovpn-connect.sh

neo_vpn_up() {
    ip -4 addr show tun0 2>/dev/null | grep -q 'inet '
}

neo_vpn_ip() {
    ip -4 addr show tun0 2>/dev/null | awk '/inet / { split($2, a, "/"); print a[1]; exit }'
}

neo_vpn_downloads_dir() {
    xdg-user-dir DOWNLOAD 2>/dev/null || echo "${HOME}/Downloads"
}

neo_vpn_dir() {
    printf '%s/vpn' "${NEO_HOME:-${HOME}/Neo}"
}

# neo_vpn_pick_newest <dir> — newest .ovpn path, or empty
neo_vpn_pick_newest() {
    find "$1" -maxdepth 1 -iname '*.ovpn' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -n1 | cut -d' ' -f2-
}

# neo_vpn_find_profiles — prints one path per line: downloads first, then vpn/
neo_vpn_find_profiles() {
    local d vpn downloads seen=()
    downloads="$(neo_vpn_downloads_dir)"
    vpn="$(neo_vpn_dir)"
    for d in "${downloads}" "${vpn}"; do
        [[ -d "${d}" ]] || continue
        while IFS= read -r -d '' f; do
            seen+=("${f}")
            printf '%s\n' "${f}"
        done < <(find "${d}" -maxdepth 1 -iname '*.ovpn' -print0 2>/dev/null | sort -z)
    done
}

# neo_vpn_resolve_profile [preferred_path]
# Picks newest from Downloads, else newest from vpn/, else preferred if set.
neo_vpn_resolve_profile() {
    local preferred="${1:-}" downloads vpn src already_filed=0
    downloads="$(neo_vpn_downloads_dir)"
    vpn="$(neo_vpn_dir)"
    mkdir -p "${vpn}"

    src="$(neo_vpn_pick_newest "${downloads}")"
    if [[ -n "${src}" ]]; then
        already_filed=0
    else
        src="$(neo_vpn_pick_newest "${vpn}")"
        already_filed=1
    fi

    if [[ -z "${src}" && -n "${preferred}" && -f "${preferred}" ]]; then
        src="${preferred}"
        [[ "${preferred}" == "${vpn}"/* ]] && already_filed=1 || already_filed=0
    fi

    [[ -n "${src}" ]] || return 1
    printf '%s\n' "${src}"
    printf '%s\n' "${already_filed}" >&2
}

# neo_vpn_stage_profile <src> — move into ~/Neo/vpn/ if needed; prints dest path
neo_vpn_stage_profile() {
    local src="$1" vpn dest already_filed="${2:-0}"
    vpn="$(neo_vpn_dir)"
    mkdir -p "${vpn}"

    if [[ "${already_filed}" == "1" ]]; then
        printf '%s\n' "${src}"
        return 0
    fi

    dest="${vpn}/$(basename "${src}")"
    find "${vpn}" -maxdepth 1 -iname '*.ovpn' ! -name "$(basename "${dest}")" -exec rm -f {} +
    mv -f "${src}" "${dest}"
    printf '%s\n' "${dest}"
}

# neo_vpn_session_name <ovpn_path>
neo_vpn_session_name() {
    local session
    session="$(basename "$1" .ovpn)"
    session="${session//[:.]/-}"
    printf '%s\n' "${session}"
}

# neo_vpn_connect_profile <ovpn_path> [wait_seconds]
# Starts openvpn in tmux (detached). Waits for tun0 when wait_seconds > 0.
neo_vpn_connect_profile() {
    local dest="$1" wait_secs="${2:-90}"
    local session

    command -v tmux >/dev/null 2>&1 || { echo "neo-vpn: tmux required" >&2; return 1; }
    command -v openvpn >/dev/null 2>&1 || { echo "neo-vpn: openvpn required" >&2; return 1; }
    command -v sudo >/dev/null 2>&1 || { echo "neo-vpn: sudo required" >&2; return 1; }
    [[ -f "${dest}" ]] || { echo "neo-vpn: profile not found: ${dest}" >&2; return 1; }

    session="$(neo_vpn_session_name "${dest}")"

    if tmux has-session -t "${session}" 2>/dev/null; then
        tmux kill-session -t "${session}" 2>/dev/null || true
    fi

    if pgrep -x openvpn >/dev/null 2>&1; then
        sudo pkill -x openvpn 2>/dev/null || true
        sleep 1
    fi

    tmux new-session -d -s "${session}" "sudo openvpn --config '${dest}'"

    if (( wait_secs <= 0 )); then
        return 0
    fi

    local i=0
    while (( i < wait_secs )); do
        neo_vpn_up && return 0
        sleep 1
        i=$((i + 1))
    done

    echo "neo-vpn: timed out waiting for tun0 (${wait_secs}s)" >&2
    return 1
}

# neo_vpn_attach_session <ovpn_path> — attach tmux (ovpn-connect interactive end)
neo_vpn_attach_session() {
    local session
    session="$(neo_vpn_session_name "$1")"
    exec tmux attach -t "${session}"
}
