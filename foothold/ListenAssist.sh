#!/usr/bin/env bash
set -euo pipefail
NEO_HOME="${NEO_HOME:?}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
source "${NEO_DIR}/lib/notes-lib.sh"
PROJECT="${3:-}"; OUTDIR="${NEO_HOME}/projects/${PROJECT}"; NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
meta_set phase foothold
