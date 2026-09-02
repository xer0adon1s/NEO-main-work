#!/usr/bin/env bash
# neo-diagnostic.sh — pre-review health check (run from repo root).
#
# Usage: ./test/neo-diagnostic.sh

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${NEO_ROOT}"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

pass=0
fail=0
warn=0

ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }
note() { printf '  [warn] %s\n' "$1" >&2; warn=$((warn + 1)); }

printf 'NEO v%s diagnostic — %s\n\n' "$(cat VERSION 2>/dev/null | tr -d '[:space:]' || echo '?')" "${NEO_ROOT}"

for f in neo.sh setup.sh phases.yaml registry.yaml VERSION AGENTS.md README.md \
    lib/notes-lib.sh lib/script-lib.sh lib/neo-ai.sh lib/neo-ai-analyze.sh lib/neo-ai-cli.sh lib/neo-hud.sh lib/neo-splash.sh lib/neo-vpn.sh lib/neo-boot.sh lib/neo-borg.sh lib/neo-payload.sh lib/neo-menu.sh lib/neo-tmux.sh lib/neo-interact.sh \
    lib/neo-core.sh lib/neo-1.0-bootstrap.sh lib/neo-secrets.sh lib/neo-evidence.sh lib/neo-actions.sh lib/neo-mission-state.sh lib/neo-scope.sh lib/neo-provider.sh lib/neo-windup-actions.sh lib/neo-vpn-consent.sh \
    lib/neo-operator-pane.sh lib/neo-workbench.sh lib/neo-toolkit.sh lib/neo-exploit-framework.sh lib/neo-pipeline-hooks.sh lib/neo-eli5.sh \
    tools/neo-secret.sh tools/scope-intake.sh tools/scope-import.sh tools/neo-vendor.sh \
    borg/borg-v2.sh recon/operator-recon.sh recon/plan-enum.sh \
    schemas/action-policy.json schemas/action.schema.json schemas/engagement-scope.schema.json \
    recon/babysteps.sh recon/analyze-recon.sh borg/borg.sh assets/borg-splash-wide.txt \
    knowledge/README.md knowledge/INDEX.yaml templates/investigation-notes.md; do
    [[ -f "${f}" ]] && ok "exists: ${f}" || bad "missing: ${f}"
done

[[ -f docs/collab/CLAUDE-COLLAB.md ]] && ok "exists: docs/collab/CLAUDE-COLLAB.md" \
    || note "missing: docs/collab/CLAUDE-COLLAB.md (co-lab brief)"
[[ -f docs/collab/CURSOR-REVIEW-LOG.md ]] && ok "exists: docs/collab/CURSOR-REVIEW-LOG.md" \
    || note "missing: docs/collab/CURSOR-REVIEW-LOG.md (dev log)"
[[ -f MASTER-CHANGELOG.md ]] && ok "exists: MASTER-CHANGELOG.md" \
    || note "missing: MASTER-CHANGELOG.md (agent milestone log)"

# --- lib/ should only contain NEO scripts ---
printf '\n--- lib/ hygiene ---\n'
neo_libs=(notes-lib.sh script-lib.sh neo-ai.sh neo-ai-analyze.sh neo-ai-cli.sh neo-ai-guard.sh neo-splash.sh neo-hud.sh neo-vpn.sh neo-vpn-consent.sh neo-boot.sh neo-borg.sh neo-borg-disclosure.sh neo-borg-library.sh neo-borg-library-ai.sh neo-borg-harvest.sh neo-borg-v2.sh neo-borg-library-batch.sh neo-payload.sh neo-menu.sh neo-tmux.sh neo-interact.sh neo-core.sh neo-1.0-bootstrap.sh neo-secrets.sh neo-evidence.sh neo-actions.sh neo-mission-state.sh neo-scope.sh neo-provider.sh neo-windup-actions.sh neo-operator-pane.sh neo-handler-pane.sh neo-workbench.sh neo-toolkit.sh neo-exploit-framework.sh neo-pipeline-hooks.sh neo-eli5.sh neo-report.sh neo-conductor.sh neo-conductor-loop.sh neo-conductor-privesc.sh neo-conductor-tuning.sh neo-enum-ai.sh neo-adaptive-scan.sh neo-operator-recon-ai.sh neo-feedback.sh)
for f in "${neo_libs[@]}"; do
    [[ -f "lib/${f}" ]] && ok "neo lib: ${f}" || bad "missing neo lib: ${f}"
done
extra_count=0
while IFS= read -r -d '' extra; do
    base="$(basename "${extra}")"
    skip=false
    for f in "${neo_libs[@]}"; do [[ "${base}" == "${f}" && "${extra}" == "lib/${f}" ]] && skip=true; done
    [[ "${skip}" == true ]] && continue
    extra_count=$((extra_count + 1))
    [[ "${extra_count}" -le 5 ]] && note "unexpected under lib/: ${extra#${NEO_ROOT}/}"
done < <(find lib -mindepth 1 -print0 2>/dev/null || true)
if (( extra_count > 5 )); then
    note "... and $((extra_count - 5)) more non-NEO paths under lib/ — run ./tools/neo-lib-cleanup.sh"
fi
(( extra_count == 0 )) && ok "lib/ contains only NEO scripts"

# --- Production script integrity (not just existence) ---
printf '\n--- production script integrity ---\n'
if [[ -f recon/babysteps.sh ]]; then
    bs_lines="$(wc -l < recon/babysteps.sh | tr -d ' ')"
    if grep -q 'rustscan' recon/babysteps.sh \
        && grep -q 'gobuster dir' recon/babysteps.sh \
        && grep -q 'PROBE_PORTS' recon/babysteps.sh \
        && ! grep -q 'babysteps-stub' recon/babysteps.sh \
        && (( bs_lines >= 400 )); then
        ok "babysteps.sh real recon script (${bs_lines} lines)"
    else
        bad "babysteps.sh is stub or corrupted (${bs_lines} lines) — restore full script"
    fi
else
    bad "missing recon/babysteps.sh"
fi

printf '\n--- NEO 1.0 production integrity gate ---\n'
if bash test/production-integrity-gate.sh >/tmp/neo-diag-integrity-gate.log 2>&1; then
    ok "production-integrity-gate ($(tail -1 /tmp/neo-diag-integrity-gate.log 2>/dev/null || echo pass))"
elif grep -qE '\[ok\]|\[FAIL\]|pass |fail ' /tmp/neo-diag-integrity-gate.log 2>/dev/null; then
    bad "production-integrity-gate ran but failed — see /tmp/neo-diag-integrity-gate.log"
    tail -8 /tmp/neo-diag-integrity-gate.log >&2 || true
else
    bad "production-integrity-gate crashed before running checks — see /tmp/neo-diag-integrity-gate.log"
    tail -8 /tmp/neo-diag-integrity-gate.log >&2 || true
fi

# --- Syntax ---
printf '\n--- bash -n ---\n'
syn_fail=0
while IFS= read -r -d '' script; do
    bash -n "${script}" || { bad "syntax: ${script#${NEO_ROOT}/}"; syn_fail=$((syn_fail + 1)); }
done < <(find . -path ./vendor -prune -o -path ./lib/node_modules -prune -o \
    -type f -name '*.sh' ! -path './wordlists/*' -print0 2>/dev/null)
(( syn_fail == 0 )) && ok "all tracked .sh syntax clean (vendor/pruned paths skipped)"

# --- Vendor ---
printf '\n--- setup.sh --check (baseline + vendor) ---\n'
if ./setup.sh --check >/tmp/neo-diag-setup.log 2>&1; then
    ok "baseline toolset ($(grep -c '\[ok\]' /tmp/neo-diag-setup.log 2>/dev/null || echo ready))"
else
    bad "setup.sh --check — missing tools (run ./setup.sh to install)"
    tail -12 /tmp/neo-diag-setup.log >&2 || true
fi

# --- Tests ---
printf '\n--- test suites ---\n'
run_test() {
    local name="$1" script="$2"
    if bash "${script}" >/tmp/neo-diag-"${name}".log 2>&1; then
        ok "${name} ($(tail -1 /tmp/neo-diag-"${name}".log 2>/dev/null || echo pass))"
    else
        bad "${name} — see /tmp/neo-diag-${name}.log"
        tail -5 /tmp/neo-diag-"${name}".log >&2 || true
    fi
}
run_test "workflow-scope-test" test/workflow-scope-test.sh
run_test "core-secrets-test" test/core-secrets-test.sh
run_test "secret-canary-test" test/secret-canary-test.sh
run_test "injection-payload-test" test/injection-payload-test.sh
run_test "mission-state-test" test/mission-state-test.sh
run_test "notes-lib-test" test/notes-lib-test.sh
run_test "recon-bundle-test" test/recon-bundle-test.sh
run_test "borg-test" test/borg-test.sh
run_test "payload-test" test/payload-test.sh
run_test "neo-boot-test" test/neo-boot-test.sh
run_test "menu-routing-test" test/menu-routing-test.sh
run_test "interact-test" test/interact-test.sh
run_test "neo-tmux-test" test/neo-tmux-test.sh
run_test "neo-tmux-integration-test" test/neo-tmux-integration-test.sh
run_test "neo-smoke-test" test/neo-smoke-test.sh
run_test "workbench-test" test/workbench-test.sh
run_test "toolkit-test" test/toolkit-test.sh
run_test "exploit-framework-test" test/exploit-framework-test.sh
run_test "plan-enum-hook-test" test/plan-enum-hook-test.sh
run_test "privesc-rank-hook-test" test/privesc-rank-hook-test.sh
run_test "vendor-test" test/vendor-test.sh
run_test "session-adapter-test" test/session-adapter-test.sh
run_test "eli5-test" test/eli5-test.sh

# --- Borg HUD (Phase 60) ---
printf '\n--- Borg HUD ---\n'
hud_frame="$(awk '/^neo_borg_hud_frame\(\)/,/^neo_borg_hud_start\(\)/' lib/neo-borg.sh)"
if grep -q 'resistance is futile' <<< "${hud_frame}"; then
    bad 'Borg HUD tagline still inside animation tick'
else
    ok 'Borg HUD tagline not in animation tick'
fi
grep -q 'resistance is futile' lib/neo-borg.sh \
    && ok 'Borg HUD tagline shown once at start' \
    || note 'Borg HUD tagline removed entirely'

# --- Config (no secrets) ---
printf '\n--- operator config ---\n'
if [[ -d "${HOME}/.config/neo" ]]; then
    while IFS= read -r f; do
        [[ -n "${f}" ]] && ok "config: $(basename "${f}") ($(stat -c%s "${f}" 2>/dev/null || echo ?) bytes)"
    done < <(find "${HOME}/.config/neo" -maxdepth 1 -type f 2>/dev/null)
else
    note "no ~/.config/neo yet"
fi

printf '\n--- projects/ ---\n'
if [[ -d projects ]]; then
    proj_count=$(find projects -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    ok "projects/ (${proj_count} mission dir(s))"
else
    bad "projects/ missing"
fi

printf '\n%d ok, %d fail, %d warn\n' "${pass}" "${fail}" "${warn}"
if (( fail == 0 )); then
    ver="$(cat VERSION 2>/dev/null | tr -d '[:space:]' || echo '?')"
    printf '\nNEO v%s — READY for Claude review.\n' "${ver}"
    exit 0
fi
printf '\nNOT READY — fix failures above.\n'
exit 1
