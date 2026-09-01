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
  rollback NAME   Restore vendor file from backup snapshot when available
  install-vendor  Run ./setup.sh to fetch vendor/ tools
EOF
}

neo_vendor_resolve_path() {
    local dest="$1"
    [[ "${dest}" == /* ]] && printf '%s' "${dest}" || printf '%s/%s' "${NEO_HOME}" "${dest#./}"
}

neo_vendor_backup_dir() {
    printf '%s/backups' "${VENDOR_DIR}"
}

neo_vendor_snapshot_entry() {
    local name="$1" dest abs sha backup tmp now
    neo_core_need jq sha256sum || return 1
    [[ -f "${MANIFEST}" ]] || return 0
    dest="$(jq -r --arg n "${name}" '.entries[] | select(.name==$n) | .destination // empty' "${MANIFEST}" | head -1)"
    [[ -n "${dest}" ]] || return 0
    abs="$(neo_vendor_resolve_path "${dest}")"
    [[ -f "${abs}" ]] || return 0
    sha="$(sha256sum -- "${abs}" | awk '{print $1}')"
    neo_core_secure_dir "$(neo_vendor_backup_dir)"
    backup="$(neo_vendor_backup_dir)/${name}-$(date +%Y%m%d%H%M%S)"
    cp -a -- "${abs}" "${backup}"
    now="$(neo_core_iso_timestamp)"
    tmp="$(neo_core_secure_tmp "$(dirname "${MANIFEST}")" .vendor-manifest)" || return 1
    jq --arg n "${name}" --arg sha "${sha}" --arg backup "${backup}" --arg now "${now}" \
        '(.entries[] | select(.name==$n)) |= . + {
            previous_sha256: $sha,
            backup_path: $backup,
            snapshot_at: $now
        }' "${MANIFEST}" > "${tmp}"
    mv -f -- "${tmp}" "${MANIFEST}"
    chmod 600 -- "${MANIFEST}"
}

neo_vendor_record_installed() {
    local name="$1" dest abs sha now tmp
    neo_core_need jq sha256sum || return 1
    dest="$(jq -r --arg n "${name}" '.entries[] | select(.name==$n) | .destination // empty' "${MANIFEST}" | head -1)"
    [[ -n "${dest}" ]] || return 0
    abs="$(neo_vendor_resolve_path "${dest}")"
    [[ -f "${abs}" ]] || return 0
    sha="$(sha256sum -- "${abs}" | awk '{print $1}')"
    now="$(neo_core_iso_timestamp)"
    tmp="$(neo_core_secure_tmp "$(dirname "${MANIFEST}")" .vendor-manifest)" || return 1
    jq --arg n "${name}" --arg sha "${sha}" --arg now "${now}" \
        '(.entries[] | select(.name==$n)) |= . + {sha256: $sha, resolved_at: $now}' \
        "${MANIFEST}" > "${tmp}"
    mv -f -- "${tmp}" "${MANIFEST}"
    chmod 600 -- "${MANIFEST}"
}

cmd_inventory() {
    neo_core_need jq || return 1
    [[ -f "${MANIFEST}" ]] || { neo_core_die "manifest not found: ${MANIFEST}"; return 1; }
    jq -r '.entries[] | "\(.name)\t\(.destination)\t\(.sha256[0:16] // "-")…\t\(.resolved_at // "-")"' "${MANIFEST}"
}

cmd_verify() {
    neo_core_need jq sha256sum || return 1
    [[ -f "${MANIFEST}" ]] || { neo_core_die 'manifest not found'; return 1; }
    local failed=0 name dest expected actual abs
    while IFS=$'\t' read -r name dest expected; do
        abs="$(neo_vendor_resolve_path "${dest}")"
        [[ -f "${abs}" ]] || { printf 'MISSING %s (%s)\n' "${name}" "${dest}" >&2; failed=1; continue; }
        actual="$(sha256sum -- "${abs}" | awk '{print $1}')"
        [[ -n "${expected}" && "${expected}" != "null" && "${actual}" == "${expected}" ]] \
            || { printf 'HASH MISMATCH %s\n' "${name}" >&2; failed=1; }
    done < <(jq -r '.entries[] | [.name,.destination,.sha256 // ""] | @tsv' "${MANIFEST}")
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
    if [[ -n "${dest}" ]]; then
        abs="$(neo_vendor_resolve_path "${dest}")"
        if [[ -e "${abs}" ]]; then
            printf '[*] %s already present at %s\n' "${name}" "${abs}"
            neo_vendor_record_installed "${name}" || true
            return 0
        fi
    fi
    case "${kind}" in
        distro)
            [[ -n "${pkg}" ]] || pkg="${name}"
            printf '[*] Installing %s via distro package %s (requires sudo)...\n' "${name}" "${pkg}"
            neo_vendor_distro_install "${pkg}"
            neo_vendor_record_installed "${name}" || true
            ;;
        vendor)
            neo_vendor_snapshot_entry "${name}" || true
            cmd_install_vendor
            neo_vendor_record_installed "${name}" || true
            ;;
        *)
            neo_core_die "unknown manifest kind for ${name}: ${kind}"
            return 1
            ;;
    esac
}

cmd_rollback() {
    local name="${1:-}" backup dest abs tmp sha
    [[ -n "${name}" ]] || { neo_core_die 'rollback requires tool name'; return 1; }
    neo_core_need jq sha256sum || return 1
    [[ -f "${MANIFEST}" ]] || { neo_core_die 'manifest not found'; return 1; }
    backup="$(jq -r --arg n "${name}" '.entries[] | select(.name==$n) | .backup_path // empty' "${MANIFEST}" | head -1)"
    dest="$(jq -r --arg n "${name}" '.entries[] | select(.name==$n) | .destination // empty' "${MANIFEST}" | head -1)"
    if [[ -z "${backup}" || ! -f "${backup}" ]]; then
        if jq -e --arg n "${name}" '.entries[] | select(.name==$n and .previous_sha256 != null)' "${MANIFEST}" >/dev/null; then
            printf '[*] Snapshot metadata exists for %s but no file backup — distro packages must be removed manually (pacman/apt).\n' "${name}"
            return 0
        fi
        printf '[*] No rollback snapshot for %s in manifest.\n' "${name}"
        return 0
    fi
    abs="$(neo_vendor_resolve_path "${dest}")"
    neo_core_secure_dir "$(dirname "${abs}")"
    cp -a -- "${backup}" "${abs}"
    sha="$(sha256sum -- "${abs}" | awk '{print $1}')"
    tmp="$(neo_core_secure_tmp "$(dirname "${MANIFEST}")" .vendor-manifest)" || return 1
    jq --arg n "${name}" --arg sha "${sha}" --arg now "$(neo_core_iso_timestamp)" \
        '(.entries[] | select(.name==$n)) |= (. + {sha256: $sha, restored_at: $now} | del(.backup_path, .previous_sha256, .snapshot_at))' \
        "${MANIFEST}" > "${tmp}"
    mv -f -- "${tmp}" "${MANIFEST}"
    chmod 600 -- "${MANIFEST}"
    printf '[+] Restored %s from %s\n' "${name}" "${backup}"
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
