#!/usr/bin/env bash
# setup-baseline-test.sh — offline checks for setup.sh audit logic.
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="${NEO_ROOT}/test/tmp/setup-baseline-$$"
pass=0
fail=0
ok()  { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

cleanup() { rm -rf "${TMP}" 2>/dev/null || true; }
trap cleanup EXIT

mkdir -p "${TMP}/vendor"
cp "${NEO_ROOT}/setup.sh" "${TMP}/setup.sh"

# Empty vendor → --check fails
if (cd "${TMP}" && bash ./setup.sh --check >/dev/null 2>&1); then
    bad '--check should fail when vendor/ empty'
else
    ok '--check fails when vendor missing'
fi

# Populate vendor stubs → vendor section passes (baseline may still fail in CI)
for f in linpeas.sh LinEnum.sh pspy32 pspy64 winPEASany.exe winPEASx64.exe; do
    printf 'stub\n' > "${TMP}/vendor/${f}"
done

out="$(cd "${TMP}" && bash ./setup.sh --check --vendor-only 2>&1)" || true
grep -q '\[ok\].*linpeas.sh' <<< "${out}" && ok 'vendor-only audit lists linpeas ok' || bad 'vendor-only audit'
grep -q 'Summary:' <<< "${out}" && ok 'vendor-only summary line' || bad 'vendor-only summary'

bash -n "${NEO_ROOT}/setup.sh" && ok 'setup.sh syntax' || bad 'setup.sh syntax'

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
