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
    recon/babysteps.sh recon/analyze-recon.sh borg/borg.sh assets/borg-splash-wide.txt \
    knowledge/README.md knowledge/INDEX.yaml templates/investigation-notes.md; do
    [[ -f "${f}" ]] && ok "exists: ${f}" || bad "missing: ${f}"
done

[[ -f CLAUDE-COLLAB.md ]] && ok "exists: CLAUDE-COLLAB.md (local)" || note "missing: CLAUDE-COLLAB.md (local co-lab brief)"
[[ -f CURSOR-REVIEW-LOG.md ]] && ok "exists: CURSOR-REVIEW-LOG.md (local)" || note "missing: CURSOR-REVIEW-LOG.md (local dev log)"

# --- lib/ should only contain NEO scripts ---
printf '\n--- lib/ hygiene ---\n'
neo_libs=(notes-lib.sh script-lib.sh neo-ai.sh neo-ai-analyze.sh neo-ai-cli.sh neo-splash.sh neo-hud.sh neo-vpn.sh neo-boot.sh neo-borg.sh neo-payload.sh neo-menu.sh neo-tmux.sh neo-interact.sh)
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

# --- Syntax ---
printf '\n--- bash -n ---\n'
syn_fail=0
while IFS= read -r -d '' script; do
    bash -n "${script}" || { bad "syntax: ${script#${NEO_ROOT}/}"; syn_fail=$((syn_fail + 1)); }
done < <(find . -path ./vendor -prune -o -path ./lib/node_modules -prune -o \
    -type f -name '*.sh' ! -path './wordlists/*' -print0 2>/dev/null)
(( syn_fail == 0 )) && ok "all tracked .sh syntax clean (vendor/pruned paths skipped)"

# --- Vendor ---
printf '\n--- setup.sh --check ---\n'
if ./setup.sh --check >/dev/null 2>&1; then
    ok "vendor tools (6/6)"
else
    bad "setup.sh --check failed"
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
