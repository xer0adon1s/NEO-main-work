#!/usr/bin/env bash
# Append-only JSONL evidence and hashed artifact storage.

# shellcheck source=neo-core.sh
source "${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/neo-core.sh"
# shellcheck source=neo-secrets.sh
source "${NEO_NEXT_ROOT}/lib/neo-secrets.sh"

NEO_EVIDENCE_PROJECT=""
NEO_EVIDENCE_DIR=""
NEO_EVIDENCE_LOG=""

neo_evidence_init() {
    local project="$1" root="${2:-${NEO_NEXT_STATE_ROOT}/projects}"
    neo_core_require_project "${project}" || return 1
    neo_core_need jq sha256sum || return 1
    NEO_EVIDENCE_PROJECT="${project}"
    NEO_EVIDENCE_DIR="${root}/${project}/evidence"
    NEO_EVIDENCE_LOG="${NEO_EVIDENCE_DIR}/events.jsonl"
    neo_core_secure_dir "${NEO_EVIDENCE_DIR}/artifacts"
    touch -- "${NEO_EVIDENCE_LOG}"
    chmod 600 -- "${NEO_EVIDENCE_LOG}"
}

neo_evidence_record() {
    local type="$1" source="$2" summary="$3" artifact_rel="${4:-}" confidence="${5:-observed}"
    [[ -n "${NEO_EVIDENCE_LOG}" ]] || {
        neo_core_die 'evidence store not initialized'
        return 1
    }
    local clean
    clean="$(neo_secret_redact_text "${summary}" ANTHROPIC_API_KEY OPENAI_API_KEY)"
    jq -cn \
        --arg schema_version '1' \
        --arg timestamp "$(neo_core_iso_timestamp)" \
        --arg project "${NEO_EVIDENCE_PROJECT}" \
        --arg type "${type}" \
        --arg source "${source}" \
        --arg summary "${clean}" \
        --arg artifact "${artifact_rel}" \
        --arg confidence "${confidence}" \
        '{schema_version:($schema_version|tonumber),timestamp:$timestamp,project:$project,type:$type,source:$source,summary:$summary,artifact:(if $artifact=="" then null else $artifact end),confidence:$confidence}' \
        >> "${NEO_EVIDENCE_LOG}"
}

# Save stdin as a redacted artifact. Prints the relative artifact path, never its content.
neo_evidence_save_artifact() {
    local label="$1" raw tmp clean hash dest rel
    [[ -n "${NEO_EVIDENCE_DIR}" ]] || return 1
    raw="$(cat)"
    clean="$(neo_secret_redact_text "${raw}" ANTHROPIC_API_KEY OPENAI_API_KEY)"
    tmp="$(neo_core_secure_tmp "${NEO_EVIDENCE_DIR}/artifacts" ".artifact")" || return 1
    printf '%s' "${clean}" > "${tmp}"
    hash="$(sha256sum -- "${tmp}" | awk '{print $1}')"
    label="$(tr -cs 'A-Za-z0-9._-' '-' <<< "${label}" | sed 's/^-//;s/-$//')"
    dest="${NEO_EVIDENCE_DIR}/artifacts/${label:-artifact}-${hash:0:16}.txt"
    mv -f -- "${tmp}" "${dest}"
    chmod 600 -- "${dest}"
    rel="artifacts/$(basename "${dest}")"
    printf '%s' "${rel}"
}

neo_evidence_record_artifact() {
    local type="$1" source="$2" summary="$3" label="$4" rel
    rel="$(neo_evidence_save_artifact "${label}")" || return 1
    neo_evidence_record "${type}" "${source}" "${summary}" "${rel}" observed
    printf '%s' "${rel}"
}
