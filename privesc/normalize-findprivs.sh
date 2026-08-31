#!/usr/bin/env bash
# Parse FindPrivs === Section === output into privesc-facts.json.

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_DIR}/lib/neo-core.sh"

INPUT=""
OUTPUT=""
SOURCE_ARTIFACT=""

usage() { printf 'Usage: normalize-findprivs.sh --input FILE --output FILE [--source-artifact PATH]\n'; }

while (($#)); do
    case "$1" in
        --input) INPUT="${2:-}"; shift 2 ;;
        --input=*) INPUT="${1#*=}"; shift ;;
        --output) OUTPUT="${2:-}"; shift 2 ;;
        --output=*) OUTPUT="${1#*=}"; shift ;;
        --source-artifact) SOURCE_ARTIFACT="${2:-}"; shift 2 ;;
        --source-artifact=*) SOURCE_ARTIFACT="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) neo_core_die "unknown argument: $1"; exit 1 ;;
    esac
done

neo_core_need jq awk || exit 1
[[ -f "${INPUT}" ]] || { neo_core_die "input not found: ${INPUT}"; exit 1; }
[[ -n "${OUTPUT}" ]] || { neo_core_die '--output required'; exit 1; }

user="" hostname="" uid="" kernel="" os=""
sudo_rules=() suid=() caps=() cron=() writable=()
section=""

while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^===[[:space:]]*(.+)[[:space:]]*===$ ]]; then
        section="${BASH_REMATCH[1]}"
        continue
    fi
    case "${section}" in
        "System identity"|"WHOAMI")
            [[ "${line}" =~ user=([^[:space:]]+) ]] && user="${BASH_REMATCH[1]}"
            [[ "${line}" =~ host=([^[:space:]]+) ]] && hostname="${BASH_REMATCH[1]}"
            [[ "${line}" =~ uid=([0-9]+) ]] && uid="${BASH_REMATCH[1]}"
            [[ "${line}" =~ kernel=(.+) ]] && kernel="${BASH_REMATCH[1]}"
            [[ "${line}" =~ os=(.+) ]] && os="${BASH_REMATCH[1]}"
            ;;
        "sudo privileges"|"SUDO")
            [[ -n "${line//[[:space:]]/}" ]] && sudo_rules+=("${line}")
            ;;
        "SUID binaries"|"SUID")
            [[ -n "${line//[[:space:]]/}" ]] && suid+=("${line}")
            ;;
        "Capabilities"|"CAPS")
            [[ -n "${line//[[:space:]]/}" ]] && caps+=("${line}")
            ;;
        "Cron jobs"|"CRON")
            [[ -n "${line//[[:space:]]/}" ]] && cron+=("${line}")
            ;;
        "Writable paths"|"FILES")
            [[ -n "${line//[[:space:]]/}" ]] && writable+=("${line}")
            ;;
    esac
done < "${INPUT}"

hypotheses='[]'
if ((${#sudo_rules[@]})); then
    hypotheses="$(jq -n --arg ref "sudo_rules" \
        '[{id:"sudo-nopasswd-check",title:"Review sudo rules for dangerous entries",category:"misconfiguration",confidence:"medium",evidence_refs:[$ref],impact:"root"}]')"
fi

jq -n \
    --arg captured "$(neo_core_iso_timestamp)" \
    --arg artifact "${SOURCE_ARTIFACT:-unknown}" \
    --arg user "${user:-unknown}" \
    --arg hostname "${hostname:-unknown}" \
    --argjson uid "${uid:-0}" \
    --arg kernel "${kernel:-}" \
    --arg os "${os:-}" \
    --argjson sudo "$(printf '%s\n' "${sudo_rules[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson suid "$(printf '%s\n' "${suid[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson caps "$(printf '%s\n' "${caps[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson cron "$(printf '%s\n' "${cron[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson writable "$(printf '%s\n' "${writable[@]:-}" | jq -R -s 'split("\n")|map(select(length>0))')" \
    --argjson hypotheses "${hypotheses}" \
    '{
      schema_version: 1,
      source_artifact: $artifact,
      captured_at: $captured,
      identity: {user: $user, hostname: $hostname, uid: $uid, groups: []},
      observations: {
        sudo_rules: $sudo, suid_binaries: $suid, capabilities: $caps,
        cron_jobs: $cron, writable_paths: $writable, kernel: $kernel, os: $os
      },
      hypotheses: $hypotheses
    }' > "${OUTPUT}"
chmod 600 -- "${OUTPUT}"
printf 'Normalized privesc facts: %s\n' "${OUTPUT}"
