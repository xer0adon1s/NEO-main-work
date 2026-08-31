#!/usr/bin/env bash
# run-linpeas.sh — run linpeas on a target and log output to the project notes.

set -euo pipefail

NEO_HOME="${NEO_HOME:-${HOME}/Neo}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 2 ]]; then
    cat <<'EOF'
Usage: run-linpeas.sh <project> user@target
EOF
    exit 0
fi

PROJECT="$1"
TARGET="$2"

source "${NEO_DIR}/lib/script-lib.sh"
cybersec_validate_project_name "${PROJECT}"

VENDOR="${NEO_DIR}/vendor/linpeas.sh"
if [[ ! -f "${VENDOR}" ]]; then
    echo "Missing ${VENDOR} — run ./setup.sh (or ./setup.sh) first." >&2
    exit 1
fi

OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
notes_init "${PROJECT}" "unknown" "${OUTDIR}" || true

ssh "${TARGET}" 'bash -s' < "${VENDOR}" | \
    "${NEO_DIR}/lib/notes-lib.sh" "${PROJECT}" log linpeas

meta_set phase privesc 2>/dev/null || true
meta_set ssh_target "${TARGET}" 2>/dev/null || true
notes_refresh_status "linpeas" "LinPEAS output logged from ${TARGET}." 2>/dev/null || true

echo "linpeas logged into ${OUTDIR}/Investigation-Notes.md"
