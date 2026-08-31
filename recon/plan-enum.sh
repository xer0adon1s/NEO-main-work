#!/usr/bin/env bash
# Convert one discovered service into typed, advisory enumeration actions.

set -euo pipefail

NEO_HOME="${NEO_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
# shellcheck source=../lib/neo-core.sh
source "${NEO_DIR}/lib/neo-core.sh"

INPUT=""
OUTPUT_DIR=""

usage() {
    printf 'Usage: plan-enum.sh --service service.json --output-dir DIR\n'
}

while (($#)); do
    case "$1" in
        --service) INPUT="${2:-}"; shift 2 ;;
        --service=*) INPUT="${1#*=}"; shift ;;
        --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
        --output-dir=*) OUTPUT_DIR="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) neo_core_die "unknown argument: $1"; exit 1 ;;
    esac
done

neo_core_need jq || exit 1
[[ -f "${INPUT}" ]] || { neo_core_die 'service JSON is required'; exit 1; }
[[ -n "${OUTPUT_DIR}" ]] || { neo_core_die 'output directory is required'; exit 1; }
jq -e '(.host|type=="string" and length>0 and length<=255) and (.port|type=="number" and .>=1 and .<=65535) and (.protocol=="tcp" or .protocol=="udp") and (.service|type=="string" and test("^[A-Za-z0-9._+-]{1,80}$"))' \
    "${INPUT}" >/dev/null || { neo_core_die 'invalid service document'; exit 1; }

host="$(jq -r '.host' "${INPUT}")"
port="$(jq -r '.port' "${INPUT}")"
service="$(jq -r '.service | ascii_downcase' "${INPUT}")"
tls="$(jq -r '.tls // false' "${INPUT}")"
[[ "${host}" != -* && "${host}" != *$'\n'* ]] || { neo_core_die 'unsafe host value'; exit 1; }
neo_core_secure_dir "${OUTPUT_DIR}"

emit_action() {
    local id="$1" title="$2" description="$3" risk="$4" expected="$5"
    shift 5
    local path="${OUTPUT_DIR}/${id}.json" argv_json
    argv_json="$(printf '%s\0' "$@" | jq -Rs 'split("\u0000")[:-1]')"
    jq -n --arg id "${id}" --arg title "${title}" --arg description "${description}" \
        --arg risk "${risk}" --arg target "${host}:${port}" --arg expected "${expected}" \
        --argjson argv "${argv_json}" \
        '{schema_version:1,id:$id,kind:"local_command",title:$title,description:$description,risk:$risk,source:"builtin",target:$target,expected_evidence:$expected,execution:{mode:"advisory",argv:$argv,timeout_seconds:120,cwd:null}}' > "${path}"
    chmod 600 -- "${path}"
    printf '%s\n' "${path}"
}

safe_id="$(tr -cs 'a-z0-9' '-' <<< "${service}-${host}-${port}" | sed 's/^-//;s/-$//')"
case "${service}" in
    http|https|http-alt|ssl/http|ssl/https)
        if [[ "${tls}" == true || "${service}" == https || "${service}" == ssl/* ]]; then scheme=https; curl_tls=(-k); else scheme=http; curl_tls=(); fi
        emit_action "${safe_id}-headers" "Inspect HTTP response headers" \
            'Retrieve response headers and protocol behavior without changing server state.' read_only \
            'Status, redirects, server headers, cookies, and security headers.' \
            curl "${curl_tls[@]}" -sS -D - -o /dev/null --max-time 15 "${scheme}://${host}:${port}/"
        emit_action "${safe_id}-nmap-http" "Run standard HTTP discovery scripts" \
            'Use standard nmap HTTP discovery scripts against only the discovered port.' read_only \
            'HTTP title, headers, methods, and common exposed paths.' \
            nmap -Pn -p "${port}" --script 'http-title,http-headers,http-methods,http-enum' "${host}"
        ;;
    ssh)
        emit_action "${safe_id}-ssh" "Inspect SSH algorithms and host key" \
            'Enumerate SSH cryptographic capabilities and host-key information without authenticating.' read_only \
            'Host keys, supported algorithms, and version evidence.' \
            nmap -Pn -p "${port}" --script 'ssh-hostkey,ssh2-enum-algos' "${host}"
        ;;
    microsoft-ds|netbios-ssn|smb)
        emit_action "${safe_id}-smb-list" "Test anonymous SMB share listing" \
            'Request a share list without credentials; do not write to any share.' read_only \
            'Whether guest/null access is accepted and which shares are visible.' \
            smbclient -L "//${host}" -N -p "${port}"
        emit_action "${safe_id}-smb-info" "Inspect SMB protocol information" \
            'Enumerate SMB protocol and security-mode information on the discovered port.' read_only \
            'Dialect, signing, time, OS, and security mode evidence.' \
            nmap -Pn -p "${port}" --script 'smb-protocols,smb-security-mode,smb2-security-mode,smb2-time' "${host}"
        ;;
    ftp)
        emit_action "${safe_id}-ftp" "Inspect FTP banner and anonymous access" \
            'Use standard nmap FTP checks without uploading or modifying files.' read_only \
            'Banner, anonymous-login result, and server capabilities.' \
            nmap -Pn -p "${port}" --script 'ftp-anon,ftp-syst' "${host}"
        ;;
    domain|dns)
        emit_action "${safe_id}-dns-version" "Inspect DNS service behavior" \
            'Query DNS version metadata when exposed; no zone-transfer attempt is included automatically.' read_only \
            'DNS response behavior and any exposed version metadata.' \
            nmap -Pn -p "${port}" --script 'dns-nsid' "${host}"
        ;;
    *)
        emit_action "${safe_id}-service" "Confirm service and version" \
            'Run a focused service/version scan only on the discovered port.' read_only \
            'Confirmed protocol, product, version, and standard script output.' \
            nmap -Pn -sV -sC -p "${port}" "${host}"
        ;;
esac

printf '\nReview actions: bash recon/review-plan.sh %s\n' "${OUTPUT_DIR}"
