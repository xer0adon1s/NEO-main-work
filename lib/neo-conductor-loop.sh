#!/usr/bin/env bash
# neo-conductor-loop.sh — event dispatcher + guided/assisted playbooks (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh"
# shellcheck source=neo-conductor-tuning.sh
source "${NEO_LIB_DIR}/neo-conductor-tuning.sh"

neo_conductor_assisted_loop_enabled() {
    local project="$1"
    [[ "${NEO_ASSISTED_LOOP:-${NEO_CONDUCTOR_LOOP:-1}}" != "0" ]] || return 1
    [[ "$(neo_conductor_resolve_mode "${project}")" == "assisted" ]] || return 1
    return 0
}

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
        recon.triage_complete|foothold.entry|privesc.entry|post.entry)
            neo_conductor_on_phase_entry "${project}" "${phase:-${event%%.*}}}" || true
            ;;
        *)
            ;;
    esac
    return 0
}

neo_conductor_loop_record_iteration() {
    local project="$1" count
    # shellcheck source=neo-mission-state.sh
    source "${NEO_LIB_DIR}/neo-mission-state.sh" 2>/dev/null || return 0
    neo_mission_open "${project}" 2>/dev/null || return 0
    count="$(neo_mission_conductor_get loop_count 0)"
    [[ "${count}" =~ ^[0-9]+$ ]] || count=0
    neo_mission_conductor_patch_int loop_count $((count + 1)) 2>/dev/null || true
}

neo_conductor_offer_batch_failure_review() {
    local project="$1" phase="$2"
    local mode
    mode="$(neo_conductor_resolve_mode "${project}")"
    # shellcheck source=neo-payload.sh
    source "${NEO_DIR}/lib/neo-payload.sh" 2>/dev/null || return 0
    declare -F neo_payload_analyze_failures_at_pause >/dev/null 2>&1 || return 0
    if [[ "${mode}" == "assisted" ]]; then
        printf '\n[*] Assisted loop cap reached — running batch failure review…\n'
        neo_payload_analyze_failures_at_pause "${project}" "${phase}" || true
        return 0
    fi
    if neo_conductor_prompt_yn 'Run batch failure review for this loop?' n; then
        neo_payload_analyze_failures_at_pause "${project}" "${phase}" || true
    fi
}

# Assisted mode: suggest → try → analyze without manual [p] or [t].
neo_conductor_run_assisted_loop() {
    local project="$1" phase="$2" max_loops tool i=0 had_success=false

    neo_conductor_skip_interactive && return 0
    neo_conductor_assisted_loop_enabled "${project}" || return 0
    neo_conductor_ai_available || return 0

    max_loops="$(neo_conductor_loop_max_for_phase "${project}" "${phase}")"

    # shellcheck source=neo-payload.sh
    source "${NEO_DIR}/lib/neo-payload.sh" 2>/dev/null || return 0
    # shellcheck source=neo-workbench.sh
    source "${NEO_DIR}/lib/neo-workbench.sh" 2>/dev/null || return 0
    declare -F neo_payload_suggest_loop_step >/dev/null 2>&1 || return 0
    declare -F neo_workbench_try_loop_step >/dev/null 2>&1 || return 0
    declare -F neo_payload_auto_tool >/dev/null 2>&1 || return 0

    # shellcheck source=neo-mission-state.sh
    source "${NEO_LIB_DIR}/neo-mission-state.sh" 2>/dev/null || true
    if declare -F neo_mission_conductor_patch >/dev/null 2>&1; then
        neo_mission_open "${project}" 2>/dev/null || true
        neo_mission_conductor_patch active_playbook "${phase}_loop" 2>/dev/null || true
        neo_mission_conductor_patch_int max_loops "${max_loops}" 2>/dev/null || true
    fi

    printf '\n[*] Assisted loop (%s): suggest → try → analyze — max %s iteration(s).\n' \
        "${phase}" "${max_loops}"
    printf '    Tuning: NEO_CONDUCTOR_MAX_LOOPS / conductor_max_loops in meta; foothold default 3, privesc 4.\n'

    while (( i < max_loops )); do
        tool="$(neo_payload_auto_tool "${project}")" || {
            printf '[*] Assisted loop: no tool candidate — stopping.\n'
            break
        }
        if ! neo_payload_suggest_loop_step "${project}" "${phase}" "${tool}"; then
            printf '[*] Assisted loop: payload suggest failed — stopping.\n'
            break
        fi
        if ! neo_workbench_try_loop_step "${project}" "${phase}" true; then
            printf '[*] Assisted loop: try step ended — stopping.\n'
            break
        fi
        neo_conductor_loop_record_iteration "${project}"
        i=$((i + 1))
        if [[ "${NEO_WORKBENCH_LAST_OUTCOME:-}" == success ]]; then
            had_success=true
            printf '[*] Assisted loop: success outcome — stopping early.\n'
            break
        fi
    done

    printf '[*] Assisted loop finished (%s iteration(s)).\n' "${i}"
    if [[ "${had_success}" != true && "${i}" -ge "${max_loops}" && "${i}" -gt 0 ]]; then
        neo_conductor_offer_batch_failure_review "${project}" "${phase}" || true
    fi
    return 0
}
