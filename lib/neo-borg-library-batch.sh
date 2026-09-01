#!/usr/bin/env bash
# neo-borg-library-batch.sh — batch library harvest queue (Tier B Wave 5 prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"

neo_borg_library_batch_build_queue_from_project() {
    local project="$1" assimilated queue slug d
    assimilated="${NEO_HOME}/projects/${project}/assimilated"
    [[ -d "${assimilated}" ]] || return 1
    queue="$(mktemp "/tmp/neo-borg-batch-${project}.XXXXXX")"
    : > "${queue}"
    for d in "${assimilated}"/*; do
        [[ -d "${d}" ]] || continue
        slug="$(basename "${d}")"
        printf '%s\n' "${slug}" >> "${queue}"
    done
    [[ -s "${queue}" ]] || { rm -f "${queue}"; return 1; }
    printf '%s' "${queue}"
}

neo_borg_library_batch_run() {
    local queue="$1" dry="${2:-0}"
    local slug rc=0
    [[ -f "${queue}" ]] || return 1
    while IFS= read -r slug || [[ -n "${slug}" ]]; do
        [[ -n "${slug}" ]] || continue
        if [[ "${dry}" == "1" ]]; then
            printf '[dry-run] would harvest library entry: %s\n' "${slug}"
        else
            if bash "${NEO_DIR}/tools/borg-library-harvest.sh" --research "${slug}"; then
                printf '[ok] batch harvested: %s\n' "${slug}"
            else
                printf '[!] batch harvest failed: %s\n' "${slug}" >&2
                rc=1
            fi
        fi
    done < "${queue}"
    return "${rc}"
}

neo_borg_library_batch_offer() {
    local project="$1"
    local queue
    queue="$(neo_borg_library_batch_build_queue_from_project "${project}" 2>/dev/null || true)"
    [[ -n "${queue}" ]] || return 0
    printf '[*] %s assimilated vector(s) eligible for library batch harvest.\n' "$(wc -l < "${queue}" | tr -d ' ')"
    rm -f "${queue}"
    return 0
}
