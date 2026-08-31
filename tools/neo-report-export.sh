#!/usr/bin/env bash
# neo-report-export.sh — PDF export stub for final reports (requires pandoc).
# Usage: neo-report-export.sh path/to/final-report.md

set -euo pipefail

MD="${1:-}"
[[ -n "${MD}" && -f "${MD}" ]] || {
    echo "Usage: neo-report-export.sh <final-report.md>" >&2
    exit 1
}

PDF="${MD%.md}.pdf"

if ! command -v pandoc >/dev/null 2>&1; then
    echo "neo-report-export: pandoc not installed." >&2
    echo "  Install: sudo apt install pandoc texlive-latex-base  (or equivalent)" >&2
    echo "  Markdown report: ${MD}" >&2
    exit 1
fi

pandoc "${MD}" -o "${PDF}" \
    --metadata title="NEO Penetration Test Report" \
    -V geometry:margin=1in

printf '[ok] PDF written: %s\n' "${PDF}"
