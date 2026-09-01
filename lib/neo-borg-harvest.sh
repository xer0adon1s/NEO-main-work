#!/usr/bin/env bash
# neo-borg-harvest.sh — mechanical fetch helpers for library harvest (Tier B prototype).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

neo_borg_harvest_network_enabled() {
    [[ "${NEO_BORG_HARVEST_NETWORK:-0}" == "1" && "${NEO_TEST_NONINTERACTIVE:-0}" != "1" ]]
}

neo_borg_harvest_slugify() {
    local s="$1"
    s="$(tr '[:upper:]' '[:lower:]' <<< "${s}")"
    s="$(sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' <<< "${s}")"
    printf '%s' "${s:-topic}"
}

neo_borg_harvest_html_to_text() {
    local html="$1"
    sed -E 's/<[^>]+>//g; s/&nbsp;/ /g; s/&amp;/\&/g' <<< "${html}" | tr -s '[:space:]' ' '
}

neo_borg_harvest_fetch_url() {
    local url="$1" dest="$2"
    neo_borg_harvest_network_enabled || return 1
    command -v curl >/dev/null 2>&1 || return 1
    curl -fsSL --max-time 30 -o "${dest}" "${url}"
}

neo_borg_harvest_fetch_nvd_cve() {
    local cve="$1" dest="$2"
    neo_borg_harvest_network_enabled || return 1
    command -v curl >/dev/null 2>&1 || return 1
    curl -fsSL --max-time 30 -o "${dest}" \
        "https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=${cve}"
}

neo_borg_harvest_make_educational() {
    local raw="$1"
    # Strip obvious platform spoilers for educational artifact.
    sed -E 's/(HackTheBox|TryHackMe)[^[:space:]]*/[platform]/gi' <<< "${raw}"
}
