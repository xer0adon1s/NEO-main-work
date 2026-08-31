#!/usr/bin/env bash
# neo-claude-setup.sh — test Anthropic key + save workspace ID for NEO AI triage.
#
# Usage: ./tools/neo-claude-setup.sh
#        ./tools/neo-claude-setup.sh wrkspc_01AbCdEf...

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"

# shellcheck source=../lib/neo-ai.sh
source "${NEO_DIR}/lib/neo-ai.sh"

C_GREEN=$'\033[0;32m'
C_YELLOW=$'\033[0;33m'
C_RESET=$'\033[0m'

usage() {
    cat <<'EOF'
Usage: neo-claude-setup.sh [wrkspc_...]

Tests your Anthropic API key for NEO analyze-recon.

If your Console shows Workspace ID as "—" (Default Workspace), use a named workspace:

  Claude Console → Settings → Workspaces → open "Neo" (or create one)
  Copy Workspace ID (wrkspc_...)

Or create a new API key scoped to one workspace at key creation (no header needed).

On ./neo.sh recon start, NEO tests the API and prompts for wrkspc_... if needed.

Then:
  ./tools/neo-claude-setup.sh wrkspc_01YourIdHere   # optional pre-save
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ -n "${1:-}" ]]; then
    ws="$(tr -d '[:space:]' <<< "$1")"
    if [[ "${ws}" != wrkspc_* ]]; then
        echo "Workspace ID should start with wrkspc_" >&2
        exit 1
    fi
    neo_ai_save_workspace_id "${ws}"
    printf '%s[ok]%s Saved workspace ID to %s\n' "${C_GREEN}" "${C_RESET}" "$(neo_ai_workspace_file_path)"
fi

if ! neo_ai_load_api_key; then
    echo "No API key — paste into neo.sh when prompted, or save to ~/.config/neo/anthropic.key" >&2
    exit 1
fi

if neo_ai_verify_setup; then
    printf '%s[ok]%s NEO Claude setup complete.\n' "${C_GREEN}" "${C_RESET}"
    exit 0
fi

printf '\n%s[!]%s Setup incomplete.\n' "${C_YELLOW}" "${C_RESET}"
usage
exit 1
