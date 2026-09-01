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

neo_borg_library_ai_system_prompt() {
    local mode="${1:-educational}"
    cat <<EOF
You synthesize Borg research library entries for authorized cybersecurity lab learning.
Library mode emphasis: ${mode}.

Output exactly these markdown sections (in order):

## Educational library entry
Teaching-oriented explanation — concepts, safe lab checks, no ready-to-paste exploit chains.

## Professional reference (full intel)
Technical reference for experienced operators — tools, technique IDs, detection notes.

## CVEs
Bullet list of CVE IDs mentioned in context, or "none identified".

## Techniques
MITRE or technique tags (one per line).

## Suggested sources
Short list of where to read more (hacktricks, nvd, vendor advisories, etc.).

## Suggested library slug
One line: lowercase slug with hyphens (e.g. redis-unauth-rce).
EOF
}

neo_borg_library_ai_research() {
    local topic="$1" ctx="$2" mode="${3:-educational}"
    local bundle sys response
    neo_borg_library_ai_available || return 1
    # shellcheck source=neo-borg-disclosure.sh
    source "${NEO_LIB_DIR}/neo-borg-disclosure.sh" 2>/dev/null || true
    # shellcheck source=neo-payload.sh
    source "${NEO_LIB_DIR}/neo-payload.sh" 2>/dev/null || return 1
    neo_payload_init_colors 2>/dev/null || true

    bundle="$(cat <<EOF
# Borg library research
Topic: ${topic}
Mode: ${mode}

$(neo_borg_disclosure_ai_rules "" 2>/dev/null || printf 'DISCLOSURE MODE: EDUCATIONAL\n')

## Research index excerpt
$(neo_borg_library_research_index_excerpt 3000)

## Context
${ctx:-_none_}
EOF
)"
    if ((${#bundle} > ${NEO_AI_BUNDLE_MAX:-28000})); then
        bundle="${bundle:0:${NEO_AI_BUNDLE_MAX:-28000}}"
    fi

    printf '[*] Borg library AI research: %s\n' "${topic}" >&2
    if ! response="$(neo_payload_call_ai "${bundle}" "$(neo_borg_library_ai_system_prompt "${mode}")" "")"; then
        return 1
    fi
    printf '%s' "${response}"
    return 0
}

neo_borg_library_ai_write_artifacts() {
    local topic="$1" response="$2" slug dir edu_file prof_file
    neo_borg_library_ai_parse_response "${response}" || return 1
    slug="${NEO_LIBRARY_AI_SLUG:-$(neo_borg_harvest_slugify "${topic}" 2>/dev/null || basename "${topic}")}"
    # shellcheck source=neo-borg-library.sh
    source "${NEO_LIB_DIR}/neo-borg-library.sh"
    # shellcheck source=neo-borg-harvest.sh
    source "${NEO_LIB_DIR}/neo-borg-harvest.sh" 2>/dev/null || true
    neo_borg_library_init
    dir="$(neo_borg_library_methods_dir)/${slug}"
    mkdir -p "${dir}"
    edu_file="${dir}/educational.md"
    prof_file="${dir}/professional-steps.md"
    printf '%s\n' "${NEO_LIBRARY_AI_EDUCATIONAL}" > "${edu_file}"
    if [[ -n "${NEO_LIBRARY_AI_PROFESSIONAL}" ]]; then
        printf '%s\n' "${NEO_LIBRARY_AI_PROFESSIONAL}" > "${prof_file}"
    else
        cp "${edu_file}" "${prof_file}"
    fi
    printf '%s|%s' "${edu_file}" "${prof_file}"
}
}
