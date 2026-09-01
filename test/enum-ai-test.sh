#!/usr/bin/env bash
# enum-ai-test.sh — offline enum AI bundle helpers (no live AI).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTDIR="$(mktemp -d /tmp/neo-enum-ai-test.XXXXXX)"
export NEO_HOME="${TESTDIR}"
export NEO_DIR="${NEO_HOME}"
export NEO_STATE_ROOT="${TESTDIR}/state"
export NEO_TEST_NONINTERACTIVE=1

trap 'rm -rf "${TESTDIR}"' EXIT

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'enum-ai-test.sh\n\n'

mkdir -p "${NEO_HOME}/templates"
cp "${NEO_ROOT}/templates/investigation-notes.md" "${NEO_HOME}/templates/"

# shellcheck source=../lib/notes-lib.sh
source "${NEO_ROOT}/lib/notes-lib.sh"
OUTDIR="${NEO_HOME}/projects/enum-proj"
notes_init "enum-proj" "10.10.10.5" "${OUTDIR}"
notes_set_section PORTS <<'EOF'
80/tcp open http
22/tcp open ssh
EOF

plan_root="${NEO_STATE_ROOT}/projects/enum-proj/enum-plans"
mkdir -p "${plan_root}/actions"
jq -n --arg title 'HTTP dir bust' --arg target '10.10.10.5:80' \
    --argjson argv '["gobuster","dir","-u","http://10.10.10.5"]' \
    '{schema_version:1,id:"http-dir",kind:"local_command",title:$title,target:$target,execution:{argv:$argv}}' \
    > "${plan_root}/actions/http-dir.json"

# shellcheck source=../lib/neo-enum-ai.sh
source "${NEO_ROOT}/lib/neo-enum-ai.sh"

actions="$(neo_enum_ai_collect_actions enum-proj 5)"
[[ "${actions}" == *"HTTP dir bust"* ]] && ok "collect actions from plan JSON" || bad "collect actions"

bundle="$(neo_enum_ai_build_bundle enum-proj 10.10.10.5)"
[[ "${bundle}" == *"10.10.10.5"* && "${bundle}" == *"gobuster"* ]] \
    && ok "enum AI bundle includes plan actions" || bad "bundle content"

bash -n "${NEO_ROOT}/lib/neo-enum-ai.sh" && ok "syntax enum-ai" || bad "syntax"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
