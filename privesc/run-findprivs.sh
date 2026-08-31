#!/usr/bin/env bash
set -euo pipefail
NEO_HOME="${NEO_HOME:?}"
source "${NEO_DIR}/lib/notes-lib.sh"
project="$1"; OUTDIR="${NEO_HOME}/projects/${project}"; NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
notes_ingest "FindPrivs" "" $'=== VERDICT ===\nSmoke privesc path.\n'
meta_set phase privesc
