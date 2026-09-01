#!/usr/bin/env bash
# neo-toolkit.sh — verify tools, wordlists, and file paths before running AI/Borg suggestions.
#
# Answers: "Is everything this command needs actually on the attack box?" with optional
# operator-approved install/fix (pacman/apt, SecLists, vendor/setup.sh).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
NEO_HOME="${NEO_HOME:-${NEO_DIR}}"
# shellcheck source=neo-core.sh
source "${NEO_LIB_DIR}/neo-core.sh"

neo_toolkit_init_colors() {
    C_RESET="${C_RESET:-$'\033[0m'}"
    C_GREEN="${C_GREEN:-$'\033[0;32m'}"
    C_YELLOW="${C_YELLOW:-$'\033[0;33m'}"
    C_CYAN="${C_CYAN:-$'\033[0;36m'}"
    C_DIM="${C_DIM:-$'\033[2m'}"
}

neo_toolkit_tool_to_package() {
    case "$1" in
        smbclient) echo samba ;;
        seclists)  echo seclists ;;
        msfconsole|msfvenom|msfdb) echo metasploit ;;
        *)         echo "$1" ;;
    esac
}

# First existing SecLists/wordlists root on this box.
neo_toolkit_seclists_root() {
    local d
    for d in \
        /usr/share/seclists \
        /usr/share/wordlists/seclists \
        /usr/share/SecLists \
        "${HOME}/SecLists" \
        "${HOME}/wordlists/SecLists" \
        "${NEO_HOME}/wordlists/SecLists"; do
        [[ -d "${d}" ]] || continue
        printf '%s' "${d}"
        return 0
    done
    return 1
}

neo_toolkit_expand_path() {
    local p="$1"
    p="${p//\$HOME/${HOME}}"
    p="${p/#\~/${HOME}}"
    printf '%s' "${p}"
}

neo_toolkit_path_exists() {
    local p
    p="$(neo_toolkit_expand_path "$1")"
    [[ -n "${p}" && -e "${p}" ]]
}

neo_toolkit_is_seclists_reference() {
    local p="$1"
    [[ "${p}" =~ [Ss]ec[Ll]ists|[Ww]ordlists|rockyou|/usr/share/seclists|/usr/share/wordlists ]]
}

neo_toolkit_command_binary() {
    local cmd="$1" tok
    cmd="$(sed 's/^[[:space:]]*//; s/[;&|].*$//' <<< "${cmd}")"
    [[ -n "${cmd}" ]] || return 1
    read -ra toks <<< "${cmd}"
    for tok in "${toks[@]}"; do
        case "${tok}" in
            sudo|env|nohup|timeout|stdbuf|command) continue ;;
            *=*) continue ;;
            /*/*)
                basename -- "${tok}"
                return 0
                ;;
            /*)
                basename -- "${tok}"
                return 0
                ;;
            *)
                printf '%s' "${tok}"
                return 0
                ;;
        esac
    done
    return 1
}

# Print one path per line (deduped later).
neo_toolkit_extract_paths_from_command() {
    local cmd="$1"
    awk '
        {
            for (i = 1; i <= NF; i++) {
                if (prev ~ /^(-w|--wordlist|-U|-P|-f|--file|--path|--paths|--payload|--list)$/) {
                    if ($i !~ /^-/) print $i
                    prev = ""
                    continue
                }
                if ($i ~ /^--wordlist=/) { sub(/^--wordlist=/, "", $i); print $i; continue }
                if ($i ~ /^(-w|-f|-U|-P)=/) { sub(/^[^=]+=/, "", $i); print $i; continue }
                if ($i ~ /^(\/|~|\$HOME\/)/) print $i
                if ($i ~ /[Ss]ec[Ll]ists|[Ww]ordlists|rockyou/) print $i
                prev = $i
            }
        }
    ' <<< "${cmd}"
}

neo_toolkit_extract_commands_from_text() {
    awk '
        /^```/ {
            if (!open) { open = 1; buf = ""; next }
            if (buf != "") print buf
            open = 0; buf = ""
            next
        }
        open { buf = (buf == "" ? $0 : buf "\n" $0) }
        END { if (open && buf != "") print buf }
    ' <<< "$1"
}

# Emit status lines: ok|tool|NAME  or  missing|tool|NAME  or  missing|path|PATH
neo_toolkit_analyze_command() {
    local cmd="$1" bin path
    [[ -n "${cmd}" ]] || return 0
    # shellcheck source=neo-exploit-framework.sh
    [[ -f "${NEO_LIB_DIR}/neo-exploit-framework.sh" ]] && \
        source "${NEO_LIB_DIR}/neo-exploit-framework.sh" 2>/dev/null || true
    bin="$(neo_toolkit_command_binary "${cmd}" 2>/dev/null || true)"
    if [[ -n "${bin}" ]]; then
        if command -v "${bin}" >/dev/null 2>&1; then
            printf 'ok|%s|tool\n' "${bin}"
        elif [[ -f "${NEO_HOME}/vendor/${bin}" ]]; then
            printf 'ok|%s|vendor\n' "${bin}"
        else
            printf 'missing|%s|tool\n' "${bin}"
        fi
    fi
    while IFS= read -r path; do
        [[ -n "${path}" ]] || continue
        if neo_toolkit_path_exists "${path}"; then
            printf 'ok|%s|path\n' "${path}"
        elif neo_toolkit_is_seclists_reference "${path}"; then
            if neo_toolkit_seclists_root >/dev/null; then
                printf 'warn|%s|seclists-path\n' "${path}"
            else
                printf 'missing|%s|seclists\n' "${path}"
            fi
        elif [[ "${path}" == vendor/* || "${path}" == */vendor/* ]]; then
            local v="${path#vendor/}"
            v="${v##*/vendor/}"
            if [[ -f "${NEO_HOME}/vendor/${v}" ]]; then
                printf 'ok|%s|vendor\n' "${path}"
            else
                printf 'missing|%s|vendor\n' "${path}"
            fi
        else
            printf 'missing|%s|path\n' "${path}"
        fi
    done < <(neo_toolkit_extract_paths_from_command "${cmd}")
}

neo_toolkit_analyze_text() {
    local text="$1" cmd tool
    # shellcheck source=neo-ai-analyze.sh
    source "${NEO_LIB_DIR}/neo-ai-analyze.sh" 2>/dev/null || true
    if declare -F neo_ai_extract_tools_from_response >/dev/null 2>&1; then
        while IFS= read -r tool; do
            [[ -n "${tool}" ]] || continue
            if command -v "${tool}" >/dev/null 2>&1; then
                printf 'ok|%s|tool\n' "${tool}"
            else
                printf 'missing|%s|tool\n' "${tool}"
            fi
        done < <(neo_ai_extract_tools_from_response "${text}")
    fi
    while IFS= read -r cmd; do
        while IFS= read -r line; do
            [[ -n "${line}" ]] || continue
            neo_toolkit_analyze_command "${line}"
        done <<< "${cmd}"
    done < <(neo_toolkit_extract_commands_from_text "${text}")
}

neo_toolkit_install_tool() {
    local tool="$1" pkg ans
    pkg="$(neo_toolkit_tool_to_package "${tool}")"
    if command -v pacman >/dev/null 2>&1; then
        read -r -p "    Install ${tool} via: sudo pacman -S --needed ${pkg} ? [y/N] " ans
        [[ "${ans}" =~ ^[yY]$ ]] || return 1
        sudo pacman -S --needed "${pkg}"
        return $?
    fi
    if command -v apt-get >/dev/null 2>&1; then
        read -r -p "    Install ${tool} via: sudo apt install ${pkg} ? [y/N] " ans
        [[ "${ans}" =~ ^[yY]$ ]] || return 1
        sudo apt install -y "${pkg}"
        return $?
    fi
    printf '    Install %s with your package manager, then retry.\n' "${tool}"
    return 1
}

neo_toolkit_install_seclists() {
    local dest="${NEO_TOOLKIT_SECLISTS_DEST:-${HOME}/wordlists/SecLists}" ans pkg
    if command -v pacman >/dev/null 2>&1; then
        read -r -p '    Install SecLists via: sudo pacman -S --needed seclists ? [y/N] ' ans
        if [[ "${ans}" =~ ^[yY]$ ]]; then
            sudo pacman -S --needed seclists && return 0
        fi
    fi
    if command -v apt-get >/dev/null 2>&1; then
        read -r -p '    Install SecLists via: sudo apt install seclists ? [y/N] ' ans
        if [[ "${ans}" =~ ^[yY]$ ]]; then
            sudo apt install -y seclists && return 0
        fi
    fi
    read -r -p "    Clone SecLists to ${dest} ? [y/N] " ans
    [[ "${ans}" =~ ^[yY]$ ]] || return 1
    neo_core_need git || return 1
    mkdir -p "$(dirname "${dest}")"
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git "${dest}"
}

neo_toolkit_install_vendor() {
    local setup="${NEO_HOME}/setup.sh" ans
    [[ -f "${setup}" ]] || {
        printf '    vendor tool missing — run from NEO root: ./setup.sh\n'
        return 1
    }
    read -r -p '    Download missing vendor tools via ./setup.sh ? [y/N] ' ans
    [[ "${ans}" =~ ^[yY]$ ]] || return 1
    (cd "${NEO_HOME}" && bash ./setup.sh)
}

neo_toolkit_suggest_path_rewrite() {
    local path="$1" root sub
    root="$(neo_toolkit_seclists_root 2>/dev/null || true)"
    [[ -n "${root}" ]] || return 1
    if [[ "${path}" =~ Discovery/Web-Content/([^[:space:]/]+) ]]; then
        sub="${BASH_REMATCH[1]}"
        if [[ -f "${root}/Discovery/Web-Content/${sub}" ]]; then
            printf '%s/Discovery/Web-Content/%s' "${root}" "${sub}"
            return 0
        fi
    fi
    if [[ "${path}" =~ /([^/[:space:]]+\.txt)$ ]]; then
        sub="${BASH_REMATCH[1]}"
        find "${root}" -name "${sub}" -type f 2>/dev/null | head -1
    fi
}

neo_toolkit_print_report() {
    local -a lines=("$@")
    local line kind item hint alt
    neo_toolkit_init_colors
    printf '\n%s  ▸ LOCK & LOAD — dependency check%s\n\n' "${C_CYAN}" "${C_RESET}"
    for line in "${lines[@]}"; do
        IFS='|' read -r kind item hint <<< "${line}"
        case "${kind}" in
            ok)
                printf '    %s[ok]%s %s\n' "${C_GREEN}" "${C_RESET}" "${item}"
                ;;
            warn)
                alt="$(neo_toolkit_suggest_path_rewrite "${item}" 2>/dev/null || true)"
                if [[ -n "${alt}" && -f "${alt}" ]]; then
                    printf '    %s[~]%s path not found: %s\n' "${C_YELLOW}" "${C_RESET}" "${item}"
                    printf '        SecLists is elsewhere — try: %s\n' "${alt}"
                else
                    printf '    %s[~]%s path not found (SecLists installed elsewhere?): %s\n' \
                        "${C_YELLOW}" "${C_RESET}" "${item}"
                fi
                ;;
            missing)
                case "${hint}" in
                    seclists)
                        printf '    %s[MISS]%s SecLists / wordlist: %s\n' "${C_YELLOW}" "${C_RESET}" "${item}"
                        ;;
                    vendor)
                        printf '    %s[MISS]%s vendor file: %s\n' "${C_YELLOW}" "${C_RESET}" "${item}"
                        ;;
                    tool)
                        printf '    %s[MISS]%s tool not on PATH: %s\n' "${C_YELLOW}" "${C_RESET}" "${item}"
                        ;;
                    *)
                        printf '    %s[MISS]%s file/path: %s\n' "${C_YELLOW}" "${C_RESET}" "${item}"
                        ;;
                esac
                ;;
        esac
    done
    printf '\n'
}

# Parse report lines and offer fixes. Returns 0 if all required items present.
neo_toolkit_preflight_text() {
    local text="$1" project="${2:-}" offer_fix="${3:-1}"
    local -A seen=()
    local -a report=() line kind item hint
    local missing=0 need_vendor=false

    [[ -n "${text}" ]] || return 0

    while IFS= read -r line; do
        [[ -n "${line}" ]] || continue
        [[ -n "${seen[${line}]:-}" ]] && continue
        seen["${line}"]=1
        report+=("${line}")
        IFS='|' read -r kind item hint <<< "${line}"
        case "${kind}" in
            missing|warn) missing=$((missing + 1)) ;;
        esac
        [[ "${hint}" == vendor ]] && need_vendor=true
    done < <(neo_toolkit_analyze_text "${text}" | sort -u)

    ((${#report[@]} == 0)) && {
        printf '\n%s  ▸ LOCK & LOAD — no commands to check in this text.%s\n\n' "${C_CYAN}" "${C_RESET}"
        return 0
    }

    neo_toolkit_print_report "${report[@]}"

    (( missing == 0 )) && {
        printf '%s  All checked dependencies look ready.%s\n\n' "${C_GREEN}" "${C_RESET}"
        return 0
    }

    [[ "${offer_fix}" == 1 && -t 0 ]] || {
        printf '  Fix missing items before running, or use an alternate path/command.\n\n'
        return 1
    }

    local ans
    read -r -p 'Check/fix missing tools and wordlists now? [y/N]: ' ans
    [[ "${ans}" =~ ^[yY]$ ]] || {
        printf '  Skipped — fix manually or adjust the command before [t] try.\n\n'
        return 1
    }

    for line in "${report[@]}"; do
        IFS='|' read -r kind item hint <<< "${line}"
        [[ "${kind}" == missing || "${kind}" == warn ]] || continue
        case "${hint}" in
            seclists)
                neo_toolkit_install_seclists && continue
                ;;
            vendor)
                need_vendor=true
                continue
                ;;
            tool)
                if neo_toolkit_install_tool "${item}"; then
                    printf '    %s[ok]%s %s installed\n' "${C_GREEN}" "${C_RESET}" "${item}"
                fi
                ;;
            path|seclists-path)
                printf '    Cannot auto-fix path: %s\n' "${item}"
                ;;
        esac
    done

    ${need_vendor} && neo_toolkit_install_vendor

    # shellcheck source=script-lib.sh
    if [[ -n "${project}" ]] && declare -F notes_append_section >/dev/null 2>&1; then
        notes_append_section TODO $'- [ ] Toolkit preflight — verify paths/tools before next [t] try' || true
    fi

    printf '\n'
    return 1
}

neo_toolkit_preflight_command() {
    local cmd="$1" project="${2:-}"
    neo_toolkit_preflight_text "${cmd}" "${project}"
}

neo_toolkit_offer_after_suggest() {
    local response="$1" project="$2"
    local ans
    [[ -t 0 ]] || return 0
    neo_toolkit_init_colors
    read -r -p "$(printf '%s  Verify tools & wordlists for this suggestion? [Y/n]: %s' "${C_CYAN}" "${C_RESET}")" ans
    case "${ans}" in
        n|N) return 0 ;;
        *) neo_toolkit_preflight_text "${response}" "${project}" 1 || true ;;
    esac
}
