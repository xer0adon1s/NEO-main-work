#!/usr/bin/env bash
# neo.sh — NEO mission conductor (MVP per CLAUDE-COLLAB.md section 11).
#
# Usage:
#   neo.sh <project> [target]
#   neo.sh <project> --from=<phase>
#   neo.sh                    # list projects (status.sh)

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
export NEO_HOME NEO_DIR
NEO_VERSION="$(cat "${NEO_HOME}/VERSION" 2>/dev/null | tr -d '[:space:]' || echo dev)"
PHASES_YAML="${NEO_DIR}/phases.yaml"
REGISTRY_YAML="${NEO_DIR}/registry.yaml"

case "${1:-}" in
    -V|--version) printf 'NEO v%s\n' "${NEO_VERSION}"; exit 0 ;;
esac

# shellcheck source=lib/neo-1.0-bootstrap.sh
source "${NEO_DIR}/lib/neo-1.0-bootstrap.sh"

NEO_LIB_SCRIPTS=(notes-lib.sh script-lib.sh neo-ai.sh neo-ai-analyze.sh neo-ai-cli.sh neo-splash.sh neo-hud.sh neo-vpn.sh neo-vpn-consent.sh neo-boot.sh neo-borg.sh neo-payload.sh neo-menu.sh neo-tmux.sh neo-interact.sh neo-core.sh neo-1.0-bootstrap.sh neo-secrets.sh neo-evidence.sh neo-actions.sh neo-mission-state.sh neo-scope.sh neo-provider.sh neo-windup-actions.sh neo-operator-pane.sh neo-handler-pane.sh neo-workbench.sh neo-toolkit.sh neo-exploit-framework.sh neo-pipeline-hooks.sh neo-eli5.sh neo-report.sh neo-conductor.sh neo-conductor-loop.sh neo-conductor-privesc.sh neo-enum-ai.sh neo-adaptive-scan.sh neo-operator-recon-ai.sh neo-feedback.sh)

neo_lib_hygiene_warn() {
    local extra=0 path rel base f skip
    [[ -d "${NEO_DIR}/lib" ]] || return 0
    while IFS= read -r -d '' path; do
        rel="${path#${NEO_DIR}/lib/}"
        base="$(basename "${path}")"
        skip=false
        if [[ "${rel}" == "${base}" ]]; then
            for f in "${NEO_LIB_SCRIPTS[@]}"; do
                [[ "${base}" == "${f}" ]] && skip=true && break
            done
        fi
        [[ "${skip}" == true ]] && continue
        extra=$((extra + 1))
        if (( extra == 1 )); then
            printf '\n  [!] lib/ contains non-NEO files (accidental /usr/lib copy?).\n' >&2
            printf '      Run: %s/tools/neo-lib-cleanup.sh\n\n' "${NEO_DIR}" >&2
        fi
        (( extra >= 3 )) && break
    done < <(find "${NEO_DIR}/lib" -mindepth 1 -print0 2>/dev/null || true)
}

neo_lib_hygiene_warn

# shellcheck source=lib/notes-lib.sh
source "${NEO_DIR}/lib/notes-lib.sh"
# shellcheck source=lib/neo-menu.sh
source "${NEO_DIR}/lib/neo-menu.sh"

PHASE_ORDER=(recon foothold privesc post)

# Mission state for checkpoint / interrupt handling
NEO_MISSION_PROJECT=""
NEO_MISSION_PHASE=""
NEO_MISSION_SCRIPT_IDX=0
NEO_JUMP_PHASE=""

usage() {
    cat <<EOF
Usage: neo.sh <project> [target]
       neo.sh <project> --from=<phase>
       neo.sh <project> [target] --fresh
       neo.sh <project> [target] --no-tmux
       neo.sh <project> --report
       neo.sh --version
       neo.sh

Walks phases in phases.yaml, calling scripts from registry.yaml.
When a prior session exists, NEO asks [R]esume or [F]resh start (interactive).
--fresh wipes projects/<name>/ entirely and restarts from step 1 (boot + recon).
--no-tmux skips auto-wrapping the mission in a tmux session (same as NEO_TMUX_WRAP=0).
--report generates a human-readable final report from Investigation-Notes and exits.
EOF
}

neo_print_version() {
    printf 'NEO v%s\n' "${NEO_VERSION}"
}

neo_print_manual_ai_mode() {
    local project="$1"
    cat <<EOF

Manual review mode — NEO will not run built-in AI analysis on this mission.

NEO still runs the full pipeline and pauses at each phase so you can review
findings as the case develops. Between pauses, work your live report with
whatever assistant you prefer — or review it yourself:

  ${NEO_HOME}/projects/${project}/Investigation-Notes.md

Ask your assistant for attack paths, gaps, and concrete next steps. Paste its
conclusions into the **AI Triage** section of Investigation-Notes.md so they
stay in the case file and you can refer back as the engagement progresses.

If Claude Code is installed, press **[a]sk Claude** at any pause to pipe your
notes into \`claude -p\` on demand (uses your Pro/Max login when configured).

Return here and continue when you are ready.

EOF
}

neo_print_subscription_mode() {
    local project="$1"
    cat <<EOF

Claude Pro/Max mode — NEO will pipe Investigation-Notes into Claude Code
(\`claude -p\`) after recon and whenever you choose **[a]sk Claude** at a pause.

This uses your Claude Code subscription login, not metered Console API credits.
Unset ANTHROPIC_API_KEY in your shell if you want subscription billing instead
of API credits.

Live case file:
  ${NEO_HOME}/projects/${project}/Investigation-Notes.md

EOF
}

neo_print_api_mode() {
    local project="$1"
    cat <<EOF

Claude API key mode — NEO will analyze Investigation-Notes via the Console API
after recon (metered credits; workspace ID may be required).

Press **[a]sk Claude** at any pause to run \`claude -p\` instead — useful if
Claude Code is installed with a Pro/Max subscription.

Live case file:
  ${NEO_HOME}/projects/${project}/Investigation-Notes.md

EOF
}

neo_load_ai_mode_from_meta() {
    local saved
    saved="$(meta_get ai_triage 2>/dev/null || true)"
    case "${saved}" in
        manual)
            NEO_AI_MODE=manual
            NEO_AI=0
            export NEO_AI NEO_AI_MODE
            return 0
            ;;
        subscription)
            NEO_AI_MODE=subscription
            NEO_AI=1
            export NEO_AI NEO_AI_MODE
            return 0
            ;;
        api|builtin)
            NEO_AI_MODE=api
            NEO_AI=1
            export NEO_AI NEO_AI_MODE
            return 0
            ;;
    esac
    return 1
}

neo_ai_mode_label() {
    case "${NEO_AI_MODE:-manual}" in
        subscription) echo 'Claude Pro/Max (claude -p)' ;;
        api)            echo 'Claude API key' ;;
        *)              echo 'manual — share Investigation-Notes.md with your assistant between pauses' ;;
    esac
}

neo_ask_claude_at_pause() {
    local project="$1" phase="$2"
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=lib/script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"
    # shellcheck source=lib/neo-ai-cli.sh
    source "${NEO_DIR}/lib/neo-ai-cli.sh"
    cybersec_init_colors
    printf '\n[*] Asking Claude Code to review Investigation-Notes...\n\n'
    neo_ai_cli_pause_review "${project}" "${phase}"
}

neo_assimilate_at_pause() {
    local project="$1" phase="$2"
    # shellcheck source=lib/neo-borg.sh
    source "${NEO_DIR}/lib/neo-borg.sh"
    neo_borg_at_pause "${project}" "${phase}"
}

neo_eli5_at_pause() {
    local project="$1" phase="$2"
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=lib/script-lib.sh
    source "${NEO_DIR}/lib/script-lib.sh"
    # shellcheck source=lib/neo-eli5.sh
    source "${NEO_DIR}/lib/neo-eli5.sh"
    cybersec_init_colors
    printf '\n[*] ELI5 — explain before you run…\n\n'
    neo_eli5_run "${project}" "${phase}" "" ""
}

neo_prompt_ai_mode() {
    local project="$1"

    if [[ "${NEO_AI:-1}" == "0" ]]; then
        NEO_AI_MODE=manual
        export NEO_AI_MODE
        return 0
    fi

    if neo_load_ai_mode_from_meta; then
        return 0
    fi

    # Interactive TTY, or piped stdin (smoke tests / automation with heredoc)
    if ! [[ -t 0 ]] && ! [[ -p /dev/stdin ]]; then
        return 0
    fi

    local choice ans
    cat <<'EOF'

How should NEO handle AI analysis for this mission?

  [A] Claude Pro/Max — Claude Code subscription (claude -p, no API key)
  [B] Claude API key — Console API / analyze-recon (metered credits)
  [C] Neither — I will review Investigation-Notes myself or with my own AI

EOF
    while true; do
        read -r -p 'Choice [A/B/C]: ' choice
        choice="$(tr '[:lower:]' '[:upper:]' <<< "${choice}")"
        case "${choice}" in
            A)
                if ! command -v claude >/dev/null 2>&1; then
                    printf '\nClaude Code (command: claude) not found on PATH.\n'
                    printf 'Install Claude Code, or choose B (API key) or C (manual).\n\n'
                    continue
                fi
                meta_set ai_triage subscription 2>/dev/null || true
                NEO_AI_MODE=subscription
                NEO_AI=1
                neo_print_subscription_mode "${project}"
                break
                ;;
            B)
                meta_set ai_triage api 2>/dev/null || true
                NEO_AI_MODE=api
                NEO_AI=1
                # shellcheck source=lib/neo-ai.sh
                source "${NEO_DIR}/lib/neo-ai.sh"
                if ! neo_ai_ensure_api_key; then
                    printf '\nNo API key configured.\n'
                    read -r -p 'Continue without built-in AI (manual review)? [Y/n] ' ans
                    if [[ "${ans}" =~ ^[Nn] ]]; then
                        continue
                    fi
                    meta_set ai_triage manual 2>/dev/null || true
                    NEO_AI_MODE=manual
                    NEO_AI=0
                    neo_print_manual_ai_mode "${project}"
                else
                    neo_print_api_mode "${project}"
                fi
                break
                ;;
            C)
                meta_set ai_triage manual 2>/dev/null || true
                NEO_AI_MODE=manual
                NEO_AI=0
                neo_print_manual_ai_mode "${project}"
                break
                ;;
            "")
                printf 'Enter A, B, or C.\n'
                ;;
            *)
                printf 'Enter A, B, or C.\n'
                ;;
        esac
    done
    export NEO_AI NEO_AI_MODE
}

neo_checkpoint_save() {
    local phase="$1" state="$2" script_idx="${3:-0}"
    meta_set neo_checkpoint "${phase}:${state}:${script_idx}" 2>/dev/null || true
    meta_set phase "${phase}" 2>/dev/null || true
}

neo_checkpoint_clear() {
    meta_set neo_checkpoint "" 2>/dev/null || true
}

neo_session_has_prior() {
    local outdir="$1"
    local mf="${outdir}/project.meta" notes="${outdir}/Investigation-Notes.md"
    local cp phase last_script ports_body

    [[ -f "${mf}" ]] || return 1

    cp="$(grep '^neo_checkpoint=' "${mf}" 2>/dev/null | cut -d= -f2- | head -n1 | tr -d '[:space:]')"
    [[ -n "${cp}" ]] && return 0

    phase="$(grep '^phase=' "${mf}" 2>/dev/null | cut -d= -f2- | head -n1)"
    [[ -n "${phase}" && "${phase}" != "recon" ]] && return 0

    last_script="$(grep '^last_script=' "${mf}" 2>/dev/null | cut -d= -f2- | head -n1 | tr -d '[:space:]')"
    [[ -n "${last_script}" ]] && return 0

    [[ -f "${notes}" ]] || return 1
    if [[ "$(wc -c < "${notes}" | tr -d '[:space:]')" -gt 4500 ]]; then
        return 0
    fi
    NOTES_FILE="${notes}"
    ports_body="$(notes_get_section PORTS 2>/dev/null || true)"
    [[ -n "${ports_body}" ]] && [[ "${ports_body}" != *"_No ports"* ]] && return 0

    return 1
}

neo_session_describe() {
    local project="$1" outdir="$2"
    local mf="${outdir}/project.meta" target phase last cp state idx scripts
    target="$(grep '^target=' "${mf}" 2>/dev/null | cut -d= -f2- | head -n1)"
    phase="$(grep '^phase=' "${mf}" 2>/dev/null | cut -d= -f2- | head -n1)"
    last="$(grep '^last_script=' "${mf}" 2>/dev/null | cut -d= -f2- | head -n1)"
    cp="$(grep '^neo_checkpoint=' "${mf}" 2>/dev/null | cut -d= -f2- | head -n1)"

    printf '  project:      %s\n' "${project}"
    printf '  target:       %s\n' "${target:-unknown}"
    printf '  phase:        %s\n' "${phase:-recon}"
    [[ -n "${last}" ]] && printf '  last script:  %s\n' "${last}"

    if neo_checkpoint_parse "${cp}"; then
        case "${NEO_CP_STATE}" in
            menu)
                printf '  checkpoint:   paused at %s menu\n' "${NEO_CP_PHASE}"
                ;;
            running)
                mapfile -t scripts < <(neo_filter_phase_scripts "${NEO_CP_PHASE}")
                if ((${#scripts[@]} > 0)) && (( NEO_CP_IDX < ${#scripts[@]} )); then
                    printf '  checkpoint:   mid-%s — next script: %s (%d/%d)\n' \
                        "${NEO_CP_PHASE}" "${scripts[NEO_CP_IDX]}" "$((NEO_CP_IDX + 1))" "${#scripts[@]}"
                else
                    printf '  checkpoint:   mid-%s (script index %s)\n' "${NEO_CP_PHASE}" "${NEO_CP_IDX}"
                fi
                ;;
            before)
                printf '  checkpoint:   start of %s\n' "${NEO_CP_PHASE}"
                ;;
        esac
    fi
}

neo_session_fresh_start() {
    local project="$1" target="$2" outdir="$3"
    local saved_target="${target}"

    NOTES_FILE="${outdir}/Investigation-Notes.md"
    if [[ -z "${saved_target}" || "${saved_target}" == "unknown" ]]; then
        saved_target="$(meta_get target 2>/dev/null || echo unknown)"
    fi

    printf '\n[*] Fresh start — deleting all data in projects/%s/ and restarting from step 1.\n\n' "${project}"

    rm -rf "${outdir}"
    mkdir -p "${outdir}"

    notes_init "${project}" "${saved_target:-unknown}" "${outdir}" 2>/dev/null || true

    OUTDIR="${outdir}"
    NOTES_FILE="${outdir}/Investigation-Notes.md"
    MF="${outdir}/project.meta"

    START_PHASE="recon"
    unset NEO_AI_MODE NEO_AI
    NEO_FORCE_BOOT=1
    NO_SPLASH=0
}

neo_session_prompt_resume_or_fresh() {
    local project="$1" target="$2" outdir="$3"
    local ans

    [[ -t 0 ]] || return 0
    [[ "${NEO_SESSION_PROMPT:-1}" == "0" ]] && return 0

    neo_session_has_prior "${outdir}" || return 0

    printf '\n'
    printf '╔══════════════════════════════════════════════════════════════╗\n'
    printf '║  Previous session found                                      ║\n'
    printf '╚══════════════════════════════════════════════════════════════╝\n'
    neo_session_describe "${project}" "${outdir}"
    printf '\n'
    printf '  [R] Resume where you left off\n'
    printf '  [F] Fresh start — wipe projects/%s/ entirely, then step 1 (boot, AI mode, VPN, babysteps)\n' "${project}"
    printf '\n'

    while true; do
        read -r -p 'Resume or fresh start? [R/f]: ' ans
        ans="$(tr '[:upper:]' '[:lower:]' <<< "${ans:-r}")"
        case "${ans}" in
            r|resume|'')
                printf '\n[*] Resuming previous session.\n\n'
                return 0
                ;;
            f|fresh)
                neo_session_fresh_start "${project}" "${target}" "${outdir}"
                return 0
                ;;
            *)
                printf 'Enter R to resume or F for fresh start.\n'
                ;;
        esac
    done
}

neo_checkpoint_parse() {
    local cp="${1:-}"
    NEO_CP_PHASE=""
    NEO_CP_STATE=""
    NEO_CP_IDX=0
    [[ -n "${cp}" ]] || return 1
    IFS=':' read -r NEO_CP_PHASE NEO_CP_STATE NEO_CP_IDX <<< "${cp}"
    NEO_CP_IDX="${NEO_CP_IDX:-0}"
    [[ -n "${NEO_CP_PHASE}" && -n "${NEO_CP_STATE}" ]] || return 1
    return 0
}

neo_pause_mission() {
    local phase="$1" project="$2" state="${3:-menu}" script_idx="${4:-0}"
    neo_checkpoint_save "${phase}" "${state}" "${script_idx}"
    printf '\nPaused at %s. Resume anytime: neo.sh %s\n' "${phase}" "${project}"
    exit 0
}

neo_trap_interrupt() {
    local phase="${NEO_MISSION_PHASE:-recon}"
    local idx="${NEO_MISSION_SCRIPT_IDX:-0}"
    printf '\nneo: interrupted — saving checkpoint at %s.\n' "${phase}"
    neo_checkpoint_save "${phase}" "running" "${idx}"
    printf 'Resume: neo.sh %s\n' "${NEO_MISSION_PROJECT}"
    exit 130
}

neo_show_step_menu() {
    local current="${1:-}"
    local i
    printf '\nMission steps:\n'
    for i in "${!PHASE_ORDER[@]}"; do
        if [[ "${PHASE_ORDER[$i]}" == "${current}" ]]; then
            printf '  %d) %s  ← current\n' "$((i + 1))" "${PHASE_ORDER[$i]}"
        else
            printf '  %d) %s\n' "$((i + 1))" "${PHASE_ORDER[$i]}"
        fi
    done
}

neo_skip_to_step() {
    local project="$1" current="$2"
    local pick target
    neo_show_step_menu "${current}"
    read -r -p "Jump to step [1-${#PHASE_ORDER[@]}], or Enter to cancel: " pick
    [[ -n "${pick}" ]] || return 1
    [[ "${pick}" =~ ^[0-9]+$ ]] || return 1
    (( pick >= 1 && pick <= ${#PHASE_ORDER[@]} )) || return 1
    target="${PHASE_ORDER[$((pick - 1))]}"
    [[ "${target}" != "${current}" ]] || return 1
    meta_set phase "${target}" 2>/dev/null || true
    neo_checkpoint_save "${target}" "before" "0"
    NEO_JUMP_PHASE="${target}"
    printf '\nJumping to %s.\n\n' "${target}"
    return 0
}

neo_splash_enabled() {
    [[ "${NEO_SPLASH:-1}" != "0" && "${NO_SPLASH:-0}" != "1" ]]
}

# Whether the boot SEQUENCE (AI mode re-prompt, VPN ritual) runs at all. --fresh
# (NEO_FORCE_BOOT=1) always forces this, since a wiped project has no state to fall
# back on — but it does NOT override an explicit NEO_SPLASH=0/--no-splash opt-out of
# the purely decorative rabbit intro; see the call site, which checks
# neo_splash_enabled separately before running that specific animation.
neo_boot_should_run() {
    [[ -t 1 && "${START_PHASE}" == "recon" ]] || return 1
    if [[ "${NEO_FORCE_BOOT:-0}" == "1" ]]; then
        neo_load_ai_mode_from_meta && return 1
        return 0
    fi
    neo_splash_enabled || return 1
    neo_load_ai_mode_from_meta && return 1
    return 0
}

registry_val() {
    local key="$1" field="$2"
    awk -v k="${key}:" -v f="${field}:" '
        $0 == k { found=1; next }
        found && /^[a-zA-Z0-9_-]+:/ { exit }
        found && index($0, "  " f) == 1 {
            sub(/^  [^:]+:[[:space:]]*/, "")
            print
            exit
        }
    ' "${REGISTRY_YAML}"
}

phase_val() {
    local phase="$1" field="$2"
    awk -v p="${phase}:" -v f="${field}:" '
        $0 == p { found=1; next }
        found && /^[a-z]+:/ { exit }
        found && index($0, "  " f) == 1 {
            sub(/^  [^:]+:[[:space:]]*/, "")
            gsub(/^>[[:space:]]-?[[:space:]]*/, "")
            print
            exit
        }
    ' "${PHASES_YAML}"
}

phase_bool() {
    local v
    v="$(phase_val "$1" "$2")"
    [[ "${v}" == "true" ]]
}

phase_scripts_raw() {
    local phase="$1" line
    line="$(awk -v p="${phase}:" '$0==p{found=1;next} found && /^  scripts:/{print; exit}' "${PHASES_YAML}")"
    line="${line#*scripts: [}"
    line="${line%]}"
    line="${line// /}"
    if [[ -z "${line}" ]]; then return 0; fi
    IFS=',' read -ra SCRIPTS <<< "${line}"
    printf '%s\n' "${SCRIPTS[@]}"
}

neo_filter_phase_scripts() {
    local phase="$1"
    local script
    while IFS= read -r script; do
        [[ -n "${script}" ]] || continue
        if [[ "${NEO_AI_MODE:-}" == "manual" || "${NEO_AI:-1}" == "0" ]] && [[ "${script}" == "analyze-recon" ]]; then
            continue
        fi
        printf '%s\n' "${script}"
    done < <(phase_scripts_raw "${phase}")
}

phase_index() {
    local want="$1" i
    for i in "${!PHASE_ORDER[@]}"; do
        [[ "${PHASE_ORDER[$i]}" == "${want}" ]] && { echo "${i}"; return 0; }
    done
    return 1
}

next_phase_name() {
    local cur="$1" idx n
    idx="$(phase_index "${cur}")" || return 1
    n=$((idx + 1))
    [[ "${n}" -lt "${#PHASE_ORDER[@]}" ]] || return 1
    echo "${PHASE_ORDER[$n]}"
}

resolve_ssh_target() {
    local project="$1"
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    meta_init "${project}" "unknown" "${OUTDIR}" 2>/dev/null || true
    local cached
    cached="$(meta_get ssh_target 2>/dev/null || true)"
    if [[ -n "${cached}" ]]; then
        echo "${cached}"
        return 0
    fi
    local t
    read -r -p "SSH target (user@host): " t
    [[ -n "${t}" ]] || return 1
    read -r -p "Save to project.meta as ssh_target? [Y/n] " ans
    if [[ ! "${ans}" =~ ^[Nn] ]]; then
        meta_set ssh_target "${t}" || true
    fi
    echo "${t}"
}

neo_scope_ensure() {
    local project="$1" target="$2"
    local scope_file="${NEO_STATE_ROOT}/projects/${project}/engagement-scope.json"
    if [[ -f "${scope_file}" ]]; then
        neo_scope_sync_project_meta "${project}" 2>/dev/null || true
        return 0
    fi
    [[ -t 0 ]] || {
        printf '[!] No engagement scope — run: ./tools/scope-intake.sh --project %s\n' "${project}" >&2
        return 0
    }
    printf '\n[*] Engagement scope required (NEO 1.0).\n\n'
    bash "${NEO_DIR}/tools/scope-intake.sh" --project "${project}" --target "${target}" || return 1
    neo_scope_sync_project_meta "${project}" 2>/dev/null || true
    return 0
}

neo_mission_bootstrap() {
    local project="$1" target="$2"
    neo_mission_init "${project}" "${target}" "${NEO_STATE_ROOT}/projects" 2>/dev/null || true
    neo_evidence_init "${project}" "${NEO_STATE_ROOT}/projects" 2>/dev/null || true
}

resolve_target_ip() {
    local project="$1" cli_target="${2:-}"

    if [[ -n "${cli_target}" ]]; then
        echo "${cli_target}"
        return 0
    fi

    OUTDIR="${NEO_HOME}/projects/${project}"
    MF="${OUTDIR}/project.meta"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"

    if [[ -f "${MF}" ]]; then
        local cached
        cached="$(grep '^target=' "${MF}" 2>/dev/null | cut -d= -f2- | head -n1)"
        if [[ -n "${cached}" && "${cached}" != "unknown" ]]; then
            echo "${cached}"
            return 0
        fi
    fi

    local t
    read -r -p "Target IP or hostname: " t
    [[ -n "${t}" ]] || return 1
    meta_init "${project}" "${t}" "${OUTDIR}" 2>/dev/null || true
    read -r -p "Save to project.meta as target? [Y/n] " ans
    if [[ ! "${ans}" =~ ^[Nn] ]]; then
        meta_set target "${t}" 2>/dev/null || true
    fi
    echo "${t}"
}

run_script() {
    local script_key="$1" project="$2" target_ip="${3:-}"
    local relpath ssh_t

    relpath="$(registry_val "${script_key}" "file")"
    [[ -n "${relpath}" ]] || { echo "neo: no registry entry for ${script_key}" >&2; return 1; }

    local script_path="${NEO_DIR}/${relpath}"

    case "${script_key}" in
        babysteps)
            local mode_flag="--speed"
            [[ "${NEO_DEEP_RECON:-0}" == "1" ]] && mode_flag="--deep"
            if [[ -n "${target_ip}" ]]; then
                bash "${script_path}" "${target_ip}" --project="${project}" --reuse "${mode_flag}"
            else
                bash "${script_path}" --project="${project}" --reuse "${mode_flag}"
            fi
            ;;
        analyze-recon)
            bash "${script_path}" --project="${project}"
            ;;
        ListenAssist)
            bash "${script_path}" --project="${project}" --target="${target_ip}" --port=4444
            # A first foothold attempt happened regardless of whether it succeeded —
            # that's exactly when Analyze Failures becomes useful, so flip its
            # visibility gate here rather than only from the Suggest flow (an operator
            # who runs ListenAssist, fails, and never touches Suggest must still see
            # [z] analyze failures at the next pause).
            meta_set foothold_attempted 1 2>/dev/null || true
            ;;
        run-findprivs|run-linpeas|run-linenum)
            ssh_t="$(resolve_ssh_target "${project}")" || return 1
            bash "${script_path}" "${project}" "${ssh_t}"
            ;;
        *)
            bash "${script_path}" "${project}"
            ;;
    esac
}

neo_run_scripts_sequence() {
    local phase="$1" project="$2" target_ip="${3:-}" start_idx="${4:-0}"
    local scripts script_key i
    mapfile -t scripts < <(neo_filter_phase_scripts "${phase}")

    for (( i=start_idx; i<${#scripts[@]}; i++ )); do
        script_key="${scripts[$i]}"
        NEO_MISSION_SCRIPT_IDX="${i}"
        neo_checkpoint_save "${phase}" "running" "${i}"
        run_script "${script_key}" "${project}" "${target_ip}" || return 3
    done
    neo_checkpoint_save "${phase}" "menu" "0"
    return 0
}

neo_run_deep_recon() {
    local project="$1" target_ip="$2"
    local saved="${NEO_DEEP_RECON:-0}"
    printf '\n[*] Starting deep enum scan (full timeouts)...\n\n'
    NEO_DEEP_RECON=1
    run_script "babysteps" "${project}" "${target_ip}" || { NEO_DEEP_RECON="${saved}"; return 1; }
    if [[ "${NEO_AI_MODE:-manual}" != "manual" && "${NEO_AI:-1}" != "0" ]]; then
        run_script "analyze-recon" "${project}" "${target_ip}" || true
    fi
    meta_set scan_mode deep 2>/dev/null || true
    NEO_DEEP_RECON="${saved}"
    neo_checkpoint_save "recon" "menu" "0"
    return 0
}

# Shared by both menus (post-phase [c/r/...] and pause_before script-choice) so their
# [a]sk-Claude / [b]org-assimilate / payload wiring can't drift out of sync — each menu
# used to build this independently and only the post-phase one offered ask/assimilate.
# Sets globals NEO_PAUSE_HAS_CLAUDE, NEO_PAUSE_HAS_BORG, NEO_PAUSE_EXTRA.
#
# Every letter below means exactly one thing regardless of case (a/A, b/B, p/P, s/S, z/Z
# all fold to the same action) — deliberately, after a/A (ask vs Assimilate) and s/S (skip
# vs Suggest payload) used to mean *different* things, which made a stray Shift or
# caps-lock risk triggering the wrong action.
neo_compute_pause_extras() {
    local phase="$1" project="${2:-${PROJECT_NAME:-}}"
    # shellcheck source=lib/neo-menu.sh
    source "${NEO_DIR}/lib/neo-menu.sh"
    neo_menu_compose_pause_extras "${phase}" "${project}"
}

neo_pause_action_begin() {
    # shellcheck source=lib/neo-menu.sh
    source "${NEO_DIR}/lib/neo-menu.sh" 2>/dev/null || true
    neo_menu_feedback_ack "$@"
}

neo_pause_action_end() {
    local rc="${2:-0}"
    # shellcheck source=lib/neo-menu.sh
    source "${NEO_DIR}/lib/neo-menu.sh" 2>/dev/null || true
    neo_menu_feedback_done "${1}" "${rc}"
}

neo_post_phase_menu() {
    local phase="$1" project="$2" target_ip="${3:-}" ran="${4:-false}"
    local prompt choice menu_extra=""

    # shellcheck source=lib/neo-menu.sh
    source "${NEO_DIR}/lib/neo-menu.sh"
    source "${NEO_DIR}/lib/neo-conductor.sh" 2>/dev/null || true
    if declare -F neo_conductor_on_pause_entry >/dev/null 2>&1; then
        neo_conductor_on_pause_entry "${project}" "${phase}" || true
    fi

    if [[ "${phase}" == "recon" && -n "${target_ip}" ]]; then
        # shellcheck source=lib/neo-pipeline-hooks.sh
        source "${NEO_DIR}/lib/neo-pipeline-hooks.sh"
        neo_pipeline_offer_plan_enum "${project}" "${target_ip}" || true
    fi

    neo_compute_pause_extras "${phase}" "${project}"
    menu_extra="${NEO_PAUSE_EXTRA}"

    if phase_bool "${phase}" "pause_after"; then
        prompt="$(phase_val "${phase}" "prompt_after")"
        [[ -n "${prompt}" ]] && printf '\n%s\n' "${prompt}"
    fi

    while true; do
        if [[ "${phase}" == "recon" ]]; then
            read -r -p "$(neo_menu_primary_prompt recon)${menu_extra}: " choice
        else
            read -r -p "$(neo_menu_primary_prompt "${phase}")${menu_extra}: " choice
        fi
        choice="${choice:-c}"
        case "$(neo_menu_classify "${choice}")" in
            continue)
                neo_checkpoint_clear
                return 0
                ;;
            ask-claude)
                if ${NEO_PAUSE_HAS_CLAUDE}; then
                    neo_pause_action_begin ask-claude
                    neo_ask_claude_at_pause "${project}" "${phase}" || true
                    neo_pause_action_end ask-claude $?
                    continue
                fi
                printf 'Claude Code not on PATH — install it or use API key mode for [b] Borg research.\n'
                ;;
            assimilate)
                if ${NEO_PAUSE_HAS_BORG}; then
                    neo_pause_action_begin assimilate
                    neo_assimilate_at_pause "${project}" "${phase}" || true
                    neo_pause_action_end assimilate $?
                    continue
                fi
                printf 'BORG needs Claude Code or ANTHROPIC_API_KEY.\n'
                ;;
            payload-suggest|analyze-failures)
                neo_pause_action_begin "$(neo_menu_classify "${choice}")"
                if neo_payload_handle_choice "${choice}" "${project}" "${phase}"; then
                    neo_pause_action_end "$(neo_menu_classify "${choice}")" 0
                    continue
                fi
                neo_pause_action_end "$(neo_menu_classify "${choice}")" 1
                printf 'Payload tools need Claude Code or ANTHROPIC_API_KEY.\n'
                ;;
            try-command|open-operator)
                neo_pause_action_begin "$(neo_menu_classify "${choice}")"
                if neo_workbench_handle_choice "${choice}" "${project}" "${phase}"; then
                    neo_pause_action_end "$(neo_menu_classify "${choice}")" 0
                    continue
                fi
                neo_pause_action_end "$(neo_menu_classify "${choice}")" 1
                printf 'Workbench unavailable for this phase.\n'
                ;;
            eli5)
                if ${NEO_PAUSE_HAS_ELI5:-false}; then
                    neo_pause_action_begin eli5
                    neo_eli5_at_pause "${project}" "${phase}" || true
                    neo_pause_action_end eli5 $?
                    continue
                fi
                printf 'ELI5 needs Claude Code (claude) or ANTHROPIC_API_KEY.\n'
                ;;
            final-report)
                if ${NEO_PAUSE_HAS_REPORT:-false}; then
                    neo_pause_action_begin final-report
                    neo_report_at_pause "${project}" "${phase}" || true
                    neo_pause_action_end final-report $?
                    continue
                fi
                printf 'Final report needs Claude Code or ANTHROPIC_API_KEY (post phase only).\n'
                ;;
            deep-enum)
                if [[ "${phase}" == "recon" ]]; then
                    neo_pause_action_begin deep-enum
                    neo_run_deep_recon "${project}" "${target_ip}"; r=$?
                    neo_pause_action_end deep-enum "${r}"
                    (( r == 3 )) && return 3
                    continue
                fi
                ;;
            repeat)
                neo_checkpoint_save "${phase}" "before" "0"
                walk_phase "${phase}" "${project}" "${target_ip}"
                return $?
                ;;
            skip-to-step)
                if neo_skip_to_step "${project}" "${phase}"; then
                    return 2
                fi
                ;;
            quit)
                neo_pause_mission "${phase}" "${project}" "menu" "0"
                ;;
        esac
    done
}

walk_phase() {
    local phase="$1" project="$2" target_ip="${3:-}"
    local scripts choice_type choice i script_key prompt ran=false
    local cp resume_idx=0 resume_at_menu=false

    NEO_MISSION_PHASE="${phase}"
    if neo_mission_open "${project}" 2>/dev/null; then
        neo_mission_sync_pipeline_phase "${phase}" || true
        # shellcheck source=lib/neo-conductor.sh
        source "${NEO_DIR}/lib/neo-conductor.sh" 2>/dev/null || true
        if declare -F neo_conductor_mission_state_hook >/dev/null 2>&1; then
            neo_conductor_mission_state_hook "${project}" "${phase}" || true
        fi
        if declare -F neo_conductor_on_phase_entry >/dev/null 2>&1; then
            neo_conductor_on_phase_entry "${project}" "${phase}" || true
        fi
    fi

    if neo_checkpoint_parse "$(meta_get neo_checkpoint 2>/dev/null || true)"; then
        if [[ "${NEO_CP_PHASE}" == "${phase}" ]]; then
            case "${NEO_CP_STATE}" in
                menu) resume_at_menu=true ;;
                running) resume_idx="${NEO_CP_IDX}" ;;
                before) resume_idx=0 ;;
            esac
        fi
    fi

    mapfile -t scripts < <(neo_filter_phase_scripts "${phase}")
    choice_type="$(phase_val "${phase}" "choice")"

    if [[ "${resume_at_menu}" == true ]]; then
        neo_post_phase_menu "${phase}" "${project}" "${target_ip}" "true"
        return $?
    fi

    if [[ "${phase}" == "post" ]]; then
        prompt="$(phase_val "${phase}" "prompt_before")"
        [[ -n "${prompt}" ]] && printf '\n%s\n\n' "${prompt}"
        # shellcheck source=lib/neo-pipeline-hooks.sh
        source "${NEO_DIR}/lib/neo-pipeline-hooks.sh"
        neo_pipeline_offer_msf_post "${project}" || true
        neo_post_phase_menu "${phase}" "${project}" "${target_ip}" "false"
        return $?
    fi

    if phase_bool "${phase}" "pause_before"; then
        prompt="$(phase_val "${phase}" "prompt_before")"
        [[ -n "${prompt}" ]] && printf '\n%s\n\n' "${prompt}"

        if [[ "${phase}" == "privesc" ]]; then
            # shellcheck source=lib/neo-pipeline-hooks.sh
            source "${NEO_DIR}/lib/neo-pipeline-hooks.sh"
            neo_pipeline_offer_privesc_rank "${project}" || true
        fi

        if [[ "${#scripts[@]}" -eq 0 || -z "${scripts[0]:-}" ]]; then
            : # post phase — no scripts
        else
            neo_compute_pause_extras "${phase}" "${project}"
            while true; do
                for i in "${!scripts[@]}"; do
                    printf '  %d) %s\n' "$((i + 1))" "${scripts[$i]}"
                done
                read -r -p "Choose script, [k] skip phase, [s] skip to step${NEO_PAUSE_EXTRA}, or [q]uit: " choice
                choice="${choice:-1}"
                case "$(neo_menu_classify "${choice}")" in
                    quit)
                        neo_pause_mission "${phase}" "${project}" "before" "0"
                        ;;
                    skip-phase)
                        neo_checkpoint_clear
                        return 0
                        ;;
                    skip-to-step)
                        if neo_skip_to_step "${project}" "${phase}"; then
                            return 2
                        fi
                        ;;
                    ask-claude)
                        if ${NEO_PAUSE_HAS_CLAUDE}; then
                            neo_pause_action_begin ask-claude
                            neo_ask_claude_at_pause "${project}" "${phase}" || true
                            neo_pause_action_end ask-claude $?
                        else
                            printf 'Claude Code not on PATH — install it or use API key mode for [b] Borg research.\n'
                        fi
                        continue
                        ;;
                    assimilate)
                        if ${NEO_PAUSE_HAS_BORG}; then
                            neo_pause_action_begin assimilate
                            neo_assimilate_at_pause "${project}" "${phase}" || true
                            neo_pause_action_end assimilate $?
                        else
                            printf 'BORG needs Claude Code or ANTHROPIC_API_KEY.\n'
                        fi
                        continue
                        ;;
                    payload-suggest|analyze-failures)
                        neo_pause_action_begin "$(neo_menu_classify "${choice}")"
                        if neo_payload_handle_choice "${choice}" "${project}" "${phase}"; then
                            neo_pause_action_end "$(neo_menu_classify "${choice}")" 0
                        else
                            neo_pause_action_end "$(neo_menu_classify "${choice}")" 1
                            printf 'Payload tools need Claude Code or ANTHROPIC_API_KEY.\n'
                        fi
                        continue
                        ;;
                    try-command|open-operator)
                        neo_pause_action_begin "$(neo_menu_classify "${choice}")"
                        if neo_workbench_handle_choice "${choice}" "${project}" "${phase}"; then
                            neo_pause_action_end "$(neo_menu_classify "${choice}")" 0
                        else
                            neo_pause_action_end "$(neo_menu_classify "${choice}")" 1
                            printf 'Workbench unavailable for this phase.\n'
                        fi
                        continue
                        ;;
                    eli5)
                        if ${NEO_PAUSE_HAS_ELI5:-false}; then
                            neo_pause_action_begin eli5
                            neo_eli5_at_pause "${project}" "${phase}" || true
                            neo_pause_action_end eli5 $?
                        else
                            printf 'ELI5 needs Claude Code (claude) or ANTHROPIC_API_KEY.\n'
                        fi
                        continue
                        ;;
                    final-report)
                        if ${NEO_PAUSE_HAS_REPORT:-false}; then
                            neo_pause_action_begin final-report
                            neo_report_at_pause "${project}" "${phase}" || true
                            neo_pause_action_end final-report $?
                        else
                            printf 'Final report needs Claude Code or ANTHROPIC_API_KEY (post phase only).\n'
                        fi
                        continue
                        ;;
                    *)
                        if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#scripts[@]} )); then
                            script_key="${scripts[$((choice - 1))]}"
                            NEO_MISSION_SCRIPT_IDX="$((choice - 1))"
                        else
                            script_key="${scripts[0]}"
                            NEO_MISSION_SCRIPT_IDX=0
                        fi
                        neo_pause_action_begin run-script "script: ${script_key}"
                        neo_checkpoint_save "${phase}" "running" "${NEO_MISSION_SCRIPT_IDX}"
                        run_script "${script_key}" "${project}" "${target_ip}"; r=$?
                        neo_pause_action_end run-script "${r}"
                        (( r != 0 )) && return 3
                        ran=true
                        neo_checkpoint_save "${phase}" "menu" "0"
                        break
                        ;;
                esac
            done
        fi
    elif [[ -n "${scripts[0]:-}" ]]; then
        if [[ "${choice_type}" == "all" ]]; then
            neo_run_scripts_sequence "${phase}" "${project}" "${target_ip}" "${resume_idx}" || return 3
            ran=true
        else
            script_key="${scripts[0]}"
            NEO_MISSION_SCRIPT_IDX=0
            neo_checkpoint_save "${phase}" "running" "0"
            run_script "${script_key}" "${project}" "${target_ip}" || return 3
            ran=true
            neo_checkpoint_save "${phase}" "menu" "0"
        fi
    fi

    if [[ "${ran}" == true ]] || phase_bool "${phase}" "pause_after" || [[ "${#scripts[@]}" -gt 0 ]]; then
        if [[ "${ran}" == true && "${phase}" == "privesc" ]]; then
            # shellcheck source=lib/neo-conductor-loop.sh
            source "${NEO_DIR}/lib/neo-conductor-loop.sh" 2>/dev/null || true
            if declare -F neo_conductor_on_event >/dev/null 2>&1; then
                neo_conductor_on_event privesc.ingest_complete "${project}" privesc || true
            fi
        fi
        neo_post_phase_menu "${phase}" "${project}" "${target_ip}" "${ran}"
        return $?
    fi

    neo_checkpoint_clear
    return 0
}

# --- main ---

PROJECT=""
TARGET=""
FROM_PHASE=""
NO_SPLASH=0
NEO_DEEP_RECON=0
NEO_FRESH=0
NEO_FORCE_BOOT=0

if [[ $# -eq 0 ]]; then
    exec bash "${NEO_DIR}/tools/status.sh"
fi

NEO_ORIGINAL_ARGS=("$@")

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -V|--version) neo_print_version; exit 0 ;;
        --from=*) FROM_PHASE="${1#*=}"; shift ;;
        --from) FROM_PHASE="${2:-}"; shift 2 ;;
        --no-splash) NO_SPLASH=1; shift ;;
        --no-tmux) NEO_TMUX_WRAP=0; shift ;;
        --deep-recon) NEO_DEEP_RECON=1; shift ;;
        --fresh) NEO_FRESH=1; shift ;;
        --report) NEO_REPORT_ONLY=1; shift ;;
        *)
            if [[ -z "${PROJECT}" ]]; then PROJECT="$1"
            elif [[ -z "${TARGET}" ]]; then TARGET="$1"
            fi
            shift
            ;;
    esac
done

[[ -n "${PROJECT}" ]] || { usage; exit 1; }

cybersec_validate_project_name() {
    [[ "${1}" != */* && "${1}" != "." && "${1}" != ".." && -n "${1}" ]]
}
cybersec_validate_project_name "${PROJECT}" || { echo "Invalid project name." >&2; exit 1; }

# shellcheck source=lib/neo-tmux.sh
source "${NEO_DIR}/lib/neo-tmux.sh"
neo_tmux_wrap_if_needed "${PROJECT}" "$0" "${NEO_ORIGINAL_ARGS[@]}"
# neo_tmux_wrap_if_needed only returns (rather than exec-replacing this process) when
# wrapping isn't appropriate right now (already in own mission session, non-interactive,
# opted out, no tmux installed) — execution falls through to the normal unwrapped mission below.

OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
MF="${OUTDIR}/project.meta"
mkdir -p "${OUTDIR}"
meta_init "${PROJECT}" "${TARGET:-unknown}" "${OUTDIR}" 2>/dev/null || true

NEO_MISSION_PROJECT="${PROJECT}"
trap neo_trap_interrupt INT TERM

if [[ "${NEO_REPORT_ONLY:-0}" == "1" ]]; then
    # shellcheck source=lib/neo-report.sh
    source "${NEO_DIR}/lib/neo-report.sh"
    neo_report_generate "${PROJECT}" || exit 1
    exit 0
fi

START_PHASE="recon"
if [[ -n "${FROM_PHASE}" ]]; then
    START_PHASE="${FROM_PHASE}"
    neo_checkpoint_save "${FROM_PHASE}" "before" "0"
elif [[ -f "${MF}" ]]; then
    START_PHASE="$(grep '^phase=' "${MF}" | cut -d= -f2- | head -n1)"
    [[ -n "${START_PHASE}" ]] || START_PHASE="recon"
fi

phase_index "${START_PHASE}" >/dev/null || { echo "Unknown phase: ${START_PHASE}" >&2; exit 1; }

if [[ "${NEO_FRESH}" == "1" ]]; then
    neo_session_fresh_start "${PROJECT}" "${TARGET:-unknown}" "${OUTDIR}"
elif [[ -z "${FROM_PHASE}" ]]; then
    neo_session_prompt_resume_or_fresh "${PROJECT}" "${TARGET:-unknown}" "${OUTDIR}"
fi

NEO_BOOT_SEQUENCE=false
if neo_boot_should_run; then
    NEO_BOOT_SEQUENCE=true
    # shellcheck source=lib/neo-boot.sh
    source "${NEO_DIR}/lib/neo-boot.sh"
    # The rabbit intro is pure decoration (~7s of matrix rain + typed quotes, no state
    # collected) — --fresh forces the boot SEQUENCE (AI mode + VPN ritual still need to
    # run), but it must not force this past an explicit NEO_SPLASH=0/--no-splash opt-out.
    neo_splash_enabled && neo_boot_rabbit_intro
fi

if ! neo_load_ai_mode_from_meta; then
    if [[ "${START_PHASE}" == "recon" ]]; then
        neo_prompt_ai_mode "${PROJECT}"
    fi
fi
if [[ "${NEO_AI_MODE:-}" == "manual" || "${NEO_AI:-1}" == "0" ]]; then
    meta_set ai_triage manual 2>/dev/null || true
    NEO_AI_MODE=manual
    export NEO_AI_MODE
fi

if ${NEO_BOOT_SEQUENCE}; then
    export NEO_BOOT_VPN_RITUAL=1
    neo_boot_ai_confirmed
    TARGET="$(neo_boot_vpn_flow "${PROJECT}" "${TARGET}")" || {
        echo "neo: VPN / target setup failed." >&2
        exit 1
    }
else
    # shellcheck source=lib/neo-boot.sh
    source "${NEO_DIR}/lib/neo-boot.sh"
    TARGET="$(resolve_target_ip "${PROJECT}" "${TARGET}")" || {
        echo "neo: target IP required." >&2
        exit 1
    }
    export NEO_BOOT_VPN_RITUAL=0
    neo_boot_vpn_flow "${PROJECT}" "${TARGET}" || true
fi

meta_init "${PROJECT}" "${TARGET}" "${OUTDIR}" 2>/dev/null || true
if ${NEO_BOOT_SEQUENCE}; then
    meta_set target "${TARGET}" 2>/dev/null || true
fi

neo_scope_ensure "${PROJECT}" "${TARGET}" || exit 1
neo_mission_bootstrap "${PROJECT}" "${TARGET}"

if ${NEO_BOOT_SEQUENCE}; then
    # shellcheck source=lib/neo-splash.sh
    source "${NEO_DIR}/lib/neo-splash.sh"
    neo_splash_mission_line "${PROJECT}" "${TARGET}"
    neo_splash_hold
fi

printf '\nNEO mission: %s\n' "${PROJECT}"
printf 'Target: %s\n' "${TARGET}"
printf 'Starting at phase: %s\n' "${START_PHASE}"
printf 'AI analysis: %s\n' "$(neo_ai_mode_label)"
printf '\n'

idx="$(phase_index "${START_PHASE}")"
while (( idx < ${#PHASE_ORDER[@]} )); do
    phase="${PHASE_ORDER[$idx]}"
    NEO_MISSION_PHASE="${phase}"
    walk_phase "${phase}" "${PROJECT}" "${TARGET}" || rc=$?
    rc=${rc:-0}
    if (( rc == 2 )); then
        idx="$(phase_index "${NEO_JUMP_PHASE}")" || exit 1
        rc=0
        continue
    fi
    if (( rc == 3 )); then
        echo "neo: script failed in phase ${phase} — mission unchanged." >&2
        exit 1
    fi
    if (( rc == 1 )); then exit 0; fi

    next="$(next_phase_name "${phase}" 2>/dev/null)" || {
        printf '\nMission complete. Review projects/%s/Investigation-Notes.md\n' "${PROJECT}"
        # shellcheck source=lib/neo-report.sh
        source "${NEO_DIR}/lib/neo-report.sh"
        neo_report_offer_mission_complete "${PROJECT}" || true
        neo_checkpoint_clear
        meta_set phase post 2>/dev/null || true
        exit 0
    }

    # Pre-foothold check-in: recon → foothold specifically, once, right before the
    # handoff — see lib/neo-interact.sh for why this is a general framework and not
    # just a web-server special case.
    if [[ "${phase}" == "recon" && "${next}" == "foothold" ]]; then
        # shellcheck source=lib/neo-interact.sh
        source "${NEO_DIR}/lib/neo-interact.sh"
        neo_interact_pause_before_foothold "${PROJECT}" || true
        # shellcheck source=lib/neo-pipeline-hooks.sh
        source "${NEO_DIR}/lib/neo-pipeline-hooks.sh"
        neo_pipeline_offer_operator_recon "${PROJECT}" || true
    fi

    meta_set phase "${next}" 2>/dev/null || true
    neo_checkpoint_save "${next}" "before" "0"
    idx=$((idx + 1))
done

printf '\nMission complete.\n'
