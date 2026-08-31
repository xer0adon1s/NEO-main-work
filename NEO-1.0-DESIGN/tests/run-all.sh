#!/usr/bin/env bash
# Run all NEO 1.0 design workspace validation (prototype + doc checks).
set -uo pipefail

DESIGN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTOTYPE="${DESIGN_ROOT}/prototype/neo-next"
failed=0

printf '== NEO 1.0 Design Validation ==\n'
printf 'Design root: %s\n\n' "${DESIGN_ROOT}"

# Manifest completeness
for f in MASTER-MANIFEST.yaml INTEGRATION-PLAN.md IMPLEMENTATION-ROADMAP.md PROGRESS.md; do
    [[ -f "${DESIGN_ROOT}/${f}" ]] && printf 'OK  %s\n' "${f}" || { printf 'MISSING %s\n' "${f}"; failed=1; }
done

# All projects have DESIGN.md
for d in "${DESIGN_ROOT}"/projects/*/; do
    proj="$(basename "${d}")"
    if [[ -f "${d}/DESIGN.md" || -f "${d}/project.yaml" && "${proj}" == "01-baseline-and-traceability" ]]; then
        [[ -f "${d}/DESIGN.md" || -f "${d}/CURRENT-STATE.md" ]] && printf 'OK  projects/%s\n' "${proj}" \
            || { printf 'MISSING design docs in %s\n' "${proj}"; failed=1; }
    else
        [[ -f "${d}/DESIGN.md" ]] && printf 'OK  projects/%s/DESIGN.md\n' "${proj}" \
            || { printf 'MISSING projects/%s/DESIGN.md\n' "${proj}"; failed=1; }
    fi
done

# P01 required outputs
for f in CURRENT-STATE.md REQUIREMENTS-TRACEABILITY.yaml DISCREPANCIES.yaml WORKFLOW-MAP.md HISTORY-INGESTION.md; do
    [[ -f "${DESIGN_ROOT}/projects/01-baseline-and-traceability/${f}" ]] \
        && printf 'OK  P01/%s\n' "${f}" || { printf 'MISSING P01/%s\n' "${f}"; failed=1; }
done

printf '\n== Prototype test suites (requires Bash) ==\n'
if command -v bash >/dev/null 2>&1; then
    bash "${PROTOTYPE}/test/run-all.sh" || failed=1
    bash "${PROTOTYPE}/tools/doc-truth-check.sh" || failed=1
    printf '\n== Production integrity gate (expect FAIL on v0.5) ==\n'
    bash "${PROTOTYPE}/test/production-integrity-gate.sh" || printf '(expected failure on v0.5 snapshot)\n'
else
    printf 'SKIP bash not available on this host\n'
fi

printf '\nDesign validation failed: %d\n' "${failed}"
(( failed == 0 ))
