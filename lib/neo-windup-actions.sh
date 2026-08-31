#!/usr/bin/env bash
# Safe wind-up execution — typed argv actions only; no eval/bash -c (Tier 1).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-core.sh
source "${NEO_LIB_DIR}/neo-core.sh"
# shellcheck source=neo-actions.sh
source "${NEO_LIB_DIR}/neo-actions.sh"

# True when the string must not be turned into argv (shell injection / chaining).
neo_windup_command_rejected() {
    local cmd="$1"
    [[ "${cmd}" == *$'\n'* || "${cmd}" == *$'\r'* ]] && return 0
    [[ "${cmd}" =~ [\;\|\&\`\$\(\)\<\>] ]] && return 0
    [[ "${cmd}" =~ \$\( ]] && return 0
    return 1
}

neo_windup_tokenize_command() {
    local cmd="$1"
    local -n _out=$2
    _out=()
    read -ra _out <<< "${cmd}"
    ((${#_out[@]} > 0))
}

neo_windup_build_action_json() {
    local id="$1" title="$2" cmd="$3" risk="${4:-read_only}" outfile="$5"
    local -a argv=()
    neo_core_need jq || return 1
    neo_windup_command_rejected "${cmd}" && return 1
    neo_windup_tokenize_command "${cmd}" argv || return 1
    jq -n \
        --arg id "${id}" \
        --arg title "${title}" \
        --arg desc "${cmd}" \
        --arg risk "${risk}" \
        --argjson argv "$(printf '%s\n' "${argv[@]}" | jq -R . | jq -s .)" \
        '{
            schema_version: 1,
            id: $id,
            kind: "local_command",
            title: $title,
            description: $desc,
            risk: $risk,
            source: "ai",
            execution: {mode: "approved_local", argv: $argv, timeout_seconds: 300}
        }' > "${outfile}"
    chmod 600 -- "${outfile}"
}

neo_windup_action_dir() {
    local project="$1"
    printf '%s/projects/%s/actions' "${NEO_HOME:-${NEO_DIR}}" "${project}"
}

# Execute an AI-proposed one-liner through neo_action_execute (argv array, no shell).
neo_windup_execute_safe() {
    local cmd="$1" slug="$2" project="$3"
    local action_dir action_file id

    [[ -n "${project}" ]] || {
        neo_core_die 'wind-up execution requires a project name'
        return 1
    }
    neo_windup_command_rejected "${cmd}" && {
        printf 'neo: refused wind-up command (shell metacharacters) — run manually:\n  %s\n' "${cmd}" >&2
        return 1
    }
    action_dir="$(neo_windup_action_dir "${project}")"
    neo_core_secure_dir "${action_dir}"
    id="windup-$(tr -cs 'a-z0-9' '-' <<< "${slug:-step}" | sed 's/^-//;s/-$//')"
    action_file="${action_dir}/${id}-$(date +%s).json"
    neo_windup_build_action_json "${id}" "Borg wind-up step" "${cmd}" read_only "${action_file}" || return 1
    neo_action_execute "${action_file}"
}

# Whitelisted NEO repo script paths only — no bash -c string interpolation.
neo_windup_run_neo_script() {
    local payload="$1"
    local rel="${payload#./}"
    local script="${NEO_HOME:-${NEO_DIR}}/${rel}"

    [[ "${rel}" =~ ^(neo\.sh|recon/|borg/|foothold/|privesc/|connect/)[A-Za-z0-9./_-]+$ ]] || {
        printf 'neo: refused NEO wind-up path (not whitelisted): %s\n' "${payload}" >&2
        return 1
    }
    [[ -f "${script}" ]] || {
        printf 'neo: wind-up script not found: %s\n' "${script}" >&2
        return 1
    }
    (cd "${NEO_HOME:-${NEO_DIR}}" && bash "${rel}")
}
