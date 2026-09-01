#!/usr/bin/env bash
set -uo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=test-helper.sh
source "${NEO_ROOT}/test/test-helper.sh"
# shellcheck source=../lib/neo-core.sh
source "${NEO_ROOT}/lib/neo-core.sh"
# shellcheck source=../lib/neo-evidence.sh
source "${NEO_ROOT}/lib/neo-evidence.sh"

CANARY="${NEO_TEST_CANARY_KEY:-canary-neo-test-do-not-use}"
tmp="$(mktemp -d /tmp/neo-canary.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf -- "${tmp}"' EXIT

export NEO_SECRET_DIR="${tmp}/secrets"
export NEO_STATE_ROOT="${tmp}/state"
# shellcheck source=../lib/neo-secrets.sh
source "${NEO_ROOT}/lib/neo-secrets.sh"

assert_true 'canary secret stored' neo_secret_store ANTHROPIC_API_KEY "${CANARY}"
assert_true 'evidence initialized' neo_evidence_init canary-box "${NEO_STATE_ROOT}/projects"

bundle="prefix ${CANARY} suffix"
neo_evidence_record test_event operator "${bundle}" '' observed
log_line="$(tail -1 "${NEO_EVIDENCE_LOG}")"
[[ "${log_line}" != *"${CANARY}"* ]] && pass 'canary redacted from evidence JSONL' \
    || fail 'canary leaked into evidence JSONL'

artifact_rel="$(printf 'leak %s here' "${CANARY}" | neo_evidence_save_artifact canary-test)"
artifact_body="$(cat "${NEO_EVIDENCE_DIR}/${artifact_rel}")"
[[ "${artifact_body}" != *"${CANARY}"* ]] && pass 'canary redacted from evidence artifact' \
    || fail 'canary leaked into evidence artifact'

load_out="${tmp}/load.out"
neo_secret_load ANTHROPIC_API_KEY >"${load_out}"
[[ ! -s "${load_out}" ]] && pass 'secret load silent on stdout' || fail 'secret load wrote to stdout'
[[ "${NEO_SECRET_VALUE}" == "${CANARY}" ]] && pass 'broker variable holds canary' || fail 'broker variable mismatch'

finish_tests
