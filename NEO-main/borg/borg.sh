#!/usr/bin/env bash
# borg.sh — BORG vector assimilation (deep-dive one attack path via Claude).
#
# Usage:
#   ./borg/borg.sh <project>
#   ./borg/borg.sh <project> --vector="Redis unauth write RCE"
#   ./borg/borg.sh <project> --vector='Apache 2.4.49 path traversal'

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"

# shellcheck source=../lib/script-lib.sh
source "${NEO_DIR}/lib/script-lib.sh"
# shellcheck source=../lib/neo-ai.sh
source "${NEO_DIR}/lib/neo-ai.sh"
# shellcheck source=../lib/neo-borg.sh
source "${NEO_DIR}/lib/neo-borg.sh"

cybersec_init_colors

usage() {
    cat <<EOF
Usage: borg.sh <project> [--vector=description]

BORG assimilates ONE attack vector: Claude researches it, publishes to the shared
collective at knowledge/vectors/<slug>/, symlinks projects/<project>/assimilated/<slug>/,
and updates Investigation-Notes Borg section.
and offers gated tool downloads (human confirm before every install/clone).

Requires Claude Code (claude -p) or ANTHROPIC_API_KEY.
Set NEO_BORG_HUD=0 to disable ASCII progress displays.
EOF
}

PROJECT=""
VECTOR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --vector=*) VECTOR="${1#*=}"; shift ;;
        --vector) VECTOR="${2:-}"; shift 2 ;;
        -*) echo "borg: unknown option $1" >&2; exit 1 ;;
        *)
            [[ -z "${PROJECT}" ]] && PROJECT="$1" || { echo "borg: unexpected arg $1" >&2; exit 1; }
            shift
            ;;
    esac
done

[[ -n "${PROJECT}" ]] || { usage; exit 1; }
cybersec_validate_project_name "${PROJECT}" || exit 1

OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
MF="${OUTDIR}/project.meta"
[[ -f "${NOTES_FILE}" ]] || {
    echo "borg: no Investigation-Notes.md for ${PROJECT} — run recon first." >&2
    exit 1
}

phase="$(grep '^phase=' "${MF}" 2>/dev/null | cut -d= -f2- | head -n1)"
phase="${phase:-recon}"

neo_borg_run "${PROJECT}" "${phase}" "${VECTOR}"
