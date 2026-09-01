#!/usr/bin/env bash
# neo-borg-disclosure.sh — educational vs professional disclosure lint (Tier B Wave 4 prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

neo_borg_disclosure_mode() {
    local _project="${1:-}"
    case "${NEO_ENGAGEMENT_MODE:-educational}" in
        professional|pro) printf 'professional' ;;
        *) printf 'educational' ;;
    esac
}

neo_borg_disclosure_check() {
    local mode="$1" text="$2"
    [[ -n "${text}" ]] || return 1
    case "${mode}" in
        educational)
            if grep -qiE '(hackthebox|htb\.|tryhackme|thm\.|box name|walkthrough for)' <<< "${text}"; then
                return 1
            fi
            ;;
        professional) ;;
        *) return 1 ;;
    esac
    return 0
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
Lab-learning tone. Teach techniques and CVEs; do NOT name specific HTB/THM boxes or spoil walkthrough paths.
EOF
            ;;
    esac
}
