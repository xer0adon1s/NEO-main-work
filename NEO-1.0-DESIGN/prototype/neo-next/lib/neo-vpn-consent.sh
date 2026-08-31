#!/usr/bin/env bash
# OpenVPN discovery and explicit-consent lifecycle helpers.

# shellcheck source=neo-core.sh
source "${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/neo-core.sh"

neo_vpn_processes() {
    pgrep -x openvpn 2>/dev/null || true
}

neo_vpn_describe_processes() {
    local pids
    pids="$(neo_vpn_processes)"
    [[ -n "${pids}" ]] || return 0
    printf 'Detected OpenVPN processes:\n'
    while IFS= read -r pid; do
        ps -o pid=,user=,etimes=,args= -p "${pid}" 2>/dev/null || printf '  PID %s (details unavailable)\n' "${pid}"
    done <<< "${pids}"
}

# Returns: 0 terminate approved/performed, 2 keep existing, 3 cancel profile change.
neo_vpn_resolve_existing() {
    local pids answer
    pids="$(neo_vpn_processes)"
    [[ -n "${pids}" ]] || return 0
    [[ -t 0 ]] || {
        neo_core_die 'OpenVPN is already running; non-interactive mode will not terminate it'
        return 3
    }

    neo_vpn_describe_processes
    cat <<'EOF'

Changing profiles may require terminating every OpenVPN process listed above. This can
disconnect unrelated lab, personal, or corporate VPN sessions.

  [k] Keep all existing connections and continue without changing profile
  [a] Terminate ALL listed OpenVPN processes, then continue
  [q] Cancel the VPN profile change
EOF
    while true; do
        read -r -p 'Choice [k/a/q]: ' answer
        case "${answer}" in
            k|K|'') return 2 ;;
            q|Q) return 3 ;;
            a|A)
                neo_core_confirm 'Type terminate-all-openvpn to confirm: ' terminate-all-openvpn || {
                    printf 'Confirmation did not match; nothing was terminated.\n'
                    continue
                }
                command -v sudo >/dev/null 2>&1 || { neo_core_die 'sudo is required'; return 1; }
                # Kill exactly the PIDs shown and approved, not a fresh wildcard lookup.
                while IFS= read -r pid; do
                    [[ "${pid}" =~ ^[0-9]+$ ]] || continue
                    sudo kill -TERM "${pid}" 2>/dev/null || true
                done <<< "${pids}"
                sleep 1
                local survivors=()
                while IFS= read -r pid; do
                    [[ -n "${pid}" ]] || continue
                    kill -0 "${pid}" 2>/dev/null && survivors+=("${pid}")
                done <<< "${pids}"
                ((${#survivors[@]} == 0)) || {
                    neo_core_die "some approved OpenVPN processes remain: ${survivors[*]}"
                    return 1
                }
                return 0
                ;;
            *) printf 'Choose k, a, or q.\n' ;;
        esac
    done
}
