#!/usr/bin/env bash
# vendor-test.sh — neo-vendor manifest CLI (offline).
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_VENDOR_MANIFEST="${NEO_ROOT}/test/tmp/vendor-manifest-$$.json"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

bash "${NEO_DIR}/tools/neo-vendor.sh" init >/dev/null
[[ -f "${NEO_VENDOR_MANIFEST}" ]] && ok 'init creates manifest' || bad 'init manifest'

count="$(jq '.entries|length' "${NEO_VENDOR_MANIFEST}")"
(( count >= 4 )) && ok "seed entries (${count})" || bad "seed count ${count}"

bash "${NEO_DIR}/tools/neo-vendor.sh" inventory >/dev/null && ok 'inventory runs' || bad 'inventory'

bash "${NEO_DIR}/tools/neo-vendor.sh" rollback nmap >/dev/null && ok 'rollback stub ok' || bad 'rollback'

bash -n "${NEO_DIR}/tools/neo-vendor.sh" && ok 'syntax neo-vendor' || bad 'syntax'

rm -f "${NEO_VENDOR_MANIFEST}" 2>/dev/null || true
printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
