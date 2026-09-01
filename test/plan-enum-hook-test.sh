#!/usr/bin/env bash
# plan-enum-hook-test.sh — neo-pipeline-hooks plan-enum (offline).
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_STATE_ROOT="${NEO_ROOT}/test/tmp/plan-hook-$$"
export NEO_TEST_NONINTERACTIVE=1

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

project="plan-hook-test"
target="10.10.10.50"
notes_dir="${NEO_HOME}/projects/${project}"
mkdir -p "${notes_dir}"

cat > "${notes_dir}/Investigation-Notes.md" <<'EOF'
<!-- SECTION:PORTS -->
80/tcp open http
22/tcp open ssh
445/tcp open microsoft-ds
<!-- /SECTION:PORTS -->
EOF

# shellcheck source=../lib/neo-pipeline-hooks.sh
source "${NEO_DIR}/lib/neo-pipeline-hooks.sh"

neo_pipeline_materialize_services "${project}" "${target}" && ok 'materialize services from PORTS' \
    || bad 'materialize services'

svc_count="$(find "$(neo_pipeline_plan_root "${project}")/services" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
(( svc_count >= 3 )) && ok "service JSON count (${svc_count})" || bad "service count ${svc_count}"

neo_pipeline_run_plan_enum "${project}" "${target}" && ok 'run plan-enum batch' || bad 'plan-enum batch'

action_count="$(find "$(neo_pipeline_plan_root "${project}")/actions" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
(( action_count >= 1 )) && ok "action JSON generated (${action_count})" || bad 'no actions'

! neo_pipeline_offer_plan_enum "${project}" "${target}" && ok 'non-interactive skips offer prompt' || bad 'offer should skip'

bash -n "${NEO_DIR}/lib/neo-pipeline-hooks.sh" && ok 'syntax pipeline-hooks' || bad 'syntax'

rm -rf "${NEO_STATE_ROOT}" "${notes_dir}" 2>/dev/null || true
printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
