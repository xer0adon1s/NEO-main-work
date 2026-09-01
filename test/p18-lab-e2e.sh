#!/usr/bin/env bash
# p18-lab-e2e.sh — P18 lab E2E harness (Wave 5 / B12).
#
# Full live validation requires NEO_P18_LAB=1 on a Linux attack box with HTB VPN.
# Offline mode validates harness + checklist only.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

pass=0
fail=0
skip=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }
skp()  { printf '  [skip] %s\n' "$1"; skip=$((skip + 1)); }

printf 'p18-lab-e2e.sh — NEO conductor E2E harness\n\n'

[[ -x "${NEO_DIR}/neo.sh" ]] && ok "neo.sh executable" || bad "neo.sh"
[[ -f "${NEO_DIR}/NEO-1.0-DESIGN/TIER-B-PLAN.md" ]] && ok "tier-b plan doc" || bad "plan doc"

checklist=(
    "Boot: engagement_mode educational → guided conductor"
    "Recon: speed scan + AI triage + adaptive targets offer"
    "Borg: assimilate vector + optional library hook"
    "Foothold: assisted/professional workbench loop + batch failure review at cap"
    "Privesc: AI triage after FindPrivs + workbench loop"
    "Post: MSF AI suggest + final report disclosure lint"
)

printf 'E2E checklist (manual on lab):\n'
for item in "${checklist[@]}"; do
    printf '  - [ ] %s\n' "${item}"
done
printf '\n'

if [[ "${NEO_P18_LAB:-0}" == "1" ]]; then
    ok "NEO_P18_LAB=1 — run ./neo.sh <scratch-project> <target> interactively on lab"
    printf '  Operator: complete one HTB easy box using conductor loop; log in CURSOR-REVIEW-LOG Phase P18.\n'
else
    skp "live lab boxes (set NEO_P18_LAB=1 on Linux HTB)"
fi

printf '\n%d passed, %d failed, %d skipped\n' "${pass}" "${fail}" "${skip}"
(( fail == 0 ))
