#!/usr/bin/env bash
# borg-disclosure-test.sh — offline tests for educational/professional disclosure helpers.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-borg-disclosure.sh
source "${NEO_DIR}/lib/neo-borg-disclosure.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'borg-disclosure-test.sh\n\n'

[[ "$(neo_borg_disclosure_mode '')" == "educational" ]] \
    && ok "default mode is educational" || bad "default mode"

export NEO_ENGAGEMENT_MODE=professional
[[ "$(neo_borg_disclosure_mode '')" == "professional" ]] \
    && ok "NEO_ENGAGEMENT_MODE=professional" || bad "env professional"
unset NEO_ENGAGEMENT_MODE

neo_borg_disclosure_check educational "Apache 2.4.49 path traversal CVE-2021-41773" \
    && ok "CVE technique text passes educational" || bad "CVE should pass"

neo_borg_disclosure_check educational "This is the Reactor box on HackTheBox" \
    && bad "box spoiler should fail" || ok "flags box spoiler"

neo_borg_disclosure_check professional "This is the Reactor box on HackTheBox" \
    && ok "professional allows box names" || bad "professional should pass"

rules="$(neo_borg_disclosure_ai_rules '')"
[[ "${rules}" == *"EDUCATIONAL"* ]] && ok "educational AI rules" || bad "AI rules educational"
export NEO_ENGAGEMENT_MODE=professional
rules="$(neo_borg_disclosure_ai_rules '')"
[[ "${rules}" == *"PROFESSIONAL"* ]] && ok "professional AI rules" || bad "AI rules professional"
unset NEO_ENGAGEMENT_MODE

bash -n "${NEO_DIR}/lib/neo-borg-disclosure.sh" && ok "syntax disclosure" || bad "syntax"
bash -n "${NEO_DIR}/lib/neo-borg-library.sh" && ok "syntax library" || bad "syntax library"
bash -n "${NEO_DIR}/tools/borg-disclosure-check.sh" && ok "syntax check tool" || bad "syntax tool"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
