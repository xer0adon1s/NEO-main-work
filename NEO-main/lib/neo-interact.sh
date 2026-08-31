#!/usr/bin/env bash
# neo-interact.sh — pre-foothold "interactable" check-in framework.
#
# Right after recon completes and before advancing to foothold, checks whether
# something worth poking at by hand was found (a web server today — see
# NEO_INTERACT_DETECTORS). If so, offers the operator a chance to go explore it
# manually and pipe findings back into the mission before foothold begins, with an
# [a]sk Claude option available at the same pause. This is deliberately a reusable
# framework, not a one-off web feature: adding a future interactable (e.g. an SNMP
# community string, an exposed git repo) means adding one name to
# NEO_INTERACT_DETECTORS plus its detect/rundown pair — the pause flow itself doesn't
# change. Pure glue: no scanning of its own, reads what babysteps/analyze-recon
# already wrote to Investigation-Notes.md.

neo_interact_init_colors() {
    C_RESET="${C_RESET:-\033[0m}"
    C_CYAN="${C_CYAN:-\033[0;36m}"
    C_YELLOW="${C_YELLOW:-\033[0;33m}"
    C_GREEN="${C_GREEN:-\033[0;32m}"
    C_BRIGHT="${C_BRIGHT:-\033[1;32m}"
}

# --- detectors ---------------------------------------------------------------
# Each entry `<name>` needs neo_interact_detect_<name> (0 = found, no output) and
# neo_interact_rundown_<name> (prints a short human rundown to stdout).

NEO_INTERACT_DETECTORS=(web)

neo_interact_detect_web() {
    local ports services log_body

    # PORTS is already filtered by babysteps to just the nmap "<port>/tcp open ..." table
    # rows (recon/babysteps.sh: `grep -E '^[0-9]+/(tcp|udp)[[:space:]]+open'`) — it never
    # contains nmap's own banner/comment prose. NMAP (the raw dump) and LOG (the full
    # findings trail) DO always contain that prose — nmap prints "Starting Nmap ... (
    # https://nmap.org )" and "...report at https://nmap.org/submit/ ." on every single
    # scan, unconditionally. An earlier version of this detector matched a bare
    # `https?://` URL / generic `http` keyword against NMAP+LOG combined, which meant it
    # false-positived as "web server found" on literally every mission, including
    # SSH-only boxes with zero web services (confirmed via isolated repro). Fixed by
    # scoping URL/keyword matching to structured, NEO-curated sources only: the SERVICES
    # section's `### Web —` header (written only when babysteps actually confirms an
    # HTTP(S) response), babysteps' own structured LOG marker phrasing, and PORTS.
    ports="$(notes_get_section PORTS 2>/dev/null || true)"
    services="$(notes_get_section SERVICES 2>/dev/null || true)"
    log_body="$(notes_get_section LOG 2>/dev/null || true)"

    # babysteps writes ### Web — http(s)://... under SERVICES once it confirms an HTTP(S)
    # response on a port — the single most reliable signal.
    grep -qiE '^### Web — https?://' <<< "${services}" && return 0

    # babysteps' own structured log markers for a confirmed HTTP(S) hit — parens must be
    # escaped (`\(`/`\)`) to match the literal "HTTP(S)"/"service(s)" text; an earlier
    # unescaped version of this regex never actually matched (parens are grouping
    # metacharacters in extended regex), silently relying on the broader checks above
    # instead — verified by testing both forms against the real babysteps output strings.
    grep -qiE 'HTTP\(S\) service confirmed|web service\(s\) found' <<< "${log_body}" && return 0

    # Common web ports + unusual app ports (e.g. HTB :3000) — PORTS is structured, safe to
    # substring-match.
    grep -qE '^(80|443|3000|5000|8000|8080|8443|8888|9000)/(tcp|udp)[[:space:]]' <<< "${ports}" && return 0
    grep -qiE 'http|apache|nginx|iis' <<< "${ports}" && return 0

    return 1
}

neo_interact_rundown_web() {
    local ports
    ports="$(notes_get_section PORTS 2>/dev/null | grep -iE '80|443|http' || true)"
    printf 'Web server(s) in recon:\n%s\n' "${ports:-_(see Service Enumeration section)_}"
}

# --- generic pause framework --------------------------------------------------

neo_interact_any_found() {
    local d
    for d in "${NEO_INTERACT_DETECTORS[@]}"; do
        "neo_interact_detect_${d}" && return 0
    done
    return 1
}

neo_interact_save() {
    local title="$1" body="$2"
    local ts doc existing placeholder=false

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    doc="$(cat <<EOF
### ${title} — ${ts}

${body}
EOF
)"

    existing="$(notes_get_section INTERACT 2>/dev/null || true)"
    if [[ -z "${existing}" ]] || [[ "${existing}" == *"_No pre-foothold"* ]]; then
        placeholder=true
    fi

    if [[ "${placeholder}" == true ]]; then
        notes_set_section INTERACT "${doc}" || return 1
    else
        notes_append_section INTERACT "$(printf '\n\n---\n\n%s' "${doc}")" || return 1
    fi
}

# neo_interact_pause_before_foothold <project>
# No-op (returns 0 immediately, no output) if nothing interactable was found, if this
# isn't an interactive terminal, or if notes don't exist yet — safe to call
# unconditionally from the main phase-walk loop right after recon finishes.
neo_interact_pause_before_foothold() {
    local project="$1"
    local d ans findings rundown_all=""

    [[ -t 0 ]] || return 0

    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    [[ -f "${NOTES_FILE}" ]] || return 0

    # shellcheck source=script-lib.sh
    source "${NEO_DIR:-${NEO_HOME}}/lib/script-lib.sh"

    neo_interact_any_found || return 0
    neo_interact_init_colors

    for d in "${NEO_INTERACT_DETECTORS[@]}"; do
        "neo_interact_detect_${d}" || continue
        rundown_all="${rundown_all}$("neo_interact_rundown_${d}")"$'\n'
    done

    printf '\n%s  ▸ PRE-FOOTHOLD CHECK-IN%s\n\n' "${C_CYAN}" "${C_RESET}"
    printf '%s\n' "${rundown_all}"

    read -r -p 'Investigate further before foothold? [y/N]: ' ans
    if [[ ! "${ans}" =~ ^[Yy] ]]; then
        neo_interact_save "Declined further investigation" \
            "Operator chose to proceed straight to foothold."
        return 0
    fi

    printf '\n%sGo explore manually now — drop any files in the project folder, they'"'"'ll be\n' "${C_YELLOW}"
    printf 'picked up next time this project is opened. Come back here when done.%s\n\n' "${C_RESET}"

    read -r -p 'What did you find? (or "a" to ask Claude first, blank to skip): ' findings

    if [[ "${findings}" =~ ^[Aa]$ ]]; then
        # shellcheck source=neo-ai-cli.sh
        source "${NEO_DIR:-${NEO_HOME}}/lib/neo-ai-cli.sh"
        neo_ai_cli_ask_claude "${project}" "recon" || true
        read -r -p 'Anything else to note before foothold? (blank to skip): ' findings
    fi

    if [[ -n "${findings}" ]]; then
        neo_interact_save "Manual pre-foothold findings" "${findings}"
        printf '%s[+]%s Saved to projects/%s/Investigation-Notes.md → Pre-Foothold Findings\n' \
            "${C_GREEN}" "${C_RESET}" "${project}"
    fi

    cybersec_finish "pre-foothold-interact" "recon" \
        "Pre-foothold findings saved → **Pre-Foothold Findings** section" \
        "$(printf '=== pre-foothold-interact %s ===\n%s' "$(date '+%Y-%m-%d %H:%M:%S')" "${findings:-declined further investigation}")"
}
