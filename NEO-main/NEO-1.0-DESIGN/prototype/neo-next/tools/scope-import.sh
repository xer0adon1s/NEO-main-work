#!/usr/bin/env bash
# Import a filled scope-policy-template.md into engagement-scope.json (design prototype).
# Parses YAML front matter + structured sections; AI dissection is integration-time.

set -euo pipefail

NEO_NEXT_ROOT="${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${NEO_NEXT_ROOT}/lib/neo-core.sh"
source "${NEO_NEXT_ROOT}/lib/neo-scope.sh"
source "${NEO_NEXT_ROOT}/lib/neo-evidence.sh"

PROJECT=""
POLICY_FILE=""
STATE_ROOT="${NEO_NEXT_STATE_ROOT}/projects"

usage() {
    cat <<'EOF'
Usage: scope-import.sh --project NAME --policy PATH

Imports a filled scope-policy-template.md (see templates/scope-policy-template.md)
into engagement-scope.json for professional mode.

Requires YAML front matter with: client_name, authorization_reference,
authorized_by, valid_from, valid_until.
EOF
}

while (($#)); do
    case "$1" in
        --project) PROJECT="${2:-}"; shift 2 ;;
        --project=*) PROJECT="${1#*=}"; shift ;;
        --policy) POLICY_FILE="${2:-}"; shift 2 ;;
        --policy=*) POLICY_FILE="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) neo_core_die "unknown argument: $1"; exit 1 ;;
    esac
done

neo_core_require_project "${PROJECT}" || exit 1
[[ -f "${POLICY_FILE}" && ! -L "${POLICY_FILE}" ]] || {
    neo_core_die "policy file not found: ${POLICY_FILE}"
    exit 1
}
neo_core_need jq awk || exit 1

# Extract YAML front matter between --- delimiters
front="$(awk 'BEGIN{f=0} /^---$/{f++; next} f==1{print; if(/^---$/){exit}}' "${POLICY_FILE}" 2>/dev/null || true)"
if [[ -z "${front}" ]]; then
    neo_core_die 'policy file missing YAML front matter (--- blocks)'
    exit 1
fi

fm_file="$(neo_core_secure_tmp "${STATE_ROOT}" .frontmatter)"
trap 'rm -f -- "${fm_file}"' EXIT
printf '%s\n' "${front}" > "${fm_file}"

for key in client_name authorization_reference authorized_by valid_from valid_until; do
    jq -e --arg k "${key}" 'has($k) and (.[ $k ] | type == "string") and (.[ $k ] | length > 0)' "${fm_file}" >/dev/null || {
        neo_core_die "front matter missing required field: ${key}"
        exit 1
    }
done

# Parse "Consolidated list for NEO" fenced block or bullet hosts from §2.1
hosts=()
while IFS= read -r line; do
    [[ -n "${line}" && "${line}" != \#* ]] && hosts+=("${line}")
done < <(awk '/\*\*Consolidated list for NEO/{f=1;next} /^```/{if(f){f=2;next} if(f==2){f=0;next}} f==1 && NF' "${POLICY_FILE}")

if ((${#hosts[@]} == 0)); then
    neo_core_die 'no in-scope hosts found; fill "Consolidated list for NEO" in section 2.1'
    exit 1
fi

# Parse exclusions block in §3.1 (lines before next ###)
exclusions=()
while IFS= read -r line; do
    [[ -n "${line}" && "${line}" != \#* ]] && exclusions+=("${line%%#*}" | sed 's/[[:space:]]*$//')
done < <(awk '/^### 3.1 Excluded hosts/{f=1;next} /^###/{if(f)exit} f && /^```/{if(!c){c=1;next}else{exit}} c' "${POLICY_FILE}")

hosts_json="$(printf '%s\n' "${hosts[@]}" | jq -R -s 'split("\n")|map(select(length>0))')"
excl_json="$(printf '%s\n' "${exclusions[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')"

scope_file="$(neo_scope_path "${PROJECT}" "${STATE_ROOT}")"
neo_core_secure_dir "${STATE_ROOT}/${PROJECT}"
work="$(neo_core_secure_tmp "${STATE_ROOT}/${PROJECT}" .scope-import)"

jq -n \
    --slurpfile fm "${fm_file}" \
    --arg project "${PROJECT}" --arg now "$(neo_core_iso_timestamp)" \
    --arg policy "${POLICY_FILE}" --argjson hosts "${hosts_json}" --argjson excl "${excl_json}" \
    --arg purpose "Imported from scope policy: ${POLICY_FILE}" \
    '($fm[0]) as $m |
    {
      schema_version: 1, mode: "professional", created_at: $now, project: $project,
      purpose: $purpose,
      attestation: {phrase: "authorized-engagement", confirmed_at: $now},
      in_scope: {hosts: $hosts, networks: [], domains: [], ports: ["1-65535"]},
      exclusions: $excl,
      authorization: {
        client_name: $m.client_name,
        reference: $m.authorization_reference,
        authorized_by: $m.authorized_by,
        valid_from: $m.valid_from,
        valid_until: $m.valid_until,
        document_path: ($m.authorization_document // null),
        policy_path: $policy
      },
      pending_targets: [], expansions: [],
      ai_scope_rules_extracted: true
    }' > "${work}"

mv -f -- "${work}" "${scope_file}"
chmod 600 -- "${scope_file}"
trap - EXIT

neo_evidence_init "${PROJECT}" "${STATE_ROOT}" 2>/dev/null || true
neo_evidence_record scope_import operator \
    "Imported professional scope policy from ${POLICY_FILE}" '' operator_confirmed 2>/dev/null || true

printf 'Imported scope policy → %s\n' "${scope_file}"
neo_scope_summary "${PROJECT}" "${STATE_ROOT}"
printf '\nAI bundles will include redacted scope summary from this policy.\n'
printf 'Review AI-SCOPE-RULES section in the policy file for model safeguards.\n'
