#!/usr/bin/env bash
# neo-conductor-loop.sh — event dispatcher + guided/assisted playbooks (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh"

neo_conductor_on_event() {
    local event="$1" project="$2" phase="${3:-}" _extra="${4:-}"
    neo_conductor_skip_interactive && return 0
    case "${event}" in
        borg.assimilate_complete)
            declare -F neo_borg_library_offer_research_hook >/dev/null 2>&1 && \
                neo_borg_library_offer_research_hook "${project}" "${phase}" || true
            ;;
        privesc.ingest_complete)
            declare -F neo_conductor_privesc_after_ingest >/dev/null 2>&1 && \
                neo_conductor_privesc_after_ingest "${project}" || true
            ;;
        recon.triage_complete)
            ;;
        foothold.entry|privesc.entry|post.entry)
            neo_conductor_on_phase_entry "${project}" "${phase:-${event%%.*}}}" || true
            ;;
        *)
            ;;
    esac
    return 0
}

neo_conductor_run_assisted_loop() {
    local project="$1" phase="$2" max_loops="${3:-$(neo_conductor_loop_default_max)}" mode
    local i=0
    neo_conductor_skip_interactive && return 0
    mode="$(neo_conductor_resolve_mode "${project}")"
    [[ "${mode}" == "assisted" ]] || return 0
    neo_conductor_prompt_yn "Run assisted workbench loop (max ${max_loops} tries)?" n || return 0
    # shellcheck source=neo-workbench.sh
    source "${NEO_DIR}/lib/neo-workbench.sh" 2>/dev/null || return 0
    while (( i < max_loops )); do
        declare -F neo_workbench_try_loop_step >/dev/null 2>&1 || break
        neo_workbench_try_loop_step "${project}" "${phase}" true || break
        i=$((i + 1))
    done
    return 0
}
