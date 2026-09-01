#!/usr/bin/env bash
# neo-borg-library-ai.sh — AI library synthesis parse/write (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"

NEO_LIBRARY_AI_EDUCATIONAL=""
NEO_LIBRARY_AI_PROFESSIONAL=""
NEO_LIBRARY_AI_SLUG=""

neo_borg_library_ai_available() {
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then return 0; fi
    command -v claude >/dev/null 2>&1
}

neo_borg_library_research_index_excerpt() {
    local max="${1:-2000}" idx
    idx="${NEO_DIR}/knowledge/resources/borg_research_index.yaml"
    [[ -f "${idx}" ]] || { printf 'borg-research-index: (missing)\n'; return 0; }
    head -c "${max}" "${idx}"
}

neo_borg_library_ai_parse_response() {
    local text="$1" section="" line
    NEO_LIBRARY_AI_EDUCATIONAL=""
    NEO_LIBRARY_AI_PROFESSIONAL=""
    NEO_LIBRARY_AI_SLUG=""
    while IFS= read -r line || [[ -n "${line}" ]]; do
        case "${line}" in
            '## Educational library entry'|'## Educational'*)
                section=educational
                continue
                ;;
            '## Professional reference'*)
                section=professional
                continue
                ;;
            '## Suggested library slug'*)
                section=slug
                continue
                ;;
            '## '*)
                section=""
                continue
                ;;
        esac
        case "${section}" in
            educational) NEO_LIBRARY_AI_EDUCATIONAL+="${line}"$'\n' ;;
            professional) NEO_LIBRARY_AI_PROFESSIONAL+="${line}"$'\n' ;;
            slug)
                [[ -z "${NEO_LIBRARY_AI_SLUG}" && -n "${line//[[:space:]]/}" ]] && \
                    NEO_LIBRARY_AI_SLUG="$(tr -d '[:space:]' <<< "${line}")"
                ;;
        esac
    done <<< "${text}"
    NEO_LIBRARY_AI_EDUCATIONAL="${NEO_LIBRARY_AI_EDUCATIONAL%$'\n'}"
    [[ -n "${NEO_LIBRARY_AI_EDUCATIONAL}" ]]
}

neo_borg_library_ai_research() {
    local topic="$1" _ctx="$2" _mode="${3:-educational}"
    printf '[*] Library AI research stub for: %s\n' "${topic}" >&2
    return 1
}

neo_borg_library_ai_write_artifacts() {
    local topic="$1" response="$2" slug dir
    neo_borg_library_ai_parse_response "${response}" || return 1
    slug="${NEO_LIBRARY_AI_SLUG:-topic}"
    # shellcheck source=neo-borg-library.sh
    source "${NEO_LIB_DIR}/neo-borg-library.sh"
    neo_borg_library_init
    dir="$(neo_borg_library_methods_dir)/${slug}"
    mkdir -p "${dir}"
    printf '%s\n' "${NEO_LIBRARY_AI_EDUCATIONAL}" > "${dir}/educational.md"
    printf '%s\n' "${dir}/educational.md"
}
