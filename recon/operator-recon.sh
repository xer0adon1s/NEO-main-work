#!/usr/bin/env bash
# Capture operator observations before AI triage/Borg. No commands are executed.

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
export NEO_STATE_ROOT="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_DIR}/lib/neo-core.sh"
# shellcheck source=../lib/neo-evidence.sh
source "${NEO_DIR}/lib/neo-evidence.sh"

PROJECT=""
INPUT_FILE=""
CATEGORY="operator-observation"
STATE_ROOT="${NEO_STATE_ROOT}/projects"

usage() {
    cat <<'EOF'
Usage: operator-recon.sh --project NAME [--file PATH] [--category NAME]

Without --file, collects multiline operator recon. Enter a line containing only .done
to save, or .cancel to discard. The content is evidence for later AI triage and Borg;
it is never treated as a command.
EOF
}

while (($#)); do
    case "$1" in
        --project) PROJECT="${2:-}"; shift 2 ;;
        --project=*) PROJECT="${1#*=}"; shift ;;
        --file) INPUT_FILE="${2:-}"; shift 2 ;;
        --file=*) INPUT_FILE="${1#*=}"; shift ;;
        --category) CATEGORY="${2:-}"; shift 2 ;;
        --category=*) CATEGORY="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) neo_core_die "unknown argument: $1"; exit 1 ;;
    esac
done

neo_core_require_project "${PROJECT}" || exit 1
[[ "${CATEGORY}" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]] || {
    neo_core_die 'invalid category'
    exit 1
}
neo_evidence_init "${PROJECT}" "${STATE_ROOT}"

content=""
if [[ -n "${INPUT_FILE}" ]]; then
    [[ -f "${INPUT_FILE}" && ! -L "${INPUT_FILE}" ]] || {
        neo_core_die "input is not a regular file: ${INPUT_FILE}"
        exit 1
    }
    content="$(cat -- "${INPUT_FILE}")"
else
    [[ -t 0 ]] || {
        neo_core_die 'interactive input requires a terminal; use --file for automation'
        exit 1
    }
    printf 'Enter recon observations. Use .done to save or .cancel to discard.\n'
    lines=()
    while IFS= read -r line; do
        [[ "${line}" == '.cancel' ]] && { printf 'Discarded.\n'; exit 0; }
        [[ "${line}" == '.done' ]] && break
        lines+=("${line}")
    done
    printf -v content '%s\n' "${lines[@]}"
fi

[[ -n "${content//[[:space:]]/}" ]] || {
    neo_core_die 'no recon content supplied'
    exit 1
}

summary="Operator supplied ${CATEGORY} recon ($(wc -c <<< "${content}" | tr -d ' ') bytes)."
artifact="$(printf '%s' "${content}" | neo_evidence_record_artifact operator_recon operator "${summary}" "${CATEGORY}")"
printf 'Saved operator recon as %s\n' "${artifact}"
printf 'This evidence will be included in AI triage and offered to Borg before foothold.\n'
# shellcheck source=../lib/neo-operator-recon-ai.sh
source "${NEO_DIR}/lib/neo-operator-recon-ai.sh" 2>/dev/null || true
declare -F neo_operator_recon_ai_offer >/dev/null 2>&1 && \
    neo_operator_recon_ai_offer "${PROJECT}" "${content}" "operator-recon" || true
