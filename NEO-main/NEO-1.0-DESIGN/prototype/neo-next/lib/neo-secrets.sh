#!/usr/bin/env bash
# Secret broker: no repo .env sourcing, no secret output, no tmux forwarding.

# shellcheck source=neo-core.sh
source "${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/neo-core.sh"

NEO_SECRET_DIR="${NEO_SECRET_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/neo/secrets}"
NEO_SECRET_VALUE=""

neo_secret_valid_name() {
    [[ "${1:-}" =~ ^[A-Z][A-Z0-9_]{1,63}$ ]]
}

neo_secret_path() {
    local name="$1"
    neo_secret_valid_name "${name}" || return 1
    printf '%s/%s' "${NEO_SECRET_DIR}" "${name}"
}

# Load into NEO_SECRET_VALUE. Nothing is printed.
neo_secret_load() {
    local name="$1" path env_value=""
    NEO_SECRET_VALUE=""
    neo_secret_valid_name "${name}" || {
        neo_core_die "invalid secret name: ${name}"
        return 1
    }

    env_value="${!name:-}"
    if [[ -n "${env_value}" ]]; then
        NEO_SECRET_VALUE="${env_value}"
        return 0
    fi

    path="$(neo_secret_path "${name}")" || return 1
    [[ -f "${path}" && ! -L "${path}" ]] || return 1

    # Reject files readable or writable by group/other. GNU stat is expected on NEO's Linux host.
    local mode
    mode="$(stat -c '%a' -- "${path}" 2>/dev/null || true)"
    [[ "${mode}" == "600" || "${mode}" == "400" ]] || {
        neo_core_die "unsafe permissions on secret file ${path}; expected 600 or 400"
        return 1
    }

    IFS= read -r NEO_SECRET_VALUE < "${path}" || true
    [[ -n "${NEO_SECRET_VALUE}" ]]
}

neo_secret_store() {
    local name="$1" value="$2" path tmp
    neo_secret_valid_name "${name}" || {
        neo_core_die "invalid secret name: ${name}"
        return 1
    }
    [[ -n "${value}" && "${value}" != *$'\n'* && "${value}" != *$'\r'* ]] || {
        neo_core_die 'secret must be non-empty and single-line'
        return 1
    }

    neo_core_secure_dir "${NEO_SECRET_DIR}"
    path="$(neo_secret_path "${name}")" || return 1
    tmp="$(neo_core_secure_tmp "${NEO_SECRET_DIR}" ".${name}")" || return 1
    printf '%s\n' "${value}" > "${tmp}"
    chmod 600 -- "${tmp}"
    mv -f -- "${tmp}" "${path}"
}

neo_secret_prompt() {
    local name="$1" label="${2:-$1}" save_answer value
    [[ -t 0 ]] || return 1
    read -r -s -p "${label}: " value
    printf '\n'
    [[ -n "${value}" ]] || return 1

    read -r -p "Store securely in ${NEO_SECRET_DIR}? [y/N] " save_answer
    if [[ "${save_answer}" =~ ^[Yy]$ ]]; then
        neo_secret_store "${name}" "${value}" || return 1
    fi
    NEO_SECRET_VALUE="${value}"
}

# Redact known values from a string and write the result to stdout.
# Secret values are never passed as subprocess arguments.
neo_secret_redact_text() {
    local text="$1" name value
    shift
    for name in "$@"; do
        value=""
        if neo_secret_load "${name}"; then
            value="${NEO_SECRET_VALUE}"
            [[ -n "${value}" ]] && text="${text//"${value}"/[REDACTED:${name}]}"
        fi
    done
    NEO_SECRET_VALUE=""
    printf '%s' "${text}"
}

neo_secret_remove() {
    local name="$1" path
    path="$(neo_secret_path "${name}")" || return 1
    [[ -e "${path}" ]] || return 0
    rm -f -- "${path}"
}

neo_secret_audit_repository() {
    local repo="$1" found=0
    [[ -d "${repo}" ]] || return 1
    while IFS= read -r path; do
        printf 'unsafe secret-like repository file: %s\n' "${path}" >&2
        found=1
    done < <(find "${repo}" -path '*/.git' -prune -o -type f \
        \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' \) -print)
    return "${found}"
}
