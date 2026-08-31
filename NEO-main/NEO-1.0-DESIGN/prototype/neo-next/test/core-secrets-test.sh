#!/usr/bin/env bash
set -uo pipefail

NEO_NEXT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=test-helper.sh
source "${NEO_NEXT_ROOT}/test/test-helper.sh"
# shellcheck source=../lib/neo-core.sh
source "${NEO_NEXT_ROOT}/lib/neo-core.sh"

tmp="$(mktemp -d /tmp/neo-next-secrets.XXXXXX)"
trap 'rm -rf -- "${tmp}"' EXIT
export NEO_SECRET_DIR="${tmp}/secrets"
# shellcheck source=../lib/neo-secrets.sh
source "${NEO_NEXT_ROOT}/lib/neo-secrets.sh"

assert_true 'valid project accepted' neo_core_valid_project 'HTB-Reactor_1'
assert_false 'slash project rejected' neo_core_valid_project '../escape'
assert_false 'space project rejected' neo_core_valid_project 'bad project'
assert_false 'newline project rejected' neo_core_valid_project $'bad\nproject'
assert_true 'valid port accepted' neo_core_valid_port 4444
assert_false 'zero port rejected' neo_core_valid_port 0
assert_false 'large port rejected' neo_core_valid_port 65536

assert_true 'secret stored' neo_secret_store ANTHROPIC_API_KEY 'sk-ant-test-canary'
mode="$(stat -c '%a' "${NEO_SECRET_DIR}/ANTHROPIC_API_KEY")"
[[ "${mode}" == 600 ]] && pass 'secret file is mode 600' || fail "secret file mode is ${mode}"
load_output_file="${tmp}/secret-load.stdout"
neo_secret_load ANTHROPIC_API_KEY >"${load_output_file}"
load_output="$(<"${load_output_file}")"
[[ -z "${load_output}" ]] && pass 'secret load prints nothing' || fail 'secret load leaked to stdout'
[[ "${NEO_SECRET_VALUE}" == 'sk-ant-test-canary' ]] && pass 'secret loaded through broker variable' || fail 'secret value mismatch'
redacted="$(neo_secret_redact_text 'token=sk-ant-test-canary' ANTHROPIC_API_KEY)"
[[ "${redacted}" == 'token=[REDACTED:ANTHROPIC_API_KEY]' ]] && pass 'known secret redacted' || fail 'redaction mismatch'

mkdir -p "${tmp}/repo"
touch "${tmp}/repo/.env"
assert_false 'repository secret audit rejects .env' neo_secret_audit_repository "${tmp}/repo"

finish_tests
