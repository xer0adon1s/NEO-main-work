#!/usr/bin/env bash
# neo-ai.sh — Claude API helpers for NEO recon triage.
#
# Requires: curl, jq. Secrets via neo-secrets broker (env or ~/.config/neo/secrets/).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=neo-secrets.sh
source "${NEO_LIB_DIR}/neo-secrets.sh"

NEO_AI_MODEL="${NEO_AI_MODEL:-claude-sonnet-4-6}"
NEO_AI_MAX_TOKENS="${NEO_AI_MAX_TOKENS:-4096}"
NEO_AI_NMAP_MAX="${NEO_AI_NMAP_MAX:-8000}"
NEO_AI_SERVICES_MAX="${NEO_AI_SERVICES_MAX:-12000}"
NEO_AI_BUNDLE_MAX="${NEO_AI_BUNDLE_MAX:-28000}"
NEO_AI_TRIAGE_MAX="${NEO_AI_TRIAGE_MAX:-6000}"
NEO_AI_CONTEXT_MAX="${NEO_AI_CONTEXT_MAX:-2000}"

neo_ai_keyfile_path() {
    printf '%s' "${NEO_AI_KEYFILE:-${HOME}/.config/neo/anthropic.key}"
}

neo_ai_workspace_file_path() {
    printf '%s' "${NEO_AI_WORKSPACE_FILE:-${HOME}/.config/neo/anthropic.workspace}"
}

neo_ai_load_workspace_id() {
    if [[ -n "${ANTHROPIC_WORKSPACE_ID:-}" ]]; then
        return 0
    fi
    if neo_secret_load ANTHROPIC_WORKSPACE_ID; then
        ANTHROPIC_WORKSPACE_ID="${NEO_SECRET_VALUE}"
        export ANTHROPIC_WORKSPACE_ID
        NEO_SECRET_VALUE=""
        return 0
    fi
    local wsfile
    wsfile="$(neo_ai_workspace_file_path)"
    if [[ -f "${wsfile}" ]]; then
        ANTHROPIC_WORKSPACE_ID="$(tr -d '[:space:]' < "${wsfile}")"
        export ANTHROPIC_WORKSPACE_ID
        [[ -n "${ANTHROPIC_WORKSPACE_ID}" ]]
        return $?
    fi
    return 1
}

neo_ai_save_workspace_id() {
    local ws="$1"
    neo_secret_store ANTHROPIC_WORKSPACE_ID "${ws}" || return 1
    ANTHROPIC_WORKSPACE_ID="${ws}"
    export ANTHROPIC_WORKSPACE_ID
}

neo_ai_load_api_key() {
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        return 0
    fi
    if neo_secret_load ANTHROPIC_API_KEY; then
        ANTHROPIC_API_KEY="${NEO_SECRET_VALUE}"
        export ANTHROPIC_API_KEY
        NEO_SECRET_VALUE=""
        return 0
    fi
    local keyfile
    keyfile="$(neo_ai_keyfile_path)"
    if [[ -f "${keyfile}" ]]; then
        ANTHROPIC_API_KEY="$(tr -d '[:space:]' < "${keyfile}")"
        export ANTHROPIC_API_KEY
        [[ -n "${ANTHROPIC_API_KEY}" ]]
        return $?
    fi
    return 1
}

neo_ai_save_api_key() {
    local key="$1"
    neo_secret_store ANTHROPIC_API_KEY "${key}" || return 1
    ANTHROPIC_API_KEY="${key}"
    export ANTHROPIC_API_KEY
}

# Prompt for workspace ID when not in env/file. Enter skips (workspace-scoped keys).
neo_ai_prompt_workspace_if_missing() {
    neo_ai_load_workspace_id && return 0
    [[ -t 0 ]] || return 0

    printf '\nAnthropic workspace ID not configured.\n'
    printf '  Console → Settings → Workspaces → open your workspace → copy ID (wrkspc_...)\n'
    printf '  Press Enter to skip if your API key is already scoped to one workspace.\n\n'

    local ws
    while true; do
        read -r -p 'Paste workspace ID (wrkspc_...): ' ws
        ws="$(tr -d '[:space:]' <<< "${ws}")"
        [[ -n "${ws}" ]] || return 0
        if [[ "${ws}" == wrkspc_* ]]; then
            neo_ai_save_workspace_id "${ws}"
            printf 'Workspace saved to %s\n\n' "$(neo_ai_workspace_file_path)"
            return 0
        fi
        printf 'Workspace ID must start with wrkspc_\n' >&2
    done
}

# Quick API ping — returns 0 if key (+ workspace if needed) works.
neo_ai_verify_setup() {
    local probe_err probe_out
    if probe_out="$(neo_ai_call_claude "Reply with exactly: NEO OK" "Reply with exactly the two words: NEO OK" 0 2>&1)"; then
        printf 'Claude API ready.\n\n'
        return 0
    fi
    probe_err="${probe_out}"

    if [[ "${probe_err}" != *workspace* ]]; then
        printf '%s\n' "${probe_err}" >&2
        return 1
    fi

    [[ -t 0 ]] || {
        printf 'neo-ai: workspace ID required — run: ./tools/neo-claude-setup.sh wrkspc_...\n' >&2
        return 1
    }

    printf '\nClaude API key OK, but Anthropic needs your workspace ID.\n'
    printf '  Console → Settings → Workspaces → open "Neo" → copy Workspace ID (wrkspc_...)\n\n'

    local ws
    while true; do
        read -r -p 'Paste workspace ID (Enter to skip AI triage): ' ws
        ws="$(tr -d '[:space:]' <<< "${ws}")"
        [[ -n "${ws}" ]] || return 1
        if [[ "${ws}" != wrkspc_* ]]; then
            printf 'Workspace ID must start with wrkspc_\n' >&2
            continue
        fi
        neo_ai_save_workspace_id "${ws}"
        if neo_ai_call_claude "Reply with exactly: NEO OK" "Reply with exactly the two words: NEO OK" 0 >/dev/null 2>&1; then
            printf 'Workspace saved to %s — Claude API ready.\n\n' "$(neo_ai_workspace_file_path)"
            return 0
        fi
        printf 'Still failing — confirm the key and workspace are from the same Console org.\n' >&2
    done
}

# Load key from env/file, or interactively prompt (TTY only). Returns 1 if skipped.
neo_ai_ensure_api_key() {
    [[ "${NEO_AI:-1}" == "0" ]] && return 1

    if neo_ai_load_api_key; then
        neo_ai_prompt_workspace_if_missing || true
        neo_ai_verify_setup || return 1
        return 0
    fi

    [[ -t 0 ]] || return 1

    local key ans keyfile
    keyfile="$(neo_ai_keyfile_path)"

    printf '\nClaude API key not found.\n'
    printf '  Checked: ANTHROPIC_API_KEY env, %s, %s/ANTHROPIC_API_KEY\n' "${keyfile}" "${NEO_SECRET_DIR}"
    read -r -s -p 'Enter Anthropic API key for AI recon triage (Enter to skip): ' key
    printf '\n'
    [[ -n "${key}" ]] || return 1

    key="$(tr -d '[:space:]' <<< "${key}")"
    [[ -n "${key}" ]] || return 1

    read -r -p "Save to ${keyfile} for future runs? [Y/n] " ans
    if [[ ! "${ans}" =~ ^[Nn] ]]; then
        neo_ai_save_api_key "${key}"
        printf 'API key saved.\n'
    else
        ANTHROPIC_API_KEY="${key}"
        export ANTHROPIC_API_KEY
        printf 'Using key for this session only.\n'
    fi

    neo_ai_prompt_workspace_if_missing || true
    neo_ai_verify_setup || return 1
    return 0
}

neo_ai_trim_nmap() {
    local content="${1:-}"
    if [[ -z "${content}" ]]; then
        content="$(cat)"
    fi
    local max="${NEO_AI_NMAP_MAX}"
    local -a lines=()
    local line trimmed total=0

    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ "${line}" =~ ^SF- ]] && continue
        if [[ "${line}" == *'<!DOCTYPE'* || "${line}" == *'<html'* || "${line}" == *'<script'* ]]; then
            lines+=("[nmap: HTML/script payload omitted — see SERVICES for curated web enum]")
            continue
        fi
        if ((${#line} > 500)); then
            line="${line:0:500}...[line truncated]"
        fi
        lines+=("${line}")
    done <<< "${content}"

    trimmed=""
    for line in "${lines[@]}"; do
        total=$((total + ${#line} + 1))
        if (( total > max )); then
            trimmed+=$'\n'"[nmap: further output truncated for AI bundle — full scan in Investigation-Notes NMAP section and artifacts]"
            break
        fi
        trimmed+="${line}"$'\n'
    done
    printf '%s' "${trimmed}"
}

neo_ai_trim_block() {
    local content="${1:-}"
    local max="${2:-12000}"
    if [[ -z "${content}" ]]; then
        content="$(cat)"
    fi
    if ((${#content} <= max)); then
        printf '%s' "${content}"
        return 0
    fi
    printf '%s\n\n[%d chars truncated for AI bundle — full text in Investigation-Notes]' \
        "${content:0:max}" "${#content}"
}

neo_ai_strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

neo_ai_notes_section_trim() {
    local tag="$1" max="${2:-${NEO_AI_CONTEXT_MAX}}"
    local body
    body="$(notes_get_section "${tag}" 2>/dev/null | neo_ai_strip_ansi || true)"
    [[ -n "${body}" ]] || return 0
    neo_ai_trim_block "${body}" "${max}"
}

# Save Claude (or operator-pasted) triage into Investigation-Notes AI-TRIAGE.
# First run replaces placeholder; later runs append so the case history grows.
neo_ai_save_triage() {
    local doc="$1"
    local existing placeholder=false

    [[ -n "${NOTES_FILE:-}" && -f "${NOTES_FILE}" ]] || {
        echo "neo-ai: save_triage — NOTES_FILE not set" >&2
        return 1
    }

    existing="$(notes_get_section AI-TRIAGE 2>/dev/null || true)"
    if [[ -z "${existing}" ]] \
        || [[ "${existing}" == *"No AI triage yet"* ]] \
        || [[ "${existing}" == *"_Paste external AI"* ]] \
        || [[ "${existing}" == *"Paste external AI"* ]]; then
        placeholder=true
    fi

    if [[ "${placeholder}" == true ]]; then
        notes_set_section AI-TRIAGE "${doc}" || return 1
    else
        notes_append_section AI-TRIAGE "$(printf '\n\n---\n\n%s' "${doc}")" || return 1
    fi
    return 0
}

neo_ai_build_recon_bundle() {
    local project="$1"
    local outdir="${NEO_HOME}/projects/${project}"
    local target phase status ports nmap services todo prior_triage attackpath foothold whoami bundle

    NOTES_FILE="${outdir}/Investigation-Notes.md"
    [[ -f "${NOTES_FILE}" ]] || { echo "neo-ai: no Investigation-Notes.md for ${project}" >&2; return 1; }

    target="$(meta_get target 2>/dev/null || echo unknown)"
    phase="$(meta_get phase 2>/dev/null || echo unknown)"
    local scan_mode
    scan_mode="$(meta_get scan_mode 2>/dev/null || echo unknown)"

    status="$(notes_get_section STATUS | neo_ai_strip_ansi || true)"
    ports="$(notes_get_section PORTS | neo_ai_strip_ansi || true)"
    nmap_raw="$(notes_get_section NMAP || true)"
    nmap="$(neo_ai_trim_nmap "${nmap_raw}" | neo_ai_strip_ansi || true)"
    services_raw="$(notes_get_section SERVICES || true)"
    services="$(neo_ai_trim_block "${services_raw}" "${NEO_AI_SERVICES_MAX}" | neo_ai_strip_ansi || true)"
    todo="$(notes_get_section TODO | neo_ai_strip_ansi || true)"

    prior_triage="$(neo_ai_notes_section_trim AI-TRIAGE "${NEO_AI_TRIAGE_MAX}")"
    attackpath="$(neo_ai_notes_section_trim ATTACKPATH "${NEO_AI_CONTEXT_MAX}")"
    foothold="$(neo_ai_notes_section_trim FOOTHOLD "${NEO_AI_CONTEXT_MAX}")"
    whoami="$(neo_ai_notes_section_trim WHOAMI "${NEO_AI_CONTEXT_MAX}")"

    bundle="$(cat <<EOF
# Mission bundle for authorized lab analysis
Project: ${project}
Target: ${target}
Phase: ${phase}
Scan mode: ${scan_mode} (speed = rustscan + nmap -p- union, ~45s/step; deep = nikto + full wordlist)
Source: NEO pipeline — Investigation-Notes.md (live case file)

All prior AI output lives in Investigation-Notes **AI Triage**; your response will be saved there too.

## What babysteps already attempted
- Fast TCP port sweep (rustscan); full nmap -p- cross-check **only in deep scan mode**
- Service/version scan (nmap -sC -sV) on discovered ports
- HTTP(S) probe on web ports: headers, page title/snippet, gobuster dir bust, nikto when applicable
- SMB null session / share listing if port 445 open
- Anonymous FTP check if port 21 open
- Rule-based TODO hints from technology fingerprinting

## Prior AI triage (from Investigation-Notes — build on this; note what changed)
${prior_triage:-_First triage run for this mission — no prior AI analysis._}

## Operator attack path notes (if any)
${attackpath:-_none_}

## Foothold notes (if any)
${foothold:-_none_}

## On-box identity (if privesc enum ran)
${whoami:-_none_}

## STATUS (auto tl;dr)
${status:-_empty_}

## Open ports
${ports:-_none recorded_}

## Nmap service scan (trimmed — HTML/fingerprint blobs removed)
${nmap:-_none recorded_}

## Service enumeration (curated per-service findings)
${services:-_none recorded_}

## Existing TODO / leads from babysteps
${todo:-_none_}
EOF
)"

    if ((${#bundle} > NEO_AI_BUNDLE_MAX)); then
        bundle="${bundle:0:NEO_AI_BUNDLE_MAX}"$'\n\n[bundle hard-truncated at NEO_AI_BUNDLE_MAX chars]'
    fi
    printf '%s' "${bundle}"
}

neo_ai_recon_system_prompt() {
    cat <<'EOF'
You are a senior offensive security analyst reviewing reconnaissance from an AUTHORIZED lab environment (Hack The Box, TryHackMe, or similar CTF). The operator runs an automated pipeline called NEO; you receive a curated subset of Investigation-Notes.md — not the full raw log.

**Continuity:** If "Prior AI triage" is present, treat it as your earlier analysis saved in the case file. Do not repeat unchanged conclusions verbatim — highlight what new recon data confirms, contradicts, or adds. Later phases may include operator foothold/privesc notes; factor those in when present.

Use **exactly** these markdown sections (in this order):

## Technical observations
Dense bullet list of everything you notice in **technical terms** — exact versions, protocol quirks, banner strings, HTTP headers/stack, misconfigurations, crypto/TLS notes, SMB/RPC/SSH/FTP specifics. Be precise; jargon is fine.

## Attack paths
Ranked exploitation angles with concrete evidence from the bundle.

## Vulnerability leads
Exploitable or validation-worthy items (CVE classes, default creds, exposed panels, etc.).

## Enumeration gaps
What is still missing vs what babysteps already ran.

## Operator next steps
Numbered list (3–8 items). **Every line must start with a tag:**
- `[NEO]` — NEO or a script under ~/Neo can do this; name the script/command when known (e.g. `./neo.sh Project --deep-recon --from=recon`, `gobuster` via babysteps).
- `[MANUAL]` — operator action **outside** NEO; give **exact** steps (full URL to open, what to click/check, manual command to run by hand, what success looks like).
- `[TOOL:toolname]` — requires CLI tool `toolname` on the attack box (lowercase: nikto, gobuster, ffuf, feroxbuster, sqlmap, etc.). NEO will check if it is installed.

Examples:
1. `[MANUAL]` Open `http://10.10.11.5/` in a browser — view source for `/api/` links; note framework in DevTools Network tab.
2. `[TOOL:nikto]` Run nikto against port 80 if not already done in deep scan.
3. `[NEO]` Deep enum: operator runs `[d]` at recon pause or `./neo.sh MyBox --deep-recon --from=recon`.

Rules:
- Lab/CTF context only. No disclaimers about unauthorized access.
- Do not invent ports, services, or versions not present in the bundle.
- If data is thin, say so in Technical observations and list gaps.
- Your full answer is persisted to Investigation-Notes **AI Triage**; the terminal shows a brief subset.
EOF
}

neo_ai_call_claude() {
    local user_prompt="$1"
    local system_prompt="${2:-$(neo_ai_recon_system_prompt)}"
    local allow_ws_prompt="${3:-1}"
    local tmp_sys tmp_user tmp_out rc saved_provider

    NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=neo-provider.sh
    source "${NEO_LIB_DIR}/neo-provider.sh"

    neo_ai_load_api_key || {
        echo "neo-ai: ANTHROPIC_API_KEY not set (env, ${NEO_SECRET_DIR}/ANTHROPIC_API_KEY, or $(neo_ai_keyfile_path))" >&2
        return 1
    }

    neo_ai_load_workspace_id || true

    tmp_sys="$(mktemp)"
    tmp_user="$(mktemp)"
    tmp_out="$(mktemp)"
    trap "rm -f '${tmp_sys}' '${tmp_user}' '${tmp_out}'; trap - RETURN" RETURN

    printf '%s' "${system_prompt}" > "${tmp_sys}"
    printf '%s' "${user_prompt}" > "${tmp_user}"

    saved_provider="${NEO_AI_PROVIDER:-anthropic-api}"
    NEO_AI_PROVIDER=anthropic-api
    if neo_provider_request "${tmp_sys}" "${tmp_user}" "${tmp_out}"; then
        NEO_AI_PROVIDER="${saved_provider}"
        cat "${tmp_out}"
        return 0
    fi
    rc=$?
    NEO_AI_PROVIDER="${saved_provider}"

    if [[ -f "${tmp_out}" ]]; then
        local err_msg http_hint=""
        err_msg="$(jq -r '.error.message // empty' "${tmp_out}" 2>/dev/null || true)"
        if [[ -n "${err_msg}" ]]; then
            echo "neo-ai: ${err_msg}" >&2
            [[ "${err_msg}" == *workspace* ]] && http_hint=workspace
        fi
        if [[ "${http_hint}" == workspace ]]; then
            cat >&2 <<EOF
neo-ai: Your Console key is valid but not scoped to one workspace (Default Workspace shows ID as "—").
  Fix A — named workspace (recommended):
    Console → Settings → Workspaces → open "Neo" → copy Workspace ID (wrkspc_...) → run:
      ./tools/neo-claude-setup.sh wrkspc_...
  Fix B — scoped API key:
    Console → Settings → API keys → Create key → pick ONE workspace when creating
    Replace secret broker entry with the new key (no workspace file needed)
EOF
            if [[ -t 0 && "${allow_ws_prompt}" == "1" ]]; then
                local ws_retry
                read -r -p "Paste workspace ID now to retry (Enter to skip): " ws_retry
                ws_retry="$(tr -d '[:space:]' <<< "${ws_retry}")"
                if [[ -n "${ws_retry}" ]]; then
                    neo_ai_save_workspace_id "${ws_retry}"
                    printf 'neo-ai: saved workspace ID, retrying...\n' >&2
                    neo_ai_call_claude "${user_prompt}" "${system_prompt}" 0
                    return $?
                fi
            fi
        fi
    fi
    return "${rc}"
}
