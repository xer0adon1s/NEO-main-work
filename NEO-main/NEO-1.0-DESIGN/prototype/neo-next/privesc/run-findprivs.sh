#!/usr/bin/env bash
# Transport-aware FindPrivs runner for an already-established authorized lab foothold.

set -euo pipefail

NEO_NEXT_ROOT="${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-$(cd "${NEO_NEXT_ROOT}/../../.." && pwd)}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_NEXT_ROOT}/lib/neo-core.sh"
# shellcheck source=../lib/neo-evidence.sh
source "${NEO_NEXT_ROOT}/lib/neo-evidence.sh"

PROJECT=""
MODE="existing-shell"
SSH_TARGET=""
INPUT_FILE=""
FINDPRIVS="${NEO_SOURCE_ROOT}/privesc/FindPrivs.sh"
STATE_ROOT="${NEO_NEXT_STATE_ROOT}/projects"

usage() {
    cat <<'EOF'
Usage: run-findprivs.sh --project NAME [mode options]

Modes:
  --existing-shell           Print a transfer/run/capture workflow for a shell you already own
  --ssh user@host            Run FindPrivs through SSH and capture its output
  --ingest-file PATH         Ingest output copied back from an existing shell
  --script PATH              Override FindPrivs.sh location

This tool enumerates and reports. It does not perform privilege escalation.
EOF
}

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

record_output() {
    local output="$1" source="$2" artifact
    [[ -n "${output}" ]] || { neo_core_die 'FindPrivs produced no output'; return 1; }
    artifact="$(printf '%s' "${output}" | neo_evidence_record_artifact privesc_enumeration "${source}" \
        'Captured FindPrivs post-foothold enumeration output.' findprivs)"
    printf 'FindPrivs output recorded: %s\n' "${artifact}"
    printf '\nReview first:\n'
    awk '/^=== (System identity|sudo privileges|SUID|Capabilities|Cron|VERDICT)/ {print; shown=1; next} shown && NF {print; count++; if(count>=40) exit}' <<< "${output}"
}

case "${MODE}" in
    ssh)
        [[ "${SSH_TARGET}" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._:-]+$ ]] || {
            neo_core_die 'SSH target must look like user@host and may not include options'
            exit 1
        }
        command -v ssh >/dev/null 2>&1 || { neo_core_die 'ssh is not installed'; exit 1; }
        printf 'Running FindPrivs through the existing SSH access to %s...\n' "${SSH_TARGET}"
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
        checksum="$(sha256sum -- "${FINDPRIVS}" | awk '{print $1}')"
        cat <<EOF

Existing-shell workflow

1. You already control the target shell. Transfer this exact local file using the method
   appropriate for that session:

   ${FINDPRIVS}

   Local SHA-256: ${checksum}

2. On the target, run the transferred copy with Bash and redirect the complete output to
   a file you can retrieve. Do not pipe the output through filters; NEO needs the section
   headers and raw evidence.

3. Copy the output back to the attack box, then ingest it with:

   ./run-findprivs.sh --project ${PROJECT} --ingest-file /path/to/findprivs-output.txt

SSH is optional. This mode deliberately does not assume NEO can control an arbitrary shell
in another window. A future session adapter can automate transfer/capture when the shell is
inside NEO's managed tmux session.
EOF
        neo_evidence_record privesc_plan run-findprivs \
            'Prepared FindPrivs workflow for an existing operator-controlled shell.' '' planned
        ;;
esac
