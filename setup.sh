#!/usr/bin/env bash
# setup.sh — baseline attack-box toolset + vendor/ third-party fetch.
#
# Usage:
#   ./setup.sh              Audit missing tools; offer pacman/AUR + vendor downloads
#   ./setup.sh --check      Report only (exit 1 if anything missing)
#   ./setup.sh --yes        Install all missing without prompts (non-interactive)
#   ./setup.sh --force      Re-download vendor/ files even if present
#   ./setup.sh --vendor-only   Only vendor/ PEASS/pspy tools
#   ./setup.sh --baseline-only Only distro baseline (nmap, seclists, …)

set -euo pipefail

# Always anchor to this script's repo root — ignore inherited NEO_HOME from tests/shells.
NEO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
VENDOR="${NEO_VENDOR_DIR:-${NEO_HOME}/vendor}"
FORCE=false
CHECK=false
AUTO_YES=false
VENDOR_ONLY=false
BASELINE_ONLY=false

for arg in "$@"; do
    case "${arg}" in
        -h|--help)
            cat <<'EOF'
Usage: setup.sh [options]

NEO baseline installer — scans your attack box for tools NEO expects, then offers
to install missing distro packages (pacman / apt; AUR via yay/paru when needed)
and download third-party scripts into vendor/.

Options:
  --check          Report missing tools only (exit 1 if any missing)
  --yes, -y        Install/fetch all missing without prompts
  --force          Re-download vendor/ files even if present
  --vendor-only    Skip distro baseline; only vendor/ downloads
  --baseline-only  Skip vendor/ downloads; only distro baseline
  -h, --help       This help

Environment:
  NEO_SETUP_NONINTERACTIVE=1   Same as --yes
EOF
            exit 0
            ;;
        --force) FORCE=true ;;
        --check) CHECK=true ;;
        --yes|-y) AUTO_YES=true ;;
        --vendor-only) VENDOR_ONLY=true ;;
        --baseline-only) BASELINE_ONLY=true ;;
        *) echo "Unknown option: ${arg}" >&2; exit 1 ;;
    esac
done

[[ "${NEO_SETUP_NONINTERACTIVE:-0}" == "1" ]] && AUTO_YES=true

# label|kind|check|pacman_pkg|aur_ok
# kind: cmd = command -v, dir = directory exists, file = file exists
BASELINE=(
    'nmap|cmd|nmap|nmap|n'
    'gobuster|cmd|gobuster|gobuster|n'
    'rustscan|cmd|rustscan|rustscan|y'
    'jq|cmd|jq|jq|n'
    'curl|cmd|curl|curl|n'
    'tmux|cmd|tmux|tmux|n'
    'smbclient|cmd|smbclient|samba|n'
    'ncat|cmd|ncat|gnu-netcat|n'
    'seclists|dir|/usr/share/seclists|seclists|y'
)

THIRD_PARTY=(
    'linpeas.sh|https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh|y'
    'LinEnum.sh|https://raw.githubusercontent.com/rebootuser/LinEnum/master/LinEnum.sh|y'
    'pspy32|https://github.com/DominicBreuker/pspy/releases/latest/download/pspy32|y'
    'pspy64|https://github.com/DominicBreuker/pspy/releases/latest/download/pspy64|y'
    'winPEASany.exe|https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASany.exe|n'
    'winPEASx64.exe|https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx64.exe|n'
)

baseline_ok=0
baseline_miss=0
vendor_ok=0
vendor_miss=0

setup_confirm() {
    local prompt="$1"
    ${AUTO_YES} && return 0
    [[ -t 0 ]] || return 1
    local ans
    read -r -p "${prompt} [y/N] " ans
    case "${ans}" in y|Y) return 0 ;; *) return 1 ;; esac
}

setup_baseline_present() {
    local kind="$1" check="$2"
    case "${kind}" in
        cmd) command -v "${check}" >/dev/null 2>&1 ;;
        dir) [[ -d "${check}" ]] ;;
        file) [[ -f "${check}" ]] ;;
        *) return 1 ;;
    esac
}

setup_pkg_in_repos() {
    local pkg="$1"
    if command -v pacman >/dev/null 2>&1; then
        pacman -Si "${pkg}" >/dev/null 2>&1 && return 0
    fi
    if command -v apt-cache >/dev/null 2>&1; then
        apt-cache show "${pkg}" >/dev/null 2>&1 && return 0
    fi
    return 1
}

setup_install_distro() {
    local label="$1" pkg="$2" aur_ok="$3"
    if setup_pkg_in_repos "${pkg}"; then
        if command -v pacman >/dev/null 2>&1; then
            printf '  [pkg]  sudo pacman -S --needed %s\n' "${pkg}"
            sudo pacman -S --needed --noconfirm "${pkg}"
            return $?
        fi
        if command -v apt-get >/dev/null 2>&1; then
            printf '  [pkg]  sudo apt install %s\n' "${pkg}"
            sudo apt-get install -y "${pkg}"
            return $?
        fi
    fi

    if [[ "${aur_ok}" == y ]]; then
        if command -v yay >/dev/null 2>&1; then
            printf '  [aur]  yay -S --needed %s\n' "${pkg}"
            yay -S --needed --noconfirm "${pkg}"
            return $?
        fi
        if command -v paru >/dev/null 2>&1; then
            printf '  [aur]  paru -S --needed %s\n' "${pkg}"
            paru -S --needed --noconfirm "${pkg}"
            return $?
        fi
    fi

    printf '  [!]    %s — install %s manually (not in repos / no AUR helper)\n' "${label}" "${pkg}" >&2
    return 1
}

setup_audit_baseline() {
    local entry label kind check pkg aur_ok
    printf 'Baseline attack-box tools (distro / SecLists):\n'
    for entry in "${BASELINE[@]}"; do
        IFS='|' read -r label kind check pkg aur_ok <<< "${entry}"
        if setup_baseline_present "${kind}" "${check}"; then
            printf '  [ok]   %s\n' "${label}"
            baseline_ok=$((baseline_ok + 1))
        else
            printf '  [miss] %s (need: %s)\n' "${label}" "${check}"
            baseline_miss=$((baseline_miss + 1))
        fi
    done
    echo ""
}

setup_install_missing_baseline() {
    local entry label kind check pkg aur_ok missing=()
    for entry in "${BASELINE[@]}"; do
        IFS='|' read -r label kind check pkg aur_ok <<< "${entry}"
        setup_baseline_present "${kind}" "${check}" || missing+=("${label}|${pkg}|${aur_ok}")
    done
    ((${#missing[@]} == 0)) && return 0

    printf 'Missing baseline: %s\n' "$(printf '%s ' "${missing[@]%%|*}")"
    setup_confirm 'Install all missing baseline packages now?' || return 0

    local item
    for item in "${missing[@]}"; do
        IFS='|' read -r label pkg aur_ok <<< "${item}"
        setup_install_distro "${label}" "${pkg}" "${aur_ok}" || true
    done
}

setup_downloader() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER=curl
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER=wget
    else
        echo "Need curl or wget to download vendor tools." >&2
        return 1
    fi
}

setup_fetch_url() {
    local url="$1" dest="$2"
    if [[ "${DOWNLOADER}" == curl ]]; then
        curl -fsSL -o "${dest}" "${url}"
    else
        wget -q -O "${dest}" "${url}"
    fi
}

setup_audit_vendor() {
    local entry name url chmod_flag dest
    printf 'Third-party tools → %s\n' "${VENDOR}"
    for entry in "${THIRD_PARTY[@]}"; do
        IFS='|' read -r name url chmod_flag <<< "${entry}"
        dest="${VENDOR}/${name}"
        if [[ -f "${dest}" ]]; then
            printf '  [ok]   %s\n' "${name}"
            vendor_ok=$((vendor_ok + 1))
        else
            printf '  [miss] %s\n' "${name}"
            vendor_miss=$((vendor_miss + 1))
        fi
    done
    echo ""
}

setup_install_vendor() {
    local entry name url chmod_flag dest missing=()
    setup_downloader || return 1
    mkdir -p "${VENDOR}"

    for entry in "${THIRD_PARTY[@]}"; do
        IFS='|' read -r name url chmod_flag <<< "${entry}"
        dest="${VENDOR}/${name}"
        [[ -f "${dest}" && "${FORCE}" != true ]] && continue
        missing+=("${name}|${url}|${chmod_flag}")
    done

    ((${#missing[@]} == 0)) && {
        printf 'All vendor tools already present (use --force to re-download).\n'
        return 0
    }

    printf 'Missing vendor tools: %s\n' "$(printf '%s ' "${missing[@]%%|*}")"
    setup_confirm 'Download missing vendor tools into vendor/ now?' || return 0

    local item tmp
    for item in "${missing[@]}"; do
        IFS='|' read -r name url chmod_flag <<< "${item}"
        dest="${VENDOR}/${name}"
        printf '  [get]  %s\n' "${name}"
        tmp="$(mktemp "${dest}.XXXXXX")"
        setup_fetch_url "${url}" "${tmp}" || { rm -f "${tmp}"; return 1; }
        mv -f "${tmp}" "${dest}"
        [[ "${chmod_flag}" == y ]] && chmod +x "${dest}"
        vendor_ok=$((vendor_ok + 1))
    done
}

# --- main ---

printf 'NEO setup — baseline toolset for %s\n\n' "${NEO_HOME}"

if ! ${VENDOR_ONLY}; then
    setup_audit_baseline
    if ${CHECK}; then
        :
    else
        setup_install_missing_baseline
        baseline_ok=0
        baseline_miss=0
        setup_audit_baseline
    fi
fi

if ! ${BASELINE_ONLY}; then
    if ${CHECK}; then
        setup_audit_vendor
    else
        setup_install_vendor
        vendor_ok=0
        vendor_miss=0
        setup_audit_vendor
    fi
fi

total_miss=$((baseline_miss + vendor_miss))
total_ok=$((baseline_ok + vendor_ok))

if ${CHECK}; then
    printf 'Summary: %d ok, %d missing\n' "${total_ok}" "${total_miss}"
    if (( total_miss > 0 )); then
        printf '\nRun ./setup.sh (no flags) to install missing tools interactively.\n' >&2
        exit 1
    fi
    exit 0
fi

printf 'Done — %d tools ready (%d baseline + %d vendor)\n' \
    "${total_ok}" "${baseline_ok}" "${vendor_ok}"
(( total_miss > 0 )) && {
    printf 'Note: %d item(s) still missing — install manually or re-run ./setup.sh\n' "${total_miss}" >&2
    exit 1
}
exit 0
