#!/usr/bin/env bash
# Transport-aware FindPrivs runner for an established authorized lab foothold (P03).

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
export NEO_STATE_ROOT="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_DIR}/lib/neo-core.sh"
# shellcheck source=../lib/neo-evidence.sh
source "${NEO_DIR}/lib/neo-evidence.sh"
# shellcheck source=../lib/notes-lib.sh
source "${NEO_DIR}/lib/notes-lib.sh"
# shellcheck source=../lib/script-lib.sh
source "${NEO_DIR}/lib/script-lib.sh"

PROJECT=""
MODE="existing-shell"
SSH_TARGET=""
INPUT_FILE=""
FINDPRIVS="${NEO_DIR}/privesc/FindPrivs.sh"
STATE_ROOT="${NEO_STATE_ROOT}/projects"

usage() {
    cat <<'EOF'
Usage: run-findprivs.sh --project NAME [mode options]
       run-findprivs.sh PROJECT user@host   (legacy neo.sh form → SSH mode)

Modes:
  --existing-shell           Print transfer/run/capture workflow (default)
  --ssh user@host            Run FindPrivs through SSH and ingest notes
  --ingest-file PATH         Ingest output copied back from an existing shell
  --script PATH              Override FindPrivs.sh location

Enumerates and reports only — does not perform privilege escalation.
EOF
}

if [[ $# -ge 2 && "${1}" != --* && "${2}" =~ ^[A-Za-z0-9._-]+@ ]]; then
    PROJECT="$1"
    MODE="ssh"
    SSH_TARGET="$2"
    set --
fi

while (($#)); do
    case "$1" in
        --project) PROJECT="${2:-}"; shift 2 ;;
        --project=*) PROJECT="${1#*=}"; shift ;;
        --existing-shell) MODE="existing-shell"; shift ;;
        --ssh) MODE="ssh"; SSH_TARGET="${2:-}"; shift 2 ;;
        --ssh=*) MODE="ssh"; SSH_TARGET="${1#*=}"; shift ;;
        --ingest-file) MODE="ingest"; INPUT_FILE="${2:-}"; shift 2 ;;
        --ingest-file=*) MODE="ingest"; INPUT_FILE="${1#*=}"; shift ;;
        --script) FINDPRIVS="${2:-}"; shift 2 ;;
        --script=*) FINDPRIVS="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) neo_core_die "unknown argument: $1"; exit 1 ;;
    esac
done

neo_core_require_project "${PROJECT}" || exit 1
[[ -f "${FINDPRIVS}" && ! -L "${FINDPRIVS}" ]] || {
    neo_core_die "FindPrivs script not found: ${FINDPRIVS}"
    exit 1
}
neo_evidence_init "${PROJECT}" "${STATE_ROOT}"

OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
[[ -f "${NOTES_FILE}" ]] || notes_init "${PROJECT}" "$(meta_get target 2>/dev/null || echo unknown)" "${OUTDIR}" 2>/dev/null || true

ingest_to_notes() {
    local output="$1" source="$2"
    notes_ingest "FindPrivs" "" "${output}" || true
    cybersec_finish "run-findprivs" privesc "FindPrivs ingested from ${source}" "${output}"
}

record_output() {
    local output="$1" source="$2" artifact
    [[ -n "${output}" ]] || { neo_core_die 'FindPrivs produced no output'; return 1; }
    artifact="$(printf '%s' "${output}" | neo_evidence_record_artifact privesc_enumeration "${source}" \
        'Captured FindPrivs post-foothold enumeration output.' findprivs)"
    printf 'FindPrivs output recorded: %s\n' "${artifact}"
    printf '\nReview first:\n'
    awk '/^=== (System identity|sudo privileges|SUID|Capabilities|Cron|VERDICT)/ {print; shown=1; next} shown && NF {print; count++; if(count>=40) exit}' <<< "${output}"
    ingest_to_notes "${output}" "${source}"
}

case "${MODE}" in
    ssh)
        [[ "${SSH_TARGET}" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._:-]+$ ]] || {
            neo_core_die 'SSH target must look like user@host and may not include options'
            exit 1
        }
        command -v ssh >/dev/null 2>&1 || { neo_core_die 'ssh is not installed'; exit 1; }
        printf 'Running FindPrivs through SSH to %s...\n' "${SSH_TARGET}"
        if output="$(ssh -- "${SSH_TARGET}" 'bash -s' < "${FINDPRIVS}" 2>&1)"; then
            record_output "${output}" "ssh:${SSH_TARGET}"
        else
            rc=$?
            record_output "${output}" "ssh:${SSH_TARGET}:failed" || true
            neo_core_die "SSH FindPrivs run exited ${rc}"
            exit "${rc}"
        fi
        ;;
    ingest)
        [[ -f "${INPUT_FILE}" && ! -L "${INPUT_FILE}" ]] || {
            neo_core_die "ingest file not found: ${INPUT_FILE}"
            exit 1
        }
        record_output "$(cat -- "${INPUT_FILE}")" operator-file
        ;;
    existing-shell)
        checksum="$(sha256sum -- "${FINDPRIVS}" 2>/dev/null | awk '{print $1}' || shasum -a 256 -- "${FINDPRIVS}" | awk '{print $1}')"
        cat <<EOF

Existing-shell workflow

1. Transfer this file to the target using your session's method:

   ${FINDPRIVS}

   Local SHA-256: ${checksum}

2. On the target, run the copy with Bash and save complete output to a file.

3. Ingest on the attack box:

   ./privesc/run-findprivs.sh --project ${PROJECT} --ingest-file /path/to/findprivs-output.txt

EOF
        neo_evidence_record privesc_plan run-findprivs \
            'Prepared FindPrivs workflow for an existing operator-controlled shell.' '' planned
        cybersec_finish "run-findprivs" privesc "Printed existing-shell FindPrivs workflow" \
            "FindPrivs SHA-256: ${checksum}"
        ;;
esac
