#!/usr/bin/env bash
# disclosure-lint-all-test.sh — Wave 4 global AI output guard (offline).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_DISCLOSURE_LINT_ALL=1
export NEO_DISCLOSURE_STRICT=1

# shellcheck source=../lib/neo-borg-disclosure.sh
source "${NEO_DIR}/lib/neo-borg-disclosure.sh"
# shellcheck source=../lib/neo-ai-guard.sh
source "${NEO_DIR}/lib/neo-ai-guard.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'disclosure-lint-all-test.sh\n\n'

clean="$(neo_ai_guard_output "" "CVE-2021-41773 Apache path traversal technique" "test")"
[[ "${clean}" == *"CVE-2021"* ]] && ok "clean CVE text passes" || bad "clean CVE"

if out="$(neo_ai_guard_output "" "This is the Reactor box on HackTheBox" "test" 2>/dev/null)"; then
    bad "strict should refuse spoiler"
else
    ok "strict refuses box spoiler"
fi

export NEO_DISCLOSURE_STRICT=0
warned="$(neo_ai_guard_output "" "HackTheBox box Reactor walkthrough" "test")"
[[ "${warned}" == *"redacted"* || "${warned}" != *"Reactor"* ]] && ok "non-strict redacts" || bad "redact mode"

bash -n "${NEO_DIR}/lib/neo-ai-guard.sh" && ok "syntax ai-guard" || bad "syntax"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
