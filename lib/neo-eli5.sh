#!/usr/bin/env bash
# neo-eli5.sh — educational "Explain Like I'm 5" tutor at pauses (payload/CVE/commands).
#
# Operator picks [e] ELI5 to have AI break down what NEO found, why it suggested a step,
# and what every flag/segment of the proposed command does — before they run it.

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
NEO_HOME="${NEO_HOME:-${NEO_DIR}}"

neo_eli5_ai_available() {
    # shellcheck source=neo-ai-cli.sh
    source "${NEO_DIR}/lib/neo-ai-cli.sh"
    # shellcheck source=neo-ai.sh
    source "${NEO_DIR}/lib/neo-ai.sh"
    neo_ai_cli_available && return 0
    neo_ai_load_api_key >/dev/null 2>&1 && return 0
    return 1
}

neo_eli5_menu_fragment() {
    neo_eli5_ai_available && printf ' / [e]xplain (ELI5)'
}

neo_eli5_system_prompt() {
    local phase="${1:-recon}"
    cat <<EOF
You are a patient cybersecurity lab tutor. The operator is learning pentesting on an
authorized HTB/THM-style lab box. Current mission phase: ${phase}.

Explain at **ELI5 level** — plain language. Define jargon the first time you use it.
This is teaching mode: help them understand before they run anything.

Use exactly these markdown sections (in order):

## What NEO found (plain English)
Summarize the relevant recon, services, CVE leads, or privesc evidence that matters here.

## Why this step was suggested
Connect the dots: what was seen → why this tool, payload, or command is the logical next move.

## Command walkthrough
For EVERY command or payload in focus:
1. Put the full command alone in a fenced code block.
2. Walk it left-to-right: binary name, each flag/argument, paths, pipes, redirects, quotes.
3. If there are \`|\` pipes, explain what each side does and what flows between them.
4. For URLs, ports, and IPs in the command, say what each is for in this lab context.
5. For msfconsole/meterpreter/module paths, explain each path segment (type/category/name).
6. For reverse-shell or handler setups, explain listener vs callback using only what is already
   in the bundle — do not invent new exploit recipes.

## Safety & lab scope
Authorized lab only. What could go wrong if mistyped (wrong IP, wrong pane, wrong user).

## Try it yourself checklist
Three short questions the operator should be able to answer before running the command.

Rules:
- Do NOT suggest new attacks beyond explaining what is already in the bundle.
- Do not paste ready-to-run alternatives they did not ask for.
- If no specific command is in focus, explain the most recent payload/suggestion instead.
EOF
}

# Pull the best command or payload string to explain from notes.
neo_eli5_extract_focus() {
    local project="$1" notes cmd triage payload
    notes="${NEO_HOME}/projects/${project}/Investigation-Notes.md"
    [[ -f "${notes}" ]] || return 1

    # shellcheck source=neo-workbench.sh
    source "${NEO_DIR}/lib/neo-workbench.sh"
    if cmd="$(neo_workbench_extract_last_command "${project}" 2>/dev/null)" && [[ -n "${cmd}" ]]; then
        printf '%s' "${cmd}"
        return 0
    fi

    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"
    payload="$(notes_get_section PAYLOAD 2>/dev/null || true)"
    if [[ -n "${payload}" ]]; then
        cmd="$(awk '
            /^## Exact next command/ { grab=1; next }
            grab && /^```/ {
                if (!open) { open=1; buf=""; next }
                open=0; if (buf != "") { print buf; exit }
                next
            }
            grab && open { buf = buf (buf == "" ? "" : "\n") $0; next }
            grab && /^## / { exit }
        ' <<< "${payload}")"
        [[ -n "${cmd}" ]] && { printf '%s' "${cmd}"; return 0; }
    fi

    return 1
}

neo_eli5_build_bundle() {
    local project="$1" phase="$2" focus="${3:-}" extra="${4:-}"
    local bundle ports services triage payload borg workbench

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"
    # shellcheck source=neo-ai.sh
    source "${NEO_DIR}/lib/neo-ai.sh"

    ports="$(notes_get_section PORTS 2>/dev/null | neo_ai_strip_ansi 2>/dev/null || true)"
    services="$(notes_get_section SERVICES 2>/dev/null | neo_ai_strip_ansi 2>/dev/null || true)"
    triage="$(neo_ai_notes_section_trim AI-TRIAGE 4000 2>/dev/null || true)"
    payload="$(neo_ai_notes_section_trim PAYLOAD 6000 2>/dev/null || true)"
    borg="$(neo_ai_notes_section_trim BORG 3000 2>/dev/null || true)"
    workbench="$(neo_ai_notes_section_trim WORKBENCH 3000 2>/dev/null || true)"

    [[ -z "${focus}" ]] && focus="$(neo_eli5_extract_focus "${project}" 2>/dev/null || true)"

    # shellcheck source=neo-borg-disclosure.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/neo-borg-disclosure.sh" 2>/dev/null || true

    cat <<EOF
## ELI5 teaching request
Phase: ${phase}
${focus:+Primary command/payload to explain:
\`\`\`
${focus}
\`\`\`}
${extra:+## Operator note
${extra}}

## Open ports
${ports:-_none_}

## Services / enum notes
${services:-_none_}

## Recent AI triage (trimmed)
${triage:-_none_}

## Payload suggestions (trimmed)
${payload:-_none_}

## Borg dossier notes (trimmed)
${borg:-_none_}

## Workbench tries (trimmed)
${workbench:-_none_}
$(neo_borg_disclosure_ai_rules "${project}" 2>/dev/null || true)
EOF
}

neo_eli5_save() {
    local label="$1" response="$2" focus="${3:-}"
    local ts doc existing placeholder=false

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    if [[ -n "${focus}" ]]; then
        doc="### ${label} — ${ts}
**Focus command:** \`${focus}\`

${response}"
    else
        doc="### ${label} — ${ts}

${response}"
    fi

    existing="$(notes_get_section ELI5 2>/dev/null || true)"
    if [[ -z "${existing}" ]] || [[ "${existing}" == *"_No ELI5"* ]]; then
        placeholder=true
    fi

    if [[ "${placeholder}" == true ]]; then
        notes_set_section ELI5 "${doc}" || return 1
    else
        notes_append_section ELI5 "$(printf '\n\n---\n\n%s' "${doc}")" || return 1
    fi
}

neo_eli5_print_brief() {
    local response="$1"
    local block
    # shellcheck source=neo-payload.sh
    source "${NEO_DIR}/lib/neo-payload.sh"
    neo_payload_init_colors
    block="$(awk '
        /^## / { if (found) exit; if ($0 ~ /^## (What NEO found|Why this step|Command walkthrough)/) found=1 }
        found { print }
    ' <<< "${response}")"
    printf '\n%s%s  ELI5 — TERMINAL BRIEF%s\n' "${C_MAGENTA:-}" "${C_BRIGHT:-}" "${C_RESET:-}"
    while IFS= read -r line; do
        [[ -n "${line}" ]] && printf '  %s\n' "${line}"
    done <<< "${block}"
    printf '\n  Full lesson → Investigation-Notes.md · ELI5 Explain\n\n'
}

neo_eli5_run() {
    local project="$1" phase="$2" focus="${3:-}" operator_note="${4:-}"
    local bundle response ts label

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"

    [[ -f "${NOTES_FILE}" ]] || {
        printf '[!] No Investigation-Notes.md for %s.\n' "${project}" >&2
        return 1
    }

    if ! neo_eli5_ai_available; then
        printf '[!] ELI5 needs Claude Code (claude) or ANTHROPIC_API_KEY.\n' >&2
        return 1
    fi

    if [[ -z "${focus}" && -t 0 && "${NEO_TEST_NONINTERACTIVE:-0}" != "1" ]]; then
        focus="$(neo_eli5_extract_focus "${project}" 2>/dev/null || true)"
        if [[ -n "${focus}" ]]; then
            printf '[*] Focus command from notes:\n  %s\n' "${focus}"
            read -r -p 'Explain this command? [Y/n]: ' ans
            case "${ans}" in
                n|N) focus="" ;;
            esac
        fi
        if [[ -z "${focus}" ]]; then
            read -r -p 'Paste a command/payload to explain (or Enter for latest suggestion): ' focus
        fi
        if [[ -z "${operator_note}" && -t 0 ]]; then
            read -r -p 'Anything else to explain? (CVE, output line — optional): ' operator_note
        fi
    fi

    [[ -z "${focus}" ]] && focus="$(neo_eli5_extract_focus "${project}" 2>/dev/null || true)"

    # shellcheck source=neo-payload.sh
    source "${NEO_DIR}/lib/neo-payload.sh"
    neo_payload_init_colors
    printf '\n%s[*]%s ELI5 — building teaching bundle…\n\n' "${C_CYAN:-}" "${C_RESET:-}"

    bundle="$(neo_eli5_build_bundle "${project}" "${phase}" "${focus}" "${operator_note}")"
    if ! response="$(neo_payload_call_ai "${bundle}" "$(neo_eli5_system_prompt "${phase}")")"; then
        return 1
    fi

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    label="ELI5 (${phase})"
    neo_eli5_save "${label}" "${response}" "${focus}"
    neo_eli5_print_brief "${response}"

    cybersec_finish "eli5" "${phase}" \
        "ELI5 lesson saved → **ELI5 Explain** section" \
        "=== eli5 ${ts} ===\nfocus: ${focus:-auto}\n${response}"
}

neo_eli5_at_pause() {
    local project="$1" phase="$2"
    neo_eli5_run "${project}" "${phase}" "" ""
}

# Optional immediate lesson after payload suggest / workbench analyze.
neo_eli5_offer_after() {
    local project="$1" phase="$2" focus="${3:-}"
    [[ -t 0 ]] || return 0
    [[ "${NEO_TEST_NONINTERACTIVE:-0}" == "1" ]] && return 0
    neo_eli5_ai_available || return 0
    local ans
    read -r -p 'Explain this at ELI5 level now? [y/N]: ' ans
    [[ "${ans}" =~ ^[yY] ]] || return 0
    neo_eli5_run "${project}" "${phase}" "${focus}" "Follow-up after latest NEO suggestion."
}

neo_eli5_offer_after_borg() {
    local project="$1" phase="$2" slug="$3" vector="$4"
    neo_eli5_offer_after "${project}" "${phase}" "" \
        "Explain the Borg dossier for \"${vector}\" (slug ${slug}) — technique, CVE leads, and suggested commands at ELI5 level."
}

neo_eli5_offer_after_triage() {
    local project="$1" phase="${2:-recon}"
    neo_eli5_offer_after "${project}" "${phase}" "" \
        "Explain the latest AI triage — what was found, why these attack paths, and what to do next."
}

neo_eli5_handle_choice() {
    local project="$1" phase="$2"
    neo_eli5_at_pause "${project}" "${phase}"
}
