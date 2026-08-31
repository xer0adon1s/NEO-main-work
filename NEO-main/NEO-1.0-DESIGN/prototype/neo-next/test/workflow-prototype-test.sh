#!/usr/bin/env bash
set -uo pipefail

NEO_NEXT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${NEO_NEXT_ROOT}/test/test-helper.sh"

tmp="$(mktemp -d /tmp/neo-next-workflow.XXXXXX)"
trap 'rm -rf -- "${tmp}"' EXIT
export NEO_NEXT_STATE_ROOT="${tmp}/state"
mkdir -p "${tmp}/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "${tmp}/bin/ncat"
chmod +x "${tmp}/bin/ncat"
export PATH="${tmp}/bin:${PATH}"

if bash "${NEO_NEXT_ROOT}/foothold/ListenAssist.sh" --project demo --target 10.10.10.10 \
    --callback-ip 10.10.14.2 --port 5555 --tool ncat > "${tmp}/listen.out"; then
    pass 'ListenAssist non-interactive plan completed'
else
    fail 'ListenAssist plan failed'
fi
grep -q 'ncat -lvnp 5555' "${tmp}/listen.out" && pass 'ListenAssist prints separate-window command' || fail 'listener command missing'
find "${tmp}/state/projects/demo/evidence/artifacts" -name 'listener-plan-*' -type f | grep -q . \
    && pass 'ListenAssist stores plan artifact' || fail 'listener plan artifact missing'

printf 'manual web observation\n' > "${tmp}/recon.txt"
if bash "${NEO_NEXT_ROOT}/recon/operator-recon.sh" --project demo --file "${tmp}/recon.txt" >/dev/null; then
    pass 'operator recon file ingested'
else
    fail 'operator recon ingest failed'
fi
jq -e 'select(.type=="operator_recon")' "${tmp}/state/projects/demo/evidence/events.jsonl" >/dev/null \
    && pass 'operator recon evidence event recorded' || fail 'operator recon event missing'

finish_tests
