#!/usr/bin/env bash
# neo-boot.sh — Matrix / rabbit first-launch intro, AI confirm, VPN ritual for neo.sh

# shellcheck source=lib/neo-splash.sh
source "${NEO_DIR}/lib/neo-splash.sh"
# shellcheck source=lib/neo-vpn.sh
source "${NEO_DIR}/lib/neo-vpn.sh"

neo_boot_init_colors() {
    neo_splash_init_colors
    C_CYAN="${C_CYAN:-$'\033[0;36m'}"
    C_WHITE="${C_WHITE:-$'\033[1;37m'}"
}

neo_boot_banner() {
    local title="$1" line2="${2:-}" line3="${3:-}"
    neo_boot_init_colors
    printf '\n' >&2
    printf '%s╔══════════════════════════════════════════════════════════════════════╗%s\n' "${C_GREEN}" "${C_RESET}" >&2
    printf '%s║%s\n' "${C_GREEN}" "${C_RESET}" >&2
    printf '%s║%s  %-66s  %s║%s\n' "${C_GREEN}" "${C_BRIGHT}" "${title}" "${C_GREEN}" "${C_RESET}" >&2
    [[ -n "${line2}" ]] && printf '%s║%s  %-66s  %s║%s\n' "${C_GREEN}" "${C_DIM}" "${line2}" "${C_GREEN}" "${C_RESET}" >&2
    [[ -n "${line3}" ]] && printf '%s║%s  %-66s  %s║%s\n' "${C_GREEN}" "${C_DIM}" "${line3}" "${C_GREEN}" "${C_RESET}" >&2
    printf '%s║%s\n' "${C_GREEN}" "${C_RESET}" >&2
    printf '%s╚══════════════════════════════════════════════════════════════════════╝%s\n\n' "${C_GREEN}" "${C_RESET}" >&2
}

neo_boot_type_line() {
    local text="$1" delay="${2:-0.04}" c
    neo_boot_init_colors
    printf '%s' "${C_BRIGHT}"
    for (( c = 0; c < ${#text}; c++ )); do
        printf '%s' "${text:c:1}"
        sleep "${delay}" 2>/dev/null || sleep 0.04
    done
    printf '%s\n' "${C_RESET}"
}

neo_boot_rabbit_intro() {
    local total="${NEO_BOOT_INTRO_SEC:-7}" elapsed=0 quote i
    local quotes=(
        'Wake up, Neo...'
        'The Matrix has you...'
        'Follow the white rabbit.'
        'Knock, knock, Neo.'
    )

    neo_boot_init_colors
    printf '\n'

    while (( elapsed < total )); do
        neo_splash_rain_frame
        elapsed=$((elapsed + 1))
    done

    cat <<'EOF' | while IFS= read -r line; do neo_splash_color_line "${line}"; done
        /\   /\
       (  . .)
        )   (
       (  v  )
      ^^  ^  ^^
EOF

    printf '\n'
    for quote in "${quotes[@]}"; do
        neo_boot_type_line "${quote}" 0.035
        sleep 0.45
    done

    if (( ${COLUMNS:-100} >= 80 )); then
        neo_splash_print
    else
        neo_boot_banner 'N E O' 'autonomous lab operator' 'authorized labs only'
    fi

    neo_boot_type_line '...the story ends, you wake up and believe whatever you want to believe.' 0.02
    sleep 0.8
    printf '\n'
}

neo_boot_ai_confirmed() {
    local mode="${NEO_AI_MODE:-manual}" sub
    case "${mode}" in
        subscription) sub='Claude Pro/Max · claude -p' ;;
        api)          sub='Claude API key · analyze-recon' ;;
        *)            sub='Manual review · Investigation-Notes.md' ;;
    esac
    neo_boot_banner '▓▓▓  A I   M O D E   C O N F I R M E D  ▓▓▓' "${sub}"
    sleep 0.6
}

neo_boot_vpn_detected_banner() {
    local addr
    addr="$(neo_vpn_ip 2>/dev/null || echo 'unknown')"
    neo_boot_banner \
        '⚡  V P N   C O N N E C T I O N   D E T E C T E D  ⚡' \
        "interface: tun0" \
        "address:   ${addr}"
}

neo_boot_vpn_confirmed_banner() {
    local addr msg="${1:-existing}"
    addr="$(neo_vpn_ip 2>/dev/null || echo 'unknown')"
    if [[ "${msg}" == "new" ]]; then
        neo_boot_banner \
            '✓  N E W   V P N   C O N N E C T I O N   C O N F I R M E D  ✓' \
            "interface: tun0" \
            "address:   ${addr}"
    else
        neo_boot_banner \
            '✓  V P N   C O N N E C T I O N   C O N F I R M E D  ✓' \
            "interface: tun0" \
            "address:   ${addr}"
    fi
}

neo_boot_attempting_connect() {
    local spin='|/-\' i=0 secs="${NEO_VPN_WAIT:-90}"
    neo_boot_init_colors
    printf '\n%s╔══════════════════════════════════════════════════════════════════════╗%s\n' "${C_GREEN}" "${C_RESET}" >&2
    printf '%s║%s  %-66s  %s║%s\n' "${C_GREEN}" "${C_BRIGHT}" '⟳  A T T E M P T I N G   T O   C O N N E C T  ⟳' "${C_GREEN}" "${C_RESET}" >&2
    printf '%s╚══════════════════════════════════════════════════════════════════════╝%s\n\n' "${C_GREEN}" "${C_RESET}" >&2

    while (( i < secs )); do
        if neo_vpn_up; then
            printf '\r%-72s\r' ' ' >&2
            return 0
        fi
        printf '\r%s%s%s waiting for tun0... %s' "${C_CYAN}" "${spin:i%4:1}" "${C_RESET}" "${i}s" >&2
        sleep 1
        i=$((i + 1))
    done
    printf '\r%-72s\r' ' ' >&2
    return 1
}

neo_boot_pick_ovpn_interactive() {
    local -a profiles=() pick downloads vpn
    mapfile -t profiles < <(neo_vpn_find_profiles | sort -u)

    if ((${#profiles[@]} == 0)); then
        downloads="$(neo_vpn_downloads_dir)"
        vpn="$(neo_vpn_dir)"
        echo "No .ovpn profiles found in ${downloads} or ${vpn}." >&2
        return 1
    fi

    if ((${#profiles[@]} == 1)); then
        printf '%s\n' "${profiles[0]}"
        return 0
    fi

    printf '\nAvailable OpenVPN profiles:\n' >&2
    local i=1
    for p in "${profiles[@]}"; do
        printf '  [%d] %s\n' "${i}" "$(basename "${p}")" >&2
        i=$((i + 1))
    done
    while true; do
        read -r -p "Choose profile [1-${#profiles[@]}]: " pick
        [[ "${pick}" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= ${#profiles[@]} )) && break
        printf 'Enter a number between 1 and %d.\n' "${#profiles[@]}" >&2
    done
    printf '%s\n' "${profiles[$((pick - 1))]}"
}

neo_boot_ping_target() {
    local target="$1"
    [[ -n "${target}" ]] || return 0
    neo_boot_init_colors
    printf '%s[*]%s Pinging lab target %s...\n' "${C_BRIGHT}" "${C_RESET}" "${target}" >&2
    if ping -c 2 -W 3 "${target}" >/dev/null 2>&1; then
        neo_boot_banner '✓  L A B   T A R G E T   R E A C H A B L E  ✓' "${target}"
        return 0
    fi
    printf '\n%s[!]%s Could not ping %s — VPN may still be settling, or IP may be wrong.\n' \
        "${C_BRIGHT}" "${C_RESET}" "${target}" >&2
    local ans
    read -r -p 'Continue anyway? [y/N] ' ans
    [[ "${ans}" =~ ^[Yy] ]]
}

neo_boot_vpn_flow() {
    local project="$1"
    local target_cli="${2:-}"
    local target="${target_cli}"
    local ans src dest already_filed downloads

    # Mission resume / non-boot paths never invoke ovpn-connect — operator connects manually.
    if [[ "${NEO_BOOT_VPN_RITUAL:-0}" != "1" ]]; then
        neo_vpn_up || printf '\n%s[!]%s VPN not detected — connect manually when needed: %s/connect/ovpn-connect.sh\n' \
            "${C_BRIGHT:-}" "${C_RESET:-}" "${NEO_DIR}" >&2
        return 0
    fi

    if neo_vpn_up; then
        neo_boot_vpn_detected_banner
        read -r -p 'Keep this VPN connection? [Y/n/new] (n or new = connect a different .ovpn) ' ans
        ans="$(tr '[:upper:]' '[:lower:]' <<< "${ans}")"
        case "${ans}" in
            n|new)
                :
                ;;
            *)
                neo_boot_vpn_confirmed_banner existing
                ;;
        esac

        if [[ "${ans}" != "n" && "${ans}" != "new" ]]; then
            if [[ -z "${target}" ]]; then
                read -r -p 'Lab target IP (connectivity check): ' target
                [[ -n "${target}" ]] || { echo "neo: target IP required." >&2; return 1; }
            fi
            neo_boot_ping_target "${target}" || return 1
            printf '%s\n' "${target}"
            return 0
        fi
    fi

    # No VPN (or operator chose a new profile after declining the current one).
    if ! neo_vpn_up; then
        downloads="$(neo_vpn_downloads_dir)"
        read -r -p "Ready to connect to the VPN using your .ovpn profile in ${downloads}? [y/N] " ans
        if [[ ! "${ans}" =~ ^[Yy]$ ]]; then
            echo "neo: VPN setup declined — re-run when ready to connect." >&2
            return 1
        fi
        printf '\n[*] Starting VPN via connect/ovpn-connect.sh (detached)...\n' >&2
        bash "${NEO_DIR}/connect/ovpn-connect.sh" --no-attach || return 1
        neo_boot_attempting_connect || {
            echo "neo: VPN did not come up. Attach with: tmux attach -t <session> (see ovpn-connect output)." >&2
            return 1
        }
        neo_boot_vpn_confirmed_banner new
        if [[ -z "${target}" ]]; then
            read -r -p 'Lab target IP (connectivity check): ' target
            [[ -n "${target}" ]] || { echo "neo: target IP required." >&2; return 1; }
        fi
        neo_boot_ping_target "${target}" || return 1
        printf '%s\n' "${target}"
        return 0
    fi

    # VPN was up but operator asked for a different profile — pick + detached connect (no attach).
    src="$(neo_boot_pick_ovpn_interactive)" || return 1
    printf '\n[*] Using profile: %s\n' "$(basename "${src}")" >&2

    if [[ "${src}" == "$(neo_vpn_downloads_dir)"/* ]]; then
        already_filed=0
    elif [[ "${src}" == "$(neo_vpn_dir)"/* ]]; then
        already_filed=1
    else
        already_filed=0
    fi

    dest="$(neo_vpn_stage_profile "${src}" "${already_filed}")"

    printf '\n[*] Starting OpenVPN (sudo password may be required in tmux)...\n' >&2
    neo_vpn_connect_profile "${dest}" 0 || return 1

    neo_boot_attempting_connect || {
        echo "neo: VPN did not come up. Attach with: tmux attach -t $(neo_vpn_session_name "${dest}")" >&2
        return 1
    }

    neo_boot_vpn_confirmed_banner new

    if [[ -z "${target}" ]]; then
        read -r -p 'Lab target IP (connectivity check): ' target
        [[ -n "${target}" ]] || { echo "neo: target IP required." >&2; return 1; }
    fi
    neo_boot_ping_target "${target}" || return 1
    printf '%s\n' "${target}"
}
