#!/usr/bin/env bash
# borg-library-ingest-test.sh — offline tests for library ingest + lookup.

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-borg-library.sh
source "${NEO_DIR}/lib/neo-borg-library.sh"
# shellcheck source=../lib/neo-borg-disclosure.sh
source "${NEO_DIR}/lib/neo-borg-disclosure.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'borg-library-ingest-test.sh\n\n'

[[ -f "${NEO_DIR}/knowledge/library/INDEX.yaml" ]] && ok "INDEX.yaml present" || bad "INDEX.yaml"
[[ -f "${NEO_DIR}/knowledge/library/methods/redis-unauth-rce/educational.md" ]] \
    && ok "seed method redis-unauth-rce" || bad "seed method"
[[ -f "${NEO_DIR}/knowledge/library/walkthroughs/htb/apache-path-traversal-example/paths/cve-2021-41773-chain/educational.md" ]] \
    && ok "seed walkthrough path" || bad "seed walkthrough"

mapfile -t cves < <(neo_borg_library_extract_cves "Apache CVE-2021-41773 and CVE-2021-42013")
((${#cves[@]} >= 2)) && ok "CVE extract: ${#cves[@]}" || bad "CVE extract"

matches="$(neo_borg_library_find_by_cve CVE-2021-41773 | head -1)"
[[ -n "${matches}" ]] && ok "library find by CVE" || bad "find by CVE"

neo_borg_disclosure_check educational "$(cat "${NEO_DIR}/knowledge/library/methods/redis-unauth-rce/educational.md")" \
    && ok "seed passes educational lint" || bad "seed lint"

bash -n "${NEO_DIR}/tools/borg-library-ingest.sh" && ok "ingest syntax" || bad "ingest syntax"
bash -n "${NEO_DIR}/tools/neo-report-export.sh" && ok "pdf export syntax" || bad "pdf syntax"
[[ -f "${NEO_DIR}/schemas/library-walkthrough.schema.json" ]] && ok "walkthrough schema" || bad "schema"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
