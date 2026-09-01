#!/usr/bin/env bash
# borg-library-ai-test.sh — offline AI library parse tests (no live Claude).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-borg-library-ai.sh
source "${NEO_DIR}/lib/neo-borg-library-ai.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'borg-library-ai-test.sh\n\n'

sample="${NEO_ROOT}/test/fixtures/library-ai-sample.md"
[[ -f "${sample}" ]] || { bad "missing fixture"; exit 1; }

neo_borg_library_ai_parse_response "$(cat "${sample}")" && ok "parse sections" || bad "parse"
[[ -n "${NEO_LIBRARY_AI_EDUCATIONAL}" ]] && ok "educational section" || bad "educational"
[[ "${NEO_LIBRARY_AI_SLUG}" == "redis-unauth-rce" ]] && ok "slug parse" || bad "slug: ${NEO_LIBRARY_AI_SLUG}"

idx="$(neo_borg_library_research_index_excerpt 500)"
[[ "${idx}" == *"borg-research-index"* || "${idx}" == *"cve_authoritative"* ]] \
    && ok "research index excerpt" || bad "index excerpt"

bash -n "${NEO_DIR}/lib/neo-borg-library-ai.sh" && ok "syntax library-ai" || bad "syntax"
bash -n "${NEO_DIR}/tools/borg-library-harvest.sh" && ok "syntax harvest" || bad "harvest syntax"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
