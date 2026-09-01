#!/usr/bin/env bash
# neo-operator-recon-ai.sh — operator recon capture AI summary (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh"

neo_operator_recon_ai_system_prompt() {
    cat <<'EOF'
You structure operator manual recon notes for an authorized lab mission.

Output markdown with:

## Web / service observations
Bullet list of pages, forms, headers, technologies noticed.

## Interesting leads
Numbered follow-up checks (non-destructive).

## Suggested NEO next steps
Which enum tools or paths NEO should prioritize based on what the operator found.

Do not invent services not mentioned in the bundle.
EOF
}

neo_operator_recon_ai_save() {
    local project="$1" category="$2" response="$3" ts
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=notes-lib.sh
    source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || return 1
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    notes_append_section INTERACT "**AI summary (${category}, ${ts})**

${response}" 2>/dev/null || true
    notes_log operator-recon-ai "=== operator recon AI ${ts} ===
${response}" 2>/dev/null || true
    printf '[*] Operator recon summary saved → INTERACT section.\n'
}

neo_operator_recon_ai_offer() {
    local project="$1" content="${2:-}" category="${3:-operator-recon}"
    local bundle excerpt response
    neo_conductor_skip_interactive && return 0
    neo_conductor_ai_available || return 0
    if neo_conductor_prompt_yn 'Summarize operator recon notes with AI?' n; then
        bundle="$(neo_conductor_build_bundle "${project}" recon triage)"
        if [[ -n "${content}" ]]; then
            excerpt="${content}"
            if ((${#excerpt} > 8000)); then
                excerpt="${excerpt:0:8000}"$'\n\n[operator recon truncated at 8000 chars]'
            fi
            bundle="${bundle}"$'\n\n'"## Operator recon (${category})
${excerpt}"
        fi
        [[ -n "${bundle}" ]] || return 1
        # shellcheck source=neo-payload.sh
        source "${NEO_LIB_DIR}/neo-payload.sh" 2>/dev/null || return 1
        neo_payload_init_colors 2>/dev/null || true
        printf '\n[*] Structuring operator recon notes…\n\n'
        if ! response="$(neo_payload_call_ai "${bundle}" "$(neo_operator_recon_ai_system_prompt)" "${project}")"; then
            return 1
        fi
        neo_operator_recon_ai_save "${project}" "${category}" "${response}"
    fi
    return 0
}

neo_operator_recon_ai_summarize() {
    local project="$1" content="${2:-}" category="${3:-operator-recon}"
    neo_operator_recon_ai_offer "${project}" "${content}" "${category}"
}
