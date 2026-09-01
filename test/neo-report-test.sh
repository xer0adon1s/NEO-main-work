#!/usr/bin/env bash
# neo-report-test.sh — offline tests for final report helpers.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/notes-lib.sh
source "${NEO_DIR}/lib/notes-lib.sh"
# shellcheck source=../lib/neo-report.sh
source "${NEO_DIR}/lib/neo-report.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'neo-report-test.sh\n\n'

neo_report_menu_visible post && ok "visible on post" || bad "post visible"
neo_report_menu_visible recon && bad "hidden on recon" || ok "hidden on recon"

frag="$(neo_report_menu_fragment post)"
[[ "${frag}" == *"[f]write report"* ]] && ok "menu fragment" || bad "fragment: ${frag}"

tmp="$(mktemp -d)"
export NEO_HOME="${tmp}/Neo"
export NEO_DIR="${NEO_HOME}"
mkdir -p "${NEO_HOME}/projects/r"
NOTES_FILE="${NEO_HOME}/projects/r/Investigation-Notes.md"
cp "${NEO_ROOT}/templates/investigation-notes.md" "${NOTES_FILE}"
meta_init r 10.10.10.5 "${NEO_HOME}/projects/r"
OUTDIR="${NEO_HOME}/projects/r"
notes_set_section PORTS $'```text\n22/tcp open ssh\n```' 2>/dev/null || true

bundle="$(neo_report_build_bundle r)"
[[ "${bundle}" == *"22/tcp"* && "${bundle}" == *"DISCLOSURE MODE: EDUCATIONAL"* ]] \
    && ok "bundle includes ports + educational disclosure" || bad "bundle content"

prof="$(neo_report_system_prompt r)"
[[ "${prof}" == *"book report"* || "${prof}" == *"learning report"* ]] \
    && ok "educational system prompt" || bad "educational prompt"

export NEO_ENGAGEMENT_MODE=professional
prof="$(neo_report_system_prompt r)"
[[ "${prof}" == *"client-deliverable"* ]] && ok "professional system prompt" || bad "professional prompt"
unset NEO_ENGAGEMENT_MODE

bash -n "${NEO_ROOT}/lib/neo-report.sh" && ok "syntax neo-report" || bad "syntax"
bash -n "${NEO_ROOT}/tools/neo-report.sh" && ok "syntax tool" || bad "syntax tool"

rm -rf "${tmp}"
printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
