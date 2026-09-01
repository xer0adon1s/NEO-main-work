#!/usr/bin/env bash
# neo-conductor-privesc.sh — privesc-phase conductor hooks (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh"

neo_conductor_privesc_plan_root() {
    local project="$1"
    printf '%s/projects/%s/privesc' \
        "${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}" "${project}"
}

neo_conductor_privesc_system_prompt() {
    cat <<'EOF'
You are a privesc triage assistant for authorized lab work only.
Review WHOAMI, SUDO, SUID, CAPS, CRON, FILES evidence plus privesc-facts.json and jq ranker output.

Write operator-facing markdown with exactly these sections:

## Summary
2-3 sentences on the most likely privesc paths grounded in the evidence.

## Ranked next steps
Numbered list — each step one concrete command or check (lab-safe, copy-paste ready).

## Caveats
What to verify before running destructive or irreversible commands.

Rules:
- Ground every recommendation in bundle evidence; do not invent CVEs or misconfigurations not present.
- Prefer checks over exploitation until a path is confirmed.
EOF
}

neo_conductor_privesc_after_ingest() {
    local project="$1" bundle response ts facts plan facts_text plan_text plan_root
    neo_conductor_skip_interactive && return 0
    neo_conductor_ai_available || return 0

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || true
    [[ -f "${NOTES_FILE}" ]] || return 0
    [[ "$(meta_get conductor_privesc_triage_done 2>/dev/null || true)" == "1" ]] && return 0

    if ! neo_conductor_prompt_yn 'Run AI privesc triage on new FindPrivs evidence?' y; then
        return 0
    fi

    plan_root="$(neo_conductor_privesc_plan_root "${project}")"
    facts="${plan_root}/privesc-facts.json"
    plan="${plan_root}/privesc-plan.json"
    facts_text="_none_"
    plan_text="_none_"
    [[ -f "${facts}" ]] && facts_text="$(head -c 8000 "${facts}" 2>/dev/null || true)"
    [[ -f "${plan}" ]] && plan_text="$(head -c 8000 "${plan}" 2>/dev/null || true)"

    bundle="$(neo_conductor_build_bundle "${project}" privesc privesc-triage)" || return 1
    bundle="${bundle}"$'\n\n'"## privesc-facts.json
${facts_text}

## privesc-plan.json (jq ranker)
${plan_text}"

    # shellcheck source=neo-payload.sh
    source "${NEO_LIB_DIR}/neo-payload.sh" 2>/dev/null || return 1
    neo_payload_init_colors 2>/dev/null || true
    printf '\n[*] Privesc AI triage…\n\n'

    if ! response="$(neo_payload_call_ai "${bundle}" "$(neo_conductor_privesc_system_prompt)" "${project}")"; then
        return 1
    fi

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    # shellcheck source=notes-lib.sh
    source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || true
    notes_set_section PRIVESC-PLAN "${response}" 2>/dev/null || true
    notes_append_section AI-TRIAGE "**Privesc triage (${ts})**

${response}" 2>/dev/null || true
    notes_log privesc-triage "=== privesc triage ${ts} ===
${response}" 2>/dev/null || true
    meta_set conductor_privesc_triage_done 1 2>/dev/null || true
    printf '[*] Privesc plan saved → PRIVESC-PLAN section.\n'
    return 0
}

neo_conductor_privesc_offer_rank() {
    local project="$1"
    neo_conductor_privesc_after_ingest "${project}"
}
