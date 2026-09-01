#!/usr/bin/env bash
# recon-bundle-test.sh — offline tests for AI bundle trimming (no API call).

set -euo pipefail

REAL_NEO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTDIR="$(mktemp -d /tmp/neo-bundle-test.XXXXXX)"
trap 'rm -rf "${TESTDIR}"' EXIT
export NEO_HOME="${TESTDIR}"
export NEO_DIR="${REAL_NEO}"
mkdir -p "${NEO_HOME}/templates"
cp "${REAL_NEO}/templates/investigation-notes.md" "${NEO_HOME}/templates/"

source "${NEO_DIR}/lib/notes-lib.sh"
source "${NEO_DIR}/lib/neo-ai.sh"
source "${NEO_DIR}/lib/neo-ai-analyze.sh"

pass=0 fail=0

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

sample_nmap=$'PORT 22 open ssh\nSF-Port3000-TCP:V=7.991%I=7\n<!DOCTYPE html><script>long</script>\nService Info: OS: Linux'
trimmed="$(neo_ai_trim_nmap "${sample_nmap}")"

assert "nmap trim drops SF- lines" test -z "$(grep '^SF-' <<< "${trimmed}" || true)"
assert "nmap trim drops HTML lines" test -z "$(grep '<!DOCTYPE' <<< "${trimmed}" || true)"
assert "nmap trim keeps Service Info" grep -q 'Service Info' <<< "${trimmed}"

OUTDIR="${NEO_HOME}/projects/bundle-proj"
notes_init "bundle-proj" "10.0.0.5" "${OUTDIR}"
notes_set_section STATUS "test status"
notes_set_section PORTS "22/tcp open"
notes_set_section NMAP "${sample_nmap}"
notes_set_section SERVICES "### Web\nheaders here"
notes_set_section TODO "- [ ] check api"

bundle="$(neo_ai_build_recon_bundle "bundle-proj")"
assert "bundle includes project" grep -q 'bundle-proj' <<< "${bundle}"
assert "bundle includes ports" grep -q '22/tcp open' <<< "${bundle}"
assert "bundle includes STATUS" grep -q 'test status' <<< "${bundle}"
assert "bundle includes gap checklist" grep -q 'babysteps already attempted' <<< "${bundle}"
assert "bundle under max size" test "${#bundle}" -le "${NEO_AI_BUNDLE_MAX}"

notes_set_section AI-TRIAGE "## Prior run\nOld attack path hypothesis"
bundle2="$(neo_ai_build_recon_bundle "bundle-proj")"
assert "bundle includes prior AI triage" grep -q 'Prior AI triage' <<< "${bundle2}"
assert "bundle includes prior triage body" grep -q 'Old attack path' <<< "${bundle2}"

neo_ai_save_triage $'## Run two\nNew findings'
triage_body="$(notes_get_section AI-TRIAGE)"
assert "save triage appends second run" grep -q 'Run two' <<< "${triage_body}"
assert "save triage keeps first run" grep -q 'Prior run' <<< "${triage_body}"

sample_response=$'## Technical observations\n- OpenSSH 8.9p1 on 22/tcp\n\n## Operator next steps\n1. `[MANUAL]` Browse http://10.0.0.5/\n2. `[TOOL:nikto]` Scan port 80\n3. `[NEO]` Deep enum via neo.sh'
assert "extract technical section" grep -q 'OpenSSH 8.9' <<< "$(neo_ai_extract_section "${sample_response}" "Technical observations")"
assert "extract tools from response" test "$(neo_ai_extract_tools_from_response "${sample_response}" | wc -l | tr -d ' ')" = "1"
assert "extract tools nikto" grep -qx nikto <<< "$(neo_ai_extract_tools_from_response "${sample_response}")"

KEYDIR="${TESTDIR}/config"
export NEO_SECRET_DIR="${TESTDIR}/secrets"
export NEO_AI_KEYFILE="${KEYDIR}/anthropic.key"
neo_ai_save_api_key "sk-ant-test-key-12345"
assert "save api key" test -f "${NEO_AI_KEYFILE}"
unset ANTHROPIC_API_KEY
assert "load saved key" neo_ai_load_api_key
assert "saved key value" test "${ANTHROPIC_API_KEY}" = "sk-ant-test-key-12345"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
