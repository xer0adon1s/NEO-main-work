#!/usr/bin/env bash
# neo-borg-library.sh — Borg research library lookup + ingest helpers (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"

neo_borg_library_root() {
    printf '%s/knowledge/library' "${NEO_DIR}"
}

neo_borg_library_init() {
    local root methods wt
    root="$(neo_borg_library_root)"
    methods="${root}/methods"
    wt="${root}/walkthroughs"
    mkdir -p "${methods}" "${wt}"
    [[ -f "${root}/INDEX.yaml" ]] || printf 'version: 1\nmethods: {}\nwalkthroughs: {}\n' > "${root}/INDEX.yaml"
    return 0
}

neo_borg_library_methods_dir() {
    printf '%s/methods' "$(neo_borg_library_root)"
}

neo_borg_library_walkthroughs_dir() {
    printf '%s/walkthroughs' "$(neo_borg_library_root)"
}

neo_borg_library_extract_cves() {
    local text="$1"
    grep -oE 'CVE-[0-9]{4}-[0-9]{4,}' <<< "${text}" | sort -u
}

neo_borg_library_find_by_cve() {
    local cve="$1" root idx
    root="$(neo_borg_library_root)"
    idx="${root}/INDEX.yaml"
    [[ -f "${idx}" ]] || return 0
    grep -i "${cve}" "${idx}" "${root}"/methods/*/educational.md 2>/dev/null | head -5 || true
}

neo_borg_library_context_for_vector() {
    local _project="$1" vector="$2"
    local slug dir
    slug="$(basename "${vector}")"
    dir="$(neo_borg_library_methods_dir)/${slug}"
    [[ -f "${dir}/educational.md" ]] && head -c 4000 "${dir}/educational.md" || true
}

neo_borg_library_offer_research_hook() {
    local project="$1" _phase="$2"
    printf '[*] Library research hook stub (project=%s) — run tools/borg-library-harvest.sh when ready.\n' "${project}"
    return 0
}

neo_borg_library_index_register_method() {
    local _slug="$1" _cve="$2"
    return 0
}

neo_borg_library_index_register_walkthrough() {
    local _box="$1" _path="$2"
    return 0
}
