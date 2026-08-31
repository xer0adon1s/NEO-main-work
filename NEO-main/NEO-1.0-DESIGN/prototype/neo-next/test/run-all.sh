#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

for test_file in \
    "${ROOT}/test/core-secrets-test.sh" \
    "${ROOT}/test/mission-state-test.sh" \
    "${ROOT}/test/action-enumerator-test.sh" \
    "${ROOT}/test/workflow-prototype-test.sh"; do
    printf '\n== %s ==\n' "$(basename "${test_file}")"
    bash "${test_file}" || failed=$((failed + 1))
done

printf '\nSyntax pass\n'
while IFS= read -r script; do
    bash -n "${script}" || failed=$((failed + 1))
done < <(find "${ROOT}" -type f -name '*.sh' -print)

printf '\nPrototype suites failed: %d\n' "${failed}"
(( failed == 0 ))
