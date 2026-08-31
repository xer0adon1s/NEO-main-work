#!/usr/bin/env bash
# privesc-rank-hook-test.sh — privesc rank hook (offline).
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_STATE_ROOT="${NEO_ROOT}/test/tmp/privesc-hook-$$"
export NEO_TEST_NONINTERACTIVE=1

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

project="privesc-hook-test"
priv_dir="${NEO_STATE_ROOT}/projects/${project}/privesc"
# shellcheck source=../lib/neo-core.sh
source "${NEO_DIR}/lib/neo-core.sh"
neo_core_secure_dir "${priv_dir}"

jq -n '{
  schema_version: 1,
  source_artifact: "test",
  hypotheses: [{
    id: "sudo-nopasswd-check",
    title: "Review sudo rules",
    category: "misconfiguration",
    confidence: "high",
    impact: "root",
    evidence_refs: ["sudo_rules"]
  }]
}' > "${priv_dir}/privesc-facts.json"

# shellcheck source=../lib/neo-pipeline-hooks.sh
source "${NEO_DIR}/lib/neo-pipeline-hooks.sh"

! neo_pipeline_offer_privesc_rank "${project}" && ok 'non-interactive skips rank offer' || bad 'should skip interactive'

bash "${NEO_DIR}/privesc/rank-privesc-plan.sh" \
    --input "${priv_dir}/privesc-facts.json" \
    --output "${priv_dir}/privesc-plan.json"

[[ -f "${priv_dir}/privesc-plan.json" ]] && ok 'rank plan written' || bad 'rank plan missing'
jq -e '.ranked_items|length > 0' "${priv_dir}/privesc-plan.json" >/dev/null \
    && ok 'ranked items present' || bad 'no ranked items'

rm -rf "${NEO_STATE_ROOT}" 2>/dev/null || true
printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
