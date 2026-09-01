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
    local prompt="$1" default="${2:-y}" ans
    neo_conductor_skip_interactive && return 1
    read -r -p "${prompt} [Y/n]: " ans
    case "${ans}" in
        n|N) return 1 ;;
        *) return 0 ;;
    esac
}

neo_conductor_resolve_mode() {
    local project="$1" mode engagement
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
    local target status ports triage bundle
# shellcheck source=notes-lib.sh
source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || return 1
    # shellcheck source=neo-ai.sh
    source "${NEO_LIB_DIR}/neo-ai.sh" 2>/dev/null || true
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    target="$(meta_get target 2>/dev/null || echo unknown)"
    status="$(notes_get_section STATUS 2>/dev/null | neo_ai_strip_ansi 2>/dev/null || true)"
    ports="$(notes_get_section PORTS 2>/dev/null | neo_ai_strip_ansi 2>/dev/null || true)"
    triage="$(notes_get_section AI-TRIAGE 2>/dev/null | neo_ai_strip_ansi 2>/dev/null || true)"
    bundle="$(cat <<EOF
# Mission bundle (conductor core)
Project: ${project}
Target: ${target}
Phase: ${phase}

## STATUS
${status:-_none_}

## PORTS
${ports:-_none_}

## AI-TRIAGE
${triage:-_none_}
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
    local _project="$1" _phase="$2"
    neo_conductor_skip_interactive && return 0
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
    local _project="$1"
    neo_conductor_skip_interactive && return 0
    return 0
}
