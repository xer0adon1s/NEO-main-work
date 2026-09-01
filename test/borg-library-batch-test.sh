#!/usr/bin/env bash
# borg-library-batch-test.sh — Wave 5 batch queue builder (offline).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTDIR="$(mktemp -d /tmp/neo-batch-test.XXXXXX)"
export NEO_HOME="${TESTDIR}"
export NEO_DIR="${NEO_ROOT}"

trap 'rm -rf "${TESTDIR}"' EXIT

# shellcheck source=../lib/neo-borg-library-batch.sh
source "${NEO_DIR}/lib/neo-borg-library-batch.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'borg-library-batch-test.sh\n\n'

mkdir -p "${NEO_HOME}/projects/batchbox/assimilated/cve-2021-41773-apache"
mkdir -p "${NEO_HOME}/projects/batchbox/assimilated/redis-unauth"
queue="$(neo_borg_library_batch_build_queue_from_project batchbox 2>/dev/null || true)"
[[ -f "${queue}" ]] && ok "queue file created" || bad "queue file"
grep -q 'cve-2021-41773' "${queue}" && ok "cve slug in queue" || bad "cve slug"
grep -q 'redis-unauth' "${queue}" && ok "redis slug in queue" || bad "redis slug"

neo_borg_library_batch_run "${queue}" 1 >/dev/null && ok "dry batch run" || bad "dry run"

bash -n "${NEO_DIR}/lib/neo-borg-library-batch.sh" && ok "syntax batch lib" || bad "syntax"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
