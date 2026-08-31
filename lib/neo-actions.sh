#!/usr/bin/env bash
# Typed action plans — no eval (C6).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-core.sh
source "${NEO_LIB_DIR}/neo-core.sh"
# shellcheck source=neo-evidence.sh
source "${NEO_LIB_DIR}/neo-evidence.sh"

NEO_ACTION_POLICY="${NEO_ACTION_POLICY:-${NEO_DIR}/schemas/action-policy.json}"

neo_action_validate() {
    local file="$1"
    neo_core_need jq || return 1
    jq -e '
      type=="object" and
      .schema_version==1 and
      (.id|type=="string" and test("^[a-z0-9][a-z0-9._-]{0,63}$")) and
      (.kind=="manual" or .kind=="local_command") and
      (.title|type=="string" and length>0 and length<=160) and
      (.description|type=="string" and length>0 and length<=2000) and
      (.risk=="read_only" or .risk=="state_change" or .risk=="invasive") and
      (.source=="builtin" or .source=="operator" or .source=="ai") and
      (.execution|type=="object") and
      (.execution.mode=="advisory" or .execution.mode=="approved_local") and
      (if .kind=="local_command" then
         (.execution.argv|type=="array" and length>0 and length<=128 and all(.[]; type=="string" and length<=8192)) and
         (.execution.timeout_seconds|type=="number" and floor==. and .>=1 and .<=3600)
       else true end)
    ' "${file}" >/dev/null
}

neo_action_tool_allowed() {
    local tool="$1"
    [[ -f "${NEO_ACTION_POLICY}" ]] || return 1
    jq -e --arg tool "${tool}" '.allowed_tools | index($tool) != null' "${NEO_ACTION_POLICY}" >/dev/null
}

neo_action_render() {
    local file="$1" kind risk source title description
    neo_action_validate "${file}" || return 1
    kind="$(jq -r '.kind' "${file}")"
    risk="$(jq -r '.risk' "${file}")"
    source="$(jq -r '.source' "${file}")"
    title="$(jq -r '.title' "${file}")"
    description="$(jq -r '.description' "${file}")"
    printf '\nAction: %s\nRisk: %s | Source: %s | Kind: %s\n%s\n' \
        "${title}" "${risk}" "${source}" "${kind}" "${description}"
    if [[ "${kind}" == "local_command" ]]; then
        local -a argv=()
        mapfile -d '' -t argv < <(jq -j '.execution.argv[] | ., "\u0000"' "${file}")
        printf 'Command: '
        neo_core_quote_argv "${argv[@]}"
    fi
}

neo_action_execute() {
    local file="$1" mode kind risk source timeout tool output rc=0 target_host="" artifact=""
    local -a argv=()
    neo_action_validate "${file}" || {
        neo_core_die "invalid action document: ${file}"
        return 1
    }
    neo_action_render "${file}" || return 1

    kind="$(jq -r '.kind' "${file}")"
    mode="$(jq -r '.execution.mode' "${file}")"
    risk="$(jq -r '.risk' "${file}")"
    source="$(jq -r '.source' "${file}")"
    target_host="$(jq -r '.target // empty' "${file}")"

    if [[ -n "${target_host}" ]] && declare -F neo_scope_check_network >/dev/null 2>&1; then
        local scope_rc=0
        neo_scope_check_network "${target_host}" || scope_rc=$?
        if (( scope_rc == 2 )); then
            neo_core_die "target outside engagement scope: ${target_host}"
            return 1
        elif (( scope_rc == 1 )); then
            neo_scope_educational_override || {
                printf 'Cancelled; target outside declared lab scope.\n'
                return 0
            }
            neo_scope_record_override "${target_host}" "action $(jq -r '.id' "${file}")"
        fi
    fi

    if [[ "${kind}" == "manual" || "${mode}" == "advisory" ]]; then
        printf 'Advisory only; no command executed.\n'
        return 0
    fi

    mapfile -d '' -t argv < <(jq -j '.execution.argv[] | ., "\u0000"' "${file}")
    tool="$(basename -- "${argv[0]}")"
    timeout="$(jq -r '.execution.timeout_seconds' "${file}")"

    if [[ "${source}" == "ai" ]] && ! neo_action_tool_allowed "${tool}"; then
        neo_core_die "AI action tool is not locally approved: ${tool}; leaving action advisory"
        return 1
    fi
    command -v "${argv[0]}" >/dev/null 2>&1 || {
        neo_core_die "action tool not installed: ${argv[0]}"
        return 1
    }

    local expected='run'
    [[ "${risk}" == "read_only" ]] || expected='run-state-change'
    neo_core_confirm "Type ${expected} to execute, or press Enter to cancel: " "${expected}" || {
        printf 'Cancelled; no command executed.\n'
        return 0
    }

    if output="$(timeout --signal=TERM "${timeout}" -- "${argv[@]}" 2>&1)"; then
        rc=0
    else
        rc=$?
    fi

    if [[ -n "${NEO_EVIDENCE_LOG:-}" ]]; then
        artifact="$(printf '%s' "${output}" | neo_evidence_save_artifact "action-$(jq -r '.id' "${file}")")" || true
        neo_evidence_record action_result "${source}:${tool}" \
            "action $(jq -r '.id' "${file}") exited ${rc}" "${artifact}" observed || true
    fi
    printf '%s\n' "${output}"
    return "${rc}"
}
