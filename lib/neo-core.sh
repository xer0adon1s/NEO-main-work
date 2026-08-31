#!/usr/bin/env bash
# NEO 1.0 shared primitives (core dependency C0).

set -o pipefail

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
export NEO_STATE_ROOT="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}"

neo_core_die() {
    printf 'neo: %s\n' "$*" >&2
    return 1
}

neo_core_need() {
    local name
    for name in "$@"; do
        command -v "${name}" >/dev/null 2>&1 || {
            neo_core_die "required command not found: ${name}"
            return 1
        }
    done
}

neo_core_valid_project() {
    local name="${1:-}"
    [[ "${name}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]
}

neo_core_require_project() {
    neo_core_valid_project "${1:-}" || neo_core_die \
        'project must be 1-64 characters: letters, numbers, dot, underscore, or dash'
}

neo_core_valid_port() {
    local port="${1:-}"
    [[ "${port}" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}

neo_core_iso_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

neo_core_secure_dir() {
    local path="$1"
    umask 077
    mkdir -p -- "${path}"
    chmod 700 -- "${path}"
}

neo_core_secure_tmp() {
    local parent="$1" prefix="${2:-neo}"
    neo_core_secure_dir "${parent}"
    mktemp "${parent}/${prefix}.XXXXXX"
}

neo_core_confirm() {
    local prompt="$1" expected="${2:-yes}" answer
    [[ -t 0 ]] || return 1
    read -r -p "${prompt}" answer
    [[ "${answer}" == "${expected}" ]]
}

neo_core_quote_argv() {
    local arg first=1
    for arg in "$@"; do
        (( first == 1 )) || printf ' '
        printf '%q' "${arg}"
        first=0
    done
    printf '\n'
}
