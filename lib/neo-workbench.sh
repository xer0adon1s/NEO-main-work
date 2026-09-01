#!/usr/bin/env bash
# neo-workbench.sh — suggest → try (with permission) → capture → analyze loop (P20).
#
# Core NEO 1.0 operator loop: enum produces leads, AI/Borg suggest commands, operator
# approves execution in a dedicated tmux pane (or safe local argv), output is interpreted
# by AI, repeat until foothold — then mission state advances.

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-core.sh
source "${NEO_LIB_DIR}/neo-core.sh"
# shellcheck source=neo-operator-pane.sh
source "${NEO_LIB_DIR}/neo-operator-pane.sh"
# shellcheck source=neo-windup-actions.sh
source "${NEO_LIB_DIR}/neo-windup-actions.sh"

NEO_WORKBENCH_LAST_ATTEMPT_ID=""

neo_workbench_state_dir() {
    local project="$1"
    printf '%s/projects/%s/workbench' "${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}" "${project}"
}

neo_workbench_attempts_dir() {
    printf '%s/attempts' "$(neo_workbench_state_dir "$1")"
}

neo_workbench_session_file() {
    printf '%s/session.json' "$(neo_workbench_state_dir "$1")"
}

neo_workbench_visible_phase() {
    local phase="$1"
    case "${phase}" in
        recon|foothold|privesc|post) return 0 ;;
        *) return 1 ;;
    esac
}

neo_workbench_has_attempts() {
    local project="$1" dir
    dir="$(neo_workbench_attempts_dir "${project}")"
    [[ -d "${dir}" ]] || return 1
    compgen -G "${dir}/*.json" >/dev/null 2>&1
}

neo_workbench_menu_fragment() {
    local phase="$1" project="${2:-}" frag=""
    neo_workbench_visible_phase "${phase}" || return 0
    frag="${frag} / [t]ry it / [o]perator pane"
    printf '%s' "${frag}"
}

neo_workbench_init_colors() {
    # shellcheck source=neo-hud.sh
    source "${NEO_DIR}/lib/neo-hud.sh" 2>/dev/null || true
}

# Extract the most recent fenced command from notes sections (PAYLOAD, WORKBENCH, AI-TRIAGE).
neo_workbench_extract_last_command() {
    local project="$1" notes cmd
    notes="${NEO_HOME:-${NEO_DIR}}/projects/${project}/Investigation-Notes.md"
    [[ -f "${notes}" ]] || return 1
    cmd="$(awk '
        function flush_exact() {
            if (exact_buf != "") { print exact_buf; exact_buf=""; exit }
        }
        function flush_last() {
            if (last_buf != "") { print last_buf; exit }
        }
        /^<!-- SECTION:(PAYLOAD|WORKBENCH|AI-TRIAGE|BORG) -->/ { in_sec=1; next }
        /^<!-- \/SECTION:/ { in_sec=0; in_exact=0; next }
        !in_sec { next }
        /^## Exact next command/ { in_exact=1; exact_buf=""; next }
        in_exact && /^## / { flush_exact(); in_exact=0 }
        /^```/ {
            if (!open) { open=1; buf=""; next }
            open=0
            if (in_exact) { exact_buf=buf; flush_exact() }
            last_buf=buf
            next
        }
        open { buf=(buf=="" ? $0 : buf "\n" $0) }
        END { flush_exact(); flush_last() }
    ' "${notes}")"
    [[ -n "${cmd}" ]] || return 1
    printf '%s' "${cmd}"
}

# local_safe | operator_pane | manual_only
neo_workbench_classify_transport() {
    local cmd="$1"
    [[ "${cmd}" == *$'\n'* ]] && { printf 'operator_pane'; return 0; }
    if neo_windup_command_rejected "${cmd}"; then
        printf 'operator_pane'
    else
        printf 'local_safe'
    fi
}

neo_workbench_new_attempt_id() {
    printf 'wb-%s-%s' "$(date +%s)" "$$"
}

neo_workbench_save_attempt_json() {
    local project="$1" id="$2" phase="$3" source="$4" cmd="$5" transport="$6" artifact="$7" rc="${8:-}" outcome="${9:-pending}"
    local dir file tmp jq_rc
    neo_core_need jq || return 1
    dir="$(neo_workbench_attempts_dir "${project}")"
    neo_core_secure_dir "${dir}"
    file="${dir}/${id}.json"
    tmp="$(neo_core_secure_tmp "${dir}" .attempt)" || return 1
    if [[ "${rc}" =~ ^[0-9]+$ ]]; then
        jq_rc="${rc}"
    else
        jq_rc=null
    fi
    jq -n \
        --arg id "${id}" --arg at "$(neo_core_iso_timestamp)" --arg phase "${phase}" \
        --arg source "${source}" --arg command "${cmd}" --arg transport "${transport}" \
        --arg artifact "${artifact:-}" --arg outcome "${outcome}" \
        --argjson exit_code "${jq_rc}" \
        '{schema_version:1,id:$id,at:$at,phase:$phase,source:$source,command:$command,transport:$transport,artifact:(if $artifact=="" then null else $artifact end),exit_code:$exit_code,outcome:$outcome,ai_analysis_ref:null}' \
        > "${tmp}"
    mv -f -- "${tmp}" "${file}"
    chmod 600 -- "${file}"
    NEO_WORKBENCH_LAST_ATTEMPT_ID="${id}"
    printf '%s' "${file}"
}

neo_workbench_append_notes() {
    local project="$1" heading="$2" body="$3"
    local existing placeholder=false doc
    OUTDIR="${NEO_HOME:-${NEO_DIR}}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"
    doc="$(cat <<EOF
### ${heading} — $(date '+%Y-%m-%d %H:%M:%S')

${body}
EOF
)"
    existing="$(notes_get_section WORKBENCH 2>/dev/null || true)"
    if [[ -z "${existing}" ]] || [[ "${existing}" == *"_No workbench"* ]]; then
        notes_set_section WORKBENCH "${doc}" || return 1
    else
        notes_append_section WORKBENCH "$(printf '\n\n---\n\n%s' "${doc}")" || return 1
    fi
}

neo_workbench_mark_foothold_attempted() {
    meta_set foothold_attempted 1 2>/dev/null || true
}

neo_workbench_mission_on_try() {
    local project="$1" phase="$2" state
    [[ "${phase}" == "foothold" ]] || return 0
    # shellcheck source=neo-mission-state.sh
    source "${NEO_LIB_DIR}/neo-mission-state.sh"
    neo_mission_init "${project}" "$(meta_get target 2>/dev/null || echo unknown)" 2>/dev/null || true
    [[ -f "${NEO_MISSION_FILE:-}" ]] || return 0
    state="$(neo_mission_current_state 2>/dev/null || true)"
    if [[ "${state}" == foothold_planning ]]; then
        neo_mission_transition foothold_attempt 'operator started workbench try' 2>/dev/null || true
    fi
}

neo_workbench_confirm_yes() {
    local prompt="$1" ans
    read -r -p "${prompt} [y/N]: " ans
    [[ "${ans}" =~ ^[yY] ]]
}

# Tier B conductor loop: try last suggested command; assisted skips execute/analyze Y/n.
neo_workbench_try_loop_step() {
    local project="$1" phase="$2" assisted="${3:-false}"
    local cmd transport id artifact_dir artifact_path output rc outcome tk_ans auto_analyze=false

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"

    neo_workbench_init_colors
    cmd="$(neo_workbench_extract_last_command "${project}" 2>/dev/null || true)"
    [[ -n "${cmd}" ]] || {
        printf 'No ## Exact next command in notes — skipping try.\n'
        return 1
    }
    transport="$(neo_workbench_classify_transport "${cmd}")"

    # shellcheck source=neo-toolkit.sh
    source "${NEO_LIB_DIR}/neo-toolkit.sh"
    if [[ "${assisted}" != true ]]; then
        if ! neo_workbench_confirm_yes 'Send to operator pane and run?'; then
            return 1
        fi
        read -r -p 'Verify tools & wordlists for this command before trying? [Y/n]: ' tk_ans
        case "${tk_ans}" in
            n|N) ;;
            *) neo_toolkit_preflight_command "${cmd}" "${project}" 1 || true ;;
        esac
    else
        # shellcheck source=neo-feedback.sh
        source "${NEO_LIB_DIR}/neo-feedback.sh" 2>/dev/null || true
        declare -F neo_feedback_ack_action >/dev/null 2>&1 && neo_feedback_ack_action try-command
        neo_toolkit_preflight_command "${cmd}" "${project}" 0 || true
        auto_analyze=true
    fi

    printf '\nCommand:\n  %s\nTransport: %s\n' "${cmd}" "${transport}"
    if [[ "${transport}" == operator_pane ]]; then
        neo_workbench_confirm_yes 'Confirm send to operator pane (live target session)?' || return 1
    fi
    if [[ "${assisted}" != true && "${transport}" == local_safe ]]; then
        neo_workbench_confirm_yes 'Second confirm (runs on attack box via argv)' || return 1
    fi

    artifact_dir="${NEO_HOME}/projects/${project}/artifacts"
    mkdir -p "${artifact_dir}"
    artifact_path="${artifact_dir}/workbench-$(date +%Y%m%d-%H%M%S).txt"
    id="$(neo_workbench_new_attempt_id)"
    rc=0
    outcome=pending

    case "${transport}" in
        local_safe)
            if output="$(neo_windup_execute_safe "${cmd}" "workbench-${id}" "${project}" 2>&1)"; then
                rc=0; outcome=success
            else
                rc=$?; outcome=failure
            fi
            printf '%s' "${output}" > "${artifact_path}"
            ;;
        operator_pane)
            if ! neo_operator_pane_send_command "${cmd}"; then
                printf 'Could not send to operator pane.\n' >&2
                return 1
            fi
            printf '%s[*]%s Command sent to operator pane — watch the right-hand pane.\n' "${C_CYAN:-}" "${C_RESET:-}"
            read -r -p 'Press Enter when the command has finished (output will be captured)…' _
            output="$(neo_operator_pane_capture "${NEO_WORKBENCH_CAPTURE_LINES:-300}" 2>/dev/null || true)"
            if [[ -z "${output}" ]]; then
                output="_operator pane capture empty_"
                outcome=unknown
            else
                outcome=partial
            fi
            printf '%s' "${output}" > "${artifact_path}"
            rc=0
            ;;
        *)
            printf 'Manual transport — copy yourself:\n  %s\n' "${cmd}"
            artifact_path=""
            outcome=manual
            ;;
    esac

    neo_workbench_save_attempt_json "${project}" "${id}" "${phase}" "conductor-loop" "${cmd}" \
        "${transport}" "${artifact_path}" "${rc}" "${outcome}"
    neo_workbench_append_notes "${project}" "Try (${id})" "$(cat <<EOF
- **Command:** \`${cmd}\`
- **Transport:** ${transport}
- **Outcome:** ${outcome}
- **Artifact:** ${artifact_path:-none}
EOF
)"
    neo_workbench_mark_foothold_attempted
    neo_workbench_mission_on_try "${project}" "${phase}"

    cybersec_finish "workbench-try" "${phase}" \
        "Workbench try recorded (${id})" \
        "=== workbench-try (loop) ===\nid: ${id}\ncmd: ${cmd}\n"

    if [[ -n "${artifact_path}" && -f "${artifact_path}" ]]; then
        if [[ "${auto_analyze}" == true ]]; then
            declare -F neo_feedback_ack_action >/dev/null 2>&1 && neo_feedback_ack_action analyze-output
            neo_workbench_analyze_last "${project}" "${phase}" "${id}" || \
                printf 'Analysis failed.\n'
        elif neo_workbench_confirm_yes 'Analyze captured output now'; then
            neo_workbench_analyze_last "${project}" "${phase}" "${id}" || \
                printf 'Analysis failed.\n'
        fi
    fi
    return 0
}

neo_workbench_prompt_command() {
    local project="$1" cmd
    cmd="$(neo_workbench_extract_last_command "${project}" 2>/dev/null || true)"
    if [[ -n "${cmd}" ]]; then
        printf 'Last suggested command:\n```\n%s\n```\n' "${cmd}"
        if neo_workbench_confirm_yes 'Use this command?'; then
            printf '%s' "${cmd}"
            return 0
        fi
    fi
    printf 'Paste command to try (single line preferred; finish with Enter on empty line):\n' >&2
    read -r cmd
    [[ -n "${cmd}" ]] || return 1
    printf '%s' "${cmd}"
}

neo_workbench_analyze_output_system_prompt() {
    cat <<'EOF'
You interpret command output from an authorized HTB/THM lab engagement. The operator ran
a suggested command with permission; your job is to read the actual output and say what
happened and what to try next.

Use exactly these sections:

## Outcome
success | partial | failure | inconclusive — one word plus one sentence why.

## What the output shows
Evidence-based reading — quote the specific lines that matter.

## Exact next command
ONE ready-to-copy-paste command in a single fenced code block, or _manual step_ if no
command applies (browser, listener setup, etc.).

## Foothold check
If this output indicates initial access (shell, creds, upload, RCE), say FOOTHOLD_LIKELY
on its own line. Otherwise say NOT_YET.

## Caveats
Misreads, missing context, or scan-data injection concerns.
EOF
}

neo_workbench_call_ai() {
    local bundle="$1" sys="$2"
    # shellcheck source=neo-payload.sh
    source "${NEO_DIR}/lib/neo-payload.sh"
    neo_payload_call_ai "${bundle}" "${sys}"
}

neo_workbench_build_analyze_bundle() {
    local project="$1" phase="$2" cmd="$3" output="$4" transport="$5"
    local mission_excerpt=""
    # shellcheck source=neo-conductor.sh
    source "${NEO_DIR}/lib/neo-conductor.sh" 2>/dev/null || true
    # shellcheck source=neo-payload.sh
    source "${NEO_DIR}/lib/neo-payload.sh"
    if declare -F neo_conductor_build_bundle >/dev/null 2>&1; then
        mission_excerpt="$(neo_conductor_build_bundle "${project}" "${phase}" workbench 2>/dev/null | head -c 12000)"
    else
        mission_excerpt="$(neo_payload_build_bundle "${project}" "${phase}" "workbench" 2>/dev/null | head -c 12000)"
    fi
    cat <<EOF
# Workbench output analysis — phase ${phase}

## Command tried
\`\`\`
${cmd}
\`\`\`

## Transport
${transport}

## Captured output
\`\`\`text
${output}
\`\`\`

## Mission context (excerpt)
${mission_excerpt}
EOF
}

neo_workbench_analyze_last() {
    local project="$1" phase="$2" id="$3" attempt_file cmd output transport bundle response ts
    attempt_file="$(neo_workbench_attempts_dir "${project}")/${id}.json"
    [[ -f "${attempt_file}" ]] || return 1
    neo_core_need jq || return 1
    cmd="$(jq -r '.command' "${attempt_file}")"
    output="$(jq -r '.artifact // empty' "${attempt_file}")"
    transport="$(jq -r '.transport' "${attempt_file}")"
    if [[ -n "${output}" && -f "${output}" ]]; then
        output="$(cat "${output}")"
    else
        output="_no artifact saved_"
    fi
    bundle="$(neo_workbench_build_analyze_bundle "${project}" "${phase}" "${cmd}" "${output}" "${transport}")"
    if ! response="$(neo_workbench_call_ai "${bundle}" "$(neo_workbench_analyze_output_system_prompt)")"; then
        return 1
    fi
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    neo_workbench_append_notes "${project}" "Analyze output (${id})" "${response}"
    # shellcheck source=neo-payload.sh
    source "${NEO_DIR}/lib/neo-payload.sh"
    neo_payload_save_section "Workbench analyze (${id})" "${response}"
    neo_payload_print_brief "${response}" "WORKBENCH ANALYZE — TERMINAL BRIEF"
    # shellcheck source=neo-toolkit.sh
    source "${NEO_LIB_DIR}/neo-toolkit.sh"
    neo_toolkit_offer_after_suggest "${response}" "${project}"
    if grep -q 'FOOTHOLD_LIKELY' <<< "${response}"; then
        neo_workbench_offer_foothold_confirm "${project}" "${phase}" "${response}"
    fi
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"
    cybersec_finish "workbench-analyze" "${phase}" \
        "Workbench analysis saved → **Operator Workbench** + **Payload suggestions**" \
        "=== workbench-analyze ${ts} (${id}) ===\n${response}"
    # shellcheck source=neo-eli5.sh
    source "${NEO_LIB_DIR}/neo-eli5.sh" 2>/dev/null || true
    declare -F neo_eli5_offer_after >/dev/null 2>&1 && neo_eli5_offer_after "${project}" "${phase}" "${cmd}" || true
}

neo_workbench_offer_foothold_confirm() {
    local project="$1" phase="$2" analysis="$3"
    [[ "${phase}" == "foothold" ]] || return 0
    printf '\n%s[!]%s Analysis suggests initial access may be working.\n' "${C_YELLOW:-}" "${C_RESET:-}"
    if ! neo_workbench_confirm_yes 'Record foothold and advance mission state?'; then
        return 0
    fi
    # shellcheck source=neo-mission-state.sh
    source "${NEO_LIB_DIR}/neo-mission-state.sh"
    if [[ -f "${NEO_MISSION_FILE:-}" ]] && [[ "$(neo_mission_current_state 2>/dev/null)" == foothold_attempt ]]; then
        neo_mission_transition session_established 'workbench analysis + operator confirm' 2>/dev/null || true
    fi
    # shellcheck source=neo-operator-pane.sh
    source "${NEO_LIB_DIR}/neo-operator-pane.sh"
    if hint="$(neo_operator_pane_ssh_hint "${project}" 2>/dev/null || true)" && [[ "${hint}" == ssh* ]]; then
        user="${hint#ssh }"
        host="${user#*@}"
        user="${user%%@*}"
        [[ -n "${user}" && -n "${host}" ]] && \
            neo_mission_record_session ssh "${user}" "${host}" bash 2>/dev/null || true
    fi
    OUTDIR="${NEO_HOME:-${NEO_DIR}}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"
    notes_append_section FOOTHOLD "$(printf 'Recorded via workbench loop at %s\n\n%s' "$(date '+%Y-%m-%d %H:%M:%S')" "${analysis}")" 2>/dev/null || true
    neo_operator_pane_offer_session_connect "${project}" || true
    printf 'Foothold recorded — continue pipeline with [c]ontinue.\n'
}

neo_workbench_try_at_pause() {
    local project="$1" phase="$2"
    local cmd transport id artifact_dir artifact_path output rc outcome confirm_again tk_ans

    OUTDIR="${NEO_HOME:-${NEO_DIR}}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"

    neo_workbench_init_colors
    printf '\n%s[*]%s Workbench — try suggested command\n\n' "${C_CYAN:-}" "${C_RESET:-}"

    cmd="$(neo_workbench_prompt_command "${project}")" || {
        printf 'No command — cancelled.\n'
        return 0
    }
    transport="$(neo_workbench_classify_transport "${cmd}")"

    # shellcheck source=neo-toolkit.sh
    source "${NEO_LIB_DIR}/neo-toolkit.sh"
    if [[ -t 0 ]]; then
        read -r -p 'Verify tools & wordlists for this command before trying? [Y/n]: ' tk_ans
        case "${tk_ans}" in
            n|N) ;;
            *) neo_toolkit_preflight_command "${cmd}" "${project}" 1 || true ;;
        esac
    fi

    printf '\nCommand:\n  %s\nTransport: %s\n' "${cmd}" "${transport}"
    neo_workbench_confirm_yes 'Execute with your permission' || {
        printf 'Cancelled.\n'
        return 0
    }
    if [[ "${transport}" == local_safe ]]; then
        neo_workbench_confirm_yes 'Second confirm (runs on attack box via argv, no shell)' || {
            printf 'Cancelled.\n'
            return 0
        }
    fi

    artifact_dir="${NEO_HOME}/projects/${project}/artifacts"
    mkdir -p "${artifact_dir}"
    artifact_path="${artifact_dir}/workbench-$(date +%Y%m%d-%H%M%S).txt"
    id="$(neo_workbench_new_attempt_id)"
    rc=0
    outcome=pending

    case "${transport}" in
        local_safe)
            if output="$(neo_windup_execute_safe "${cmd}" "workbench-${id}" "${project}" 2>&1)"; then
                rc=0
                outcome=success
            else
                rc=$?
                outcome=failure
            fi
            printf '%s' "${output}" > "${artifact_path}"
            ;;
        operator_pane)
            if ! neo_operator_pane_send_command "${cmd}"; then
                printf 'Could not send to operator pane.\n' >&2
                return 1
            fi
            printf '%s[*]%s Command sent to operator pane — watch the right-hand pane.\n' "${C_CYAN:-}" "${C_RESET:-}"
            read -r -p 'Press Enter when the command has finished (output will be captured)…' _
            output="$(neo_operator_pane_capture "${NEO_WORKBENCH_CAPTURE_LINES:-300}" 2>/dev/null || true)"
            if [[ -z "${output}" ]]; then
                output="_operator pane capture empty — run [o]perator shell first or check tmux._"
                outcome=unknown
            else
                outcome=partial
            fi
            printf '%s' "${output}" > "${artifact_path}"
            rc=0
            ;;
        *)
            printf 'Manual only — copy command yourself:\n  %s\n' "${cmd}"
            artifact_path=""
            outcome=manual
            ;;
    esac

    neo_workbench_save_attempt_json "${project}" "${id}" "${phase}" "workbench" "${cmd}" \
        "${transport}" "${artifact_path}" "${rc}" "${outcome}"
    neo_workbench_append_notes "${project}" "Try (${id})" "$(cat <<EOF
- **Command:** \`${cmd}\`
- **Transport:** ${transport}
- **Outcome:** ${outcome}
- **Artifact:** ${artifact_path:-none}
EOF
)"
    neo_workbench_mark_foothold_attempted
    neo_workbench_mission_on_try "${project}" "${phase}"

    # shellcheck source=script-lib.sh
    cybersec_finish "workbench-try" "${phase}" \
        "Workbench try recorded (${id})" \
        "=== workbench-try ===\nid: ${id}\ncmd: ${cmd}\ntransport: ${transport}\nartifact: ${artifact_path}\n"

    if [[ -n "${artifact_path}" && -f "${artifact_path}" ]]; then
        if neo_workbench_confirm_yes 'Analyze captured output now'; then
            neo_workbench_analyze_last "${project}" "${phase}" "${id}" || \
                printf 'Analysis failed — use [z] analyze failures later.\n'
        fi
    fi
}

neo_workbench_open_at_pause() {
    local project="$1"
    neo_workbench_init_colors
    neo_operator_pane_open_shell "${project}"
}

neo_workbench_handle_choice() {
    local choice="$1" project="$2" phase="$3"
    case "${choice}" in
        t|T)
            neo_workbench_visible_phase "${phase}" || return 1
            neo_workbench_try_at_pause "${project}" "${phase}"
            return 0
            ;;
        o|O)
            neo_workbench_visible_phase "${phase}" || return 1
            neo_workbench_open_at_pause "${project}"
            return 0
            ;;
    esac
    return 1
}
