#!/usr/bin/env bash
# script-lib.sh — shared bootstrap for local NEO pipeline scripts.

NEO_HOME="${NEO_HOME:-${CYBERSEC:-${HOME}/Neo}}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
PROJECTS="${NEO_HOME}/projects"

# shellcheck source=notes-lib.sh
source "${NEO_DIR}/lib/notes-lib.sh"

cybersec_validate_project_name() {
    local name="$1"
    if [[ "${name}" == */* || "${name}" == "." || "${name}" == ".." || -z "${name}" ]]; then
        echo "Invalid project name: ${name}" >&2
        return 1
    fi
}

cybersec_need() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            echo "Missing required tool: ${cmd}" >&2
            return 1
        fi
    done
}

cybersec_init_colors() {
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_MAGENTA=$'\033[0;35m'
    C_CYAN=$'\033[0;36m'
}

cybersec_run_with_countdown() {
    local budget="$1" label="$2" outfile="$3"
    shift 3

    if [[ "${NEO_HUD:-1}" == "1" && -t 1 ]]; then
        local hud_lib="${NEO_DIR}/lib/neo-hud.sh"
        if [[ -f "${hud_lib}" ]]; then
            # shellcheck source=neo-hud.sh
            source "${hud_lib}"
            neo_hud_countdown "${budget}" "${label}" "${outfile}" "$@"
            return $?
        fi
    fi

    timeout "${budget}" "$@" > "${outfile}" 2>&1 &
    local pid=$! elapsed=0 remaining

    while kill -0 "${pid}" 2>/dev/null; do
        remaining=$((budget - elapsed))
        (( remaining < 0 )) && remaining=0
        printf '\r  [%s] %3ds remaining... ' "${label}" "${remaining}"
        sleep 1
        elapsed=$((elapsed + 1))
    done
    printf '\r%-60s\r' ' '

    local status=0
    wait "${pid}" || status=$?
    return "${status}"
}

cybersec_finish() {
    local script_name="$1" phase="$2" summary="$3" raw_content="$4"

    meta_set phase "${phase}" 2>/dev/null || true
    notes_log_smart "${script_name}" "${raw_content}" || true
    notes_refresh_status "${script_name}" "${summary}" || true
}

cybersec_print_banner() {
    local title="$1"
    cat <<BANNER

  ╔══════════════════════════════════════════╗
  ║                                          ║
  ║      [ ✓ ]  ${title}      ║
  ║                                          ║
  ╚══════════════════════════════════════════╝
BANNER
}

cybersec_parse_common_flags() {
    PARSED_PROJECT=""
    PARSED_TARGET=""
    PARSED_QUICK=false
    PARSED_ARGS=()

    local arg
    for arg in "$@"; do
        case "${arg}" in
            --project=*) PARSED_PROJECT="${arg#*=}" ;;
            --target=*)  PARSED_TARGET="${arg#*=}" ;;
            --quick)     PARSED_QUICK=true ;;
            -h|--help)   PARSED_ARGS+=("${arg}") ;;
            *)           PARSED_ARGS+=("${arg}") ;;
        esac
    done
}
