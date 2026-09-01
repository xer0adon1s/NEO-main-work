#!/usr/bin/env bash
# neo-borg-v2.sh — Borg v2 dossier validation + pause hooks (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"

neo_borg_v2_validate_dossier() {
    local file="$1"
    [[ -f "${file}" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    jq -e '.schema_version == 1 and (.vectors | type) == "array" and (.vectors | length) >= 1' \
        "${file}" >/dev/null 2>&1 || return 1
    jq -e '.vectors[] | select(.id and .title and (.sources|type)=="array" and (.tool_inventory|type)=="array" and (.operator_actions|type)=="array")' \
        "${file}" >/dev/null 2>&1
}

neo_borg_v2_offer_at_pause() {
    local project="$1"
    [[ -f "${NEO_DIR}/borg/borg-v2.sh" ]] || return 0
    printf '[*] Borg v2 available — run: borg/borg-v2.sh --project %s\n' "${project}"
    return 0
}

neo_borg_v2_schema_path() {
    printf '%s/schemas/borg-dossier.schema.json' "${NEO_DIR}"
}
