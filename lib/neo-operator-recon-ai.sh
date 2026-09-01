#!/usr/bin/env bash
# neo-operator-recon-ai.sh — operator recon capture AI summary (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh"

neo_operator_recon_ai_offer() {
    local project="$1"
    neo_conductor_skip_interactive && return 0
    if neo_conductor_prompt_yn 'Summarize operator recon notes with AI?' n; then
        bundle="$(neo_conductor_build_bundle "${project}" recon triage)"
        [[ -n "${bundle}" ]] && printf '[*] Operator recon AI bundle ready.\n'
    fi
    return 0
}

neo_operator_recon_ai_summarize() {
    local project="$1"
    neo_operator_recon_ai_offer "${project}"
}
