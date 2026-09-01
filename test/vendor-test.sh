#!/usr/bin/env bash
# vendor-test.sh — neo-vendor manifest CLI (offline).
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_VENDOR_MANIFEST="${NEO_ROOT}/test/tmp/vendor-manifest-$$.json"
export NEO_VENDOR_DIR="${NEO_ROOT}/test/tmp/vendor-$$"
TOOL_REL="test/tmp/vendor-files/sample-tool-$$.txt"
TOOL="${NEO_ROOT}/${TOOL_REL}"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

mkdir -p "${NEO_VENDOR_DIR}/backups" "$(dirname "${TOOL}")"
printf 'version-one' > "${TOOL}"
backup="${NEO_VENDOR_DIR}/backups/sample-test"

bash "${NEO_DIR}/tools/neo-vendor.sh" init >/dev/null
jq --arg dest "${TOOL_REL}" --arg backup "${backup}" \
    '.entries += [{name:"sample", destination:$dest, kind:"vendor", package:"sample", backup_path:$backup}]' \
    "${NEO_VENDOR_MANIFEST}" > "${NEO_VENDOR_MANIFEST}.tmp"
mv "${NEO_VENDOR_MANIFEST}.tmp" "${NEO_VENDOR_MANIFEST}"

[[ -f "${NEO_VENDOR_MANIFEST}" ]] && ok 'init creates manifest' || bad 'init manifest'
count="$(jq '.entries|length' "${NEO_VENDOR_MANIFEST}")"
(( count >= 5 )) && ok "manifest entries (${count})" || bad "entry count ${count}"

bash "${NEO_DIR}/tools/neo-vendor.sh" inventory >/dev/null && ok 'inventory runs' || bad 'inventory'

cp -a "${TOOL}" "${backup}"
printf 'version-two' > "${TOOL}"
bash "${NEO_DIR}/tools/neo-vendor.sh" rollback sample >/dev/null && ok 'rollback runs' || bad 'rollback'
grep -q 'version-one' "${TOOL}" && ok 'rollback restored content' || bad 'rollback content'

bash "${NEO_DIR}/tools/neo-vendor.sh" rollback nmap >/dev/null && ok 'rollback no backup ok' || bad 'rollback no backup'

bash -n "${NEO_DIR}/tools/neo-vendor.sh" && ok 'syntax neo-vendor' || bad 'syntax'

rm -rf "${NEO_VENDOR_DIR}" "${TOOL}" "${NEO_VENDOR_MANIFEST}" 2>/dev/null || true
printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
