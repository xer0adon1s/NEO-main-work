#!/usr/bin/env bash
# neo-enum-ai.sh — post enum-plan AI hook (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh"

neo_enum_ai_offer_after_plan() {
    local project="$1" target="$2"
    neo_conductor_skip_interactive && return 0
    if neo_conductor_prompt_yn 'AI-review enum plan and suggest top actions?' n; then
        bundle="$(neo_conductor_build_bundle "${project}" recon triage)"
        [[ -n "${bundle}" ]] && printf '[*] Enum AI review bundle ready for %s (%s).\n' "${target}" "${project}"
    fi
    return 0
}
