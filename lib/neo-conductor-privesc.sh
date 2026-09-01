#!/usr/bin/env bash
# neo-conductor-privesc.sh — privesc-phase conductor hooks (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh"

neo_conductor_privesc_after_ingest() {
    local project="$1"
    neo_conductor_skip_interactive && return 0
    if neo_conductor_prompt_yn 'Run AI privesc triage on new FindPrivs evidence?' y; then
        bundle="$(neo_conductor_build_bundle "${project}" privesc privesc-triage)"
        [[ -n "${bundle}" ]] && printf '[*] Privesc triage bundle ready (%s bytes).\n' "${#bundle}"
    fi
    return 0
}

neo_conductor_privesc_offer_rank() {
    local project="$1"
    neo_conductor_privesc_after_ingest "${project}"
}
