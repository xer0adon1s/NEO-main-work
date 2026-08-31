#!/usr/bin/env bash
# neo-tmux.sh — self-wrap the mission in tmux; capture scrollback for Analyze Failures.
#
# Two independent halves:
#   1. neo_tmux_wrap_if_needed  — re-exec neo.sh inside a named tmux session on a real
#      interactive launch, so a session always exists to capture from later. Never wraps
#      piped/non-interactive runs (tests, automation), or when already inside THIS
#      mission's own neo-<project> session (see neo_tmux_already_in_own_session below —
#      that is deliberately NOT the same thing as "already inside tmux at all").
#   2. neo_tmux_capture_recent  — dump recent scrollback from every pane in the current
#      tmux session to a text blob, for Analyze Failures to bundle into its Claude call.

neo_tmux_slug() {
    local s="$1"
    s="$(tr '[:upper:]' '[:lower:]' <<< "${s}")"
    s="$(sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' <<< "${s}")"
    printf '%s' "${s:-mission}"
}

neo_tmux_wrap_enabled() {
    [[ "${NEO_TMUX_WRAP:-1}" != "0" ]] || return 1
    [[ -t 0 && -t 1 ]] || return 1
    command -v tmux >/dev/null 2>&1 || return 1
    return 0
}

# neo_tmux_already_in_own_session <target-session>
# True only if the CURRENT tmux client is attached to exactly that session — e.g. the
# operator split a pane inside their own neo-<project> session and re-ran neo.sh from
# there. False if $TMUX is unset, OR if it's set but pointing at some OTHER session.
#
# That second case matters: an earlier version of this gate skipped wrapping on ANY
# $TMUX being set, on the theory that this meant "already in the right place" (e.g. an
# IDE-embedded terminal that's already tmux-wrapped for some other reason). That's too
# broad — confirmed live: an operator's shell was sitting inside their OpenVPN tmux
# session (created earlier by connect/ovpn-connect.sh, unrelated to any mission) when
# they launched neo.sh. The old gate saw $TMUX set and skipped wrapping entirely, so the
# whole mission — boot ritual included — ran inline inside the VPN's pane, with hours of
# old openvpn scrollback sitting above it. From the operator's side that looked exactly
# like NEO re-attaching them to the VPN (the bug this file's tmux auto-wrap was supposed
# to help avoid, not reintroduce) — and it silently broke Analyze Failures too, since
# neo_tmux_current_session would report the VPN's session, not the mission's, so its
# terminal capture would be VPN connection logs, never anything the operator actually did.
# Being inside some OTHER foreign tmux session is not "already wrapped" — switch-client
# moves this terminal's view to the mission session while the foreign one keeps running.
neo_tmux_already_in_own_session() {
    local target="$1" current
    [[ -n "${TMUX:-}" ]] || return 1
    current="$(tmux display-message -p '#S' 2>/dev/null || true)"
    [[ -n "${current}" && "${current}" == "${target}" ]]
}

# neo_tmux_args_want_fresh <original-arg...>
# True only when --fresh appears as its own argv token (neo.sh boolean flag, no =value form).
neo_tmux_args_want_fresh() {
    local arg
    for arg in "$@"; do
        [[ "${arg}" == "--fresh" ]] && return 0
    done
    return 1
}

neo_tmux_die() {
    printf 'neo: %s\n' "$1" >&2
    exit 1
}

neo_tmux_create_session_detached() {
    local session="$1" cmd="$2"
    tmux new-session -d -s "${session}" -c "$(pwd)" "${cmd}" \
        || neo_tmux_die "could not create tmux session '${session}' (is tmux running?)"
}

neo_tmux_switch_client_or_die() {
    local session="$1"
    tmux switch-client -t "${session}" \
        || neo_tmux_die "could not switch this terminal to tmux session '${session}' — it may already exist and be running; attach manually: tmux attach -t ${session}"
}

# neo_tmux_wrap_if_needed <project> <script-path> <original-arg...>
# Re-execs the current process (exec, not fork — same PID slot) inside a tmux session
# named neo-<project>, then attaches. No-op if wrapping isn't appropriate right now — see
# neo_tmux_wrap_enabled for exactly when. Caller passes script-path/args explicitly
# (rather than this function reading $0/$@ itself) since it's called as a function, whose
# own $@ is unrelated to the calling script's original argv unless handed over.
#
# Builds ONE bash-quoted command string and passes it as tmux's single trailing
# shell-command argument (tmux runs that through $SHELL -c internally) — same pattern
# lib/neo-vpn.sh's neo_vpn_connect_profile already uses successfully for exactly this
# reason: passing multiple raw argv tokens to `tmux new-session` gets space-joined and
# re-split by tmux's own shell layer, which breaks on any argument containing spaces.
NEO_TMUX_ENV_FORWARD=(
    NEO_HOME NEO_DIR NEO_SPLASH NEO_HUD NEO_AI NEO_AI_MODE NEO_AI_MODEL NEO_AI_MAX_TOKENS
    NEO_AI_HUD NEO_AI_TIMER NEO_AI_WAIT_TIMER_SEC NEO_BORG_HUD NEO_TMUX_WRAP
    NEO_DEEP_RECON NEO_SESSION_PROMPT NEO_VPN_WAIT NEO_BOOT_INTRO_SEC
    NEO_ASK_CONTEXT_LINES NEO_ANALYZE_TERM_LINES
    ANTHROPIC_API_KEY ANTHROPIC_WORKSPACE_ID
)

neo_tmux_wrap_if_needed() {
    local project="$1" script_path="$2"
    shift 2
    neo_tmux_wrap_enabled || return 0

    local session="neo-$(neo_tmux_slug "${project}")"
    local cmd env_prefix="" var val

    neo_tmux_already_in_own_session "${session}" && return 0

    local switch_note="" foreign_session=""
    if [[ -n "${TMUX:-}" ]]; then
        foreign_session="$(tmux display-message -p '#S' 2>/dev/null || true)"
        [[ -n "${foreign_session}" ]] || foreign_session="your current session"
        switch_note=" (switching this terminal to ${session}; ${foreign_session} keeps running in the background)"
    fi

    # Confirmed empirically (not assumed): a brand-new tmux session does NOT inherit the
    # launching client's exported env vars — only NEO_HOME/NEO_DIR self-heal (neo.sh
    # recomputes them from $0 + cwd when unset); everything else the operator has
    # exported (NEO_SPLASH, ANTHROPIC_API_KEY, etc.) must be forwarded explicitly or it
    # silently reverts to defaults inside the wrapped session.
    for var in "${NEO_TMUX_ENV_FORWARD[@]}"; do
        val="${!var:-}"
        [[ -n "${val}" ]] || continue
        env_prefix="${env_prefix}${var}=$(printf '%q' "${val}") "
    done

    cmd="${env_prefix}$(printf '%q ' bash "${script_path}" "$@")"

    # `tmux new-session`/`tmux attach` WITHOUT -d try to attach directly to the calling
    # process's controlling terminal. That's fine when nothing else is already attached
    # to it — but when $TMUX is already set (this terminal is already a tmux client, e.g.
    # sitting inside a foreign session like an OpenVPN one), tmux's own nested-session
    # safety kicks in ("sessions should be nested with care, unset $TMUX to force") and
    # the attach can outright fail (confirmed via isolated test: `exec tmux new-session`
    # from inside another session exited 1, no session ever got created — silently
    # leaving the operator stuck in the foreign session, exactly what this fix exists to
    # prevent). The correct way to move an already-attached client to a different/new
    # session is `switch-client`, not attach — so branch on whether we're already inside
    # some tmux client right now, not just whether the target differs.
    local already_in_tmux=false
    [[ -n "${TMUX:-}" ]] && already_in_tmux=true

    # --fresh from outside the mission session: kill stale neo-<project> so the new
    # invocation's env-forwarding and neo_session_fresh_start() actually run. Only ever
    # targets neo-<slug> — never a foreign session like an OpenVPN one. Disruptive if
    # another client is attached to the stale mission session (by design, same category
    # as VPN profile switch). Already inside the mission session → early return above;
    # in-process wipe handles --fresh there.
    if neo_tmux_args_want_fresh "$@" && tmux has-session -t "${session}" 2>/dev/null; then
        printf '\n[*] --fresh: replacing existing tmux session: %s\n' "${session}"
        tmux kill-session -t "${session}" \
            || neo_tmux_die "could not kill existing tmux session '${session}' for --fresh"
    fi

    if tmux has-session -t "${session}" 2>/dev/null; then
        printf '\n[*] Reattaching existing tmux session: %s\n' "${session}"
        printf '    (env from when this session was first created — not this launch'"'"'s)\n'
        if ${already_in_tmux}; then
            neo_tmux_switch_client_or_die "${session}"
            exec true
        fi
        exec tmux attach -t "${session}"
    fi

    printf '\n[*] Starting mission in tmux session: %s%s (NEO_TMUX_WRAP=0 to disable)\n' "${session}" "${switch_note}"
    printf '    Manual exploit attempts outside NEO should happen in this same session\n'
    printf '    (split a pane with Ctrl-b %%%%) so Analyze Failures can review them.\n'
    if ${already_in_tmux}; then
        neo_tmux_create_session_detached "${session}" "${cmd}"
        neo_tmux_switch_client_or_die "${session}"
        exec true
    fi
    exec tmux new-session -s "${session}" -c "$(pwd)" "${cmd}"
}

neo_tmux_current_session() {
    [[ -n "${TMUX:-}" ]] || return 1
    tmux display-message -p '#S' 2>/dev/null
}

# neo_tmux_capture_recent [lines]
# Concatenates recent scrollback (default last 300 lines) from every pane in the current
# tmux session, each labeled by window/pane, to stdout. Returns 1 if not inside tmux.
neo_tmux_capture_recent() {
    local lines="${1:-300}"
    local session pane label body any=false

    session="$(neo_tmux_current_session)" || return 1

    while IFS= read -r pane; do
        [[ -n "${pane}" ]] || continue
        label="$(tmux display-message -p -t "${pane}" '#{window_name}:#{pane_index}' 2>/dev/null || echo "${pane}")"
        body="$(tmux capture-pane -t "${pane}" -p -S "-${lines}" 2>/dev/null || true)"
        [[ -n "${body}" ]] || continue
        any=true
        printf '### tmux pane %s (%s)\n```text\n%s\n```\n\n' "${pane}" "${label}" "${body}"
    done < <(tmux list-panes -s -t "${session}" -F '#{pane_id}' 2>/dev/null || true)

    ${any} || return 1
}

# neo_tmux_save_capture <project> [lines] — snapshot to a unique artifacts/ file, print
# the relative path on stdout. Returns 1 if there was nothing to capture (no tmux, or
# tmux present but genuinely empty).
neo_tmux_save_capture() {
    local project="$1" lines="${2:-300}"
    local outdir="${NEO_HOME}/projects/${project}/artifacts"
    local ts path rel body

    body="$(neo_tmux_capture_recent "${lines}")" || return 1

    mkdir -p "${outdir}"
    ts="$(date '+%Y%m%d-%H%M%S')"
    path="${outdir}/terminal-log-${ts}.txt"
    printf '%s' "${body}" > "${path}"
    rel="artifacts/$(basename "${path}")"
    printf '%s' "${rel}"
}
