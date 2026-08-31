#!/usr/bin/env bash
# Rank privesc hypotheses from privesc-facts.json (deterministic, no AI).

set -euo pipefail

NEO_NEXT_ROOT="${NEO_NEXT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${NEO_NEXT_ROOT}/lib/neo-core.sh"

INPUT=""
OUTPUT=""

usage() { printf 'Usage: rank-privesc-plan.sh --input privesc-facts.json --output privesc-plan.json\n'; }

while (($#)); do
    case "$1" in
        --input) INPUT="${2:-}"; shift 2 ;;
        --input=*) INPUT="${1#*=}"; shift ;;
        --output) OUTPUT="${2:-}"; shift 2 ;;
        --output=*) OUTPUT="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) neo_core_die "unknown argument: $1"; exit 1 ;;
    esac
done

neo_core_need jq || exit 1
[[ -f "${INPUT}" ]] || { neo_core_die "input not found: ${INPUT}"; exit 1; }
[[ -n "${OUTPUT}" ]] || { neo_core_die '--output required'; exit 1; }

jq '
  . as $facts |
  {
    schema_version: 1,
    generated_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    source_artifact: $facts.source_artifact,
    ranked_items: (
      ($facts.hypotheses // []) |
      map(. + {
        rank_score: (
          (if .impact == "root" then 30 elif .impact == "user" then 10 else 0 end) +
          (if .confidence == "high" then 20 elif .confidence == "medium" then 10 else 5 end) +
          (if .category == "misconfiguration" then 15 else 0 end)
        )
      }) |
      sort_by(-.rank_score) |
      to_entries |
      map(.value + {rank: (.key + 1)})
    ),
    operator_note: "Each item requires manual validation. GTFOBins references are citations only."
  }
' "${INPUT}" > "${OUTPUT}"
chmod 600 -- "${OUTPUT}"
printf 'Privesc plan: %s (%s items)\n' "${OUTPUT}" "$(jq '.ranked_items|length' "${OUTPUT}")"
