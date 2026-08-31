#!/usr/bin/env bash
# analyze-recon.sh — AI triage: Claude API key (B) or Claude Code subscription (A).

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"

# shellcheck source=../lib/script-lib.sh
source "${NEO_DIR}/lib/script-lib.sh"
# shellcheck source=../lib/neo-ai.sh
source "${NEO_DIR}/lib/neo-ai.sh"
# shellcheck source=../lib/neo-ai-analyze.sh
source "${NEO_DIR}/lib/neo-ai-analyze.sh"
# shellcheck source=../lib/neo-ai-cli.sh
source "${NEO_DIR}/lib/neo-ai-cli.sh"

cybersec_init_colors

usage() {
    cat <<EOF
Usage: analyze-recon.sh <project>
       analyze-recon.sh --project=<name>

Runs AI triage based on project ai_triage mode:
  subscription — Claude Code \`claude -p\` (Pro/Max)
  api          — Anthropic Console API key
  manual       — skipped

Set NEO_AI=0 to force skip.
EOF
}

PROJECT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --project=*) PROJECT="${1#*=}"; shift ;;
        --project) PROJECT="${2:-}"; shift 2 ;;
        -*) echo "analyze-recon: unknown option $1" >&2; exit 1 ;;
        *) PROJECT="$1"; shift ;;
    esac
done

[[ -n "${PROJECT}" ]] || { usage; exit 1; }
cybersec_validate_project_name "${PROJECT}" || exit 1

OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"

if [[ ! -f "${NOTES_FILE}" ]]; then
    echo "analyze-recon: no Investigation-Notes.md for ${PROJECT} — run babysteps first." >&2
    exit 1
fi

if [[ "${NEO_AI:-1}" == "0" ]]; then
    printf '%s[*]%s AI triage disabled (NEO_AI=0).\n' "${C_BLUE:-}" "${C_RESET:-}"
    exit 0
fi

ai_mode="$(meta_get ai_triage 2>/dev/null || echo api)"
case "${ai_mode}" in
    manual)
        printf '%s[*]%s AI triage off (manual review mode).\n' "${C_BLUE:-}" "${C_RESET:-}"
        exit 0
        ;;
    subscription)
        phase="$(meta_get phase 2>/dev/null || echo recon)"
        neo_ai_run_cli_triage "${PROJECT}" "${phase}" || exit 0
        exit 0
        ;;
    api|builtin)
        ;;
    *)
        ai_mode="api"
        ;;
esac

if ! neo_ai_ensure_api_key; then
    printf '%s[*]%s AI triage skipped (no API key).\n' "${C_BLUE:-}" "${C_RESET:-}"
    notes_append_section TODO $'- [ ] Re-run AI triage when API key is configured: `./recon/analyze-recon.sh '"${PROJECT}"'`' || true
    exit 0
fi

scan_mode="$(meta_get scan_mode 2>/dev/null || echo unknown)"
phase="$(meta_get phase 2>/dev/null || echo recon)"

printf '%s[*]%s Building recon bundle from Investigation-Notes.md...\n' "${C_BLUE:-}" "${C_RESET:-}" >&2
bundle="$(neo_ai_build_recon_bundle "${PROJECT}")" || exit 1
printf '%s[*]%s Bundle ready (%d bytes). Calling Claude API — output below; %ds countdown on stderr.\n' \
    "${C_BLUE:-}" "${C_RESET:-}" "${#bundle}" "${NEO_AI_WAIT_TIMER_SEC:-90}" >&2

tmp_out="$(mktemp)"
if neo_ai_run_with_analyze_hud_to_file "${tmp_out}" \
    neo_ai_call_claude "${bundle}" "$(neo_ai_recon_system_prompt)" 0; then
    response="$(cat "${tmp_out}")"
    rm -f "${tmp_out}"
else
    rm -f "${tmp_out}"
    printf '%s[!]%s AI triage failed — mission continues. Re-run: ./recon/analyze-recon.sh %s\n' \
        "${C_YELLOW:-}" "${C_RESET:-}" "${PROJECT}" >&2
    notes_append_section TODO $'- [ ] Re-run AI triage (last attempt failed): `./recon/analyze-recon.sh '"${PROJECT}"'`' || true
    notes_refresh_status "analyze-recon" "AI triage failed — see TODO; prior **AI Triage** section unchanged." || true
    exit 0
fi

neo_ai_finish_triage_run "${PROJECT}" "${response}" "analyze-recon" "${scan_mode}"
exit 0
