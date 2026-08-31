#!/usr/bin/env bash
# Vendor manifest install/verify/inventory (design prototype for P11).

set -euo pipefail

NEO_NEXT_ROOT="${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-$(cd "${NEO_NEXT_ROOT}/../../.." && pwd)}"
source "${NEO_NEXT_ROOT}/lib/neo-core.sh"

MANIFEST="${NEO_VENDOR_MANIFEST:-${NEO_SOURCE_ROOT}/vendor/manifest.json}"
VENDOR_DIR="${NEO_VENDOR_DIR:-${NEO_SOURCE_ROOT}/vendor}"

usage() {
    cat <<'EOF'
Usage: neo-vendor.sh <command>

Commands:
  inventory    Print manifest entries
  verify       Check SHA-256 of installed files against manifest
  init         Create empty manifest scaffold

Install/rollback are integration-time operations — see P11 DESIGN.md.
EOF
}

cmd_inventory() {
    neo_core_need jq || return 1
    [[ -f "${MANIFEST}" ]] || { neo_core_die "manifest not found: ${MANIFEST}"; return 1; }
    jq -r '.entries[] | "\(.name)\t\(.destination)\t\(.sha256[0:16])…\t\(.resolved_at)"' "${MANIFEST}"
}

cmd_verify() {
    neo_core_need jq sha256sum || return 1
    [[ -f "${MANIFEST}" ]] || { neo_core_die "manifest not found"; return 1; }
    local failed=0 name dest expected actual
    while IFS=$'\t' read -r name dest expected; do
        [[ -f "${NEO_SOURCE_ROOT}/${dest}" ]] || { printf 'MISSING %s (%s)\n' "${name}" "${dest}" >&2; failed=1; continue; }
        actual="$(sha256sum -- "${NEO_SOURCE_ROOT}/${dest}" | awk '{print $1}')"
        [[ "${actual}" == "${expected}" ]] || { printf 'HASH MISMATCH %s\n' "${name}" >&2; failed=1; }
    done < <(jq -r '.entries[] | [.name,.destination,.sha256] | @tsv' "${MANIFEST}")
    return "${failed}"
}

cmd_init() {
    neo_core_need jq || return 1
    neo_core_secure_dir "$(dirname "${MANIFEST}")"
    jq -n '{schema_version:1,entries:[]}' > "${MANIFEST}"
    chmod 600 -- "${MANIFEST}"
    printf 'Created empty manifest: %s\n' "${MANIFEST}"
}

case "${1:-}" in
    inventory) cmd_inventory ;;
    verify) cmd_verify ;;
    init) cmd_init ;;
    -h|--help|help|"") usage ;;
    *) neo_core_die "unknown command: ${1:-}"; exit 1 ;;
esac
