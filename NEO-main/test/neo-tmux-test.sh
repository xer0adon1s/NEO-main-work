#!/usr/bin/env bash
# neo-tmux-test.sh — neo_tmux_already_in_own_session (neo-tmux.sh), offline.
#
# Regression for the bug this exists to catch: an operator's shell was sitting inside
# their OpenVPN tmux session (unrelated to any mission) when they launched neo.sh. The
# original wrap gate skipped wrapping on ANY $TMUX being set, so the whole mission ran
# inline inside the VPN's pane instead of its own neo-<project> session — which looked
# to the operator exactly like NEO re-attaching them to the VPN, and silently broke
# Analyze Failures too (it captures "the current tmux session", which was the VPN's, not
# the mission's). Fixed by distinguishing "already in MY session" from "already in tmux
# at all" — this test exercises exactly that distinction via a faked `tmux` command.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-tmux.sh
source "${NEO_DIR}/lib/neo-tmux.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'neo-tmux-test.sh\n\n'

unset TMUX
neo_tmux_already_in_own_session "neo-htb-reactor" \
    && bad "TMUX unset should never count as already-in-own-session" \
    || ok "TMUX unset: not already in own session"

# Regression case: current tmux session is a foreign one (the VPN's own session, in the
# reported bug) — must NOT be treated as "already wrapped".
export TMUX="/tmp/fake-tmux-socket,1234,0"
tmux() { [[ "$1" == "display-message" ]] && printf '%s\n' "machines_us-4"; }
neo_tmux_already_in_own_session "neo-htb-reactor" \
    && bad "foreign tmux session (machines_us-4) incorrectly counted as own mission session" \
    || ok "foreign tmux session (machines_us-4) correctly NOT counted as own session"

# Positive case: current tmux session genuinely IS the mission's own session (e.g. a pane
# split inside it) — should be recognized so neo.sh doesn't re-wrap/re-exec pointlessly.
tmux() { [[ "$1" == "display-message" ]] && printf '%s\n' "neo-htb-reactor"; }
neo_tmux_already_in_own_session "neo-htb-reactor" \
    || bad "own mission session (neo-htb-reactor) not recognized as already-wrapped"
neo_tmux_already_in_own_session "neo-htb-reactor" \
    && ok "own mission session (neo-htb-reactor) correctly recognized as already-wrapped"

unset -f tmux
unset TMUX

neo_tmux_args_want_fresh --fresh \
    && ok "exact --fresh token recognized" \
    || bad "--fresh alone should count as want_fresh"

neo_tmux_args_want_fresh HTB-Reactor --target 10.0.0.1 \
    && bad "args without --fresh should not want_fresh" \
    || ok "no --fresh: want_fresh is false"

neo_tmux_args_want_fresh --fresh-recon \
    && bad "--fresh-recon must not false-positive want_fresh" \
    || ok "--fresh-recon does not false-positive want_fresh"

bash -n "${NEO_DIR}/lib/neo-tmux.sh" && ok "syntax: lib/neo-tmux.sh" || bad "syntax: lib/neo-tmux.sh"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
