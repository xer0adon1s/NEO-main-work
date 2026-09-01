#!/usr/bin/env bash
# status.sh — quick glance at a project's pipeline state.

set -euo pipefail

NEO_HOME="${NEO_HOME:-${HOME}/Neo}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
PROJECTS="${NEO_HOME}/projects"

source "${NEO_DIR}/lib/notes-lib.sh"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: status.sh [project-name]
EOF
    exit 0
fi

if [[ -z "${1:-}" ]]; then
    echo "Projects under ${PROJECTS}:"
    if [[ ! -d "${PROJECTS}" ]] || [[ -z "$(ls -A "${PROJECTS}" 2>/dev/null)" ]]; then
        echo "  (none yet — run neo.sh to start one)"
        exit 0
    fi
    for d in "${PROJECTS}"/*; do
        [[ -d "${d}" ]] || continue
        name="$(basename "${d}")"
        mf="${d}/project.meta"
        if [[ -f "${mf}" ]]; then
            phase="$(grep '^phase=' "${mf}" 2>/dev/null | cut -d= -f2- || echo '?')"
            target="$(grep '^target=' "${mf}" 2>/dev/null | cut -d= -f2- || echo '?')"
            last="$(grep '^last_script=' "${mf}" 2>/dev/null | cut -d= -f2- || echo '?')"
            printf '  %-20s  target=%-15s  phase=%-10s  last=%s\n' "${name}" "${target}" "${phase}" "${last}"
        else
            printf '  %-20s  (no project.meta)\n' "${name}"
        fi
    done
    exit 0
fi

PROJECT="$1"
OUTDIR="${PROJECTS}/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
MF="${OUTDIR}/project.meta"

if [[ ! -d "${OUTDIR}" ]]; then
    echo "No such project: ${PROJECT}" >&2
    exit 1
fi

echo "=== ${PROJECT} ==="
if [[ -f "${MF}" ]]; then
    cat "${MF}"
else
    echo "(no project.meta)"
fi

echo ""
if [[ -f "${NOTES_FILE}" ]]; then
    echo "--- STATUS ---"
    STATUS_BODY="$(awk '/<!-- SECTION:STATUS -->/,/<!-- \/SECTION:STATUS -->/' "${NOTES_FILE}" \
        | grep -v 'SECTION:STATUS' || true)"
    if [[ -z "${STATUS_BODY//[[:space:]]/}" ]]; then
        echo "(no STATUS section — project may predate STATUS; run a pipeline script)"
    else
        printf '%s\n' "${STATUS_BODY}"
    fi
else
    echo "(no Investigation-Notes.md yet)"
fi
