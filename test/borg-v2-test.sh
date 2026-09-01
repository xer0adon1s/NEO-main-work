#!/usr/bin/env bash
# borg-v2-test.sh — Wave 5 Borg v2 validation helpers (offline).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-borg-v2.sh
source "${NEO_DIR}/lib/neo-borg-v2.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'borg-v2-test.sh\n\n'

[[ -f "${NEO_DIR}/schemas/borg-dossier.schema.json" ]] && ok "schema file" || bad "schema"
[[ -f "${NEO_DIR}/borg/borg-v2.sh" ]] && ok "borg-v2 script" || bad "borg-v2.sh"
bash -n "${NEO_DIR}/borg/borg-v2.sh" && ok "syntax borg-v2.sh" || bad "syntax v2"

sample="$(mktemp)"
jq -n '{schema_version:1,vectors:[{id:"test-vector",title:"T",sources:[],tool_inventory:[],operator_actions:[{title:"a",risk:"low"}]}]}' > "${sample}"
neo_borg_v2_validate_dossier "${sample}" && ok "validate sample dossier" || bad "validate"
rm -f "${sample}"

bash -n "${NEO_DIR}/lib/neo-borg-v2.sh" && ok "syntax neo-borg-v2.sh" || bad "syntax lib"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
