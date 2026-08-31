#!/usr/bin/env bash
# Mission state machine (C7).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=neo-core.sh
source "${NEO_LIB_DIR}/neo-core.sh"

NEO_MISSION_FILE=""

neo_mission_init() {
    local project="$1" target="$2" root="${3:-${NEO_STATE_ROOT}/projects}"
    neo_core_require_project "${project}" || return 1
    neo_core_need jq || return 1
    [[ -n "${target}" && "${target}" != *$'\n'* ]] || return 1
    local dir="${root}/${project}" tmp scope_file
    neo_core_secure_dir "${dir}"
    NEO_MISSION_FILE="${dir}/mission.json"
    [[ -f "${NEO_MISSION_FILE}" ]] && return 0
    scope_file=""
    if declare -F neo_scope_path >/dev/null 2>&1; then
        scope_file="$(neo_scope_path "${project}" "${root}" 2>/dev/null || true)"
    fi
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq -n \
        --arg project "${project}" --arg target "${target}" --arg now "$(neo_core_iso_timestamp)" \
        --arg scope "${scope_file}" \
        '{schema_version:1,project:$project,target:$target,state:"preflight",scope_file:(if $scope=="" then null else $scope end),created_at:$now,updated_at:$now,session:null,history:[{at:$now,from:null,to:"preflight",reason:"mission created"}]}' \
        > "${tmp}"
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

neo_mission_allowed_transition() {
    local from="$1" to="$2"
    case "${from}:${to}" in
        preflight:recon|recon:operator_recon|operator_recon:triage|triage:borg_offer|\
        borg_offer:borg_assimilation|borg_offer:foothold_planning|\
        borg_assimilation:foothold_planning|foothold_planning:foothold_attempt|\
        foothold_attempt:foothold_planning|foothold_attempt:session_established|\
        session_established:post_foothold_enum|post_foothold_enum:privesc_planning|\
        privesc_planning:privesc_attempt|privesc_attempt:privesc_planning|\
        privesc_attempt:privileged|privileged:post|post:complete) return 0 ;;
        *) return 1 ;;
    esac
}

neo_mission_transition() {
    local to="$1" reason="$2" from tmp dir
    [[ -f "${NEO_MISSION_FILE}" ]] || { neo_core_die 'mission state is not initialized'; return 1; }
    from="$(jq -r '.state' "${NEO_MISSION_FILE}")"
    neo_mission_allowed_transition "${from}" "${to}" || {
        neo_core_die "invalid mission transition: ${from} -> ${to}"
        return 1
    }
    dir="$(dirname "${NEO_MISSION_FILE}")"
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq --arg from "${from}" --arg to "${to}" --arg reason "${reason}" --arg now "$(neo_core_iso_timestamp)" \
        '.state=$to | .updated_at=$now | .history += [{at:$now,from:$from,to:$to,reason:$reason}]' \
        "${NEO_MISSION_FILE}" > "${tmp}"
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

# Silent transition for pipeline sync (no die on invalid).
neo_mission_try_transition() {
    local to="$1" reason="$2" from tmp dir
    [[ -f "${NEO_MISSION_FILE}" ]] || return 1
    from="$(jq -r '.state' "${NEO_MISSION_FILE}")"
    [[ "${from}" == "${to}" ]] && return 0
    neo_mission_allowed_transition "${from}" "${to}" || return 1
    dir="$(dirname "${NEO_MISSION_FILE}")"
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq --arg from "${from}" --arg to "${to}" --arg reason "${reason}" --arg now "$(neo_core_iso_timestamp)" \
        '.state=$to | .updated_at=$now | .history += [{at:$now,from:$from,to:$to,reason:$reason}]' \
        "${NEO_MISSION_FILE}" > "${tmp}"
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

neo_mission_open() {
    local project="$1" root="${2:-${NEO_STATE_ROOT}/projects}"
    NEO_MISSION_FILE="${root}/${project}/mission.json"
    [[ -f "${NEO_MISSION_FILE}" ]]
}

# Align mission.json with phases.yaml walk (best-effort, no die).
neo_mission_sync_pipeline_phase() {
    local phase="$1" cur
    [[ -f "${NEO_MISSION_FILE}" ]] || return 0
    case "${phase}" in
        recon)
            neo_mission_try_transition recon 'pipeline: recon phase' || true
            ;;
        foothold)
            cur="$(neo_mission_current_state)"
            [[ "${cur}" == preflight ]] && neo_mission_try_transition recon 'pipeline sync' || true
            cur="$(neo_mission_current_state)"
            [[ "${cur}" == recon ]] && neo_mission_try_transition borg_offer 'pipeline sync' || true
            cur="$(neo_mission_current_state)"
            [[ "${cur}" == borg_offer || "${cur}" == borg_assimilation ]] && \
                neo_mission_try_transition foothold_planning 'pipeline sync' || true
            ;;
        privesc)
            cur="$(neo_mission_current_state)"
            case "${cur}" in
                session_established)
                    neo_mission_try_transition post_foothold_enum 'pipeline sync' || true
                    cur="$(neo_mission_current_state)"
                    [[ "${cur}" == post_foothold_enum ]] && \
                        neo_mission_try_transition privesc_planning 'pipeline sync' || true
                    ;;
                post_foothold_enum)
                    neo_mission_try_transition privesc_planning 'pipeline sync' || true
                    ;;
            esac
            ;;
        post)
            cur="$(neo_mission_current_state)"
            [[ "${cur}" == privileged ]] && neo_mission_try_transition post 'pipeline sync' || true
            ;;
    esac
}

neo_mission_context_block() {
    local project="$1"
    local file="${NEO_STATE_ROOT}/projects/${project}/mission.json"
    [[ -f "${file}" ]] || return 0
    neo_core_need jq || return 0
    jq -r '
        "## Mission state",
        ("State: " + .state),
        (if .handler_plan then "Handler: \(.handler_plan.backend) \(.handler_plan.payload) @ \(.handler_plan.lhost):\(.handler_plan.lport)" else empty end),
        (if .session then
            "Session: \(.session.transport)"
            + (if .session.msf_session_id then " id=\(.session.msf_session_id)" else "" end)
            + (if .session.user then " \(.session.user)@\(.session.host // "?")" else "" end)
         else empty end)
    ' "${file}" 2>/dev/null || true
}

neo_mission_record_session() {
    local transport="$1" user="$2" host="$3" shell_type="$4" msf_id="${5:-}" state tmp dir
    [[ -f "${NEO_MISSION_FILE}" ]] || return 1
    state="$(jq -r '.state' "${NEO_MISSION_FILE}")"
    case "${state}" in
        session_established|privileged|post|foothold_attempt) ;;
        *)
            neo_core_die "session details may not be recorded in state: ${state}"
            return 1
            ;;
    esac
    dir="$(dirname "${NEO_MISSION_FILE}")"
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    if [[ -n "${msf_id}" ]]; then
        jq --arg transport "${transport}" --arg user "${user}" --arg host "${host}" \
            --arg shell "${shell_type}" --arg msf_id "${msf_id}" --arg now "$(neo_core_iso_timestamp)" \
            '.session={transport:$transport,user:$user,host:$host,shell:$shell,msf_session_id:$msf_id,confirmed_at:$now}' \
            "${NEO_MISSION_FILE}" > "${tmp}"
    else
        jq --arg transport "${transport}" --arg user "${user}" --arg host "${host}" \
            --arg shell "${shell_type}" --arg now "$(neo_core_iso_timestamp)" \
            '.session={transport:$transport,user:$user,host:$host,shell:$shell,confirmed_at:$now}' \
            "${NEO_MISSION_FILE}" > "${tmp}"
    fi
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

# Record Metasploit session id after operator confirms meterpreter/shell (P21).
neo_mission_record_msf_session() {
    local session_id="$1" transport="${2:-msf_meterpreter}" payload="${3:-}" state tmp dir
    [[ -f "${NEO_MISSION_FILE}" ]] || return 1
    [[ -n "${session_id}" ]] || return 1
    state="$(jq -r '.state' "${NEO_MISSION_FILE}")"
    case "${state}" in
        foothold_planning|foothold_attempt|session_established|post_foothold_enum|privesc_planning|privesc_attempt|privileged|post)
            [[ "${state}" == foothold_planning || "${state}" == foothold_attempt ]] && \
                neo_mission_try_transition session_established 'MSF session confirmed' || true
            ;;
        *)
            neo_core_die "MSF session may not be recorded in state: ${state}"
            return 1
            ;;
    esac
    dir="$(dirname "${NEO_MISSION_FILE}")"
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq --arg transport "${transport}" --argjson msf_id "${session_id}" --arg payload "${payload}" \
        --arg now "$(neo_core_iso_timestamp)" \
        '.session={transport:$transport,user:"",host:"",shell:"msf",msf_session_id:$msf_id,payload:(if $payload=="" then null else $payload end),confirmed_at:$now}' \
        "${NEO_MISSION_FILE}" > "${tmp}"
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

# Record handler plan before session is established (P21 stub).
neo_mission_record_handler_plan() {
    local lhost="$1" lport="$2" payload="$3" backend="${4:-msf}" tmp dir
    [[ -f "${NEO_MISSION_FILE}" ]] || return 1
    dir="$(dirname "${NEO_MISSION_FILE}")"
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq --arg lhost "${lhost}" --argjson lport "${lport}" --arg payload "${payload}" \
        --arg backend "${backend}" --arg now "$(neo_core_iso_timestamp)" \
        '.handler_plan={backend:$backend,lhost:$lhost,lport:$lport,payload:$payload,recorded_at:$now}' \
        "${NEO_MISSION_FILE}" > "${tmp}"
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

neo_mission_current_state() {
    jq -r '.state' "${NEO_MISSION_FILE}"
}

neo_mission_require_state() {
    local expected="$1" current
    [[ -f "${NEO_MISSION_FILE}" ]] || return 0
    current="$(neo_mission_current_state)"
    [[ "${current}" == "${expected}" ]] || {
        neo_core_die "mission state is ${current}; expected ${expected}"
        return 1
    }
}

# --- Conductor playbook state (Tier B) ---

neo_mission_conductor_get() {
    local field="$1" default="${2:-}"
    [[ -f "${NEO_MISSION_FILE}" ]] || { printf '%s' "${default}"; return 0; }
    neo_core_need jq || { printf '%s' "${default}"; return 0; }
    jq -r --arg f "${field}" --arg d "${default}" \
        'if .conductor then (.conductor[$f] // $d) else $d end' "${NEO_MISSION_FILE}" 2>/dev/null || printf '%s' "${default}"
}

neo_mission_conductor_patch() {
    local field="$1" value="$2" tmp dir
    [[ -f "${NEO_MISSION_FILE}" ]] || return 1
    neo_core_need jq || return 1
    dir="$(dirname "${NEO_MISSION_FILE}")"
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq --arg f "${field}" --arg v "${value}" --arg now "$(neo_core_iso_timestamp)" \
        '.conductor = (.conductor // {}) | .conductor[$f] = $v | .updated_at = $now' \
        "${NEO_MISSION_FILE}" > "${tmp}"
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

neo_mission_conductor_patch_int() {
    local field="$1" value="$2" tmp dir
    [[ -f "${NEO_MISSION_FILE}" ]] || return 1
    neo_core_need jq || return 1
    dir="$(dirname "${NEO_MISSION_FILE}")"
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq --arg f "${field}" --argjson v "${value}" --arg now "$(neo_core_iso_timestamp)" \
        '.conductor = (.conductor // {}) | .conductor[$f] = $v | .updated_at = $now' \
        "${NEO_MISSION_FILE}" > "${tmp}"
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

neo_mission_conductor_reset_loop() {
    neo_mission_conductor_patch active_playbook ""
    neo_mission_conductor_patch_int loop_count 0
    neo_mission_conductor_patch playbook_state idle
    neo_mission_conductor_patch stopped_reason ""
}
