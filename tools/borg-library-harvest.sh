#!/usr/bin/env bash
# borg-library-harvest.sh — AI-driven library research (Phase C).
#
# PRIMARY: Claude researches a topic and writes library entries.
# OPTIONAL: mechanical fetch (NVD, URL) feeds context into AI — not the final artifact.
#
# Usage:
#   ./tools/borg-library-harvest.sh --research "CVE-2021-41773 Apache path traversal"
#   NEO_BORG_HARVEST=1 ./tools/borg-library-harvest.sh --research "..." --cve CVE-2021-41773
#   ./tools/borg-library-harvest.sh --research "redis unauth write" --context-file notes.txt

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-borg-library.sh
source "${NEO_DIR}/lib/neo-borg-library.sh"
# shellcheck source=../lib/neo-borg-harvest.sh
source "${NEO_DIR}/lib/neo-borg-harvest.sh"
# shellcheck source=../lib/neo-borg-library-ai.sh
source "${NEO_DIR}/lib/neo-borg-library-ai.sh"
# shellcheck source=../lib/neo-borg-disclosure.sh
source "${NEO_DIR}/lib/neo-borg-disclosure.sh"

RESEARCH=""
CVE=""
URL=""
FROM_FILE=""
CONTEXT_FILE=""
NVD_JSON=""
BOX_ID=""
PATH_ID=""
PLATFORM="other"
METHOD_SLUG=""
LIBRARY_MODE="educational"
DRY_RUN=0
MECHANICAL_ONLY=0
BATCH_PROJECT=""
BATCH_QUEUE=""

usage() {
    cat <<'EOF'
borg-library-harvest.sh — AI-driven Borg library research

PRIMARY (recommended):
  --research "TOPIC"           Claude synthesizes library entry (needs claude or API key)
  --context-file FILE          Extra text fed into AI bundle (your notes, page save, etc.)
  --library-mode educational|professional   AI emphasis (default: educational)

Optional context fetch (feeds AI only; requires NEO_BORG_HARVEST=1 for network):
  --cve CVE-2021-41773           Attach NVD JSON to AI bundle
  --url URL                      Attach fetched page text to AI bundle
  --from-file FILE               Offline page/text → AI context (no network gate)
  --nvd-json FILE                Offline NVD JSON → AI context

Install targets:
  --method SLUG                Store as methods/<slug>/ (default from AI slug or topic)
  --box-id PLATFORM:slug       Store as walkthrough path (with --path-id)
  --path-id ID
  --platform htb|tryhackme|...

Legacy (no AI — not recommended):
  --mechanical-only              Use html strip / jq only (old prototype path)

  --dry-run
  --batch                      Run batch queue (with --from-project or --queue-file)
  --from-project NAME          Build queue from projects/NAME/assimilated/
  --queue-file PATH            Batch topics file (one per line)
  -h, --help

Environment:
  NEO_BORG_HARVEST=1     enable --cve / --url network fetch
  NEO_PROVIDER_WEB_RESEARCH=1   (future) provider-native web search when available
EOF
}

while (($# > 0)); do
    case "$1" in
        --research) RESEARCH="${2:-}"; shift 2 ;;
        --research=*) RESEARCH="${1#*=}"; shift ;;
        --cve) CVE="${2:-}"; shift 2 ;;
        --cve=*) CVE="${1#*=}"; shift ;;
        --url) URL="${2:-}"; shift 2 ;;
        --url=*) URL="${1#*=}"; shift ;;
        --from-file) FROM_FILE="${2:-}"; shift 2 ;;
        --from-file=*) FROM_FILE="${1#*=}"; shift ;;
        --context-file) CONTEXT_FILE="${2:-}"; shift 2 ;;
        --context-file=*) CONTEXT_FILE="${1#*=}"; shift ;;
        --nvd-json) NVD_JSON="${2:-}"; shift 2 ;;
        --nvd-json=*) NVD_JSON="${1#*=}"; shift ;;
        --box-id) BOX_ID="${2:-}"; shift 2 ;;
        --box-id=*) BOX_ID="${1#*=}"; shift ;;
        --path-id) PATH_ID="${2:-}"; shift 2 ;;
        --path-id=*) PATH_ID="${1#*=}"; shift ;;
        --platform) PLATFORM="${2:-}"; shift 2 ;;
        --platform=*) PLATFORM="${1#*=}"; shift ;;
        --method) METHOD_SLUG="${2:-}"; shift 2 ;;
        --method=*) METHOD_SLUG="${1#*=}"; shift ;;
        --library-mode) LIBRARY_MODE="${2:-}"; shift 2 ;;
        --library-mode=*) LIBRARY_MODE="${1#*=}"; shift ;;
        --mechanical-only) MECHANICAL_ONLY=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --batch) shift ;;
        --from-project) BATCH_PROJECT="${2:-}"; shift 2 ;;
        --from-project=*) BATCH_PROJECT="${1#*=}"; shift ;;
        --queue-file) BATCH_QUEUE="${2:-}"; shift 2 ;;
        --queue-file=*) BATCH_QUEUE="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -n "${BATCH_PROJECT}" || -n "${BATCH_QUEUE}" ]]; then
    # shellcheck source=../lib/neo-borg-library-batch.sh
    source "${NEO_DIR}/lib/neo-borg-library-batch.sh"
    queue="${BATCH_QUEUE}"
    [[ -n "${queue}" ]] || queue="$(neo_borg_library_batch_build_queue_from_project "${BATCH_PROJECT}" 2>/dev/null || true)"
    [[ -n "${queue}" && -f "${queue}" ]] || {
        echo "borg-library-harvest: no batch queue (assimilated vectors empty?)" >&2
        exit 1
    }
    neo_borg_library_batch_run "${queue}" "${DRY_RUN}"
    exit 0
fi

[[ -n "${RESEARCH}" || "${MECHANICAL_ONLY}" == "1" ]] || {
    echo "borg-library-harvest: --research TOPIC is required (AI-driven)." >&2
    usage
    exit 1
}

neo_borg_library_init
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

build_ai_context() {
    local ctx="" file raw
    if [[ -n "${NVD_JSON}" && -f "${NVD_JSON}" ]]; then
        ctx="${ctx}"$'\n\n'"### NVD JSON (fetched)"$'\n'"$(head -c 12000 "${NVD_JSON}")"
    fi
    if [[ -n "${CVE}" && -z "${NVD_JSON}" ]]; then
        if neo_borg_harvest_network_enabled; then
            neo_borg_harvest_fetch_nvd_cve "${CVE}" "${tmpdir}/nvd.json" && \
                ctx="${ctx}"$'\n\n'"### NVD JSON"$'\n'"$(head -c 12000 "${tmpdir}/nvd.json")"
        else
            ctx="${ctx}"$'\n\n'"_(Set NEO_BORG_HARVEST=1 to attach live NVD for ${CVE})_"
        fi
    fi
    if [[ -n "${URL}" ]]; then
        if neo_borg_harvest_network_enabled; then
            neo_borg_harvest_fetch_url "${URL}" "${tmpdir}/page.html" && \
                ctx="${ctx}"$'\n\n'"### URL excerpt: ${URL}"$'\n'"$(neo_borg_harvest_html_to_text "$(head -c 50000 "${tmpdir}/page.html")" | head -c 12000)"
        fi
    fi
    for file in "${FROM_FILE}" "${CONTEXT_FILE}"; do
        [[ -n "${file}" && -f "${file}" ]] || continue
        if grep -qi '<html' "${file}" 2>/dev/null; then
            raw="$(neo_borg_harvest_html_to_text "$(cat "${file}")" | head -c 12000)"
        else
            raw="$(head -c 12000 "${file}")"
        fi
        ctx="${ctx}"$'\n\n'"### Context file: ${file}"$'\n'"${raw}"
    done
    printf '%s' "${ctx}"
}

install_from_ai() {
    local topic="$1" response="$2" paths edu steps slug
    paths="$(neo_borg_library_ai_write_artifacts "${topic}" "${response}")" || return 1
    edu="${paths%%|*}"
    steps="${paths#*|}"

    slug="${METHOD_SLUG:-${NEO_LIBRARY_AI_SLUG:-}}"
    slug="${slug:-$(neo_borg_harvest_slugify "${topic}")}"

    [[ "${DRY_RUN}" == "1" ]] && {
        echo "[dry-run] AI educational ($(wc -c < "${edu}") bytes) + professional steps"
        return 0
    }

    if [[ -n "${BOX_ID}" ]]; then
        [[ -n "${PATH_ID}" ]] || PATH_ID="ai-$(neo_borg_harvest_slugify "${topic}")"
        bash "${NEO_DIR}/tools/borg-library-ingest.sh" \
            --box-id "${BOX_ID}" --path-id "${PATH_ID}" --platform "${PLATFORM}" \
            --educational "${edu}" --steps "${steps}"
        neo_borg_library_index_register_walkthrough "${BOX_ID}" "${PATH_ID}" || true
        echo "[ok] AI walkthrough: ${BOX_ID} / ${PATH_ID}"
    else
        bash "${NEO_DIR}/tools/borg-library-ingest.sh" \
            --method "${slug}" --educational "${edu}" --steps "${steps}"
        neo_borg_library_index_register_method "${slug}" "${CVE}" || true
        echo "[ok] AI method library: methods/${slug}/"
    fi
}

if [[ "${MECHANICAL_ONLY}" == "1" ]]; then
    echo "[!] mechanical-only mode — bypassing AI (not recommended)" >&2
    RESEARCH="${RESEARCH:-${CVE:-mechanical-harvest}}"
    ctx="$(build_ai_context)"
    raw="${ctx}"
    [[ -n "${FROM_FILE}" ]] && raw="$(cat "${FROM_FILE}")"
    printf '%s' "${raw}" > "${tmpdir}/steps.md"
    neo_borg_harvest_make_educational "${raw}" > "${tmpdir}/educational.md"
    neo_borg_disclosure_check educational "$(cat "${tmpdir}/educational.md")" || exit 1
    slug="${METHOD_SLUG:-$(neo_borg_harvest_slugify "${RESEARCH}")}"
    bash "${NEO_DIR}/tools/borg-library-ingest.sh" --method "${slug}" \
        --educational "${tmpdir}/educational.md" --steps "${tmpdir}/steps.md"
    exit 0
fi

neo_borg_library_ai_available || {
    echo "borg-library-harvest: AI required — install Claude Code or set ANTHROPIC_API_KEY." >&2
    exit 1
}

ctx="$(build_ai_context)"
[[ "${DRY_RUN}" == "1" ]] && {
    echo "[dry-run] would AI-research: ${RESEARCH}"
    echo "[dry-run] context bytes: $(wc -c <<< "${ctx}" | tr -d ' ')"
    exit 0
}

response="$(neo_borg_library_ai_research "${RESEARCH}" "${ctx}" "${LIBRARY_MODE}")" || exit 1
install_from_ai "${RESEARCH}" "${response}"
