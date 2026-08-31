#!/usr/bin/env bash
# migrate-status.sh — add STATUS section markers to legacy Investigation-Notes.md
#
# Projects created before pipeline v2 may lack <!-- SECTION:STATUS --> markers.
# Without them, notes_refresh_status and status.sh cannot show the auto tl;dr.
#
# Usage:
#   migrate-status.sh              # all projects under ~/Neo/projects/
#   migrate-status.sh HTB-Reactor  # one project

set -euo pipefail

NEO_HOME="${NEO_HOME:-${HOME}/Neo}"
PROJECTS="${NEO_HOME}/projects"

STATUS_BLOCK=$'<!-- SECTION:STATUS -->\n_No runs logged yet._\n<!-- /SECTION:STATUS -->\n'

migrate_one() {
    local name="$1"
    local notes="${PROJECTS}/${name}/Investigation-Notes.md"

    if [[ ! -f "${notes}" ]]; then
        printf '  [skip] %s — no Investigation-Notes.md\n' "${name}"
        return 0
    fi
    if grep -q 'SECTION:STATUS' "${notes}"; then
        printf '  [ok]   %s — STATUS already present\n' "${name}"
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    {
        head -n 1 "${notes}"
        printf '\n%s\n' "${STATUS_BLOCK}"
        tail -n +2 "${notes}"
    } > "${tmp}"
    mv "${tmp}" "${notes}"
    printf '  [fix]  %s — STATUS section inserted after title\n' "${name}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: migrate-status.sh [project-name]

Inserts the STATUS marker block into Investigation-Notes.md when missing.
Safe to re-run — skips projects that already have STATUS.
EOF
    exit 0
fi

if [[ -n "${1:-}" ]]; then
    migrate_one "$1"
    exit 0
fi

if [[ ! -d "${PROJECTS}" ]]; then
    echo "No projects directory: ${PROJECTS}" >&2
    exit 1
fi

echo "Migrating STATUS sections under ${PROJECTS}:"
found=false
for d in "${PROJECTS}"/*; do
    [[ -d "${d}" ]] || continue
    found=true
    migrate_one "$(basename "${d}")"
done
if [[ "${found}" != true ]]; then
    echo "  (no projects yet)"
fi
