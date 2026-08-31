#!/usr/bin/env bash
# NEO 1.0 core library bootstrap (C13). Source order matters.

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
export NEO_STATE_ROOT="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}"

# shellcheck source=neo-core.sh
source "${NEO_LIB_DIR}/neo-core.sh"
# shellcheck source=neo-secrets.sh
source "${NEO_LIB_DIR}/neo-secrets.sh"
# shellcheck source=neo-evidence.sh
source "${NEO_LIB_DIR}/neo-evidence.sh"
# shellcheck source=neo-actions.sh
source "${NEO_LIB_DIR}/neo-actions.sh"
# shellcheck source=neo-mission-state.sh
source "${NEO_LIB_DIR}/neo-mission-state.sh"
# shellcheck source=neo-scope.sh
source "${NEO_LIB_DIR}/neo-scope.sh"
# shellcheck source=neo-provider.sh
source "${NEO_LIB_DIR}/neo-provider.sh"

neo_1_0_core_loaded=1
