#!/usr/bin/env bash
# neo-conductor.sh — unified mission bundle + conductor gates (Tier A prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=notes-lib.sh
source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || true

neo_conductor_skip_interactive() {
    [[ "${NEO_TEST_NONINTERACTIVE:-0}" == "1" || "${NEO_CONDUCTOR:-1}" == "0" || ! -t 0 ]]
}

neo_conductor_ai_available() {
    [[ "${NEO_AI:-1}" != "0" && "${NEO_AI:-1}" != "manual" ]]
}

neo_conductor_prompt_yn() {
    local prompt="$1" default="${2:-y}" ans hint=""
    neo_conductor_skip_interactive && return 1
    case "${default}" in
        n|N) hint='[y/N]' ;;
        *) hint='[Y/n]' ;;
    esac
    read -r -p "${prompt} ${hint} " ans
    case "${default}" in
        n|N)
            case "${ans}" in
                y|Y) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        *)
            case "${ans}" in
                n|N) return 1 ;;
                *) return 0 ;;
            esac
            ;;
    esac
}

neo_conductor_resolve_mode() {
    local project="$1" mode engagement
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || true
    mode="$(meta_get conductor_mode 2>/dev/null || true)"
    [[ -n "${mode}" ]] && {
        case "${mode}" in
            assisted|aggressive) printf 'assisted'; return 0 ;;
            guided) printf 'guided'; return 0 ;;
        esac
    }
    case "${NEO_CONDUCTOR_MODE:-}" in
        assisted|aggressive) printf 'assisted'; return 0 ;;
    esac
    engagement="$(meta_get engagement_mode 2>/dev/null || true)"
    [[ "${engagement}" == professional ]] && { printf 'assisted'; return 0; }
    printf 'guided'
}

neo_conductor_loop_default_max() {
    printf '5'
}

neo_conductor_mission_core_bundle() {
    local project="$1" phase="$2"
    local target status ports services triage borg payload mission_file mission_excerpt bundle
    # shellcheck source=notes-lib.sh
    source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || return 1
    # shellcheck source=neo-ai.sh
    source "${NEO_LIB_DIR}/neo-ai.sh" 2>/dev/null || true
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    target="$(meta_get target 2>/dev/null || echo unknown)"
    status="$(notes_get_section STATUS 2>/dev/null | neo_ai_strip_ansi 2>/dev/null || true)"
    ports="$(notes_get_section PORTS 2>/dev/null | neo_ai_strip_ansi 2>/dev/null || true)"
    services="$(notes_get_section SERVICES 2>/dev/null | neo_ai_strip_ansi 2>/dev/null || true)"
    triage="$(neo_ai_notes_section_trim AI-TRIAGE 6000 2>/dev/null || true)"
    borg="$(neo_ai_notes_section_trim BORG 3000 2>/dev/null || true)"
    payload="$(neo_ai_notes_section_trim PAYLOAD 3000 2>/dev/null || true)"
    mission_file="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}/projects/${project}/mission.json"
    mission_excerpt="_none_"
    if [[ -f "${mission_file}" ]]; then
        mission_excerpt="$(head -c 2000 "${mission_file}" 2>/dev/null || true)"
    fi
    bundle="$(cat <<EOF
# Mission bundle (conductor core)
Project: ${project}
Target: ${target}
Phase: ${phase}

## STATUS
${status:-_none_}

## PORTS
${ports:-_none_}

## SERVICES
${services:-_none_}

## AI-TRIAGE
${triage:-_none_}

## BORG (recent)
${borg:-_none_}

## PAYLOAD (recent)
${payload:-_none_}

## mission.json (excerpt)
${mission_excerpt}
EOF
)"
    printf '%s' "${bundle}"
}

neo_conductor_build_bundle() {
    local project="$1" phase="$2" intent="${3:-triage}" extra="${4:-}"
    local core bundle whoami sudo
    core="$(neo_conductor_mission_core_bundle "${project}" "${phase}")" || return 1
    case "${intent}" in
        triage)
            bundle="${core}"$'\n\n'"## What babysteps already attempted
- Fast TCP port sweep; service/version scan on discovered ports
- HTTP probe, SMB/FTP checks when ports open

## Prior AI triage (from Investigation-Notes)
$(notes_get_section AI-TRIAGE 2>/dev/null || echo _none_)"
            ;;
        payload)
            bundle="${core}"$'\n\n'"## Payload assistant context
Suggest the exact next command for authorized lab work.
Tool hint: ${extra:-general}"
            ;;
        borg|workbench|report|eli5|ask|msf-suggest)
            bundle="${core}"$'\n\n'"## Intent: ${intent}"
            ;;
        analyze-failures-batch)
            bundle="${core}"$'\n\n'"## Analyze failures batch (mission bundle)
Review failed foothold attempts and suggest next steps."
            ;;
        privesc-triage)
            whoami="$(notes_get_section WHOAMI 2>/dev/null || true)"
            sudo="$(notes_get_section SUDO 2>/dev/null || true)"
            bundle="${core}"$'\n\n'"## Privesc triage (mission bundle)
## WHOAMI
${whoami:-_none_}

## SUDO
${sudo:-_none_}"
            ;;
        *)
            bundle="${core}"$'\n\n'"## Intent: ${intent}"
            ;;
    esac
    if ((${#bundle} > ${NEO_AI_BUNDLE_MAX:-28000})); then
        bundle="${bundle:0:${NEO_AI_BUNDLE_MAX:-28000}}"
    fi
    printf '%s' "${bundle}"
}

neo_conductor_on_phase_entry() {
    local project="$1" phase="$2" key pending=0
    neo_conductor_skip_interactive && return 0
    neo_conductor_ai_available || return 0
    [[ "${NEO_CONDUCTOR:-1}" == "0" ]] && return 0

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || true
    key="conductor_phase_entry_${phase}"
    [[ "$(meta_get "${key}" 2>/dev/null || true)" == "1" ]] && return 0
    meta_set "${key}" 1 2>/dev/null || true

    case "${phase}" in
        foothold)
            # shellcheck source=neo-borg.sh
            source "${NEO_LIB_DIR}/neo-borg.sh" 2>/dev/null || true
            if declare -F neo_borg_pending_count >/dev/null 2>&1; then
                pending="$(neo_borg_pending_count "${project}" 2>/dev/null || echo 0)"
            fi
            if (( pending > 0 )) && declare -F neo_borg_ai_available >/dev/null 2>&1 && neo_borg_ai_available 2>/dev/null; then
                if neo_conductor_prompt_yn "Assimilate ${pending} pending vector lead(s) with Borg?" y; then
                    # shellcheck source=script-lib.sh
                    source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || true
                    cybersec_init_colors 2>/dev/null || true
                    if declare -F neo_borg_run >/dev/null 2>&1; then
                        neo_borg_run "${project}" "${phase}" "" || true
                    fi
                fi
            fi
            if neo_conductor_prompt_yn '[p] Payload suggestion for foothold?' y; then
                # shellcheck source=neo-payload.sh
                source "${NEO_LIB_DIR}/neo-payload.sh" 2>/dev/null || true
                if declare -F neo_payload_suggest_at_pause >/dev/null 2>&1; then
                    neo_payload_suggest_at_pause "${project}" "${phase}" || true
                fi
            fi
            ;;
        privesc)
            if neo_conductor_prompt_yn '[p] Privesc-focused payload suggestion?' y; then
                # shellcheck source=neo-payload.sh
                source "${NEO_LIB_DIR}/neo-payload.sh" 2>/dev/null || true
                if declare -F neo_payload_suggest_at_pause >/dev/null 2>&1; then
                    neo_payload_suggest_at_pause "${project}" "${phase}" || true
                fi
            fi
            ;;
        post)
            printf '[*] Post phase — press [f] to write the final report.\n'
            ;;
    esac
    return 0
}

neo_conductor_on_pause_entry() {
    local _project="$1" _phase="$2"
    return 0
}

neo_conductor_mission_state_hook() {
    local _project="$1" _phase="$2"
    return 0
}

neo_conductor_after_triage() {
    local project="$1" phase="${2:-recon}" pending=0
    neo_conductor_skip_interactive && return 0
    neo_conductor_ai_available || return 0
    [[ "${NEO_CONDUCTOR:-1}" == "0" ]] && return 0

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=script-lib.sh
    source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || true
    if [[ "$(meta_get conductor_after_triage_done 2>/dev/null || true)" == "1" ]]; then
        return 0
    fi
    meta_set conductor_after_triage_done 1 2>/dev/null || true

    # shellcheck source=neo-borg.sh
    source "${NEO_LIB_DIR}/neo-borg.sh" 2>/dev/null || true
    if declare -F neo_borg_pending_count >/dev/null 2>&1; then
        pending="$(neo_borg_pending_count "${project}" 2>/dev/null || echo 0)"
    fi

    if (( pending > 0 )) && neo_borg_ai_available 2>/dev/null; then
        if neo_conductor_prompt_yn "Assimilate ${pending} pending vector lead(s) with Borg?" y; then
            # shellcheck source=script-lib.sh
            source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || true
            cybersec_init_colors 2>/dev/null || true
            if declare -F neo_borg_run >/dev/null 2>&1; then
                neo_borg_run "${project}" "${phase}" "" || true
            fi
        fi
    fi

    if neo_conductor_prompt_yn '[p] Payload suggestion after triage?' n; then
        # shellcheck source=neo-payload.sh
        source "${NEO_LIB_DIR}/neo-payload.sh" 2>/dev/null || true
        if declare -F neo_payload_suggest_at_pause >/dev/null 2>&1; then
            neo_payload_suggest_at_pause "${project}" "${phase}" || true
        fi
    fi

    # shellcheck source=neo-adaptive-scan.sh
    source "${NEO_LIB_DIR}/neo-adaptive-scan.sh" 2>/dev/null || true
    if declare -F neo_adaptive_scan_offer_after_triage >/dev/null 2>&1; then
        neo_adaptive_scan_offer_after_triage "${project}" || true
    fi

    # shellcheck source=neo-conductor-loop.sh
    source "${NEO_LIB_DIR}/neo-conductor-loop.sh" 2>/dev/null || true
    if declare -F neo_conductor_on_event >/dev/null 2>&1; then
        neo_conductor_on_event recon.triage_complete "${project}" "${phase}" || true
    fi

    return 0
}
