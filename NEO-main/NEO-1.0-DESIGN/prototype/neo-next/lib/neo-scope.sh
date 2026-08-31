#!/usr/bin/env bash
# Engagement scope: educational vs professional intake and network checks.

# shellcheck source=neo-core.sh
source "${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/neo-core.sh"

NEO_SCOPE_FILE=""
NEO_SCOPE_MODE=""

# Platform hints — editable by operator during intake; not enforced as hard defaults.
neo_scope_platform_hints() {
    case "$1" in
        htb) printf '%s\n' '10.10.10.0/23' '10.10.11.0/24' '10.129.0.0/16' ;;
        tryhackme) printf '%s\n' '10.10.0.0/16' ;;
        *) return 0 ;;
    esac
}

neo_scope_path() {
    local project="$1" root="${2:-${NEO_NEXT_STATE_ROOT}/projects}"
    printf '%s/%s/engagement-scope.json' "${root}" "${project}"
}

neo_scope_load() {
    local project="$1" root="${2:-${NEO_NEXT_STATE_ROOT}/projects}"
    neo_core_require_project "${project}" || return 1
    neo_core_need jq || return 1
    NEO_SCOPE_FILE="$(neo_scope_path "${project}" "${root}")"
    [[ -f "${NEO_SCOPE_FILE}" ]] || {
        neo_core_die "engagement scope not defined for project ${project}; run scope intake first"
        return 1
    }
    NEO_SCOPE_MODE="$(jq -r '.mode' "${NEO_SCOPE_FILE}")"
    [[ "${NEO_SCOPE_MODE}" == educational || "${NEO_SCOPE_MODE}" == professional ]]
}

neo_scope_host_in_cidr() {
    local ip="$1" cidr="$2"
    # Minimal check: exact match or delegate to python/ipcalc at integration if needed.
    [[ "${ip}" == "${cidr}" ]] && return 0
    [[ "${cidr}" == *"/"* ]] || return 1
    # Stub: integration should use proper CIDR match; prototype uses prefix heuristic.
    local net="${cidr%%/*}"
    [[ "${ip}" == "${net}"* ]] && return 0
    return 1
}

neo_scope_target_allowed() {
    local target="$1" host="${target%%:*}" port="${target#*:}"
    [[ "${target}" == *:* ]] || port=""
    jq -e --arg host "${host}" '
      . as $s |
      (($s.in_scope.hosts // []) | index($host) != null) or
      (([$s.in_scope.networks[]?] | any(. as $n | $host | startswith($n | split("/")[0]))))
    ' "${NEO_SCOPE_FILE}" >/dev/null 2>&1
}

# Returns: 0 in-scope | 1 educational warn | 2 professional block
neo_scope_check_network() {
    local target="$1"
    [[ -n "${NEO_SCOPE_FILE}" ]] || neo_scope_load "${NEO_EVIDENCE_PROJECT:-}" || return 2
    neo_scope_target_allowed "${target}" && return 0
    [[ "${NEO_SCOPE_MODE}" == educational ]] && return 1
    return 2
}

neo_scope_educational_override() {
    [[ -t 0 ]] || return 1
    neo_core_confirm 'Target is outside declared lab scope. Type scope-override to continue: ' scope-override
}

neo_scope_record_override() {
    local target="$1" reason="${2:-operator override}"
    [[ -n "${NEO_EVIDENCE_LOG:-}" ]] || return 0
    # shellcheck source=neo-evidence.sh
    source "${NEO_NEXT_ROOT}/lib/neo-evidence.sh"
    neo_evidence_record scope_override operator \
        "Educational scope override for ${target}: ${reason}" '' operator_confirmed
}

neo_scope_save() {
    local file="$1"
    neo_core_need jq || return 1
    jq -e '.' "${file}" >/dev/null || return 1
    local dir
    dir="$(dirname "${file}")"
    neo_core_secure_dir "${dir}"
    local tmp
    tmp="$(neo_core_secure_tmp "${dir}" .scope)" || return 1
    jq '.' "${file}" > "${tmp}"
    chmod 600 -- "${tmp}"
    mv -f -- "${tmp}" "${file}"
    NEO_SCOPE_FILE="${file}"
    NEO_SCOPE_MODE="$(jq -r '.mode' "${file}")"
}

neo_scope_summary() {
    neo_scope_load "${1}" "${2:-}" || return 1
    jq -r '"\(.mode) | \(.purpose) | hosts: \(.in_scope.hosts | join(", "))"' "${NEO_SCOPE_FILE}"
}
