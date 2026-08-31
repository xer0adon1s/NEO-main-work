#!/usr/bin/env bash
# Interactive engagement scope intake at project creation (P13).

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
export NEO_STATE_ROOT="${NEO_STATE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/neo}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_DIR}/lib/neo-core.sh"
# shellcheck source=../lib/neo-scope.sh
source "${NEO_DIR}/lib/neo-scope.sh"
# shellcheck source=../lib/neo-evidence.sh
source "${NEO_DIR}/lib/neo-evidence.sh"

PROJECT=""
TARGET=""
STATE_ROOT="${NEO_STATE_ROOT}/projects"

usage() {
    cat <<'EOF'
Usage: scope-intake.sh --project NAME [--target IP]

Runs the engagement mode wizard and writes engagement-scope.json.
Call before recon on new projects.
EOF
}

while (($#)); do
    case "$1" in
        --project) PROJECT="${2:-}"; shift 2 ;;
        --project=*) PROJECT="${1#*=}"; shift ;;
        --target) TARGET="${2:-}"; shift 2 ;;
        --target=*) TARGET="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) neo_core_die "unknown argument: $1"; exit 1 ;;
    esac
done

neo_core_require_project "${PROJECT}" || exit 1
[[ -t 0 ]] || { neo_core_die 'scope intake requires an interactive terminal'; exit 1; }
neo_core_need jq || exit 1

scope_file="$(neo_scope_path "${PROJECT}" "${STATE_ROOT}")"
if [[ -f "${scope_file}" ]]; then
    printf 'Scope already defined:\n  %s\n' "$(neo_scope_summary "${PROJECT}" "${STATE_ROOT}")"
    read -r -p 'Replace scope? [y/N] ' replace
    [[ "${replace}" =~ ^[Yy]$ ]] || exit 0
fi

cat <<'EOF'

Engagement mode — who is this project for?

  [E] Educational lab (HTB, TryHackMe, course VM, home lab)
  [P] Professional authorized assessment (real client engagement)

EOF
read -r -p 'Choice [E/P]: ' mode_choice
case "${mode_choice}" in
    e|E|educational) MODE=educational ;;
    p|P|professional) MODE=professional ;;
    *) neo_core_die 'invalid mode'; exit 1 ;;
esac

work="$(neo_core_secure_tmp "${STATE_ROOT}/${PROJECT}" .scope-intake)"
trap 'rm -f -- "${work}"' EXIT

if [[ "${MODE}" == educational ]]; then
    cat <<'EOF'
Platform:
  1) Hack The Box
  2) TryHackMe
  3) Home lab
  4) Course / training
  5) Other
EOF
    read -r -p 'Platform [1-5]: ' plat
    case "${plat}" in
        1) PLATFORM=htb ;;
        2) PLATFORM=tryhackme ;;
        3) PLATFORM=home_lab ;;
        4) PLATFORM=course ;;
        5) PLATFORM=other; read -r -p 'Platform name: ' PLATFORM_LABEL ;;
        *) neo_core_die 'invalid platform'; exit 1 ;;
    esac
    [[ -n "${TARGET}" ]] || read -r -p 'Lab target IP/hostname: ' TARGET
    [[ -n "${TARGET}" ]] || { neo_core_die 'target required'; exit 1; }
    read -r -p 'Purpose (one line): ' PURPOSE
    printf 'Suggested lab networks (comma-separated, edit as needed):\n'
    hints="$(neo_scope_platform_hints "${PLATFORM:-other}" | paste -sd, -)"
    read -r -p "Networks [${hints}]: " NETS
    NETS="${NETS:-${hints}}"
    read -r -p 'Type authorized-lab to confirm this is an authorized learning environment: ' ATTEST
    [[ "${ATTEST}" == authorized-lab ]] || { neo_core_die 'attestation failed'; exit 1; }
    jq -n \
        --arg project "${PROJECT}" --arg mode educational --arg platform "${PLATFORM}" \
        --arg purpose "${PURPOSE}" --arg target "${TARGET}" --arg nets "${NETS}" \
        --arg now "$(neo_core_iso_timestamp)" --arg attest "${ATTEST}" \
        --arg label "${PLATFORM_LABEL:-}" \
        '{
          schema_version: 1, mode: $mode, created_at: $now, project: $project,
          platform: $platform,
          platform_label: (if $label=="" then null else $label end),
          purpose: $purpose,
          attestation: {phrase: $attest, confirmed_at: $now},
          in_scope: {
            hosts: [$target],
            networks: ($nets | split(",") | map(gsub("^ +| +$";"")) | map(select(length>0))),
            domains: [], ports: ["1-65535"]
          },
          exclusions: [], authorization: null, pending_targets: [], expansions: []
        }' > "${work}"
else
    read -r -p 'Client name: ' CLIENT
    read -r -p 'Authorization reference (SOW / ticket #): ' REF
    read -r -p 'Authorized by (name, role): ' AUTH_BY
    read -r -p 'Valid from (YYYY-MM-DD): ' VALID_FROM
    read -r -p 'Valid until (YYYY-MM-DD): ' VALID_UNTIL
    read -r -p 'Document path (optional, outside repo): ' DOC_PATH
    [[ -n "${TARGET}" ]] || read -r -p 'Primary in-scope target IP/hostname: ' TARGET
    read -r -p 'Additional in-scope hosts/CIDRs (comma-separated): ' EXTRA
    read -r -p 'Exclusions (comma-separated, optional): ' EXCL
    read -r -p 'Engagement purpose: ' PURPOSE
    read -r -p 'Type authorized-engagement to confirm written permission exists: ' ATTEST
    [[ "${ATTEST}" == authorized-engagement ]] || { neo_core_die 'attestation failed'; exit 1; }
    hosts_json="$(jq -n --arg t "${TARGET}" --arg e "${EXTRA}" \
        '[$t] + ($e|split(",")|map(gsub("^ +| +$";""))|map(select(length>0)))')"
    jq -n \
        --arg project "${PROJECT}" --arg now "$(neo_core_iso_timestamp)" \
        --arg purpose "${PURPOSE}" --arg attest "${ATTEST}" \
        --arg client "${CLIENT}" --arg ref "${REF}" --arg auth_by "${AUTH_BY}" \
        --arg vf "${VALID_FROM}" --arg vu "${VALID_UNTIL}" --arg doc "${DOC_PATH}" \
        --arg excl "${EXCL}" --argjson hosts "${hosts_json}" \
        '{
          schema_version: 1, mode: "professional", created_at: $now, project: $project,
          purpose: $purpose,
          attestation: {phrase: $attest, confirmed_at: $now},
          in_scope: {
            hosts: $hosts, networks: [], domains: [], ports: ["1-65535"]
          },
          exclusions: ($excl|split(",")|map(gsub("^ +| +$";""))|map(select(length>0))),
          authorization: {
            client_name: $client, reference: $ref, authorized_by: $auth_by,
            valid_from: $vf, valid_until: $vu,
            document_path: (if $doc=="" then null else $doc end)
          },
          pending_targets: [], expansions: []
        }' > "${work}"
fi

neo_core_secure_dir "${STATE_ROOT}/${PROJECT}"
mv -f -- "${work}" "${scope_file}"
chmod 600 -- "${scope_file}"
trap - EXIT

neo_evidence_init "${PROJECT}" "${STATE_ROOT}" 2>/dev/null || true
neo_evidence_record scope_defined operator \
    "Engagement scope captured: $(jq -r '.mode' "${scope_file}") — $(jq -r '.purpose' "${scope_file}")" \
    '' operator_confirmed 2>/dev/null || true

printf '\nScope saved: %s\n' "${scope_file}"
neo_scope_summary "${PROJECT}" "${STATE_ROOT}"
neo_scope_sync_project_meta "${PROJECT}" 2>/dev/null || true
