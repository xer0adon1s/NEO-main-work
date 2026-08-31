#!/usr/bin/env bash
# Provider-neutral AI calls with secrets kept out of process arguments (C9).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=neo-core.sh
source "${NEO_LIB_DIR}/neo-core.sh"
# shellcheck source=neo-secrets.sh
source "${NEO_LIB_DIR}/neo-secrets.sh"

NEO_AI_PROVIDER="${NEO_AI_PROVIDER:-claude-cli}"
NEO_AI_MODEL="${NEO_AI_MODEL:-claude-sonnet-4-6}"
NEO_AI_MAX_TOKENS="${NEO_AI_MAX_TOKENS:-6000}"
NEO_PROVIDER_WEB_RESEARCH="${NEO_PROVIDER_WEB_RESEARCH:-0}"

neo_provider_available() {
    case "${NEO_AI_PROVIDER}" in
        claude-cli) command -v claude >/dev/null 2>&1 ;;
        anthropic-api) command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && neo_secret_load ANTHROPIC_API_KEY ;;
        *) return 1 ;;
    esac
}

neo_provider_capability() {
    case "$1" in
        structured_json) return 0 ;;
        web_research) [[ "${NEO_PROVIDER_WEB_RESEARCH}" == "1" ]] ;;
        *) return 1 ;;
    esac
}

neo_provider_claude_cli() {
    local system_file="$1" user_file="$2" output_file="$3" prompt_file rc=0
    prompt_file="$(neo_core_secure_tmp "${NEO_STATE_ROOT}/tmp" provider-prompt)" || return 1
    {
        printf '%s\n\n--- OPERATOR DATA BOUNDARY ---\n' "$(cat -- "${system_file}")"
        cat -- "${user_file}"
    } > "${prompt_file}"

    if env -u ANTHROPIC_API_KEY -u ANTHROPIC_WORKSPACE_ID \
        claude -p 'Follow the supplied instructions and return only the requested output.' \
        < "${prompt_file}" > "${output_file}"; then
        rc=0
    else
        rc=$?
    fi
    rm -f -- "${prompt_file}"
    return "${rc}"
}

neo_provider_anthropic_api() {
    local system_file="$1" user_file="$2" output_file="$3"
    local body response config http_code secret workspace="" rc=0
    neo_core_need curl jq || return 1
    neo_secret_load ANTHROPIC_API_KEY || {
        neo_core_die 'Anthropic API key is not available through the secret broker'
        return 1
    }
    secret="${NEO_SECRET_VALUE}"
    [[ "${secret}" =~ ^[A-Za-z0-9_-]+$ ]] || {
        NEO_SECRET_VALUE=""; secret=""
        neo_core_die 'Anthropic API key contains unsupported characters'
        return 1
    }
    if neo_secret_load ANTHROPIC_WORKSPACE_ID; then workspace="${NEO_SECRET_VALUE}"; fi

    body="$(neo_core_secure_tmp "${NEO_STATE_ROOT}/tmp" provider-body)" || return 1
    response="$(neo_core_secure_tmp "${NEO_STATE_ROOT}/tmp" provider-response)" || { rm -f -- "${body}"; return 1; }
    config="$(neo_core_secure_tmp "${NEO_STATE_ROOT}/tmp" provider-curl)" || { rm -f -- "${body}" "${response}"; return 1; }
    chmod 600 -- "${body}" "${response}" "${config}"

    jq -n --arg model "${NEO_AI_MODEL}" --arg system "$(cat -- "${system_file}")" \
        --arg user "$(cat -- "${user_file}")" --argjson max_tokens "${NEO_AI_MAX_TOKENS}" \
        '{model:$model,max_tokens:$max_tokens,system:$system,messages:[{role:"user",content:$user}]}' > "${body}"
    {
        printf 'silent\nshow-error\nurl = "https://api.anthropic.com/v1/messages"\n'
        printf 'header = "x-api-key: %s"\n' "${secret}"
        printf 'header = "anthropic-version: 2023-06-01"\n'
        printf 'header = "content-type: application/json"\n'
        [[ -n "${workspace}" ]] && printf 'header = "anthropic-workspace-id: %s"\n' "${workspace}"
    } > "${config}"
    NEO_SECRET_VALUE=""; secret=""; workspace=""

    if http_code="$(curl --config "${config}" -o "${response}" -w '%{http_code}' --data @"${body}")"; then
        rc=0
    else
        rc=$?
    fi
    rm -f -- "${config}" "${body}"
    if (( rc != 0 )); then
        rm -f -- "${response}"
        return "${rc}"
    fi
    if [[ "${http_code}" != 200 ]]; then
        printf 'neo: AI provider returned HTTP %s\n' "${http_code}" >&2
        jq -r '.error.message // "unknown provider error"' "${response}" >&2 || true
        rm -f -- "${response}"
        return 1
    fi
    jq -r '[.content[] | select(.type=="text") | .text] | join("\n")' "${response}" > "${output_file}"
    rm -f -- "${response}"
}

neo_provider_request() {
    local system_file="$1" user_file="$2" output_file="$3"
    [[ -f "${system_file}" && -f "${user_file}" ]] || return 1
    umask 077
    case "${NEO_AI_PROVIDER}" in
        claude-cli) neo_provider_claude_cli "${system_file}" "${user_file}" "${output_file}" ;;
        anthropic-api) neo_provider_anthropic_api "${system_file}" "${user_file}" "${output_file}" ;;
        *) neo_core_die "unsupported AI provider: ${NEO_AI_PROVIDER}" ;;
    esac
}

neo_provider_extract_json() {
    local input="$1" output="$2"
    if jq -e 'type=="object"' "${input}" >/dev/null 2>&1; then
        jq '.' "${input}" > "${output}"
        return 0
    fi
    awk '/^```json[[:space:]]*$/{on=1;next} /^```[[:space:]]*$/{if(on){exit}} on{print}' "${input}" > "${output}"
    jq -e 'type=="object"' "${output}" >/dev/null 2>&1
}
