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
    local project="$1" _phase="$2" slug="" d assimilated
    # shellcheck source=neo-conductor.sh
    source "${NEO_LIB_DIR}/neo-conductor.sh" 2>/dev/null || true
    # shellcheck source=neo-borg-library-ai.sh
    source "${NEO_LIB_DIR}/neo-borg-library-ai.sh" 2>/dev/null || true
    neo_conductor_skip_interactive && return 0
    declare -F neo_borg_library_ai_available >/dev/null 2>&1 || return 0
    neo_borg_library_ai_available || return 0
    assimilated="${NEO_HOME}/projects/${project}/assimilated"
    [[ -d "${assimilated}" ]] || return 0
    for d in "${assimilated}"/*; do
        [[ -d "${d}" ]] || continue
        slug="$(basename "${d}")"
        break
    done
    [[ -n "${slug}" ]] || slug="assimilated-vector"
    if neo_conductor_prompt_yn "Research latest assimilated vector (${slug}) in Borg library?" n; then
        printf '[*] Run: ./tools/borg-library-harvest.sh --research "%s"\n' "${slug}"
        printf '    Or batch: ./tools/borg-library-harvest.sh --batch --from-project %s\n' "${project}"
    fi
    return 0
}

neo_borg_library_index_register_method() {
    local slug="$1" cve="$2" idx line ts
    neo_borg_library_init
    idx="$(neo_borg_library_root)/INDEX.yaml"
    ts="$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date)"
    line="# registered method slug=${slug} cve=${cve:-none} at=${ts}"
    grep -Fq "slug=${slug}" "${idx}" 2>/dev/null && return 0
    printf '%s\n' "${line}" >> "${idx}"
    return 0
}

neo_borg_library_index_register_walkthrough() {
    local box="$1" path="$2" idx line ts
    neo_borg_library_init
    idx="$(neo_borg_library_root)/INDEX.yaml"
    ts="$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date)"
    line="# registered walkthrough box=${box} path=${path} at=${ts}"
    grep -Fq "path=${path}" "${idx}" 2>/dev/null && return 0
    printf '%s\n' "${line}" >> "${idx}"
    return 0
}
