#!/usr/bin/env bash
# neo-ai-cli.sh — Claude Code subscription triage via `claude -p` (Pro/Max login).

NEO_AI_CLI_MAX="${NEO_AI_CLI_MAX:-9000000}"  # stay under ~10MB stdin cap

neo_ai_cli_available() {
    command -v claude >/dev/null 2>&1
}

# Run claude -p with stdin; prefer subscription (unset API key for this call).
neo_ai_cli_call() {
    local prompt="$1"
    local stdin_content="${2:-}"
    local tmp_in rc saved_key="${ANTHROPIC_API_KEY:-}"

    if ! neo_ai_cli_available; then
        echo "neo-ai-cli: claude not found on PATH (install Claude Code)" >&2
        return 1
    fi

    if ((${#stdin_content} > NEO_AI_CLI_MAX)); then
        stdin_content="${stdin_content:0:NEO_AI_CLI_MAX}"$'\n\n[truncated for claude -p stdin cap — full notes in Investigation-Notes.md]'
    fi

    tmp_in="$(mktemp)"
    printf '%s' "${stdin_content}" > "${tmp_in}"
    # Same fix as lib/neo-ai.sh's neo_ai_call_claude — see that comment for why the
    # single-quoted deferred-expansion form crashes with "unbound variable" if this RETURN
    # trap ever fires after this function's own scope is gone (untriggered here so far, but
    # the same landmine for mode A/claude -p).
    trap "rm -f '${tmp_in}'; trap - RETURN" RETURN

    unset ANTHROPIC_API_KEY
    set +e
    claude -p "${prompt}" < "${tmp_in}"
    rc=$?
    set -e

    [[ -n "${saved_key}" ]] && export ANTHROPIC_API_KEY="${saved_key}"
    return "${rc}"
}

neo_ai_cli_call_with_hud() {
    local tmp out rc
    tmp="$(mktemp)"
    if neo_ai_run_with_analyze_hud_to_file "${tmp}" neo_ai_cli_call "$@"; then
        out="$(cat "${tmp}")"
        rm -f "${tmp}"
        printf '%s' "${out}"
        return 0
    fi
    rc=$?
    rm -f "${tmp}"
    return "${rc}"
}

neo_ai_cli_user_prompt() {
    local phase="${1:-recon}"
    cat <<EOF
Review the Investigation-Notes bundle below from an authorized HTB/THM-style lab engagement.
Current mission phase: ${phase}

Provide your analysis using exactly these markdown sections (in order):

## Technical observations
## Attack paths
## Vulnerability leads
## Enumeration gaps
## Operator next steps

For Operator next steps, every line must start with [NEO], [MANUAL], or [TOOL:toolname].
Give concrete next steps and specific instructions the operator should follow now.
Build on any prior AI triage in the bundle; note what changed.
EOF
}

# Shared post-call: brief, tool checks, save to AI-TRIAGE.
neo_ai_finish_triage_run() {
    local project="$1" response="$2" source="$3" scan_mode="${4:-unknown}"
    local ts triage_doc raw_log

    # shellcheck source=neo-ai-analyze.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-ai-analyze.sh"

    neo_ai_print_triage_brief "${response}"
    neo_ai_process_tool_requests "${response}"

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    triage_doc="$(cat <<EOF
## AI triage run ${ts}
_Source: \`${source}\` · scan mode: \`${scan_mode}\` · saved to Investigation-Notes **AI Triage**_

${response}
EOF
)"

    neo_ai_save_triage "${triage_doc}" || return 1

    raw_log="$(cat <<EOF
=== ${source} ${ts} ===
scan_mode: ${scan_mode}

${response}
EOF
)"

    cybersec_finish "${source}" "$(meta_get phase 2>/dev/null || echo recon)" \
        "AI triage saved in **AI Triage** section (included in future runs)." \
        "${raw_log}"

    printf '%s[+]%s AI triage written to projects/%s/Investigation-Notes.md → AI Triage\n' \
        "${C_GREEN:-}" "${C_RESET:-}" "${project}"
}

neo_ai_run_cli_triage() {
    local project="$1" phase="${2:-recon}"
    local bundle response scan_mode

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    [[ -f "${NOTES_FILE}" ]] || {
        echo "neo-ai-cli: no Investigation-Notes.md for ${project}" >&2
        return 1
    }

    if ! neo_ai_cli_available; then
        printf '%s[!]%s Claude Code (claude) not on PATH — install it or switch AI mode.\n' \
            "${C_YELLOW:-}" "${C_RESET:-}" >&2
        return 1
    fi

    # shellcheck source=neo-ai.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-ai.sh"

    scan_mode="$(meta_get scan_mode 2>/dev/null || echo unknown)"
    printf '%s[*]%s Building mission bundle from Investigation-Notes.md...\n' \
        "${C_BLUE:-}" "${C_RESET:-}" >&2
    bundle="$(neo_ai_build_recon_bundle "${project}")" || return 1
    printf '%s[*]%s Bundle ready (%d bytes). Calling Claude (claude -p) — output below; %ds countdown on stderr.\n' \
        "${C_BLUE:-}" "${C_RESET:-}" "${#bundle}" "${NEO_AI_WAIT_TIMER_SEC:-90}" >&2

    local tmp_out response rc
    tmp_out="$(mktemp)"
    # shellcheck source=neo-ai-analyze.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-ai-analyze.sh"
    if neo_ai_run_with_analyze_hud_to_file "${tmp_out}" \
        neo_ai_cli_call "$(neo_ai_cli_user_prompt "${phase}")" "${bundle}"; then
        response="$(cat "${tmp_out}")"
        rm -f "${tmp_out}"
        neo_ai_finish_triage_run "${project}" "${response}" "analyze-recon-cli" "${scan_mode}"
        return 0
    fi
    rc=$?
    rm -f "${tmp_out}"
    printf '%s[!]%s Claude Code triage failed — mission continues.\n' \
        "${C_YELLOW:-}" "${C_RESET:-}" >&2
    notes_append_section TODO $'- [ ] Re-run AI triage: `[a]` at a pause or `./recon/analyze-recon.sh '"${project}"'`' || true
    return "${rc}"
}

neo_ai_save_ask() {
    local question="$1" response="$2"
    local ts doc existing placeholder=false

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    doc="$(cat <<EOF
### Q — ${ts}
**Asked:** ${question}

${response}
EOF
)"

    existing="$(notes_get_section ASK 2>/dev/null || true)"
    if [[ -z "${existing}" ]] || [[ "${existing}" == *"_No questions"* ]]; then
        placeholder=true
    fi

    if [[ "${placeholder}" == true ]]; then
        notes_set_section ASK "${doc}" || return 1
    else
        notes_append_section ASK "$(printf '\n\n---\n\n%s' "${doc}")" || return 1
    fi
}

# [a]sk Claude — prompts for a free-text question, attaches the last N lines of
# Investigation-Notes.md as context (default 800; NEO_ASK_CONTEXT_LINES to override) so
# Claude sees what's happened recently, not a generic fixed triage prompt. Answer is
# printed in full and saved to the ASK section (append-only Q&A log).
neo_ai_cli_ask_claude() {
    local project="$1" phase="${2:-recon}"
    local question context_lines context tmp_out response rc

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    [[ -f "${NOTES_FILE}" ]] || {
        echo "neo-ai-cli: no Investigation-Notes.md for ${project}" >&2
        return 1
    }

    if ! neo_ai_cli_available; then
        printf '%s[!]%s Claude Code (claude) not on PATH.\n' "${C_YELLOW:-}" "${C_RESET:-}" >&2
        return 1
    fi

    [[ -t 0 ]] || {
        echo "neo-ai-cli: ask-claude needs an interactive terminal to take a question." >&2
        return 1
    }

    read -r -p 'What do you want to ask Claude? ' question
    [[ -n "${question}" ]] || {
        printf 'No question given — skipped.\n'
        return 1
    }

    context_lines="${NEO_ASK_CONTEXT_LINES:-800}"
    context="$(tail -n "${context_lines}" "${NOTES_FILE}")"

    printf '%s[*]%s Asking Claude (claude -p) — last %d lines of Investigation-Notes.md attached for context.\n' \
        "${C_BLUE:-}" "${C_RESET:-}" "${context_lines}" >&2

    tmp_out="$(mktemp)"
    # shellcheck source=neo-ai-analyze.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-ai-analyze.sh"
    if neo_ai_run_with_analyze_hud_to_file "${tmp_out}" \
        neo_ai_cli_call "${question}" "$(cat <<EOF
Mission phase: ${phase}. Recent Investigation-Notes.md (last ${context_lines} lines, for context — this is a live HTB/THM-style lab case file):

${context}
EOF
)"; then
        response="$(cat "${tmp_out}")"
        rm -f "${tmp_out}"
    else
        rc=$?
        rm -f "${tmp_out}"
        printf '%s[!]%s Ask Claude failed.\n' "${C_YELLOW:-}" "${C_RESET:-}" >&2
        return "${rc}"
    fi

    neo_ai_save_ask "${question}" "${response}" || true
    printf '\n%s\n\n' "${response}"
    printf '%s[+]%s Saved to projects/%s/Investigation-Notes.md → Ask Claude Log\n' \
        "${C_GREEN:-}" "${C_RESET:-}" "${project}"
}

neo_ai_cli_pause_review() {
    local project="$1" phase="$2"
    neo_ai_cli_ask_claude "${project}" "${phase}" || true
}
