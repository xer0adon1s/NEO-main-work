#!/usr/bin/env bash
# menu-routing-test.sh — pause-menu letter routing (neo_menu_classify), offline.
#
# Covers the Phase 48 fix: every menu letter maps to exactly one action regardless of
# case, and neo.sh's two menu loops (neo_post_phase_menu, the pause_before script-choice
# block) both actually dispatch through neo_menu_classify() rather than matching raw
# letters independently (which is how [a]/[A] and [s]/[S] drifted into meaning different
# things the first time). Exercises the real function neo.sh sources, not a copy of it.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-menu.sh
source "${NEO_DIR}/lib/neo-menu.sh"

pass=0
fail=0

ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'menu-routing-test.sh\n\n'

assert_classify() {
    local input="$1" expect="$2" got
    got="$(neo_menu_classify "${input}")"
    [[ "${got}" == "${expect}" ]] \
        && ok "classify '${input}' -> ${expect}" \
        || bad "classify '${input}' -> expected ${expect}, got ${got}"
}

# --- every letter, both cases, must classify to exactly one action ---
assert_classify c continue
assert_classify C continue
assert_classify a ask-claude
assert_classify A ask-claude
assert_classify b assimilate
assert_classify B assimilate
assert_classify p payload-suggest
assert_classify P payload-suggest
assert_classify z analyze-failures
assert_classify Z analyze-failures
assert_classify d deep-enum
assert_classify D deep-enum
assert_classify r repeat
assert_classify R repeat
assert_classify s skip-to-step
assert_classify S skip-to-step
assert_classify k skip-phase
assert_classify K skip-phase
assert_classify q quit
assert_classify Q quit

# --- unmatched input (numeric script choices, garbage, empty) falls through cleanly ---
assert_classify 1 unmatched
assert_classify x unmatched
assert_classify "" unmatched

# --- no two distinct actions can share a letter (would mean an old case-sensitive-split
#     regression crept back in) ---
declare -A seen_actions=()
collision=false
for letter in c C a A b B p P z Z d D r R s S k K q Q; do
    action="$(neo_menu_classify "${letter}")"
    lower="$(tr '[:upper:]' '[:lower:]' <<< "${letter}")"
    if [[ -n "${seen_actions[${lower}]:-}" && "${seen_actions[${lower}]}" != "${action}" ]]; then
        bad "letter '${lower}' classifies inconsistently: '${seen_actions[${lower}]}' vs '${action}'"
        collision=true
    fi
    seen_actions["${lower}"]="${action}"
done
${collision} || ok "no letter classifies inconsistently by case"

# --- neo.sh's two menu case statements must actually dispatch via neo_menu_classify,
#     not raw letters again — this is the exact class of drift Phase 48 fixed ---
neo_sh="${NEO_ROOT}/neo.sh"
case_count="$(grep -c 'case "\$(neo_menu_classify "\${choice}")" in' "${neo_sh}" || true)"
((case_count >= 2)) \
    && ok "neo.sh has >=2 case blocks dispatching via neo_menu_classify (found ${case_count})" \
    || bad "expected neo.sh's two menu loops to both use neo_menu_classify — found ${case_count}"

# A stray raw `a|A)` / `s|S)` case arm reappearing anywhere in neo.sh (outside this
# guard's own line) would mean someone bypassed the shared classifier again.
raw_arms="$(grep -nE '^\s*(a\|A|s\|S)\)' "${neo_sh}" || true)"
[[ -z "${raw_arms}" ]] \
    && ok "no raw a|A or s|S case arms left in neo.sh (all routed through neo_menu_classify)" \
    || bad "found raw letter case arms bypassing neo_menu_classify:
${raw_arms}"

bash -n "${NEO_DIR}/lib/neo-menu.sh" && ok "syntax: lib/neo-menu.sh" || bad "syntax: lib/neo-menu.sh"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
