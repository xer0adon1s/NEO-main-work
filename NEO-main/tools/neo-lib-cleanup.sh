#!/usr/bin/env bash
# neo-lib-cleanup.sh — remove accidental non-NEO files from lib/ (keep only NEO scripts).
#
# Usage: ./tools/neo-lib-cleanup.sh [--dry-run]

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${NEO_ROOT}/lib"
DRY_RUN=false

NEO_LIBS=(
    notes-lib.sh
    script-lib.sh
    neo-ai.sh
    neo-ai-analyze.sh
    neo-ai-cli.sh
    neo-splash.sh
    neo-hud.sh
)

for arg in "$@"; do
    case "${arg}" in
        -h|--help)
            cat <<EOF
Usage: neo-lib-cleanup.sh [--dry-run]

Keeps only NEO's six lib/*.sh scripts; deletes everything else under lib/.
Safe to run — NEO scripts are never removed.
EOF
            exit 0
            ;;
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown option: ${arg}" >&2; exit 1 ;;
    esac
done

is_neo_lib() {
    local base="$1"
    for f in "${NEO_LIBS[@]}"; do
        [[ "${base}" == "${f}" ]] && return 0
    done
    return 1
}

if [[ ! -d "${LIB_DIR}" ]]; then
    echo "lib/ not found at ${LIB_DIR}" >&2
    exit 1
fi

removed=0
while IFS= read -r -d '' path; do
    rel="${path#${LIB_DIR}/}"
    base="$(basename "${path}")"
    if [[ "${rel}" == "${base}" ]] && is_neo_lib "${base}"; then
        continue
    fi
    if ${DRY_RUN}; then
        printf '  [dry-run] would remove: lib/%s\n' "${rel}"
    else
        rm -rf "${path}"
        printf '  [removed] lib/%s\n' "${rel}"
    fi
    removed=$((removed + 1))
done < <(find "${LIB_DIR}" -mindepth 1 -print0 2>/dev/null)

for f in "${NEO_LIBS[@]}"; do
    [[ -f "${LIB_DIR}/${f}" ]] || echo "  [warn] missing expected NEO lib: ${f}" >&2
done

if (( removed == 0 )); then
    printf 'lib/ is clean — only NEO scripts present.\n'
else
    ${DRY_RUN} && printf '\nDry run: %d path(s) would be removed.\n' "${removed}" \
        || printf '\nRemoved %d non-NEO path(s) from lib/.\n' "${removed}"
fi
