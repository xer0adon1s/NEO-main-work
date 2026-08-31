#!/usr/bin/env bash
# neo-secret — operator CLI for the secret broker (Tier 1.8).

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
# shellcheck source=../lib/neo-secrets.sh
source "${NEO_DIR}/lib/neo-secrets.sh"

usage() {
    cat <<'EOF'
Usage:
  neo-secret store NAME          Store NAME interactively (600 file under ~/.config/neo/secrets/)
  neo-secret remove NAME         Delete stored secret file
  neo-secret audit [REPO]        Fail if repo contains .env / *.pem / *.key
  neo-secret path NAME           Print secret file path (no value)
  neo-secret redact FILE [NAMES] Redact known secrets from FILE into stdout

Examples:
  neo-secret store ANTHROPIC_API_KEY
  neo-secret audit ~/Neo
EOF
}

cmd="${1:-}"
name="${2:-}"
shift 2 2>/dev/null || true

case "${cmd}" in
    store)
        [[ -n "${name}" ]] || { usage; exit 1; }
        neo_secret_prompt "${name}" "${name}" || exit 1
        printf 'Stored %s\n' "$(neo_secret_path "${name}")"
        ;;
    remove)
        [[ -n "${name}" ]] || { usage; exit 1; }
        neo_secret_remove "${name}"
        printf 'Removed (if present): %s\n' "$(neo_secret_path "${name}" 2>/dev/null || echo "${name}")"
        ;;
    audit)
        repo="${name:-${NEO_HOME}}"
        neo_secret_audit_repository "${repo}" && exit 1
        printf 'No secret-like files under %s\n' "${repo}"
        ;;
    path)
        [[ -n "${name}" ]] || { usage; exit 1; }
        neo_secret_path "${name}"
        ;;
    redact)
        file="${name:-}"
        [[ -n "${file}" && -f "${file}" ]] || { usage; exit 1; }
        shift 1 2>/dev/null || true
        names=(ANTHROPIC_API_KEY ANTHROPIC_WORKSPACE_ID OPENAI_API_KEY)
        if (($#)); then names=("$@"); fi
        neo_secret_redact_text "$(cat -- "${file}")" "${names[@]}"
        ;;
    -h|--help|help|'')
        usage
        ;;
    *)
        printf 'neo-secret: unknown command %s\n' "${cmd}" >&2
        usage
        exit 1
        ;;
esac
