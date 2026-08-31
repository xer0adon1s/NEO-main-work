#!/usr/bin/env bash
# Vendor manifest install/verify/inventory (P11 / Tier 3).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEO_HOME="${NEO_HOME:-${NEO_ROOT}}"
NEO_DIR="${NEO_DIR:-${NEO_ROOT}}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_DIR}/lib/neo-core.sh"

MANIFEST="${NEO_VENDOR_MANIFEST:-${NEO_HOME}/vendor/manifest.json}"
VENDOR_DIR="${NEO_VENDOR_DIR:-${NEO_HOME}/vendor}"

usage() {
    cat <<'EOF'
Usage: neo-vendor.sh <command> [args]

Commands:
  inventory       Print manifest entries
  verify          Check SHA-256 of installed files against manifest
  init            Create manifest scaffold with common tool entries
  install NAME    Install tool via manifest entry or distro package (operator-approved)
  rollback NAME   Restore previous manifest entry if backup exists (stub)
  install-vendor  Run ./setup.sh to fetch vendor/ tools
EOF
}

cmd_inventory() {
    neo_core_need jq || return 1
    [[ -f "${MANIFEST}" ]] || { neo_core_die "manifest not found: ${MANIFEST}"; return 1; }
    jq -r '.entries[] | "\(.name)\t\(.destination)\t\(.sha256[0:16])…\t\(.resolved_at)"' "${MANIFEST}"
}

cmd_verify() {
    neo_core_need jq sha256sum || return 1
    [[ -f "${MANIFEST}" ]] || { neo_core_die 'manifest not found'; return 1; }
    local failed=0 name dest expected actual
    while IFS=$'\t' read -r name dest expected; do
        [[ -f "${NEO_HOME}/${dest}" ]] || { printf 'MISSING %s (%s)\n' "${name}" "${dest}" >&2; failed=1; continue; }
        actual="$(sha256sum -- "${NEO_HOME}/${dest}" | awk '{print $1}')"
        [[ "${actual}" == "${expected}" ]] || { printf 'HASH MISMATCH %s\n' "${name}" >&2; failed=1; }
    done < <(jq -r '.entries[] | [.name,.destination,.sha256] | @tsv' "${MANIFEST}")
    return "${failed}"
}

cmd_init() {
    neo_core_need jq || return 1
    neo_core_secure_dir "$(dirname "${MANIFEST}")"
    jq -n '{
        schema_version: 1,
        entries: [
            {name:"nmap", destination:"/usr/bin/nmap", package:"nmap", kind:"distro"},
            {name:"gobuster", destination:"/usr/bin/gobuster", package:"gobuster", kind:"distro"},
            {name:"seclists", destination:"/usr/share/seclists", package:"seclists", kind:"distro"},
            {name:"msfconsole", destination:"/usr/bin/msfconsole", package:"metasploit", kind:"distro"}
        ]
    }' > "${MANIFEST}"
    chmod 600 -- "${MANIFEST}"
    printf 'Created manifest with common entries: %s\n' "${MANIFEST}"
}

neo_vendor_distro_install() {
    local pkg="$1"
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "${pkg}"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y "${pkg}"
    else
        neo_core_die "no supported package manager for install: ${pkg}"
        return 1
    fi
}

cmd_install() {
    local name="${1:-}" pkg dest kind
    [[ -n "${name}" ]] || { neo_core_die 'install requires tool name'; return 1; }
    neo_core_need jq || return 1
    [[ -f "${MANIFEST}" ]] || cmd_init
    pkg="$(jq -r --arg n "${name}" '.entries[] | select(.name==$n) | .package // empty' "${MANIFEST}" | head -1)"
    kind="$(jq -r --arg n "${name}" '.entries[] | select(.name==$n) | .kind // "distro"' "${MANIFEST}" | head -1)"
    dest="$(jq -r --arg n "${name}" '.entries[] | select(.name==$n) | .destination // empty' "${MANIFEST}" | head -1)"
    if [[ -n "${dest}" && -e "${dest}" ]]; then
        printf '[*] %s already present at %s\n' "${name}" "${dest}"
        return 0
    fi
    case "${kind}" in
        distro)
            [[ -n "${pkg}" ]] || pkg="${name}"
            printf '[*] Installing %s via distro package %s (requires sudo)...\n' "${name}" "${pkg}"
            neo_vendor_distro_install "${pkg}"
            ;;
        vendor)
            cmd_install_vendor
            ;;
        *)
            neo_core_die "unknown manifest kind for ${name}: ${kind}"
            return 1
            ;;
    esac
}

cmd_rollback() {
    local name="${1:-}"
    [[ -n "${name}" ]] || { neo_core_die 'rollback requires tool name'; return 1; }
    neo_core_need jq || return 1
    [[ -f "${MANIFEST}" ]] || { neo_core_die 'manifest not found'; return 1; }
    if jq -e --arg n "${name}" '.entries[] | select(.name==$n and .previous_sha256 != null)' "${MANIFEST}" >/dev/null; then
        neo_core_die 'rollback restore not implemented — re-run install or setup.sh manually'
        return 1
    fi
    printf '[*] No rollback snapshot for %s in manifest (expected for distro packages).\n' "${name}"
    return 0
}

cmd_install_vendor() {
    local setup="${NEO_HOME}/setup.sh"
    [[ -f "${setup}" ]] || { neo_core_die "setup.sh not found at ${setup}"; return 1; }
    (cd "${NEO_HOME}" && bash ./setup.sh)
}

case "${1:-}" in
    inventory) cmd_inventory ;;
    verify) cmd_verify ;;
    init) cmd_init ;;
    install) shift; cmd_install "${1:-}" ;;
    rollback) shift; cmd_rollback "${1:-}" ;;
    install-vendor) cmd_install_vendor ;;
    -h|--help|help|"") usage ;;
    *) neo_core_die "unknown command: ${1:-}"; exit 1 ;;
esac
