#!/usr/bin/env bash
# borg-disclosure-check.sh — lint text or library files for educational disclosure violations.
# Usage:
#   ./tools/borg-disclosure-check.sh [--mode educational|professional] [file ...]
#   echo "text" | ./tools/borg-disclosure-check.sh

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-borg-disclosure.sh
source "${NEO_DIR}/lib/neo-borg-disclosure.sh"

mode="educational"
files=()

while (($# > 0)); do
    case "$1" in
        --mode)
            mode="$2"
            shift 2
            ;;
        --mode=*)
            mode="${1#--mode=}"
            shift
            ;;
        -h|--help)
            cat <<'EOF'
borg-disclosure-check.sh — educational disclosure linter for Borg library text

  --mode educational   (default) flag box-name spoilers and cheat-sheet phrasing
  --mode professional  always pass (full intel allowed)

Exit 0 = all inputs pass; 1 = one or more violations.
EOF
            exit 0
            ;;
        *)
            files+=("$1")
            shift
            ;;
    esac
done

fail=0
check_text() {
    local label="$1" text="$2"
    if neo_borg_disclosure_check "${mode}" "${text}"; then
        printf '[ok] %s\n' "${label}"
    else
        printf '[FAIL] %s\n' "${label}" >&2
        fail=$((fail + 1))
    fi
}

if ((${#files[@]} == 0)); then
    text="$(cat)"
    check_text "stdin" "${text}"
else
    for f in "${files[@]}"; do
        [[ -f "${f}" ]] || { echo "missing: ${f}" >&2; fail=$((fail + 1)); continue; }
        check_text "${f}" "$(cat "${f}")"
    done
fi

exit "${fail}"
