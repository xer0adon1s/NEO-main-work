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

neo_borg_disclosure_check() {
    local mode="$1" text="$2"
    [[ -n "${text}" ]] || return 1
    case "${mode}" in
        educational)
            if grep -qiE \
                '(hackthebox|htb[[:space:].]|tryhackme|thm[[:space:].]|box name|walkthrough for|walkthrough path|root flag|user flag|pass the hash|/home/[^[:space:]/]+/user\.txt|/root/root\.txt)' \
                <<< "${text}"; then
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
