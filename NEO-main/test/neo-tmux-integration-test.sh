#!/usr/bin/env bash
# neo-tmux-integration-test.sh — full exec/switch-client wrap mechanics, live tmux, offline.
#
# Exercises neo_tmux_wrap_if_needed for real on an isolated tmux server (TMUX_TMPDIR):
#   1. switch-client path from a foreign session (real attached client, not just $TMUX set)
#   2. --fresh kills a stale mission session and recreates it (real attached client)
#   3. --fresh inside the mission session returns without killing (in-process wipe path)
#
# Scenarios 1 and 2 fake a GENUINELY attached tmux client via `script` (allocates a pty for
# the attach process). `tmux switch-client` requires an actual attached client — a bare
# `tmux new-session -d` + `send-keys` sets $TMUX for the pane process but leaves no client,
# so switch-client fails ("no current client") while side-effect assertions still pass.

set -uo pipefail   # deliberately NOT -e: must always reach cleanup even on assertion failure

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }
skip() { printf '  [skip] %s\n' "$1"; }

printf 'neo-tmux-integration-test.sh\n\n'

if ! command -v tmux >/dev/null 2>&1; then
    skip "tmux not installed — nothing to test"
    printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
    exit 0
fi
if ! command -v script >/dev/null 2>&1; then
    skip "script(1) not installed — can't fake a real tmux client attach"
    printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
    exit 0
fi

export TMUX_TMPDIR
TMUX_TMPDIR="$(mktemp -d /tmp/neo-tmux-inttest.XXXXXX)"
FOREIGN="foreign-test-session"
MISSION_PROJECT="tmux-integration-test"
MISSION_SESSION="neo-${MISSION_PROJECT}"
TMUX_WAS_SET="${TMUX_TMPDIR}/tmux-was-set"
ATTACH_PID=""

kill_attach() {
    [[ -n "${ATTACH_PID}" ]] || return 0
    kill "${ATTACH_PID}" 2>/dev/null
    for _ in $(seq 1 10); do
        kill -0 "${ATTACH_PID}" 2>/dev/null || break
        sleep 0.1
    done
    kill -9 "${ATTACH_PID}" 2>/dev/null
    ATTACH_PID=""
}

cleanup() {
    kill_attach
    tmux kill-server 2>/dev/null || true
    rm -rf "${TMUX_TMPDIR}"
}
trap cleanup EXIT

mission_script="${TMUX_TMPDIR}/fake_mission.sh"
MARKER="${TMUX_TMPDIR}/mission-ran"
cat > "${mission_script}" <<EOF
#!/usr/bin/env bash
touch "${MARKER}"
sleep 5
EOF
chmod +x "${mission_script}"

write_harness() {
    local path="$1" extra_args="$2"
    cat > "${path}" <<EOF
#!/usr/bin/env bash
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
[[ -n "\${TMUX:-}" ]] && touch "${TMUX_WAS_SET}"
source "${NEO_ROOT}/lib/neo-tmux.sh"
neo_tmux_wrap_if_needed "${MISSION_PROJECT}" "${mission_script}" ${extra_args}
EOF
    chmod +x "${path}"
}

reset_server() {
    kill_attach
    tmux kill-server 2>/dev/null || true
    sleep 0.2
    rm -f "${MARKER}" "${TMUX_TMPDIR}/own-wrap-returned" "${TMUX_WAS_SET}"
}

# Creates <name> detached, fakes a real interactive attach via `script`, waits for
# session_attached==1. Returns 1 if no client ever attached (fail-fast).
# TERM must be a real terminal type — util-linux script's default pty often makes
# tmux attach fail with "terminal does not support clear", leaving session_attached=0.
attach_fake_client() {
    local name="$1"
    tmux new-session -d -s "${name}" -x 200 -y 50
    script -q -c "export TERM=xterm-256color; stty rows 50 cols 200 2>/dev/null; tmux attach -t ${name}; sleep 120" /dev/null >/dev/null 2>&1 &
    ATTACH_PID=$!
    disown "${ATTACH_PID}" 2>/dev/null || true
    for _ in $(seq 1 25); do
        [[ "$(tmux display-message -p -t "${name}" '#{session_attached}' 2>/dev/null)" == "1" ]] && return 0
        sleep 0.2
    done
    return 1
}

# neo_tmux_die prints these strings before exit — grep panes explicitly; a missing
# fallthrough marker is NOT proof switch-client succeeded.
assert_no_wrap_error_in_panes() {
    local label="$1"
    shift
    local sess body
    for sess in "$@"; do
        body="$(tmux capture-pane -t "${sess}" -p -S -50 2>/dev/null || true)"
        if grep -qE 'neo: could not switch|neo: could not create|neo: could not kill' <<< "${body}"; then
            bad "${label}: wrap failure text found in pane (${sess})"
            return 1
        fi
    done
    ok "${label}: no wrap failure text in captured panes"
    return 0
}

run_switch_client_scenario() {
    local label="$1" extra_args="$2" seed_stale="${3:-false}"
    local harness="${TMUX_TMPDIR}/harness-${label}.sh"

    reset_server
    if ${seed_stale}; then
        local stale_marker="${TMUX_TMPDIR}/stale-marker"
        tmux new-session -d -s "${MISSION_SESSION}" "touch '${stale_marker}'; sleep 60"
        for _ in $(seq 1 25); do
            [[ -f "${stale_marker}" ]] && break
            sleep 0.2
        done
        [[ -f "${stale_marker}" ]] \
            && ok "${label}: stale mission session seeded" \
            || bad "${label}: failed to seed stale mission session"
    fi

    write_harness "${harness}" "${extra_args}"

    if attach_fake_client "${FOREIGN}"; then
        ok "${label}: fake client attached to ${FOREIGN}"
    else
        bad "${label}: could not establish fake attached client — aborting"
        return 1
    fi

    tmux send-keys -t "${FOREIGN}" "bash '${harness}'" Enter
    sleep 0.5

    for _ in $(seq 1 50); do
        tmux has-session -t "${MISSION_SESSION}" 2>/dev/null && break
        sleep 0.2
    done

    tmux has-session -t "${MISSION_SESSION}" 2>/dev/null \
        && ok "${label}: mission session exists" \
        || bad "${label}: mission session never appeared"

    tmux set-option -t "${MISSION_SESSION}" remain-on-exit on 2>/dev/null || true

    for _ in $(seq 1 25); do
        [[ -f "${TMUX_WAS_SET}" ]] && break
        sleep 0.2
    done
    [[ -f "${TMUX_WAS_SET}" ]] \
        && ok "${label}: harness ran with TMUX set" \
        || bad "${label}: harness did not see TMUX"

    local client_now=""
    for _ in $(seq 1 25); do
        client_now="$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -1)"
        [[ "${client_now}" == "${MISSION_SESSION}" ]] && break
        sleep 0.2
    done
    [[ "${client_now}" == "${MISSION_SESSION}" ]] \
        && ok "${label}: client view moved to ${MISSION_SESSION}" \
        || bad "${label}: client watching '${client_now:-nothing}', not ${MISSION_SESSION}"

    assert_no_wrap_error_in_panes "${label}" "${FOREIGN}" "${MISSION_SESSION}"

    for _ in $(seq 1 25); do
        [[ -f "${MARKER}" ]] && break
        sleep 0.2
    done
    [[ -f "${MARKER}" ]] \
        && ok "${label}: mission script ran" \
        || bad "${label}: mission script never ran"

    tmux has-session -t "${FOREIGN}" 2>/dev/null \
        && ok "${label}: foreign session survives" \
        || bad "${label}: foreign session was destroyed"
}

# --- Scenario 1 -----------------------------------------------------------------------------

printf 'scenario 1: switch-client path from an ATTACHED foreign session\n'
run_switch_client_scenario "scenario 1" "" false

# --- Scenario 2 -----------------------------------------------------------------------------

printf '\nscenario 2: --fresh replaces stale mission session (ATTACHED foreign session)\n'
run_switch_client_scenario "scenario 2" "--fresh" true

# --- Scenario 3: --fresh inside own session does NOT kill ---------------------------------
# No attached client needed — early return before switch-client; display-message -p '#S'
# works from inside any pane.

printf '\nscenario 3: --fresh inside own session returns without killing\n'

reset_server
OWN_RETURN="${TMUX_TMPDIR}/own-wrap-returned"
harness_own="${TMUX_TMPDIR}/harness-own.sh"
cat > "${harness_own}" <<EOF
#!/usr/bin/env bash
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
source "${NEO_ROOT}/lib/neo-tmux.sh"
neo_tmux_wrap_if_needed "${MISSION_PROJECT}" "${mission_script}" --fresh
touch "${OWN_RETURN}"
EOF
chmod +x "${harness_own}"

tmux new-session -d -s "${MISSION_SESSION}" -x 200 -y 50
sleep 0.3
tmux send-keys -t "${MISSION_SESSION}" "bash '${harness_own}'" Enter

for _ in $(seq 1 25); do
    [[ -f "${OWN_RETURN}" ]] && break
    sleep 0.2
done

tmux has-session -t "${MISSION_SESSION}" 2>/dev/null \
    && ok "scenario 3: mission session not killed" \
    || bad "scenario 3: mission session was killed"

[[ -f "${OWN_RETURN}" ]] \
    && ok "scenario 3: wrap returned to caller (no exec)" \
    || bad "scenario 3: wrap did not return to caller"

[[ ! -f "${MARKER}" ]] \
    && ok "scenario 3: did not re-exec mission via tmux wrap" \
    || bad "scenario 3: unexpectedly ran mission script via wrap"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
