#!/usr/bin/env bash
# ovpn-connect — find a lab .ovpn (Downloads first, then ~/Neo/vpn/), stage it,
# and bring OpenVPN up in a detached tmux session.
#
# Usage:
#   ./ovpn-connect.sh              # interactive: attach to VPN tmux when up
#   ./ovpn-connect.sh --no-attach  # start VPN detached only (NEO boot ritual)

set -euo pipefail

NEO_HOME="${NEO_HOME:-${HOME}/Neo}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
ATTACH=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-attach) ATTACH=0; shift ;;
        -h|--help)
            sed -n '2,8p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# shellcheck source=lib/neo-vpn.sh
source "${NEO_DIR}/lib/neo-vpn.sh"

VPN_DIR="$(neo_vpn_dir)"
DOWNLOADS="$(neo_vpn_downloads_dir)"

log() {
    printf '[*] %s\n' "$*"
}

need() {
    command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' is required but not on PATH." >&2; exit 1; }
}

need tmux
need openvpn
need sudo

mkdir -p "$VPN_DIR"

ovpn_src="$(neo_vpn_pick_newest "$DOWNLOADS")"
already_filed=0
if [[ -n "$ovpn_src" ]]; then
    log "Found profile in Downloads: $(basename "$ovpn_src")"
else
    ovpn_src="$(neo_vpn_pick_newest "$VPN_DIR")"
    already_filed=1
    if [[ -n "$ovpn_src" ]]; then
        log "Using profile in ${VPN_DIR}: $(basename "$ovpn_src")"
    fi
fi

if [[ -z "$ovpn_src" ]]; then
    echo "ERROR: no .ovpn file found in ${DOWNLOADS} or ${VPN_DIR}." >&2
    exit 1
fi

dest="$(neo_vpn_stage_profile "$ovpn_src" "$already_filed")"
if [[ "$already_filed" -eq 0 ]]; then
    log "Moved to ${dest} (replaced any previous profile in ${VPN_DIR})"
fi

session="$(neo_vpn_session_name "$dest")"
log "Starting OpenVPN in tmux session '${session}'..."
neo_vpn_connect_profile "$dest" 0

if [[ "${ATTACH}" == "0" ]]; then
    log "OpenVPN started detached (sudo password, if needed, is in tmux session '${session}')."
    log "Attach manually: tmux attach -t ${session}"
    exit 0
fi

echo
log "Attaching now — enter your sudo password if prompted."
log "Watch for 'Initialization Sequence Completed', then detach with Ctrl+b, d."
log "(Reattach anytime with: tmux attach -t ${session})"
echo
sleep 1
neo_vpn_attach_session "$dest"
