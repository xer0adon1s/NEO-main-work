#!/usr/bin/env bash
# neo-borg-disclosure.sh — educational vs professional disclosure lint (Tier B Wave 4 prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"

neo_borg_disclosure_mode() {
    local project="${1:-}" mode="" meta_mode=""
    if [[ -n "${project}" && -n "${NEO_HOME:-}" ]]; then
        # shellcheck source=script-lib.sh
        source "${NEO_LIB_DIR}/script-lib.sh" 2>/dev/null || \
            source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || true
        if declare -F meta_get >/dev/null 2>&1; then
            OUTDIR="${NEO_HOME}/projects/${project}"
            NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
            meta_mode="$(meta_get engagement_mode 2>/dev/null || true)"
            [[ -n "${meta_mode}" ]] && mode="${meta_mode}"
        fi
    fi
    [[ -n "${mode}" ]] || mode="${NEO_ENGAGEMENT_MODE:-educational}"
    case "${mode}" in
        professional|pro) printf 'professional' ;;
        *) printf 'educational' ;;
    esac
}

# Block obvious CTF box spoilers in educational mode. Technique/CVE/privesc paths are OK.
neo_borg_disclosure_check() {
    local mode="$1" text="$2"
    [[ -n "${text}" ]] || return 1
    case "${mode}" in
        educational)
            if grep -qiE '(hackthebox|htb[[:space:].:]|tryhackme|try hack me|thm[[:space:].:]|hackthebox\.(com|eu)|tryhackme\.com|walkthrough for (this |the )?(box|machine|room)|(on|for) this (htb|thm|ctf) (box|machine|room)|the solution (for|on) this (box|machine|room)|/home/[^[:space:]/]+/user\.txt|/root/root\.txt)' \
                <<< "${text}"; then
                return 1
            fi
            ;;
        professional) ;;
        *) return 1 ;;
    esac
    return 0
}

neo_borg_disclosure_scrub_educational() {
    local text="$1"
    [[ -n "${text}" ]] || { printf ''; return 0; }
    text="$(sed -E \
        -e 's/(HackTheBox|TryHackMe|Try Hack Me|HTB Machine|THM Room)/[lab platform]/gi' \
        -e 's/(https?:\/\/)?(www\.|app\.)?hackthebox\.(com|eu)[^[:space:]]*/[lab link redacted]/gi' \
        -e 's/(https?:\/\/)?(www\.)?tryhackme\.com[^[:space:]]*/[lab link redacted]/gi' \
        -e 's/(on|for) this (HTB|THM|CTF) (box|machine|room)/for this lab target/gi' \
        -e 's/the solution (for|on) this (box|machine|room)/a technique path/gi' \
        <<< "${text}")"
    printf '%s' "${text}"
}

neo_borg_disclosure_redact_educational() {
    local text="$1"
    neo_borg_disclosure_scrub_educational "${text}" | \
        sed -E 's/(walkthrough for|walkthrough on)[^[:space:]\n]*/[walkthrough reference redacted]/gi'
}

neo_borg_disclosure_ai_rules() {
    local _project="${1:-}" mode
    mode="$(neo_borg_disclosure_mode "${_project}")"
    case "${mode}" in
        professional)
            cat <<'EOF'
## DISCLOSURE MODE: PROFESSIONAL
Client-deliverable tone. Box/platform names and walkthrough paths are allowed when evidence supports them.
Still avoid credentialed secrets and live target credentials in notes.
EOF
            ;;
        *)
            cat <<'EOF'
## DISCLOSURE MODE: EDUCATIONAL
Lab-learning tone. Teach attack vectors, CVEs, and privesc techniques from evidence.
Do NOT name HackTheBox/TryHackMe boxes or spoil full walkthrough solutions.
Reference techniques and privesc paths — not "on this HTB box, do X to get root".
EOF
            ;;
    esac
}
