# Phase 59 — PROPOSED fix (not implemented)

**Status:** IMPLEMENTED (2026-08-30) — see CURSOR-REVIEW-LOG.md Phase 59
**Date:** 2026-08-30
**Repo:** `~/Neo` · base **v0.4.1** (Phase 58, uncommitted)
**Trigger:** Claude's Phase 58 implementation review found that
`test/neo-tmux-integration-test.sh` reports 12/12 passing while its two most important
scenarios (switch-client from a foreign session; `--fresh` replace) are silently failing
the exact mechanism they claim to verify.

**Do not implement until Cursor reviews and the operator says go.**

---

## Report card (Phase 58 implementation)

| Area | Grade | Notes |
|---|---|---|
| `--fresh` kill-and-recreate | **A** | Correct, exact-token match verified (`--fresh-recon` doesn't false-positive), correctly scoped to skip when already inside the target session |
| Messaging fix (switch-client wording) | **A** | Thorough — verified live banner output directly; all "nested"/"double-tap" language gone from current-state text in `lib/neo-tmux.sh`, `AGENTS.md`, `README.md`, `CLAUDE-COLLAB.md` |
| Branded error handling | **B+** | Implemented as designed; investigating it surfaced a real gap (see "Secondary finding" below) |
| **Integration test** | **C-** | **Reports 12/12 green while its two most important scenarios are silently failing the exact thing they claim to test** |
| Docs/version/chmod polish | **A** | Verified clean — extension log, test counts, executable bits, `VERSION` → 0.4.1 |
| **Overall** | **B** | Good engineering on the actual fix; a test-validity regression needs fixing before this can be called done |

## The bug — verified directly, not inferred

Cursor's own Phase 58 log: *"Dropped `script`-based fake client attach (unreliable in
automation); detached-pane `send-keys` still sets `$TMUX` and exercises the switch-client
branch."*

That's true only in the sense that the code *path* runs. `tmux switch-client` requires a
**genuinely attached client** to redirect — a bare `tmux new-session -d` + `send-keys` sets
`$TMUX` for the process running inside the pane, but there is still no attached client, and
`switch-client` fails outright. Confirmed by capturing the pane directly during a manual
replay of the test's own scenario 1:

```
[*] Starting mission in tmux session: neo-tmux-manual-check (switching this terminal to ...)
no current client
neo: could not switch to tmux session 'neo-tmux-manual-check'
```

`neo_tmux_die` fires and the process exits 1 — **and the test still reports pass**, because
the mission session is created and starts running *before* `switch-client` is ever called,
so "session exists" / "mission ran" / "fallthrough marker absent" are all satisfied
regardless of whether `switch-client` succeeded. Confirmed this isn't a fluke: reran it, and
separately confirmed scenario 2 (`--fresh` replace) hits the identical blind spot, since it
goes through the same `switch-client` call. `tmux list-clients` was empty in both cases —
nobody was actually attached to the session that supposedly "passed."

**This is a test regression, not a production regression.** Rebuilt the `script`-based
fake-attach technique (the one dropped) against Cursor's *current* `lib/neo-tmux.sh` and
confirmed `switch-client` genuinely works when a real client is attached — matching the
actual operator's `machines_us-4` situation (2 real ttys attached). The underlying fix is
sound; the test just stopped proving it.

**Secondary finding:** when `switch-client` legitimately fails for real, the operator gets a
terse error with no recovery guidance — no mention that a `neo-<project>` session may
already exist (or, for `--fresh`, was just killed-and-recreated) and is now running
*unattended*. Included a one-line fix for this below.

---

## Proposed fix 1 — reinstate the fake-attach technique, restore the load-bearing assertion

**File:** `test/neo-tmux-integration-test.sh` (full replacement)

Reinstates `script`-based fake client attach (the technique from Claude's original Phase 57
test) for scenarios 1 and 2 — the two that depend on `switch-client` actually succeeding.
Scenario 3 is untouched: it tests `neo_tmux_already_in_own_session`'s early-return path,
which never calls `switch-client` and doesn't need a real attach (`display-message -p '#S'`
works from inside any pane regardless of attachment).

Adds back the assertion that actually catches the bug — reading `tmux list-clients` to
confirm the previously-attached client's view moved to the mission session — to both
scenario 1 and scenario 2 (the original only had it in one place, and only in the version
Cursor later replaced).

Addresses the reliability concern that likely motivated dropping the technique in the first
place: disciplined cleanup (`kill`, poll for death, `kill -9` fallback) plus `disown` on the
backgrounded `script` process (suppresses bash's own noisy "Killed" job-control message on
cleanup — cosmetic, but was cluttering output during verification).

```bash
#!/usr/bin/env bash
# neo-tmux-integration-test.sh — full exec/switch-client wrap mechanics, live tmux, offline.
#
# Exercises neo_tmux_wrap_if_needed for real on an isolated tmux server (TMUX_TMPDIR):
#   1. switch-client path from a foreign session (real attached client, not just $TMUX set)
#   2. --fresh kills a stale mission session and recreates it (real attached client)
#   3. --fresh inside the mission session returns without killing (in-process wipe path)
#
# Scenarios 1 and 2 fake a GENUINELY attached tmux client via `script` (allocates a pty for
# the attach process) rather than merely running a command inside a detached session's pane.
# This distinction is load-bearing, not cosmetic: `tmux switch-client` requires an actual
# attached client to redirect — a bare `tmux new-session -d` + `send-keys` sets $TMUX for the
# process running inside the pane, but there is still no attached client, and
# `tmux switch-client` fails outright ("no current client") in that setup. An earlier version
# of this test relied on send-keys alone; every run's switch-client call was silently failing
# and hitting neo_tmux_die's exit path, but the assertions (session exists, mission script
# ran, fallthrough marker absent) all still passed regardless, because the mission session
# starts running as soon as it's created — before switch-client is ever called — so those
# checks can't tell a real success from neo_tmux_die killing the process. Confirmed directly
# by capturing the pane during a manual replay: it printed `no current client` /
# `neo: could not switch to tmux session ...` while the test suite reported 12/12 passed.
# The fix is the fake-attach technique below, plus restoring an assertion that actually reads
# `tmux list-clients` to confirm the previously-attached client's view moved to the mission
# session — the one check that would have caught this.

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

# `script`'s attach process doesn't always die instantly with a plain kill — give it a beat,
# then a harder nudge, so repeated runs (10x standalone, 3x inside the full diagnostic suite,
# per the Phase 58 verification gate) don't accumulate stray processes.
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
    local path="$1" extra_args="$2" fallthrough_marker="$3"
    cat > "${path}" <<EOF
#!/usr/bin/env bash
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
[[ -n "\${TMUX:-}" ]] && touch "${TMUX_WAS_SET}"
source "${NEO_ROOT}/lib/neo-tmux.sh"
neo_tmux_wrap_if_needed "${MISSION_PROJECT}" "${mission_script}" ${extra_args}
touch "${fallthrough_marker}"
sleep 3
EOF
    chmod +x "${path}"
}

reset_server() {
    kill_attach
    tmux kill-server 2>/dev/null || true
    sleep 0.2
    rm -f "${MARKER}" "${TMUX_TMPDIR}/wrap-did-not-exec" \
        "${TMUX_TMPDIR}/own-wrap-returned" "${TMUX_WAS_SET}"
}

# Creates <name> detached, then fakes a REAL interactive attach to it via `script` (allocates
# a pty for the attach process) and waits for tmux to confirm a client is actually attached.
# Sets the module-level ATTACH_PID (consumed by kill_attach). This is the detail that made
# the earlier version of this test invalid — see the file header.
attach_fake_client() {
    local name="$1"
    tmux new-session -d -s "${name}" -x 200 -y 50
    script -qc "tmux attach -t ${name}" /dev/null >/dev/null 2>&1 &
    ATTACH_PID=$!
    disown "${ATTACH_PID}" 2>/dev/null || true   # suppress bash's own "Killed" job notice on cleanup
    for _ in $(seq 1 25); do
        [[ "$(tmux display-message -p -t "${name}" '#{session_attached}' 2>/dev/null)" == "1" ]] && break
        sleep 0.2
    done
}

# --- Scenario 1: switch-client path from foreign session ----------------------------------

printf 'scenario 1: switch-client path from an ATTACHED foreign session\n'

reset_server
FALLTHROUGH="${TMUX_TMPDIR}/wrap-did-not-exec"
harness="${TMUX_TMPDIR}/harness.sh"
write_harness "${harness}" "" "${FALLTHROUGH}"

attach_fake_client "${FOREIGN}"
tmux send-keys -t "${FOREIGN}" "bash '${harness}'" Enter

for _ in $(seq 1 50); do
    tmux has-session -t "${MISSION_SESSION}" 2>/dev/null && break
    sleep 0.2
done

if tmux has-session -t "${MISSION_SESSION}" 2>/dev/null; then
    ok "wrap created its own session (${MISSION_SESSION}) from inside a foreign one"
else
    bad "no ${MISSION_SESSION} session ever appeared — wrap silently failed"
fi

tmux set-option -t "${MISSION_SESSION}" remain-on-exit on 2>/dev/null || true

[[ -f "${TMUX_WAS_SET}" ]] \
    && ok "harness ran with TMUX set (exercises switch-client branch, not bare attach)" \
    || bad "harness did not see TMUX — wrong code path"

# The exact assertion the original bug (and the earlier, send-keys-only version of this test)
# would fail to catch: the previously-attached client's tty must now be watching the mission
# session, not stuck in the foreign one, and not just... gone because switch-client died.
client_now="$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -1)"
[[ "${client_now}" == "${MISSION_SESSION}" ]] \
    && ok "the previously-attached client's view actually moved to the mission session" \
    || bad "attached client ended up watching '${client_now:-nothing}', not ${MISSION_SESSION} — switch-client likely failed"

for _ in $(seq 1 25); do
    [[ -f "${MARKER}" ]] && break
    sleep 0.2
done
[[ -f "${MARKER}" ]] \
    && ok "mission script actually ran inside the new session" \
    || bad "mission script never ran"

[[ -f "${FALLTHROUGH}" ]] \
    && bad "neo_tmux_wrap_if_needed returned instead of exec-replacing the process" \
    || ok "neo_tmux_wrap_if_needed exec-replaced the process (never fell through)"

tmux has-session -t "${FOREIGN}" 2>/dev/null \
    && ok "original foreign session survives, untouched (just switched away from)" \
    || bad "foreign session was destroyed — should only be switched away from"

# --- Scenario 2: --fresh replaces stale mission session -----------------------------------

printf '\nscenario 2: --fresh replaces stale mission session (ATTACHED foreign session)\n'

reset_server
STALE_MARKER="${TMUX_TMPDIR}/stale-marker"
tmux new-session -d -s "${MISSION_SESSION}" "touch '${STALE_MARKER}'; sleep 60"
for _ in $(seq 1 25); do
    [[ -f "${STALE_MARKER}" ]] && break
    sleep 0.2
done
[[ -f "${STALE_MARKER}" ]] && ok "stale mission session seeded" || bad "failed to seed stale mission session"

attach_fake_client "${FOREIGN}"
FALLTHROUGH="${TMUX_TMPDIR}/wrap-did-not-exec"
harness="${TMUX_TMPDIR}/harness-fresh.sh"
write_harness "${harness}" "--fresh" "${FALLTHROUGH}"
tmux send-keys -t "${FOREIGN}" "bash '${harness}'" Enter

for _ in $(seq 1 50); do
    [[ -f "${MARKER}" ]] && break
    sleep 0.2
done

tmux has-session -t "${MISSION_SESSION}" 2>/dev/null \
    && ok "--fresh: mission session exists after replace" \
    || bad "--fresh: mission session missing after replace"

tmux set-option -t "${MISSION_SESSION}" remain-on-exit on 2>/dev/null || true

client_now="$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -1)"
[[ "${client_now}" == "${MISSION_SESSION}" ]] \
    && ok "--fresh: previously-attached client's view moved to the recreated session" \
    || bad "--fresh: attached client ended up watching '${client_now:-nothing}', not ${MISSION_SESSION}"

[[ -f "${MARKER}" ]] \
    && ok "--fresh: new mission script ran in replaced session" \
    || bad "--fresh: new mission script never ran"

[[ -f "${FALLTHROUGH}" ]] \
    && bad "--fresh replace path returned instead of exec-replacing" \
    || ok "--fresh replace path exec-replaced the process"

# --- Scenario 3: --fresh inside own session does NOT kill ---------------------------------
# No attached client needed here — neo_tmux_already_in_own_session only reads
# `tmux display-message -p '#S'`, which works from inside a pane regardless of whether a
# client is attached, and this path returns before ever calling switch-client.

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
    && ok "--fresh inside own session: mission session not killed" \
    || bad "--fresh inside own session: mission session was killed"

[[ -f "${OWN_RETURN}" ]] \
    && ok "--fresh inside own session: wrap returned to caller (no exec)" \
    || bad "--fresh inside own session: wrap did not return to caller"

[[ ! -f "${MARKER}" ]] \
    && ok "--fresh inside own session: did not re-exec mission via tmux wrap" \
    || bad "--fresh inside own session: unexpectedly ran mission script via wrap"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
```

## Proposed fix 2 — recovery guidance when `switch-client` genuinely fails

**File:** `lib/neo-tmux.sh` — one-line change to `neo_tmux_switch_client_or_die()`

```diff
 neo_tmux_switch_client_or_die() {
     local session="$1"
     tmux switch-client -t "${session}" \
-        || neo_tmux_die "could not switch to tmux session '${session}'"
+        || neo_tmux_die "could not switch this terminal to tmux session '${session}' — it may already exist and be running; attach manually: tmux attach -t ${session}"
 }
```

`neo_tmux_create_session_detached()`'s existing message doesn't need this — if session
creation itself fails there's nothing orphaned to recover.

---

## Verification (Claude, against the proposed test file)

Set up an isolated copy (symlinked `lib/` to the real, unmodified `lib/neo-tmux.sh`; did not
touch any file in the actual repo) and ran the proposed test repeatedly:

- `bash -n` — clean.
- **5 consecutive standalone runs — 14/14 passed every time**, including the two assertions
  that actually read `tmux list-clients` (the ones missing from the current Phase 58 test).
- Confirmed no leftover `script`/tmux-attach processes after repeated runs (`pgrep` clean).
- Confirmed the noisy "Killed" job-control message from `kill_attach` is gone (`disown` fix).
- Did **not** run this against a deliberately-broken `lib/neo-tmux.sh` to confirm the new
  assertions actually fail on a regression (the current code is correct, so there was nothing
  to break it against without editing production code, which this review avoided per the
  operator's read-only instruction) — worth Cursor or the operator doing a quick sanity check
  of that before/during implementation (e.g., temporarily reverting to plain
  `exec tmux new-session` and confirming the new assertions catch it, matching how the
  original Phase 57 test was validated).

---

## Not done here (per operator instruction: draft only, no implementation)

- `test/neo-tmux-integration-test.sh` and `lib/neo-tmux.sh` in the actual repo are
  **unmodified** — the content above is a proposal, verified against a throwaway copy.
- No commit, no version bump beyond what Phase 58 already did.
- Awaiting Cursor's review of this proposal, then operator go-ahead, before any real file
  is touched.
