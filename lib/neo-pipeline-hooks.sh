#!/usr/bin/env bash
# neo-pipeline-hooks.sh — opt-in conductor hooks (plan-enum, operator-recon, privesc rank).
#
# Every hook is Y/n gated. Skipped when NEO_TEST_NONINTERACTIVE=1 or stdin is not a TTY.

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
NEO_HOME="${NEO_HOME:-${NEO_DIR}}"
# shellcheck source=neo-core.sh
source "${NEO_LIB_DIR}/neo-core.sh"

neo_pipeline_skip_interactive() {
    [[ "${NEO_TEST_NONINTERACTIVE:-0}" == "1" || ! -t 0 ]]
}

# Default: y → return 0 (yes), n → return 1. Non-interactive → return 1 (skip).
neo_pipeline_prompt_yn() {
    local prompt="$1" default="${2:-n}" choice
    neo_pipeline_skip_interactive && return 1
    if [[ "${default}" == y ]]; then
        read -r -p "${prompt} [Y/n] " choice
        choice="${choice:-Y}"
        [[ "${choice}" =~ ^[Yy] ]]
    else
        read -r -p "${prompt} [y/N] " choice
        [[ "${choice}" =~ ^[Yy] ]]
    fi
}

neo_pipeline_notes_setup() {
    local project="$1"
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    export OUTDIR NOTES_FILE
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"
}

neo_pipeline_plan_root() {
    local project="$1"
    printf '%s/projects/%s/enum-plans' "${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}" "${project}"
}

# Emit service JSON files under plan_root/services/ from PORTS section (nmap lines).
neo_pipeline_materialize_services() {
    local project="$1" target="$2" plan_root svc_dir ports line port proto service safe
    plan_root="$(neo_pipeline_plan_root "${project}")"
    svc_dir="${plan_root}/services"
    neo_core_secure_dir "${svc_dir}"
    neo_pipeline_notes_setup "${project}" || return 1
    [[ -f "${NOTES_FILE}" ]] || return 1
    ports="$(notes_get_section PORTS 2>/dev/null || true)"
    [[ -n "${ports//[[:space:]]/}" ]] || return 1
    neo_core_need jq || return 1
    local count=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ "${line}" =~ ^([0-9]+)/(tcp|udp)[[:space:]]+open[[:space:]]+([^[:space:]]+) ]] || continue
        port="${BASH_REMATCH[1]}"
        proto="${BASH_REMATCH[2]}"
        service="${BASH_REMATCH[3]}"
        safe="$(tr -cs 'a-z0-9' '-' <<< "${service}-${target}-${port}" | sed 's/^-//;s/-$//')"
        jq -n \
            --arg host "${target}" \
            --argjson port "${port}" \
            --arg protocol "${proto}" \
            --arg service "${service}" \
            '{host:$host,port:$port,protocol:$protocol,service:$service,tls:false}' \
            > "${svc_dir}/${safe}.json"
        chmod 600 -- "${svc_dir}/${safe}.json"
        count=$((count + 1))
    done <<< "${ports}"
    (( count > 0 ))
}

neo_pipeline_run_plan_enum() {
    local project="$1" target="$2" plan_root actions_dir svc count=0
    plan_root="$(neo_pipeline_plan_root "${project}")"
    actions_dir="${plan_root}/actions"
    neo_core_secure_dir "${actions_dir}"
    neo_pipeline_materialize_services "${project}" "${target}" || {
        printf '[*] No open ports in PORTS section — skip enum plan.\n'
        return 1
    }
    shopt -s nullglob
    for svc in "${plan_root}/services/"*.json; do
        bash "${NEO_DIR}/recon/plan-enum.sh" --service "${svc}" --output-dir "${actions_dir}" >/dev/null 2>&1 || true
        count=$((count + 1))
    done
    printf '[*] Enum plan: %s action file(s) under %s\n' "$(find "${actions_dir}" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')" "${actions_dir}"
    (( count > 0 ))
}

neo_pipeline_append_top_actions() {
    local project="$1" plan_root="$2" limit="${3:-3}" actions_dir lines=""
    actions_dir="${plan_root}/actions"
    [[ -d "${actions_dir}" ]] || return 1
    neo_core_need jq || return 1
    lines="$(find "${actions_dir}" -maxdepth 1 -name '*.json' -print0 2>/dev/null | \
        xargs -0 jq -r '.title + " → " + (.execution.argv | join(" "))' 2>/dev/null | head -n "${limit}" || true)"
    [[ -n "${lines}" ]] || return 1
    neo_pipeline_notes_setup "${project}" 2>/dev/null || return 1
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -n "${line//[[:space:]]/}" ]] || continue
        notes_append_section TODO "- [ ] Enum: ${line}" 2>/dev/null || true
    done <<< "${lines}"
    printf '[*] Top %s enum action(s) appended to TODO.\n' "${limit}"
}

neo_pipeline_offer_plan_enum() {
    local project="$1" target="$2" plan_root note offered
    [[ -n "${project}" && -n "${target}" ]] || return 0
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    offered="$(meta_get plan_enum_offered 2>/dev/null || true)"
    [[ "${offered}" == "1" ]] && return 0
    if neo_pipeline_prompt_yn 'Generate service enumeration plan from open ports?' y; then
        plan_root="$(neo_pipeline_plan_root "${project}")"
        neo_pipeline_run_plan_enum "${project}" "${target}" || return 1
        meta_set plan_enum_offered 1 2>/dev/null || true
        neo_pipeline_append_top_actions "${project}" "${plan_root}" 3 || true
        neo_pipeline_notes_setup "${project}" 2>/dev/null || true
        if [[ -f "${NOTES_FILE}" ]]; then
            note="$(printf '\n### Enum plan — %s\n\nGenerated action JSON under `%s/actions/`. Review: `bash recon/review-plan.sh %s/actions`\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" "${plan_root}" "${plan_root}")"
            notes_append_section TODO "- [ ] Review enum plan: bash recon/review-plan.sh ${plan_root}/actions" 2>/dev/null || true
            notes_append_section SERVICES "${note}" 2>/dev/null || true
        fi
        if neo_pipeline_prompt_yn 'Review enum plan now (interactive)?' n; then
            bash "${NEO_DIR}/recon/review-plan.sh" "${plan_root}/actions" || true
        fi
        # shellcheck source=neo-enum-ai.sh
        source "${NEO_DIR}/lib/neo-enum-ai.sh" 2>/dev/null || true
        declare -F neo_enum_ai_offer_after_plan >/dev/null 2>&1 && \
            neo_enum_ai_offer_after_plan "${project}" "${target}" || true
        return 0
    fi
    return 1
}

neo_pipeline_offer_operator_recon() {
    local project="$1" offered
    [[ -n "${project}" ]] || return 0
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    offered="$(meta_get operator_recon_offered 2>/dev/null || true)"
    [[ "${offered}" == "1" ]] && return 0
    if neo_pipeline_prompt_yn 'Capture operator recon notes before foothold?' n; then
        meta_set operator_recon_offered 1 2>/dev/null || true
        if neo_pipeline_skip_interactive; then
            return 0
        fi
        bash "${NEO_DIR}/recon/operator-recon.sh" --project "${project}" || true
    fi
}

neo_pipeline_findprivs_artifact() {
    local project="$1" dir
    dir="${NEO_HOME}/projects/${project}/artifacts"
    [[ -d "${dir}" ]] || return 1
    find "${dir}" \( -maxdepth 1 -name 'FindPrivs-*' -o -name 'findprivs-*' \) 2>/dev/null | head -1
}

neo_pipeline_offer_privesc_rank() {
    local project="$1" plan_root facts plan artifact note top
    [[ -n "${project}" ]] || return 0
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    offered="$(meta_get privesc_rank_offered 2>/dev/null || true)"
    [[ "${offered}" == "1" ]] && return 0
    plan_root="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}/projects/${project}/privesc"
    neo_core_secure_dir "${plan_root}"
    facts="${plan_root}/privesc-facts.json"
    plan="${plan_root}/privesc-plan.json"

    neo_pipeline_notes_setup "${project}" 2>/dev/null || true
    if [[ ! -f "${facts}" ]]; then
        artifact="$(neo_pipeline_findprivs_artifact "${project}" || true)"
        if [[ -n "${artifact}" && -f "${artifact}" ]]; then
            bash "${NEO_DIR}/privesc/normalize-findprivs.sh" \
                --input "${artifact}" --output "${facts}" --source-artifact "${artifact}" 2>/dev/null || true
        elif [[ -f "${NOTES_FILE}" ]] && notes_get_section WHOAMI >/dev/null 2>&1; then
            tmp="$(neo_core_secure_tmp "${plan_root}" findprivs)"
            {
                notes_get_section WHOAMI 2>/dev/null || true
                notes_get_section SUDO 2>/dev/null | sed '1s/^/=== sudo privileges ===\n/' || true
                notes_get_section SUID 2>/dev/null | sed '1s/^/=== SUID binaries ===\n/' || true
            } > "${tmp}"
            bash "${NEO_DIR}/privesc/normalize-findprivs.sh" \
                --input "${tmp}" --output "${facts}" 2>/dev/null || true
            rm -f -- "${tmp}"
        fi
    fi

    [[ -f "${facts}" ]] || return 0

    if ! neo_pipeline_prompt_yn 'Rank privesc hypotheses from FindPrivs evidence?' y; then
        return 1
    fi

    bash "${NEO_DIR}/privesc/rank-privesc-plan.sh" --input "${facts}" --output "${plan}" || return 1
    meta_set privesc_rank_offered 1 2>/dev/null || true
    top="$(jq -r '.ranked_items[0:3][] | "\(.rank). \(.title) (score \(.rank_score))"' "${plan}" 2>/dev/null || true)"
    [[ -n "${top}" ]] && printf '\nTop privesc leads:\n%s\n\n' "${top}"

    if neo_pipeline_prompt_yn 'Append ranked plan summary to Investigation-Notes?' y; then
        note="$(printf '### Privesc rank — %s\n\n```text\n%s\n```\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${top}")"
        notes_append_section ATTACKPATH "${note}" 2>/dev/null || \
            notes_append_section TODO "- [ ] Privesc rank: see ${plan}" 2>/dev/null || true
    fi
}

neo_pipeline_mission_has_session_context() {
    local project="$1" mission_file state has=""
    mission_file="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}/projects/${project}/mission.json"
    [[ -f "${mission_file}" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    state="$(jq -r '.state' "${mission_file}" 2>/dev/null || true)"
    has="$(jq -r 'if .session then "yes" elif .handler_plan then "handler" else "no" end' "${mission_file}" 2>/dev/null || true)"
    [[ "${has}" != no ]] || [[ "${state}" == session_established || "${state}" == privileged || "${state}" == post ]]
}

neo_pipeline_offer_msf_post() {
    local project="$1" offered
    [[ -n "${project}" ]] || return 0
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh" 2>/dev/null || true
    offered="$(meta_get msf_post_offered 2>/dev/null || true)"
    [[ "${offered}" == "1" ]] && return 0
    neo_pipeline_mission_has_session_context "${project}" || return 0
    # shellcheck source=neo-exploit-framework.sh
    source "${NEO_LIB_DIR}/neo-exploit-framework.sh"
    neo_msf_binary_available msfconsole || return 0
    if ! neo_pipeline_prompt_yn 'Open Metasploit post-module menu (advisory)?' n; then
        return 0
    fi
    meta_set msf_post_offered 1 2>/dev/null || true
    # shellcheck source=neo-conductor.sh
    source "${NEO_DIR}/lib/neo-conductor.sh" 2>/dev/null || true
    if declare -F neo_conductor_ai_available >/dev/null 2>&1 && neo_conductor_ai_available && \
        neo_conductor_prompt_yn 'AI-suggest MSF post modules first?' y; then
        neo_msf_ai_suggest_post "${project}" || true
        if neo_pipeline_prompt_yn 'Also open static MSF post menu?' n; then
            neo_msf_offer_post_module_menu "${project}" || true
        fi
        return 0
    fi
    neo_msf_offer_post_module_menu "${project}" || true
}
