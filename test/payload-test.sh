#!/usr/bin/env bash
# payload-test.sh — offline tests for [p]ayload suggest / [z] analyze failures visibility
# and tool candidate listing (the tool-picker, copy-paste-only redesign — no more
# auto-execute wind-up parsing, see lib/neo-payload.sh's header comment).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/notes-lib.sh
source "${NEO_DIR}/lib/notes-lib.sh"
# shellcheck source=../lib/neo-ai.sh
source "${NEO_DIR}/lib/neo-ai.sh"
# shellcheck source=../lib/neo-payload.sh
source "${NEO_DIR}/lib/neo-payload.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'payload-test.sh\n\n'

tmp="$(mktemp -d)"
export NEO_HOME="${tmp}/Neo"
export NEO_DIR="${NEO_HOME}"
mkdir -p "${NEO_HOME}/projects/t"
NOTES_FILE="${NEO_HOME}/projects/t/Investigation-Notes.md"
cp "${NEO_ROOT}/templates/investigation-notes.md" "${NOTES_FILE}"
meta_init t 10.10.10.10 "${NEO_HOME}/projects/t"

# --- [p]ayload suggest visibility ---
neo_payload_suggest_visible recon && ok "suggest visible: recon" || bad "suggest visible: recon"
neo_payload_suggest_visible privesc && ok "suggest visible: privesc" || bad "suggest visible: privesc"
neo_payload_suggest_visible post && bad "suggest visible: post should hide" || ok "suggest hidden: post"
neo_payload_suggest_visible foothold && ok "suggest visible: foothold before shell" || bad "suggest visible: foothold before shell"

notes_set_section FOOTHOLD $'```text\nuser@box via ssh\n```' 2>/dev/null || true
neo_payload_has_foothold && ok "detects foothold content" || bad "detects foothold content"
neo_payload_suggest_visible foothold && bad "suggest visible: foothold after shell should hide" || ok "suggest hidden: foothold after shell"

# --- [z] analyze failures visibility (foothold only, after a first attempt) ---
neo_payload_analyze_failures_visible foothold && bad "analyze-failures should be hidden before any attempt" \
    || ok "analyze-failures hidden: foothold, no attempt yet"
neo_payload_analyze_failures_visible recon && bad "analyze-failures should never show outside foothold" \
    || ok "analyze-failures hidden: recon"

neo_payload_mark_foothold_attempted
[[ "$(meta_get foothold_attempted 2>/dev/null)" == "1" ]] && ok "mark_foothold_attempted sets meta" || bad "mark_foothold_attempted sets meta"
neo_payload_analyze_failures_visible foothold && ok "analyze-failures visible: foothold after an attempt" \
    || bad "analyze-failures visible: foothold after an attempt"
neo_payload_analyze_failures_visible privesc && bad "analyze-failures should stay foothold-only even after attempt" \
    || ok "analyze-failures hidden: privesc (foothold-only)"

# --- tool candidate listing ---
mapfile -t candidates < <(neo_payload_list_candidate_tools t)
((${#candidates[@]} > 0)) && ok "candidate tool list non-empty" || bad "candidate tool list non-empty"

dup_check="$(printf '%s\n' "${candidates[@]}" | cut -d'|' -f1 | sort | uniq -d)"
[[ -z "${dup_check}" ]] && ok "candidate tool list has no duplicate names" || bad "duplicate candidate tool names: ${dup_check}"

bash_line="$(printf '%s\n' "${candidates[@]}" | grep '^nmap|')"
[[ "${bash_line}" == "nmap|1" || "${bash_line}" == "nmap|0" ]] && ok "nmap candidate carries a 0/1 availability flag" \
    || bad "nmap candidate availability flag malformed: ${bash_line}"

declare -f neo_payload_analyze_command_failure >/dev/null \
    && ok "neo_payload_analyze_command_failure available for Borg wind-up" \
    || bad "neo_payload_analyze_command_failure missing"

# Regression: neo_tmux_save_capture must be called exactly once per analyze-failures run —
# it writes a fresh timestamped artifacts/terminal-log-<ts>.txt file every time it's called,
# so calling it twice (once directly, once again inside the shared context-block helper)
# silently created two different artifact files per run and made the printed/logged
# terminal-capture filename reference the wrong one. Structural check since the actual tmux
# capture path isn't exercisable offline (see the project's established pattern for
# interactive/TTY-gated code).
declare -f neo_payload_capture_failure_context >/dev/null \
    && ok "neo_payload_capture_failure_context exists (single capture point)" \
    || bad "neo_payload_capture_failure_context missing"
call_count="$(grep -cE '^\s*NEO_PAYLOAD_TERM_REL="\$\(neo_tmux_save_capture' "${NEO_ROOT}/lib/neo-payload.sh")"
((call_count == 1)) && ok "neo_tmux_save_capture invoked exactly once in neo-payload.sh" \
    || bad "expected exactly 1 invocation of neo_tmux_save_capture, found ${call_count} — duplicate capture risk"

bash -n "${NEO_ROOT}/lib/neo-payload.sh" && ok "syntax" || bad "syntax"

rm -rf "${tmp}"
printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
