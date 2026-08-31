#!/usr/bin/env bash
# notes-lib.sh — shared helpers for writing to a project's Investigation-Notes.md.
#
# Source this from any recon/enumeration script that runs locally (against the
# VPN target, not on-box):
#
#   source "${HOME}/Neo/lib/notes-lib.sh"
#   notes_init "${PROJECT_NAME}" "${TARGET}" "${OUTDIR}"
#   notes_set_section PORTS "some content"       # overwrite a fixed section
#   notes_append_section SERVICES "some content" # append to a growing section
#   notes_log_smart "babysteps" "raw output"     # LOG + artifact if huge
#   notes_refresh_status "babysteps" "3 ports open, 1 web lead"
#
# A script that runs ON THE TARGET instead (SSH session, curl|bash — no
# access to this machine's ~/Neo tree) can't source this file. Run it
# as a standalone command instead and pipe content into it over stdin:
#
#   ssh user@target 'bash -s' < FindPrivs.sh | notes-lib.sh <project> ingest FindPrivs
#   ssh user@target 'bash -s' < FindPrivs.sh | notes-lib.sh <project> log FindPrivs
#   notes-lib.sh <project> set WHOAMI    <<< "$(id)"
#   notes-lib.sh <project> append TODO   <<< "- [ ] a new lead"
#   notes-lib.sh <project> init <target>
#
# See "CLI mode" at the bottom of this file for the full verb list.
#
# The notes file (Investigation-Notes.md) is generated once per project from
# templates/investigation-notes.md and then never re-templated, so anything a
# human adds by hand survives every later script run. Each fillable section is
# wrapped in an HTML-comment marker pair
# (<!-- SECTION:TAG --> ... <!-- /SECTION:TAG -->) so a script can replace or
# append to exactly that section without touching anything else in the file —
# no fragile whole-document text matching required.

CYBERSEC="${CYBERSEC:-${NEO_HOME:-${HOME}/Neo}}"
NEO_HOME="${NEO_HOME:-${CYBERSEC}}"
NEO_DIR="${NEO_DIR:-${NEO_HOME}}"
NOTES_TEMPLATE="${NEO_HOME}/templates/investigation-notes.md"
NOTES_LOG_MAX_LINES="${NOTES_LOG_MAX_LINES:-100}"

_notes_outdir() {
    [[ -n "${NOTES_FILE:-}" ]] || return 1
    dirname "${NOTES_FILE}"
}

_meta_file() {
    echo "$(_notes_outdir)/project.meta"
}

# Creates or updates project.meta beside Investigation-Notes.md.
meta_init() {
    local project="$1" target="$2" outdir="$3"
    local mf="${outdir}/project.meta"
    mkdir -p "${outdir}"
    if [[ ! -f "${mf}" ]]; then
        cat > "${mf}" <<EOF
project=${project}
target=${target}
phase=recon
platform=
ssh_target=
last_script=
last_updated=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    fi
}

meta_set() {
    local key="$1" value="$2"
    local mf tmp
    mf="$(_meta_file)" || { echo "notes-lib: meta_set — NOTES_FILE not set" >&2; return 1; }
    [[ -f "${mf}" ]] || return 1
    tmp="$(mktemp)"
    grep -v "^${key}=" "${mf}" > "${tmp}" 2>/dev/null || true
    printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
    mv "${tmp}" "${mf}"
}

meta_get() {
    local key="$1"
    local mf
    mf="$(_meta_file)" || return 1
    [[ -f "${mf}" ]] || return 1
    grep "^${key}=" "${mf}" 2>/dev/null | cut -d= -f2- | head -n1
}

# Creates Investigation-Notes.md in $3 from the template, filling in the
# project name/target/start time. A no-op if the file already exists, so
# re-running a script against the same project never clobbers prior notes.
# Sets the global NOTES_FILE for the other notes_* functions to use.
notes_init() {
    local project="$1" target="$2" outdir="$3"
    NOTES_FILE="${outdir}/Investigation-Notes.md"
    mkdir -p "${outdir}"

    if [[ ! -f "${NOTES_FILE}" ]]; then
        if [[ ! -f "${NOTES_TEMPLATE}" ]]; then
            echo "notes-lib: template not found at ${NOTES_TEMPLATE}, skipping notes" >&2
            return 1
        fi
        local date_str
        date_str="$(date '+%Y-%m-%d %H:%M:%S')"
        while IFS= read -r line || [[ -n "${line}" ]]; do
            line="${line//\{\{PROJECT\}\}/${project}}"
            line="${line//\{\{TARGET\}\}/${target}}"
            line="${line//\{\{DATE\}\}/${date_str}}"
            printf '%s\n' "${line}"
        done < "${NOTES_TEMPLATE}" > "${NOTES_FILE}"
    fi

    meta_init "${project}" "${target}" "${outdir}"
    mkdir -p "${outdir}/artifacts"
}

notes_save_artifact() {
    local source="$1" content="$2"
    local outdir artifact_dir ts relpath path
    outdir="$(_notes_outdir)" || return 1
    artifact_dir="${outdir}/artifacts"
    mkdir -p "${artifact_dir}"
    ts="$(date '+%Y%m%d-%H%M%S')"
    path="${artifact_dir}/${source}-${ts}.txt"
    printf '%s' "${content}" > "${path}"
    relpath="artifacts/$(basename "${path}")"
    printf '%s' "${relpath}"
}

notes_set_section() {
    local tag="$1" content="$2"
    [[ -n "${NOTES_FILE:-}" ]] || { echo "notes-lib: notes_init not called yet" >&2; return 1; }
    [[ -f "${NOTES_FILE}" ]] || { echo "notes-lib: notes file not found: ${NOTES_FILE}" >&2; return 1; }

    local cfile tmp awk_status=0
    cfile="$(mktemp)"; tmp="$(mktemp)"
    printf '%s\n' "${content}" > "${cfile}"

    awk -v start="<!-- SECTION:${tag} -->" -v end="<!-- /SECTION:${tag} -->" -v cfile="${cfile}" '
        BEGIN { in_section=0; found_start=0 }
        $0 == start {
            print
            while ((getline line < cfile) > 0) print line
            close(cfile)
            in_section=1
            found_start=1
            next
        }
        in_section {
            if ($0 == end) {
                in_section=0
                print
            }
            next
        }
        { print }
        END {
            if (in_section) exit 1
            if (!found_start) exit 2
        }
    ' "${NOTES_FILE}" > "${tmp}" || awk_status=$?

    rm -f "${cfile}"

    case "${awk_status}" in
        0) mv "${tmp}" "${NOTES_FILE}" ;;
        1)
            rm -f "${tmp}"
            echo "notes-lib: section '${tag}' missing closing marker in ${NOTES_FILE} — not modified" >&2
            return 1
            ;;
        2)
            rm -f "${tmp}"
            echo "notes-lib: section tag '${tag}' not found in ${NOTES_FILE} — skipped" >&2
            return 1
            ;;
        *)
            rm -f "${tmp}"
            echo "notes-lib: failed to update section '${tag}'" >&2
            return 1
            ;;
    esac
}

notes_append_section() {
    local tag="$1" content="$2"
    [[ -n "${NOTES_FILE:-}" ]] || { echo "notes-lib: notes_init not called yet" >&2; return 1; }
    [[ -f "${NOTES_FILE}" ]] || { echo "notes-lib: notes file not found: ${NOTES_FILE}" >&2; return 1; }

    local cfile tmp awk_status=0
    cfile="$(mktemp)"; tmp="$(mktemp)"
    printf '%s\n' "${content}" > "${cfile}"

    awk -v end="<!-- /SECTION:${tag} -->" -v cfile="${cfile}" '
        BEGIN { found_end=0 }
        $0 == end {
            while ((getline line < cfile) > 0) print line
            close(cfile)
            found_end=1
        }
        { print }
        END { if (!found_end) exit 2 }
    ' "${NOTES_FILE}" > "${tmp}" || awk_status=$?

    rm -f "${cfile}"

    case "${awk_status}" in
        0) mv "${tmp}" "${NOTES_FILE}" ;;
        2)
            rm -f "${tmp}"
            echo "notes-lib: section tag '${tag}' not found in ${NOTES_FILE} — skipped" >&2
            return 1
            ;;
        *)
            rm -f "${tmp}"
            echo "notes-lib: failed to append to section '${tag}'" >&2
            return 1
            ;;
    esac
}

# Returns the body of a marked section (stdout). Empty string if missing/empty.
notes_get_section() {
    local tag="$1"
    [[ -n "${NOTES_FILE:-}" && -f "${NOTES_FILE}" ]] || return 1
    awk -v start="<!-- SECTION:${tag} -->" -v end="<!-- /SECTION:${tag} -->" '
        $0 == start { in_section=1; next }
        in_section && $0 == end { exit 0 }
        in_section { print }
    ' "${NOTES_FILE}"
}

notes_log() {
    local source="$1" content="$2"
    local entry
    entry="$(printf '\n### [%s] %s\n\n```text\n%s\n```\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "${source}" "${content}")"
    notes_append_section LOG "${entry}"
}

# Writes to LOG; spills full output to artifacts/ when content exceeds
# NOTES_LOG_MAX_LINES (default 100) so the report stays readable.
notes_log_smart() {
    local source="$1" content="$2"
    local line_count preview artifact_rel entry ts

    line_count="$(printf '%s\n' "${content}" | wc -l)"
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    if (( line_count > NOTES_LOG_MAX_LINES )); then
        artifact_rel="$(notes_save_artifact "${source}" "${content}")" \
            || { notes_log "${source}" "${content}"; return $?; }
        preview="$(printf '%s\n' "${content}" | head -n 20)"
        entry="$(printf '\n### [%s] %s\n\n_Output truncated (%s lines). Full artifact:_ `%s`\n\n```text\n%s\n... (see artifact)\n```\n' \
            "${ts}" "${source}" "${line_count}" "${artifact_rel}" "${preview}")"
        notes_append_section LOG "${entry}"
    else
        notes_log "${source}" "${content}"
    fi
}

# Rebuilds the reader-facing STATUS section (tl;dr at the top of the report).
notes_refresh_status() {
    local script="$1" summary="$2"
    local phase target updated status_text

    phase="$(meta_get phase 2>/dev/null || echo "unknown")"
    target="$(meta_get target 2>/dev/null || echo "unknown")"
    updated="$(date '+%Y-%m-%d %H:%M:%S')"
    status_text="_Last updated by **${script}** at ${updated} — phase \`${phase}\`, target \`${target}\`. ${summary}_"
    notes_set_section STATUS "${status_text}" || true
    meta_set last_script "${script}" || true
    meta_set last_updated "${updated}" || true
}

# Default === Section === → TAG maps for known on-target scripts (see registry.yaml).
_notes_ingest_default_map() {
    case "$1" in
        FindPrivs)
            printf '%s' \
                'System identity:WHOAMI,'\
'sudo privileges:SUDO,'\
'SUID / SGID binaries:SUID,'\
'Linux capabilities:CAPS,'\
'Cron jobs:CRON,'\
'Writable sensitive files:FILES,'\
'PATH hijacking:+FILES,'\
'Privileged group membership:+FILES,'\
'NFS no_root_squash:+FILES,'\
'VERDICT:+TODO'
            ;;
        *)
            printf '%s' ""
            ;;
    esac
}

# Parses `=== Header ===` blocks from on-target script output into section tags.
# map_spec: "Header:TAG,Header:+TAG,..." — TAG = set, +TAG = append.
notes_ingest() {
    local source="$1" map_spec="$2" content="$3"
    local sections_file hdr line mode tag block
    declare -A ingest_mode=() ingest_tag=()

    if [[ -z "${map_spec}" ]]; then
        map_spec="$(_notes_ingest_default_map "${source}")"
    fi
    if [[ -z "${map_spec}" ]]; then
        echo "notes-lib: no ingest map for '${source}' — use log instead, or pass a map" >&2
        return 1
    fi

    local IFS=',' item
    for item in ${map_spec}; do
        hdr="${item%%:*}"
        tag="${item#*:}"
        mode="set"
        if [[ "${tag}" == +* ]]; then
            mode="append"
            tag="${tag#+}"
        fi
        ingest_mode["${hdr}"]="${mode}"
        ingest_tag["${hdr}"]="${tag}"
    done

    sections_file="$(mktemp)"
    printf '%s' "${content}" > "${sections_file}"

    _ingest_flush() {
        local h="$1" body="$2"
        [[ -n "${h}" && -n "${ingest_tag[${h}]+x}" ]] || return 0
        mode="${ingest_mode[${h}]}"
        tag="${ingest_tag[${h}]}"
        block="$(printf '**From %s — %s**\n\n```text\n%s\n```\n' "${source}" "${h}" "${body}")"
        if [[ "${mode}" == "append" ]]; then
            notes_append_section "${tag}" "${block}" || true
        else
            notes_set_section "${tag}" "${block}" || true
        fi
    }

    hdr=""
    block=""
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" =~ ^===[[:space:]](.+)[[:space:]]===$ ]]; then
            _ingest_flush "${hdr}" "${block}"
            hdr="${BASH_REMATCH[1]}"
            block=""
        elif [[ -n "${hdr}" ]]; then
            if [[ -n "${block}" ]]; then
                block+=$'\n'
            fi
            block+="${line}"
        fi
    done < "${sections_file}"
    _ingest_flush "${hdr}" "${block}"

    rm -f "${sections_file}"
    notes_log_smart "${source}" "${content}"
}

# ---------------------------------------------------------------------------
# CLI mode
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -uo pipefail

    project="${1:-}"
    verb="${2:-}"
    arg="${3:-}"
    arg2="${4:-}"

    if [[ -z "${project}" || -z "${verb}" ]]; then
        cat >&2 <<'EOF'
Usage: notes-lib.sh <project> init <target>
       notes-lib.sh <project> set       <TAG>       < content
       notes-lib.sh <project> append    <TAG>       < content
       notes-lib.sh <project> log       <source>    < content
       notes-lib.sh <project> ingest    <source>    [map-spec]  < content
       notes-lib.sh <project> status    [summary text for STATUS section]
       notes-lib.sh <project> meta-get <key>
       notes-lib.sh <project> meta-set  <key> <value>

ingest maps `=== Header ===` blocks to section tags (FindPrivs has a built-in map).
Use +TAG in a map to append instead of replace (e.g. 'Extra:+TODO').

On-target scripts — pipe from your attack box:
  ssh user@target 'bash -s' < FindPrivs.sh | notes-lib.sh <project> ingest FindPrivs
EOF
        exit 1
    fi

    OUTDIR="${NEO_HOME}/projects/${project}"
    mkdir -p "${OUTDIR}"

    case "${verb}" in
        init)
            notes_init "${project}" "${arg:-unknown}" "${OUTDIR}"
            ;;
        set)
            [[ -n "${arg}" ]] || { echo "notes-lib: 'set' needs a section TAG" >&2; exit 1; }
            notes_init "${project}" "unknown" "${OUTDIR}"
            notes_set_section "${arg}" "$(cat -)" || exit 1
            ;;
        append)
            [[ -n "${arg}" ]] || { echo "notes-lib: 'append' needs a section TAG" >&2; exit 1; }
            notes_init "${project}" "unknown" "${OUTDIR}"
            notes_append_section "${arg}" "$(cat -)" || exit 1
            ;;
        log)
            [[ -n "${arg}" ]] || { echo "notes-lib: 'log' needs a source name" >&2; exit 1; }
            notes_init "${project}" "unknown" "${OUTDIR}"
            notes_log_smart "${arg}" "$(cat -)" || exit 1
            ;;
        ingest)
            [[ -n "${arg}" ]] || { echo "notes-lib: 'ingest' needs a source name" >&2; exit 1; }
            map_spec="${arg2:-}"
            notes_init "${project}" "unknown" "${OUTDIR}"
            notes_ingest "${arg}" "${map_spec}" "$(cat -)" || exit 1
            ;;
        status)
            notes_init "${project}" "unknown" "${OUTDIR}"
            NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
            summary="${arg:-Run in progress.}"
            notes_refresh_status "manual" "${summary}" || exit 1
            ;;
        meta-get)
            [[ -n "${arg}" ]] || { echo "notes-lib: 'meta-get' needs a key" >&2; exit 1; }
            notes_init "${project}" "unknown" "${OUTDIR}"
            val="$(meta_get "${arg}")"
            [[ -n "${val}" ]] || exit 1
            printf '%s\n' "${val}"
            ;;
        meta-set)
            [[ -n "${arg}" && -n "${arg2}" ]] || { echo "notes-lib: 'meta-set' needs key and value" >&2; exit 1; }
            notes_init "${project}" "unknown" "${OUTDIR}"
            meta_set "${arg}" "${arg2}" || exit 1
            ;;
        *)
            echo "notes-lib: unknown verb '${verb}'" >&2
            exit 1
            ;;
    esac

    echo "notes-lib: updated ${NOTES_FILE}" >&2
fi
