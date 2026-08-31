#!/usr/bin/env bash
# Guided listener preparation for an operator-controlled authorized lab workflow.

set -euo pipefail

NEO_NEXT_ROOT="${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_NEXT_ROOT}/lib/neo-core.sh"
# shellcheck source=../lib/neo-evidence.sh
source "${NEO_NEXT_ROOT}/lib/neo-evidence.sh"

PROJECT=""
TARGET=""
CALLBACK_IP=""
PORT="4444"
TOOL=""
MODE="reverse"
START_LISTENER=0
STATE_ROOT="${NEO_NEXT_STATE_ROOT}/projects"

usage() {
    cat <<'EOF'
Usage: ListenAssist.sh --project NAME --target HOST [options]

Options:
  --callback-ip IP     Local VPN/callback address; auto-detected when possible
  --port PORT          Listener or bind-shell port (default 4444)
  --tool TOOL          ncat, nc, or socat
  --mode MODE          reverse or bind (default reverse)
  --start              Offer to start a detached tmux listener

The default behavior prepares a command for a separate operator window and records the
plan. It does not generate or deliver a payload.
EOF
}

while (($#)); do
    case "$1" in
        --project) PROJECT="${2:-}"; shift 2 ;;
        --project=*) PROJECT="${1#*=}"; shift ;;
        --target) TARGET="${2:-}"; shift 2 ;;
        --target=*) TARGET="${1#*=}"; shift ;;
        --callback-ip) CALLBACK_IP="${2:-}"; shift 2 ;;
        --callback-ip=*) CALLBACK_IP="${1#*=}"; shift ;;
        --port) PORT="${2:-}"; shift 2 ;;
        --port=*) PORT="${1#*=}"; shift ;;
        --tool) TOOL="${2:-}"; shift 2 ;;
        --tool=*) TOOL="${1#*=}"; shift ;;
        --mode) MODE="${2:-}"; shift 2 ;;
        --mode=*) MODE="${1#*=}"; shift ;;
        --start) START_LISTENER=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) neo_core_die "unknown argument: $1"; exit 1 ;;
    esac
done

neo_core_require_project "${PROJECT}" || exit 1
[[ -n "${TARGET}" && "${TARGET}" != -* && "${TARGET}" != *$'\n'* ]] || {
    neo_core_die 'target is required and must be a single value'
    exit 1
}
neo_core_valid_port "${PORT}" || { neo_core_die "invalid port: ${PORT}"; exit 1; }
[[ "${MODE}" == reverse || "${MODE}" == bind ]] || { neo_core_die 'mode must be reverse or bind'; exit 1; }

if [[ -z "${CALLBACK_IP}" && "${MODE}" == reverse ]] && command -v ip >/dev/null 2>&1; then
    CALLBACK_IP="$(ip route get "${TARGET}" 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
fi
if [[ "${MODE}" == reverse && -z "${CALLBACK_IP}" ]]; then
    [[ -t 0 ]] || { neo_core_die 'callback IP required'; exit 1; }
    read -r -p 'Callback/VPN IP: ' CALLBACK_IP
fi

if [[ -z "${TOOL}" ]]; then
    for candidate in ncat nc socat; do
        if command -v "${candidate}" >/dev/null 2>&1; then TOOL="${candidate}"; break; fi
    done
fi
if [[ -z "${TOOL}" && -t 0 ]]; then
    read -r -p 'Listener tool (ncat/nc/socat): ' TOOL
fi
[[ "${TOOL}" == ncat || "${TOOL}" == nc || "${TOOL}" == socat ]] || {
    neo_core_die 'listener tool must be ncat, nc, or socat'
    exit 1
}
command -v "${TOOL}" >/dev/null 2>&1 || {
    neo_core_die "listener tool is not installed: ${TOOL}"
    exit 1
}

argv=()
if [[ "${MODE}" == reverse ]]; then
    case "${TOOL}" in
        ncat) argv=(ncat -lvnp "${PORT}") ;;
        nc) argv=(nc -lvnp "${PORT}") ;;
        socat) argv=(socat -d -d "TCP-LISTEN:${PORT},reuseaddr,fork" -) ;;
    esac
else
    case "${TOOL}" in
        ncat) argv=(ncat -v "${TARGET}" "${PORT}") ;;
        nc) argv=(nc -v "${TARGET}" "${PORT}") ;;
        socat) argv=(socat -d -d - "TCP:${TARGET}:${PORT}") ;;
    esac
fi

printf '\nListener plan\n'
printf '  Project: %s\n  Target: %s\n  Mode: %s\n' "${PROJECT}" "${TARGET}" "${MODE}"
[[ "${MODE}" == reverse ]] && printf '  Callback: %s:%s\n' "${CALLBACK_IP}" "${PORT}"
printf '\nRun this in your separate listener window or pane:\n\n  '
neo_core_quote_argv "${argv[@]}"
printf '\nExpected progress:\n'
if [[ "${MODE}" == reverse ]]; then
    printf '  1. The listener reports that it is listening on port %s.\n' "${PORT}"
    printf '  2. After you trigger your separately reviewed foothold method, it reports a connection.\n'
    printf '  3. In the new session, confirm identity and host before continuing.\n'
else
    printf '  1. The client attempts a connection to %s:%s.\n' "${TARGET}" "${PORT}"
    printf '  2. Confirm the remote endpoint and resulting session before continuing.\n'
fi

neo_evidence_init "${PROJECT}" "${STATE_ROOT}"
plan_json="$(jq -cn --arg target "${TARGET}" --arg callback "${CALLBACK_IP}" --arg port "${PORT}" \
    --arg mode "${MODE}" --arg tool "${TOOL}" --argjson argv "$(printf '%s\0' "${argv[@]}" | jq -Rs 'split("\u0000")[:-1]')" \
    '{schema_version:1,target:$target,callback_ip:(if $callback=="" then null else $callback end),port:($port|tonumber),mode:$mode,tool:$tool,argv:$argv}')"
artifact="$(printf '%s\n' "${plan_json}" | neo_evidence_record_artifact foothold_plan ListenAssist \
    "Prepared ${MODE} listener plan with ${TOOL} on port ${PORT}." listener-plan)"
printf '\nPlan recorded: %s\n' "${artifact}"

if (( START_LISTENER == 1 )); then
    command -v tmux >/dev/null 2>&1 || { neo_core_die 'tmux is required for --start'; exit 1; }
    session="neo-listener-$(tr '[:upper:]' '[:lower:]' <<< "${PROJECT}" | tr -cs 'a-z0-9' '-')"
    quoted="$(neo_core_quote_argv "${argv[@]}")"
    if neo_core_confirm "Type start-listener to create detached tmux session ${session}: " start-listener; then
        tmux has-session -t "${session}" 2>/dev/null && {
            neo_core_die "tmux listener session already exists: ${session}"
            exit 1
        }
        tmux new-session -d -s "${session}" "${quoted}"
        printf 'Listener started. Open it with: tmux attach -t %s\n' "${session}"
        neo_evidence_record listener_started ListenAssist "Started tmux listener ${session}." "${artifact}" observed
    else
        printf 'Listener was not started. Use the printed command in your own window.\n'
    fi
fi

if [[ -t 0 ]]; then
    read -r -p 'Did you receive a working session? [y/N/not-yet] ' result
    case "${result}" in
        y|Y|yes|YES) neo_evidence_record foothold_observation operator 'Operator confirmed a working session.' '' operator_confirmed ;;
        not-yet|later) neo_evidence_record foothold_observation operator 'Listener prepared; session result pending.' '' operator_reported ;;
        *) neo_evidence_record foothold_observation operator 'No working session confirmed from this listener attempt.' '' operator_reported ;;
    esac
fi
