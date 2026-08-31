#!/usr/bin/env bash
# Atomic mission state with explicit transition rules and append-only history.

# shellcheck source=neo-core.sh
source "${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/neo-core.sh"

NEO_MISSION_FILE=""

neo_mission_init() {
    local project="$1" target="$2" root="${3:-${NEO_NEXT_STATE_ROOT}/projects}"
    neo_core_require_project "${project}" || return 1
    neo_core_need jq || return 1
    [[ -n "${target}" && "${target}" != *$'\n'* ]] || return 1
    local dir="${root}/${project}" tmp
    neo_core_secure_dir "${dir}"
    NEO_MISSION_FILE="${dir}/mission.json"
    [[ -f "${NEO_MISSION_FILE}" ]] && return 0
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq -n --arg project "${project}" --arg target "${target}" --arg now "$(neo_core_iso_timestamp)" \
        '{schema_version:1,project:$project,target:$target,state:"preflight",created_at:$now,updated_at:$now,session:null,history:[{at:$now,from:null,to:"preflight",reason:"mission created"}]}' > "${tmp}"
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

neo_mission_record_session() {
    local transport="$1" user="$2" host="$3" shell_type="$4" tmp dir
    [[ -f "${NEO_MISSION_FILE}" ]] || return 1
    [[ "$(jq -r '.state' "${NEO_MISSION_FILE}")" == session_established ]] || {
        neo_core_die 'session details may only be recorded in session_established state'
        return 1
    }
    dir="$(dirname "${NEO_MISSION_FILE}")"
    tmp="$(neo_core_secure_tmp "${dir}" .mission)" || return 1
    jq --arg transport "${transport}" --arg user "${user}" --arg host "${host}" \
        --arg shell "${shell_type}" --arg now "$(neo_core_iso_timestamp)" \
        '.session={transport:$transport,user:$user,host:$host,shell:$shell,confirmed_at:$now}' \
        "${NEO_MISSION_FILE}" > "${tmp}"
    mv -f -- "${tmp}" "${NEO_MISSION_FILE}"
    chmod 600 -- "${NEO_MISSION_FILE}"
}

neo_mission_current_state() {
    jq -r '.state' "${NEO_MISSION_FILE}"
}
