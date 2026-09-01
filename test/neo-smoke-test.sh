#!/usr/bin/env bash
# neo-smoke-test.sh — end-to-end neo.sh walk with stub scripts (no network/tmux).

set -euo pipefail

REAL_NEO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d /tmp/neo-smoke.XXXXXX)"
trap 'rm -rf "${WORKDIR}"' EXIT

pass=0
fail=0

assert() {
    local desc="$1"
    shift
    if "$@"; then
        printf '  [ok] %s\n' "${desc}"
        pass=$((pass + 1))
    else
        printf '  [FAIL] %s\n' "${desc}" >&2
        fail=$((fail + 1))
    fi
}

setup_worktree() {
    mkdir -p "${WORKDIR}"/{lib,recon,foothold,privesc,tools,connect,projects,templates}

    cp "${REAL_NEO}/templates/investigation-notes.md" "${WORKDIR}/templates/"
    cp "${REAL_NEO}/neo.sh" "${REAL_NEO}/phases.yaml" "${REAL_NEO}/registry.yaml" "${WORKDIR}/"
    cp "${REAL_NEO}"/lib/*.sh "${WORKDIR}/lib/"
    cp "${REAL_NEO}/tools/status.sh" "${WORKDIR}/tools/"

    cat > "${WORKDIR}/recon/babysteps.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
NEO_HOME="${NEO_HOME:?}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
source "${NEO_DIR}/lib/notes-lib.sh"
PROJECT="" TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project=*) PROJECT="${1#*=}"; shift ;;
        --quick|--speed|--deep) shift ;;
        --reuse) shift ;;
        -*) echo "babysteps-stub: unknown option $1" >&2; exit 1 ;;
        *) TARGET="$1"; shift ;;
    esac
done
[[ -n "${PROJECT}" && -n "${TARGET}" ]] || exit 1
OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
notes_init "${PROJECT}" "${TARGET}" "${OUTDIR}"
meta_set phase recon
notes_refresh_status "babysteps-stub" "smoke recon complete"
exit 0
STUB

    cat > "${WORKDIR}/recon/analyze-recon.sh" <<'STUB'
#!/usr/bin/env bash
# smoke stub — real script needs ANTHROPIC_API_KEY
exit 0
STUB

    cat > "${WORKDIR}/foothold/ListenAssist.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
NEO_HOME="${NEO_HOME:?}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
source "${NEO_DIR}/lib/notes-lib.sh"
PROJECT="${3:-}"
[[ -n "${PROJECT}" ]] || exit 1
OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
meta_set phase foothold
notes_refresh_status "ListenAssist-stub" "smoke foothold complete"
exit 0
STUB

    cat > "${WORKDIR}/privesc/run-findprivs.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
NEO_HOME="${NEO_HOME:?}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
source "${NEO_DIR}/lib/notes-lib.sh"
project="$1"
OUTDIR="${NEO_HOME}/projects/${project}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
sample=$'=== System identity ===\nuid=1000(smoke)\n\n=== sudo privileges ===\n(smoke) NOPASSWD: ALL\n\n=== VERDICT ===\nSmoke privesc path.\n'
notes_ingest "FindPrivs" "" "${sample}"
meta_set phase privesc
notes_refresh_status "run-findprivs-stub" "smoke privesc complete"
exit 0
STUB

    chmod +x "${WORKDIR}/recon/babysteps.sh" \
        "${WORKDIR}/recon/analyze-recon.sh" \
        "${WORKDIR}/foothold/ListenAssist.sh" \
        "${WORKDIR}/privesc/run-findprivs.sh" \
        "${WORKDIR}/tools/status.sh"
}

PHASES_YAML="${REAL_NEO}/phases.yaml"

phase_val() {
    local phase="$1" field="$2"
    awk -v p="${phase}:" -v f="${field}:" '
        $0 == p { found=1; next }
        found && /^[a-z]+:/ { exit }
        found && index($0, "  " f) == 1 {
            sub(/^  [^:]+:[[:space:]]*/, "")
            gsub(/^>[[:space:]]-?[[:space:]]*/, "")
            print
            exit
        }
    ' "${PHASES_YAML}"
}

recon_prompt="$(phase_val recon prompt_after)"
assert "recon prompt not broken YAML" test "${recon_prompt}" != ">-"
assert "recon prompt has text" grep -q 'Recon complete' <<< "${recon_prompt}"

setup_worktree
export NEO_HOME="${WORKDIR}"
export NEO_DIR="${WORKDIR}"
export NEO_AI=0
export NEO_SPLASH=0
export NEO_HUD=0
PROJECT="neo-smoke-box"
TARGET="10.99.99.99"
MF="${WORKDIR}/projects/${PROJECT}/project.meta"

printf 'c\n1\nc\n1\nsmoke@10.99.99.99\nY\nc\nc\n' \
    | bash "${WORKDIR}/neo.sh" "${PROJECT}" "${TARGET}"

assert "project created" test -f "${MF}"
assert "notes created" test -f "${WORKDIR}/projects/${PROJECT}/Investigation-Notes.md"
assert "mission ended at post" grep -q '^phase=post' "${MF}"
assert "manual ai mode saved" grep -q '^ai_triage=manual' "${MF}"
assert "ssh_target cached" grep -q '^ssh_target=smoke@10.99.99.99' "${MF}"
assert "target IP in notes from recon" grep -q '10.99.99.99' "${WORKDIR}/projects/${PROJECT}/Investigation-Notes.md"
assert "final STATUS from privesc stub" grep -q 'run-findprivs-stub' "${WORKDIR}/projects/${PROJECT}/Investigation-Notes.md"
assert "privesc ingest in notes" grep -q 'Smoke privesc path' "${WORKDIR}/projects/${PROJECT}/Investigation-Notes.md"

# A/B/C startup prompt — choice C saves manual mode (no NEO_AI=0 bypass)
setup_worktree
export NEO_HOME="${WORKDIR}"
export NEO_DIR="${WORKDIR}"
unset NEO_AI
export NEO_SPLASH=0 NEO_HUD=0
PROJECT="neo-abc-manual"
TARGET="10.99.99.94"
MF="${WORKDIR}/projects/${PROJECT}/project.meta"

printf 'C\nq\n' | bash "${WORKDIR}/neo.sh" "${PROJECT}" "${TARGET}"
assert "ABC prompt C saves manual" grep -q '^ai_triage=manual' "${MF}"

setup_worktree
export NEO_HOME="${WORKDIR}"
export NEO_DIR="${WORKDIR}"
export NEO_AI=0 NEO_SPLASH=0 NEO_HUD=0
PROJECT="neo-checkpoint-box"
TARGET="10.99.99.97"
MF="${WORKDIR}/projects/${PROJECT}/project.meta"
RUNS="${WORKDIR}/babysteps.runs"

cat > "${WORKDIR}/recon/babysteps.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
NEO_HOME="${NEO_HOME:?}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
source "${NEO_DIR}/lib/notes-lib.sh"
PROJECT="" TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project=*) PROJECT="${1#*=}"; shift ;;
        --reuse|--speed|--deep) shift ;;
        -*) shift ;;
        *) TARGET="$1"; shift ;;
    esac
done
OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
notes_init "${PROJECT}" "${TARGET:-10.0.0.1}" "${OUTDIR}" 2>/dev/null || true
echo 1 >> "${NEO_HOME}/babysteps.runs"
exit 0
STUB
chmod +x "${WORKDIR}/recon/babysteps.sh"

printf 'q\n' | bash "${WORKDIR}/neo.sh" "${PROJECT}" "${TARGET}"
assert "checkpoint saved on quit" grep -q '^neo_checkpoint=recon:menu:0' "${MF}"
assert "paused at recon menu" grep -q '^phase=recon' "${MF}"
assert "babysteps ran once before quit" test "$(wc -l < "${RUNS}" | tr -d ' ')" = "1"

printf 'c\n1\nc\n1\nchk@10.99.99.97\nY\nc\nc\n' \
    | bash "${WORKDIR}/neo.sh" "${PROJECT}"
assert "resume at menu skips re-running babysteps" test "$(wc -l < "${RUNS}" | tr -d ' ')" = "1"

setup_worktree
export NEO_HOME="${WORKDIR}"
export NEO_DIR="${WORKDIR}"
export NEO_AI=0 NEO_SPLASH=0 NEO_HUD=0 NEO_SESSION_PROMPT=0
PROJECT="neo-fresh-box"
TARGET="10.99.99.95"
MF="${WORKDIR}/projects/${PROJECT}/project.meta"
RUNS="${WORKDIR}/babysteps.runs"
rm -f "${RUNS}"

cat > "${WORKDIR}/recon/babysteps.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
NEO_HOME="${NEO_HOME:?}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
source "${NEO_DIR}/lib/notes-lib.sh"
PROJECT="" TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project=*) PROJECT="${1#*=}"; shift ;;
        --reuse|--speed|--deep) shift ;;
        -*) shift ;;
        *) TARGET="$1"; shift ;;
    esac
done
OUTDIR="${NEO_HOME}/projects/${PROJECT}"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
notes_init "${PROJECT}" "${TARGET:-10.0.0.1}" "${OUTDIR}" 2>/dev/null || true
notes_set_section PORTS "22/tcp open ssh" 2>/dev/null || true
echo 1 >> "${NEO_HOME}/babysteps.runs"
exit 0
STUB
chmod +x "${WORKDIR}/recon/babysteps.sh"

printf 'q\n' | bash "${WORKDIR}/neo.sh" "${PROJECT}" "${TARGET}"
assert "checkpoint before fresh" grep -q '^neo_checkpoint=recon:menu:0' "${MF}"

printf 'C\nc\n1\nc\n1\nfresh@10.99.99.95\nY\nc\nc\n' \
    | bash "${WORKDIR}/neo.sh" "${PROJECT}" "${TARGET}" --fresh
assert "fresh re-runs babysteps" test "$(wc -l < "${RUNS}" | tr -d ' ')" = "2"
assert "fresh re-prompts ai mode" grep -q '^ai_triage=manual' "${MF}"
assert "fresh resets phase to recon path" grep -q '^phase=post' "${MF}"

setup_worktree
export NEO_HOME="${WORKDIR}"
export NEO_DIR="${WORKDIR}"
export NEO_AI=0 NEO_SPLASH=0 NEO_HUD=0
PROJECT="neo-resume-box"
TARGET="10.99.99.98"

printf 'c\nq\n' | bash "${WORKDIR}/neo.sh" "${PROJECT}" "${TARGET}"
assert "paused at foothold" grep -q '^phase=foothold' "${WORKDIR}/projects/${PROJECT}/project.meta"

printf 'k\nc\n1\nresume@10.99.99.98\nY\nc\nc\n' \
    | bash "${WORKDIR}/neo.sh" "${PROJECT}"
assert "resume completed" grep -q '^phase=post' "${WORKDIR}/projects/${PROJECT}/project.meta"

setup_worktree
export NEO_HOME="${WORKDIR}"
export NEO_DIR="${WORKDIR}"
export NEO_AI=0 NEO_SPLASH=0 NEO_HUD=0
PROJECT="neo-jump-box"
TARGET="10.99.99.96"

printf 'c\ns\n3\n1\njump@10.99.99.96\nY\nc\nc\n' \
    | bash "${WORKDIR}/neo.sh" "${PROJECT}" "${TARGET}"
assert "skip to step reaches privesc" grep -q 'run-findprivs-stub' "${WORKDIR}/projects/${PROJECT}/Investigation-Notes.md"

setup_worktree
export NEO_HOME="${WORKDIR}"
export NEO_DIR="${WORKDIR}"
export NEO_AI=0 NEO_SPLASH=0 NEO_HUD=0
PROJECT="neo-fail-box"

cat > "${WORKDIR}/privesc/run-findprivs.sh" <<'STUB'
#!/usr/bin/env bash
echo "simulated SSH failure" >&2
exit 1
STUB
chmod +x "${WORKDIR}/privesc/run-findprivs.sh"

printf 'c\nk\n1\nfail@10.99.99.97\nY\n' \
    | bash "${WORKDIR}/neo.sh" "${PROJECT}" "10.99.99.97" \
    && rc=0 || rc=$?
assert "neo.sh exits non-zero on script fail" test "${rc}" -ne 0
fail_phase="$(grep '^phase=' "${WORKDIR}/projects/${PROJECT}/project.meta" 2>/dev/null | cut -d= -f2- | head -n1 || true)"
assert "phase not advanced to post on fail" test "${fail_phase}" != "post"

if [[ -f "${REAL_NEO}/projects/HTB-Reactor/project.meta" ]]; then
    legacy_phase="$(grep '^phase=' "${REAL_NEO}/projects/HTB-Reactor/project.meta" | cut -d= -f2- | head -n1)"
    setup_worktree
    mkdir -p "${WORKDIR}/projects/HTB-Reactor"
    cp "${REAL_NEO}/projects/HTB-Reactor/project.meta" "${WORKDIR}/projects/HTB-Reactor/"
    cp "${REAL_NEO}/projects/HTB-Reactor/Investigation-Notes.md" "${WORKDIR}/projects/HTB-Reactor/" 2>/dev/null || \
        cp "${REAL_NEO}/templates/investigation-notes.md" "${WORKDIR}/projects/HTB-Reactor/Investigation-Notes.md"
    export NEO_HOME="${WORKDIR}"
    export NEO_DIR="${WORKDIR}"
    printf 'c\nq\n' | bash "${WORKDIR}/neo.sh" HTB-Reactor --from=recon \
        && rc=0 || rc=$?
    assert "HTB-Reactor --from=recon starts cleanly" test "${rc}" -eq 0
    assert "legacy project still exists" test -f "${REAL_NEO}/projects/HTB-Reactor/project.meta"
    printf '  [info] HTB-Reactor legacy phase=%s\n' "${legacy_phase}"
else
    printf '  [skip] HTB-Reactor not present\n'
fi

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
