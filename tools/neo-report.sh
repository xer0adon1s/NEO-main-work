#!/usr/bin/env bash
# neo-report.sh — generate human-readable final report from Investigation-Notes.
# Usage: ./tools/neo-report.sh <project>

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

PROJECT="${1:-}"
[[ -n "${PROJECT}" ]] || {
    echo "Usage: neo-report.sh <project>" >&2
    exit 1
}

# shellcheck source=../lib/script-lib.sh
source "${NEO_DIR}/lib/script-lib.sh"
# shellcheck source=../lib/neo-report.sh
source "${NEO_DIR}/lib/neo-report.sh"

OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
[[ -f "${NOTES_FILE}" ]] || {
    echo "neo-report: no Investigation-Notes.md for ${PROJECT}" >&2
    exit 1
}

neo_report_generate "${PROJECT}"
