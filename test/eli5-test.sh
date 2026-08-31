#!/usr/bin/env bash
# eli5-test.sh — ELI5 tutor module (offline).
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_TEST_NONINTERACTIVE=1

# shellcheck source=../lib/neo-menu.sh
source "${NEO_DIR}/lib/neo-menu.sh"
# shellcheck source=../lib/neo-eli5.sh
source "${NEO_DIR}/lib/neo-eli5.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'eli5-test.sh\n\n'

[[ "$(neo_menu_classify e)" == eli5 ]] && ok 'e -> eli5' || bad 'e -> eli5'
[[ "$(neo_menu_classify E)" == eli5 ]] && ok 'E -> eli5' || bad 'E -> eli5'

prompt="$(neo_eli5_system_prompt foothold)"
[[ "${prompt}" == *'Command walkthrough'* && "${prompt}" == *ELI5* ]] \
    && ok 'system prompt sections' || bad 'system prompt'

[[ -f "${NEO_ROOT}/templates/investigation-notes.md" ]] \
    && grep -q 'SECTION:ELI5' "${NEO_ROOT}/templates/investigation-notes.md" \
    && ok 'template ELI5 section' || bad 'template ELI5 section'

bundle="$(NEO_HOME="${NEO_ROOT}" OUTDIR="${NEO_ROOT}/test/tmp-eli5" NOTES_FILE="${NEO_ROOT}/test/tmp-eli5/notes.md" \
    mkdir -p "${NEO_ROOT}/test/tmp-eli5" && \
    printf '<!-- SECTION:PAYLOAD -->\n## Exact next command\n```\ncurl -s http://10.0.0.1/\n```\n<!-- /SECTION:PAYLOAD -->' > "${NEO_ROOT}/test/tmp-eli5/notes.md" && \
    neo_eli5_build_bundle test-box foothold 'curl -s http://10.0.0.1/' 2>/dev/null || true)"
[[ "${bundle}" == *'curl -s'* && "${bundle}" == *'ELI5 teaching request'* ]] \
    && ok 'bundle includes focus' || bad 'bundle build'

focus="$(mkdir -p "${NEO_ROOT}/projects/eli5-fixture" && \
    printf '<!-- SECTION:PAYLOAD -->\n## Exact next command\n```\nnc -lvnp 4444\n```\n<!-- /SECTION:PAYLOAD -->' \
    > "${NEO_ROOT}/projects/eli5-fixture/Investigation-Notes.md" && \
    neo_eli5_extract_focus eli5-fixture 2>/dev/null || true)"
[[ "${focus}" == *'nc -lvnp 4444'* ]] && ok 'extract focus from payload' || bad 'extract focus'
rm -rf "${NEO_ROOT}/projects/eli5-fixture" "${NEO_ROOT}/test/tmp-eli5" 2>/dev/null || true

grep -q 'neo_eli5_at_pause\|eli5)' "${NEO_ROOT}/neo.sh" \
    && ok 'neo.sh dispatches eli5' || bad 'neo.sh eli5 dispatch'

grep -q 'NEO_PAUSE_HAS_ELI5' "${NEO_ROOT}/neo.sh" \
    && ok 'pause extras includes ELI5' || bad 'pause extras ELI5'

bash -n "${NEO_DIR}/lib/neo-eli5.sh" && ok 'syntax neo-eli5.sh' || bad 'syntax'

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
