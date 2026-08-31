#!/usr/bin/env bash
# neo-feedback-test.sh — offline operator feedback ack tests.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_FEEDBACK=1

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'neo-feedback-test.sh\n\n'

# shellcheck source=../lib/neo-feedback.sh
source "${NEO_DIR}/lib/neo-feedback.sh"
# shellcheck source=../lib/neo-menu.sh
source "${NEO_DIR}/lib/neo-menu.sh"

[[ "$(neo_feedback_action_title assimilate)" == '[b] Borg research' ]] \
    && ok 'borg title' || bad 'borg title'
[[ "$(neo_feedback_action_title payload-suggest)" == '[p] Payload suggestion' ]] \
    && ok 'payload title' || bad 'payload title'

out="$(neo_feedback_action_title analyze-failures)"
[[ "${out}" == '[z] Diagnose failure' ]] && ok 'diagnose title' || bad "diagnose: ${out}"

bash -n "${NEO_DIR}/lib/neo-feedback.sh" && ok 'syntax neo-feedback.sh' || bad 'syntax'

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
