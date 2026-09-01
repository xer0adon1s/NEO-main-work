#!/usr/bin/env bash
# notes-lib-test.sh — regression tests for the notes framework.

set -euo pipefail

NEO_HOME="${NEO_HOME:-${HOME}/Neo}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
TESTDIR="$(mktemp -d /tmp/cybersec-notes-test.XXXXXX)"
trap 'rm -rf "${TESTDIR}"' EXIT

source "${NEO_DIR}/lib/notes-lib.sh"

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

OUTDIR="${TESTDIR}/my-project"
notes_init "test-proj" "10.0.0.1" "${OUTDIR}"

assert "notes file created" test -f "${OUTDIR}/Investigation-Notes.md"
assert "project.meta created" test -f "${OUTDIR}/project.meta"
assert "meta_init default phase is recon" grep -q '^phase=recon' "${OUTDIR}/project.meta"
assert "artifacts dir created" test -d "${OUTDIR}/artifacts"
assert "ssh_target in meta" grep -q '^ssh_target=' "${OUTDIR}/project.meta"

SPECIAL_DIR="${TESTDIR}/special-chars"
notes_init "proj|name" "10.0.0.1|foo" "${SPECIAL_DIR}"
assert "init special chars in project name" grep -q 'proj|name' "${SPECIAL_DIR}/Investigation-Notes.md"
assert "init special chars in target" grep -q '10.0.0.1|foo' "${SPECIAL_DIR}/Investigation-Notes.md"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"

notes_set_section PORTS $'22/tcp open ssh\nline with \\ backslash'
assert "set section" grep -q 'backslash' "${OUTDIR}/Investigation-Notes.md"

got_ports="$(notes_get_section PORTS)"
assert "get section" test "${got_ports}" = $'22/tcp open ssh\nline with \\ backslash'

notes_append_section TODO $'- [ ] lead'
assert "append section" grep -q 'lead' "${OUTDIR}/Investigation-Notes.md"

rc=0
notes_set_section NONEXISTENT "nope" 2>/dev/null || rc=$?
assert "missing tag returns non-zero" test "${rc}" -ne 0

CORRUPT_DIR="${TESTDIR}/corrupt"
mkdir -p "${CORRUPT_DIR}"
cp "${NEO_HOME}/templates/investigation-notes.md" "${CORRUPT_DIR}/Investigation-Notes.md"
sed -i 's/{{PROJECT}}/x/; s/{{TARGET}}/y/; s/{{DATE}}/z/' "${CORRUPT_DIR}/Investigation-Notes.md"
sed -i '/<!-- \/SECTION:PORTS -->/d' "${CORRUPT_DIR}/Investigation-Notes.md"
NOTES_FILE="${CORRUPT_DIR}/Investigation-Notes.md"
lines_before="$(wc -l < "${NOTES_FILE}")"
rc=0
notes_set_section PORTS "new content" 2>/dev/null || rc=$?
lines_after="$(wc -l < "${NOTES_FILE}")"
assert "corrupt file rejected" test "${rc}" -ne 0
assert "corrupt file not truncated" test "${lines_before}" -eq "${lines_after}"

NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
sample=$'=== System identity ===\nuid=1000(user)\n\n=== sudo privileges ===\nUser may run ALL\n'
notes_ingest "FindPrivs" "" "${sample}"
assert "ingest fills WHOAMI" grep -q 'System identity' "${OUTDIR}/Investigation-Notes.md"
assert "ingest fills SUDO" grep -q 'sudo privileges' "${OUTDIR}/Investigation-Notes.md"

verdict_sample=$'=== VERDICT ===\nTry sudo -l first.\n'
notes_ingest "FindPrivs" "" "${verdict_sample}"
assert "ingest VERDICT to TODO" grep -q 'Try sudo' "${OUTDIR}/Investigation-Notes.md"

big="$(printf '%s\n' $(seq 1 150))"
notes_log_smart "bigtest" "${big}"
assert "smart log artifact link" grep -q 'artifacts/bigtest-' "${OUTDIR}/Investigation-Notes.md"
artifact_file="$(find "${OUTDIR}/artifacts" -name 'bigtest-*.txt' -print -quit)"
assert "artifact file exists" test -n "${artifact_file}" -a -f "${artifact_file}"

meta_set phase recon
meta_set target 10.0.0.1
notes_refresh_status "testscript" "three ports open"
assert "STATUS updated" grep -q 'testscript' "${OUTDIR}/Investigation-Notes.md"
assert "STATUS has summary" grep -q 'three ports open' "${OUTDIR}/Investigation-Notes.md"

assert "meta_set works" test "$(meta_get phase)" = "recon"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
