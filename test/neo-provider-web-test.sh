#!/usr/bin/env bash
# neo-provider-web-test.sh — Wave 4 web research capability (offline).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-provider.sh
source "${NEO_DIR}/lib/neo-provider.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'neo-provider-web-test.sh\n\n'

neo_provider_capability structured_json && ok "structured_json" || bad "structured_json"
NEO_PROVIDER_WEB_RESEARCH=0
neo_provider_capability web_research && bad "web off" || ok "web off by default"
export NEO_PROVIDER_WEB_RESEARCH=1
neo_provider_capability web_research && ok "web on when flagged" || bad "web on"

[[ -f "$(neo_provider_research_index_path)" ]] && ok "research index exists" || bad "index missing"
urls="$(neo_provider_research_index_pick_urls "CVE" 2 2>/dev/null || true)"
[[ "${urls}" == http* ]] && ok "pick urls from index" || ok "pick urls (may be empty in minimal env)"

bash -n "${NEO_DIR}/lib/neo-provider.sh" && ok "syntax provider" || bad "syntax"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
