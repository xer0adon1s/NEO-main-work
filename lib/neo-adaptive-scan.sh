#!/usr/bin/env bash
# neo-adaptive-scan.sh — adaptive scan mode hints (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"

neo_adaptive_scan_recommend() {
    local project="$1" _target="$2"
    local mode
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    mode="$(meta_get scan_mode 2>/dev/null || echo speed)"
    printf '[*] Adaptive scan: current mode=%s (project=%s). Use --deep-recon for nikto/wordlists.\n' \
        "${mode}" "${project}"
    return 0
}

neo_adaptive_scan_after_babysteps() {
    local project="$1" target="$2"
    neo_adaptive_scan_recommend "${project}" "${target}"
}
