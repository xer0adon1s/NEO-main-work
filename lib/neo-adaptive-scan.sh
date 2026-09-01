#!/usr/bin/env bash
# neo-adaptive-scan.sh — adaptive scan mode hints + deep-target queue (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh" 2>/dev/null || true

neo_adaptive_scan_targets_file() {
    printf '%s/projects/%s/state/deep-targets.txt' "${NEO_HOME}" "$1"
}

neo_adaptive_scan_extract_ports() {
    local project="$1" ports
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=notes-lib.sh
    source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || return 1
    ports="$(notes_get_section PORTS 2>/dev/null | grep -oE '[0-9]+/tcp' | cut -d/ -f1 | sort -nu | tr '\n' ' ')"
    [[ -n "${ports// /}" ]] || return 1
    printf '%s' "${ports}"
}

neo_adaptive_scan_build_targets_file() {
    local project="$1" ports file p
    ports="$(neo_adaptive_scan_extract_ports "${project}" 2>/dev/null || true)"
    [[ -n "${ports}" ]] || return 1
    file="$(neo_adaptive_scan_targets_file "${project}")"
    mkdir -p "$(dirname "${file}")"
    : > "${file}"
    for p in ${ports}; do
        printf '%s/tcp\n' "${p}" >> "${file}"
    done
    sort -u -o "${file}" "${file}" 2>/dev/null || true
    [[ -s "${file}" ]] || return 1
    printf '%s' "${file}"
}

neo_adaptive_scan_recommend() {
    local project="$1" _target="$2"
    local mode
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    mode="$(meta_get scan_mode 2>/dev/null || echo speed)"
    printf '[*] Adaptive scan: current mode=%s (project=%s). Use --deep-recon for nikto/wordlists.\n' \
        "${mode}" "${project}"
    return 0
}

neo_adaptive_scan_offer_after_triage() {
    local project="$1" file mode
    neo_conductor_skip_interactive && return 0
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    mode="$(meta_get scan_mode 2>/dev/null || echo speed)"
    [[ "${mode}" == "deep" ]] && return 0
    file="$(neo_adaptive_scan_build_targets_file "${project}" 2>/dev/null || true)"
    [[ -n "${file}" && -s "${file}" ]] || return 0
    if neo_conductor_prompt_yn 'Queue targeted deep enum on discovered ports?' n; then
        OUTDIR="${NEO_HOME}/projects/${project}"
        NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
        # shellcheck source=notes-lib.sh
        source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || true
        notes_append_section TODO "- [ ] Targeted deep enum: recon/babysteps.sh ${project} --deep --targets-file=${file}" 2>/dev/null || true
        meta_set adaptive_deep_targets "${file}" 2>/dev/null || true
        printf '[*] Deep targets saved: %s (%s ports)\n' "${file}" "$(wc -l < "${file}" | tr -d ' ')"
    fi
    return 0
}
neo_adaptive_scan_after_babysteps() {
    local project="$1" target="$2"
    neo_adaptive_scan_recommend "${project}" "${target}"
}
