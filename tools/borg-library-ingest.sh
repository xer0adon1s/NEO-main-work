#!/usr/bin/env bash
# borg-library-ingest.sh — ingest a walkthrough/method entry into knowledge/library/ (Phase 66).
# Does NOT scrape the web — operator supplies markdown + metadata.
#
# Usage:
#   borg-library-ingest.sh --box-id htb:example-slug --path-id technique-a \
#       --platform htb --educational path/to/educational.md [--steps path/to/steps.md]
#   borg-library-ingest.sh --method redis-unauth-rce --educational path/to/method.md
#   borg-library-ingest.sh --check-only file.md

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-borg-library.sh
source "${NEO_DIR}/lib/neo-borg-library.sh"
# shellcheck source=../lib/neo-borg-disclosure.sh
source "${NEO_DIR}/lib/neo-borg-disclosure.sh"

BOX_ID=""
PATH_ID=""
PLATFORM="other"
METHOD_SLUG=""
EDU_FILE=""
STEPS_FILE=""
DISPLAY_NAME=""
PATH_NAME=""
CHECK_ONLY=""
CVE_LIST=""
DRY_RUN=0

usage() {
    cat <<'EOF'
borg-library-ingest.sh — add technique/walkthrough text to knowledge/library/

Walkthrough:
  --box-id PLATFORM:slug     e.g. htb:redis-lab-example
  --path-id ID               unique path under box (e.g. operator-notes-2026)
  --platform htb|tryhackme|...
  --educational FILE         technique-safe markdown (required)
  --steps FILE               full steps (professional; optional)
  --display-name TEXT        professional display only
  --path-name TEXT           short label for this solve path
  --cve CVE-2021-1234          repeatable

Method (technique-first):
  --method SLUG              e.g. redis-unauth-rce
  --educational FILE

Options:
  --check-only FILE          run educational disclosure lint only
  --dry-run                  print paths, do not write
  -h, --help
EOF
}

while (($# > 0)); do
    case "$1" in
        --box-id) BOX_ID="${2:-}"; shift 2 ;;
        --box-id=*) BOX_ID="${1#*=}"; shift ;;
        --path-id) PATH_ID="${2:-}"; shift 2 ;;
        --path-id=*) PATH_ID="${1#*=}"; shift ;;
        --platform) PLATFORM="${2:-}"; shift 2 ;;
        --platform=*) PLATFORM="${1#*=}"; shift ;;
        --method) METHOD_SLUG="${2:-}"; shift 2 ;;
        --method=*) METHOD_SLUG="${1#*=}"; shift ;;
        --educational) EDU_FILE="${2:-}"; shift 2 ;;
        --educational=*) EDU_FILE="${1#*=}"; shift ;;
        --steps) STEPS_FILE="${2:-}"; shift 2 ;;
        --steps=*) STEPS_FILE="${1#*=}"; shift ;;
        --display-name) DISPLAY_NAME="${2:-}"; shift 2 ;;
        --display-name=*) DISPLAY_NAME="${1#*=}"; shift ;;
        --path-name) PATH_NAME="${2:-}"; shift 2 ;;
        --path-name=*) PATH_NAME="${1#*=}"; shift ;;
        --cve) CVE_LIST="${CVE_LIST} ${2:-}"; shift 2 ;;
        --cve=*) CVE_LIST="${CVE_LIST} ${1#*=}"; shift ;;
        --check-only) CHECK_ONLY="${2:-}"; shift 2 ;;
        --check-only=*) CHECK_ONLY="${1#*=}"; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -n "${CHECK_ONLY}" ]]; then
    [[ -f "${CHECK_ONLY}" ]] || { echo "missing file: ${CHECK_ONLY}" >&2; exit 1; }
    neo_borg_disclosure_check educational "$(cat "${CHECK_ONLY}")"
    echo "[ok] educational disclosure check passed: ${CHECK_ONLY}"
    exit 0
fi

[[ -n "${EDU_FILE}" && -f "${EDU_FILE}" ]] || {
    echo "borg-library-ingest: --educational FILE required" >&2
    exit 1
}

if ! neo_borg_disclosure_check educational "$(cat "${EDU_FILE}")"; then
    echo "borg-library-ingest: educational.md failed disclosure lint — fix or use professional-only --steps" >&2
    exit 1
fi

neo_borg_library_init
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"

if [[ -n "${METHOD_SLUG}" ]]; then
    dest_dir="$(neo_borg_library_methods_dir)/${METHOD_SLUG}"
    [[ "${DRY_RUN}" == "1" ]] && { echo "would write: ${dest_dir}/"; exit 0; }
    mkdir -p "${dest_dir}"
    cp -- "${EDU_FILE}" "${dest_dir}/educational.md"
    [[ -n "${STEPS_FILE}" && -f "${STEPS_FILE}" ]] && cp -- "${STEPS_FILE}" "${dest_dir}/steps.md"
    cat > "${dest_dir}/meta.yaml" <<EOF
schema_version: 1
kind: method
slug: ${METHOD_SLUG}
ingested: ${ts}
cves: []
disclosure:
  educational_safe: true
  professional_full: $([[ -n "${STEPS_FILE}" ]] && echo true || echo false)
  lint_passed: true
source:
  kind: manual
  note: ingested via borg-library-ingest.sh
EOF
    echo "[ok] method ingested: knowledge/library/methods/${METHOD_SLUG}/"
    exit 0
fi

[[ -n "${BOX_ID}" && -n "${PATH_ID}" ]] || {
    echo "borg-library-ingest: walkthrough requires --box-id and --path-id (or use --method)" >&2
    exit 1
}

platform_from_id="${BOX_ID%%:*}"
slug_from_id="${BOX_ID#*:}"
dest_dir="$(neo_borg_library_walkthroughs_dir)/${platform_from_id}/${slug_from_id}/paths/${PATH_ID}"

[[ "${DRY_RUN}" == "1" ]] && { echo "would write: ${dest_dir}/"; exit 0; }

mkdir -p "${dest_dir}"
cp -- "${EDU_FILE}" "${dest_dir}/educational.md"
[[ -n "${STEPS_FILE}" && -f "${STEPS_FILE}" ]] && cp -- "${STEPS_FILE}" "${dest_dir}/steps.md"

cat > "${dest_dir}/meta.yaml" <<EOF
schema_version: 1
path_id: ${PATH_ID}
box_id: ${BOX_ID}
platform: ${PLATFORM}
display_name: ${DISPLAY_NAME:-null}
path_name: ${PATH_NAME:-${PATH_ID}}
ingested: ${ts}
cves: []
techniques: []
tags: []
source:
  kind: manual
  note: seed / operator ingest — not scraped
disclosure:
  educational_safe: true
  professional_full: $([[ -n "${STEPS_FILE}" ]] && echo true || echo false)
  lint_passed: true
files:
  educational: educational.md
  steps: $([[ -n "${STEPS_FILE}" ]] && echo steps.md || echo null)
EOF

# Box-level meta if missing
box_dir="$(dirname "$(dirname "${dest_dir}")")"
if [[ ! -f "${box_dir}/meta.yaml" ]]; then
    cat > "${box_dir}/meta.yaml" <<EOF
schema_version: 1
box_id: ${BOX_ID}
platform: ${PLATFORM}
display_name: ${DISPLAY_NAME:-${slug_from_id}}
paths_count: 1
tags: [example]
cves: []
techniques: []
EOF
fi

echo "[ok] walkthrough path ingested: knowledge/library/walkthroughs/${platform_from_id}/${slug_from_id}/paths/${PATH_ID}/"
