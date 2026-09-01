#!/usr/bin/env bash
# neo-ai-guard.sh — global AI output disclosure guard (Tier B Wave 4 prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=neo-borg-disclosure.sh
source "${NEO_LIB_DIR}/neo-borg-disclosure.sh"

neo_ai_guard_output() {
    local project="${1:-}" text="$2" _label="${3:-ai-output}"
    local mode scrubbed
    [[ -n "${text}" ]] || return 0
    mode="$(neo_borg_disclosure_mode "${project}")"

    if [[ "${mode}" == "educational" ]]; then
        scrubbed="$(neo_borg_disclosure_scrub_educational "${text}")"
        if ! neo_borg_disclosure_check educational "${scrubbed}"; then
            if [[ "${NEO_DISCLOSURE_STRICT:-0}" == "1" ]]; then
                return 1
            fi
            scrubbed="$(neo_borg_disclosure_redact_educational "${scrubbed}")"
        fi
        printf '%s' "${scrubbed}"
        return 0
    fi

    if [[ "${NEO_DISCLOSURE_LINT_ALL:-0}" == "1" ]]; then
        if neo_borg_disclosure_check professional "${text}"; then
            printf '%s' "${text}"
            return 0
        fi
        if [[ "${NEO_DISCLOSURE_STRICT:-0}" == "1" ]]; then
            return 1
        fi
    fi
    printf '%s' "${text}"
    return 0
}
