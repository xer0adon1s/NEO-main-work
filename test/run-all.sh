#!/usr/bin/env bash
# Aggregate test runner — CORE unit tests, integrity gate, v0.5 suites, diagnostic.
set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${NEO_ROOT}"
failed=0

run_suite() {
    local label="$1" script="$2"
    printf '\n== %s ==\n' "${label}"
    if bash "${script}"; then
        return 0
    fi
    failed=$((failed + 1))
    return 1
}

printf 'NEO test aggregate — %s\n' "${NEO_ROOT}"

for test_file in \
    "${NEO_ROOT}/test/core-secrets-test.sh" \
    "${NEO_ROOT}/test/mission-state-test.sh" \
    "${NEO_ROOT}/test/secret-canary-test.sh" \
    "${NEO_ROOT}/test/injection-payload-test.sh" \
    "${NEO_ROOT}/test/workflow-scope-test.sh"; do
    run_suite "$(basename "${test_file}")" "${test_file}" || true
done

run_suite 'workbench-test' "${NEO_ROOT}/test/workbench-test.sh" || true

run_suite 'toolkit-test' "${NEO_ROOT}/test/toolkit-test.sh" || true

run_suite 'exploit-framework-test' "${NEO_ROOT}/test/exploit-framework-test.sh" || true

run_suite 'plan-enum-hook-test' "${NEO_ROOT}/test/plan-enum-hook-test.sh" || true

run_suite 'privesc-rank-hook-test' "${NEO_ROOT}/test/privesc-rank-hook-test.sh" || true

run_suite 'vendor-test' "${NEO_ROOT}/test/vendor-test.sh" || true

run_suite 'session-adapter-test' "${NEO_ROOT}/test/session-adapter-test.sh" || true

run_suite 'eli5-test' "${NEO_ROOT}/test/eli5-test.sh" || true

run_suite 'doc-truth-check' "${NEO_ROOT}/tools/doc-truth-check.sh" || true

run_suite 'production-integrity-gate' "${NEO_ROOT}/test/production-integrity-gate.sh" || true

for test_file in \
    notes-lib-test.sh \
    recon-bundle-test.sh \
    borg-test.sh \
    payload-test.sh \
    neo-boot-test.sh \
    menu-routing-test.sh \
    interact-test.sh \
    neo-tmux-test.sh \
    neo-tmux-integration-test.sh \
    neo-smoke-test.sh; do
    [[ -f "${NEO_ROOT}/test/${test_file}" ]] || continue
    run_suite "${test_file}" "${NEO_ROOT}/test/${test_file}" || true
done

printf '\n== bash -n (repo .sh syntax) ==\n'
syn_fail=0
while IFS= read -r -d '' script; do
    bash -n "${script}" || { printf '  [FAIL] syntax: %s\n' "${script#${NEO_ROOT}/}" >&2; syn_fail=$((syn_fail + 1)); }
done < <(find "${NEO_ROOT}" -path "${NEO_ROOT}/vendor" -prune -o -path "${NEO_ROOT}/NEO-1.0-DESIGN" -prune -o \
    -type f -name '*.sh' -print0 2>/dev/null)
(( syn_fail == 0 )) || failed=$((failed + 1))

printf '\nAggregate suites failed: %d\n' "${failed}"
(( failed == 0 ))
