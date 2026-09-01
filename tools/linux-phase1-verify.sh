#!/usr/bin/env bash
# linux-phase1-verify.sh — Full Linux verification through Phase 74 (2026-09-01).
#
# Run from repo root OR tools/:
#   bash tools/linux-phase1-verify.sh
#
# Writes: artifacts/linux-phase1-verify-YYYYMMDD-HHMMSS.log
# Email that log back to the operator.

set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${NEO_ROOT}"

TS="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo manual)"
LOG_DIR="${NEO_ROOT}/artifacts"
LOG_FILE="${LOG_DIR}/linux-phase1-verify-${TS}.log"
mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_FILE}") 2>&1

banner() {
    printf '\n%s\n' "================================================================"
    printf '%s\n' "$1"
    printf '%s\n\n' "================================================================"
}

failures=0
step_n=0
total_steps=6

run_step() {
    local label="$1"
    shift
    step_n=$((step_n + 1))
    banner "${step_n}/${total_steps} — ${label}"
    if "$@"; then
        printf '[RESULT] %s — PASS\n' "${label}"
        return 0
    fi
    local rc=$?
    printf '[RESULT] %s — FAIL (exit %s)\n' "${label}" "${rc}"
    failures=$((failures + 1))
    return "${rc}"
}

run_suite() {
    local name="$1" script="$2"
    printf '\n--- %s ---\n' "${name}"
    if bash "${script}"; then
        printf '[ok] %s\n' "${name}"
        return 0
    fi
    local rc=$?
    printf '[FAIL] %s (exit %s)\n' "${name}" "${rc}"
    return "${rc}"
}

run_phase73_74_suites() {
    local rc=0 suite
    local suites=(
        neo-feedback-test.sh
        borg-disclosure-test.sh
        conductor-test.sh
        conductor-automation-test.sh
        borg-library-ai-test.sh
        neo-report-test.sh
    )
    for suite in "${suites[@]}"; do
        [[ -f "${NEO_ROOT}/test/${suite}" ]] || {
            printf '[FAIL] missing test/%s\n' "${suite}"
            rc=1
            continue
        }
        run_suite "${suite}" "${NEO_ROOT}/test/${suite}" || rc=1
    done
    return "${rc}"
}

run_offline_tool_smoke() {
    local rc=0 tmp batch_rc
    printf '\n--- borg-library-harvest --research --dry-run ---\n'
    if bash "${NEO_ROOT}/tools/borg-library-harvest.sh" \
        --research "redis unauthenticated write test topic" --dry-run; then
        printf '[ok] harvest --research --dry-run\n'
    else
        printf '[FAIL] harvest --research --dry-run\n'
        rc=1
    fi

    tmp="$(mktemp -d /tmp/neo-batch-smoke.XXXXXX 2>/dev/null || mktemp -d)"
    mkdir -p "${tmp}/projects/batchbox/assimilated/redis-unauth"
    mkdir -p "${tmp}/projects/batchbox/assimilated/cve-2021-41773-apache"
    printf '\n--- borg-library-harvest --batch --dry-run ---\n'
    if NEO_HOME="${tmp}" NEO_DIR="${NEO_ROOT}" bash "${NEO_ROOT}/tools/borg-library-harvest.sh" \
        --batch --from-project batchbox --dry-run; then
        printf '[ok] harvest --batch --dry-run\n'
    else
        printf '[FAIL] harvest --batch --dry-run\n'
        rc=1
    fi
    rm -rf "${tmp}"

    printf '\n--- Phase 74 lib syntax (bash -n) ---\n'
    local lib
    for lib in \
        neo-conductor.sh neo-conductor-loop.sh neo-conductor-privesc.sh \
        neo-adaptive-scan.sh neo-handler-pane.sh neo-operator-recon-ai.sh \
        neo-report.sh neo-borg-library-ai.sh neo-borg-library.sh neo-borg-library-batch.sh; do
        if bash -n "${NEO_ROOT}/lib/${lib}"; then
            printf '  [ok] lib/%s\n' "${lib}"
        else
            printf '  [FAIL] lib/%s\n' "${lib}"
            rc=1
        fi
    done
    return "${rc}"
}

print_test_manifest() {
    cat <<'EOF'
Test manifest (through Phase 74 — 2026-09-01)
---------------------------------------------
run-all.sh aggregate:
  CORE: core-secrets, mission-state, secret-canary, injection-payload, workflow-scope
  Tier 2.5/3: workbench, toolkit, exploit-framework, plan-enum-hook, privesc-rank-hook
              vendor, session-adapter, eli5
  Borg/library: borg, borg-disclosure, borg-library-ingest, borg-library-ai
                disclosure-lint-all, borg-v2, borg-library-batch
  Conductor: conductor, conductor-automation, neo-feedback, menu-routing, payload, neo-report
  Smoke: neo-boot, interact, neo-tmux, neo-tmux-integration, neo-smoke
  Notes: notes-lib, recon-bundle, production-integrity-gate, p18-lab-e2e, neo-provider-web
  Plus: doc-truth-check, bash -n all .sh

neo-diagnostic.sh: file existence, lib hygiene, babysteps integrity, integrity gate

Phase 73–74 focused: neo-feedback, borg-disclosure, conductor, conductor-automation,
                     borg-library-ai, neo-report

Offline smoke: borg-library-harvest --dry-run, --batch --dry-run, Phase 74 lib bash -n
EOF
}

banner "NEO Linux verification (Phases 1–74)"
printf 'Repo:     %s\n' "${NEO_ROOT}"
printf 'Log file: %s\n' "${LOG_FILE}"
printf 'Date:     %s\n' "$(date -Is 2>/dev/null || date)"
printf 'User:     %s\n' "$(whoami 2>/dev/null || echo unknown)"
printf 'Host:     %s\n' "$(hostname 2>/dev/null || echo unknown)"
printf 'Bash:     %s\n' "${BASH_VERSION:-unknown}"
if command -v git >/dev/null 2>&1 && [[ -d "${NEO_ROOT}/.git" ]]; then
    printf 'Git:      %s\n' "$(git -C "${NEO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    printf 'Branch:   %s\n' "$(git -C "${NEO_ROOT}" branch --show-current 2>/dev/null || echo unknown)"
fi

if [[ ! -f "${NEO_ROOT}/neo.sh" ]]; then
    echo "[FATAL] neo.sh not found — are you in the NEO repo?"
    exit 1
fi

print_test_manifest

chmod +x "${NEO_ROOT}/neo.sh" 2>/dev/null || true
chmod +x "${NEO_ROOT}/test/"*.sh "${NEO_ROOT}/tools/"*.sh 2>/dev/null || true

banner "Preflight"
bash "${NEO_ROOT}/neo.sh" --version || true
if [[ -x "${NEO_ROOT}/setup.sh" ]]; then
    bash "${NEO_ROOT}/setup.sh" --check || \
        printf '[NOTE] setup.sh --check failed — often OK if vendor/ not fetched yet.\n'
else
    printf '[SKIP] setup.sh not found\n'
fi

run_step "test/run-all.sh (full aggregate + bash -n)" \
    bash "${NEO_ROOT}/test/run-all.sh" || true

run_step "test/neo-diagnostic.sh (pre-review gate)" \
    bash "${NEO_ROOT}/test/neo-diagnostic.sh" || true

run_step "tools/doc-truth-check.sh" \
    bash "${NEO_ROOT}/tools/doc-truth-check.sh" || true

run_step "Phase 73–74 focused suites" run_phase73_74_suites || true

run_step "offline tool smoke (harvest dry-run + lib syntax)" run_offline_tool_smoke || true

banner "SUMMARY"
printf 'Steps failed: %d (0 = all main steps passed)\n' "${failures}"
printf '\nFull log saved to:\n  %s\n' "${LOG_FILE}"
printf '\nPlease email that log file back to the operator.\n'
printf 'Failures are OK for triage — send the log either way.\n'
printf '\nOperator optional live smoke (NOT run by this script):\n'
printf '  ./neo.sh scratch-tierb-test <HTB_IP>\n'
printf '  NEO_P18_LAB=1 ./test/p18-lab-e2e.sh\n'

exit "${failures}"
