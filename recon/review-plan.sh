#!/usr/bin/env bash
# Review and optionally execute validated enumeration actions one at a time (P15).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEO_DIR="${NEO_DIR:-${NEO_ROOT}}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_DIR}/lib/neo-core.sh"
# shellcheck source=../lib/neo-actions.sh
source "${NEO_DIR}/lib/neo-actions.sh"

PLAN_DIR="${1:-}"
[[ -d "${PLAN_DIR}" ]] || { neo_core_die 'plan directory required'; exit 1; }

shopt -s nullglob
files=("${PLAN_DIR}"/*.json)
((${#files[@]} > 0)) || { neo_core_die 'no action documents found'; exit 1; }

for file in "${files[@]}"; do
    neo_action_render "${file}" || {
        printf 'Skipping invalid action: %s\n' "${file}" >&2
        continue
    }
    if [[ -t 0 ]]; then
        read -r -p 'Review only [r], request execution [e], or skip [s]? [r] ' choice
        case "${choice:-r}" in
            e|E)
                approved="$(neo_core_secure_tmp "${NEO_STATE_ROOT:-${HOME}/.local/state}/neo/tmp" approved-action)"
                jq '.execution.mode="approved_local"' "${file}" > "${approved}"
                neo_action_execute "${approved}" || true
                rm -f -- "${approved}"
                ;;
            s|S) printf 'Skipped.\n' ;;
            *) printf 'Retained as advisory.\n' ;;
        esac
    fi
done
