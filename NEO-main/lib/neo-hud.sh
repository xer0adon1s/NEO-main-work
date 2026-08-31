#!/usr/bin/env bash
# neo-hud.sh — Matrix recon progress HUD (replaces plain countdown)

neo_hud_init_colors() {
    C_RESET="${C_RESET:-$'\033[0m'}"
    C_GREEN="${C_GREEN:-$'\033[0;32m'}"
    C_DIM="${C_DIM:-$'\033[2;32m'}"
    C_BRIGHT="${C_BRIGHT:-$'\033[1;32m'}"
}

neo_hud_rain_chars=(ｱ ｲ ｳ ｴ ｵ 0 1 0 1 1 0)
neo_hud_spinner=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
neo_hud_substatus=(ports services banners paths creds shells)

neo_hud_rain_line() {
    local width=60 i s=""
    for ((i = 0; i < width; i++)); do
        s+="${neo_hud_rain_chars[$((RANDOM % ${#neo_hud_rain_chars[@]}))]}"
    done
    printf '%s' "${s}"
}

neo_hud_progress_bar() {
    local pct="$1" width=24 filled empty i
    filled=$((pct * width / 100))
    empty=$((width - filled))
    printf '['
    for ((i = 0; i < filled; i++)); do printf '▓'; done
    for ((i = 0; i < empty; i++)); do printf '░'; done
    printf ']'
}

neo_hud_resolve_target() {
    local t=""
    t="$(meta_get target 2>/dev/null || true)"
    [[ -n "${t}" && "${t}" != "unknown" ]] && printf '%s' "${t}" && return 0
    printf '%s' "target"
}

neo_hud_clear_lines() {
    local n="${1:-4}"
    tput cuu "${n}" 2>/dev/null || true
    tput el 2>/dev/null || true
    printf '\033[%dA\033[J' "${n}" 2>/dev/null || true
}

neo_hud_wide_tick() {
    local budget="$1" label="$2" target="$3" elapsed="$4"
    local remaining pct spin="$5" sub="$6"
    remaining=$((budget - elapsed))
    (( remaining < 0 )) && remaining=0
    pct=$((elapsed * 100 / budget))
    (( pct > 100 )) && pct=100

    neo_hud_init_colors
    tput cuu 4 2>/dev/null || true
    printf '  %s▓▒░ RECON ░▒▓  %s ────────────────────────────────────────%s\n' \
        "${C_GREEN}" "${label}" "${C_RESET}"
    printf '  %s%s  %3d%%  │  %3ds left%s\n' \
        "$(neo_hud_progress_bar "${pct}")" "${C_BRIGHT}" "${pct}" "${remaining}" "${C_RESET}"
    printf '  %s%s%s  scanning %s\n' \
        "${C_DIM}" "$(neo_hud_rain_line)" "${C_RESET}" "${target}"
    printf '  %s%s %s │ matrix cascade active%s\n' \
        "${C_GREEN}" "${neo_hud_spinner[$((spin % ${#neo_hud_spinner[@]}))]}" \
        "${neo_hud_substatus[$((sub % ${#neo_hud_substatus[@]}))]}" "${C_RESET}"
}

neo_hud_compact_tick() {
    local budget="$1" label="$2" elapsed="$3" spin="$4"
    local remaining pct
    remaining=$((budget - elapsed))
    (( remaining < 0 )) && remaining=0
    pct=$((elapsed * 100 / budget))
    (( pct > 100 )) && pct=100
    neo_hud_init_colors
    printf '\r  %s%s%s %s %s %3d%% · %3ds   ' \
        "${C_GREEN}" "${neo_hud_spinner[$((spin % ${#neo_hud_spinner[@]}))]}" "${C_RESET}" \
        "[${label}]" "$(neo_hud_progress_bar "${pct}")" "${pct}" "${remaining}"
}

neo_hud_countdown() {
    local budget="$1" label="$2" outfile="$3"
    shift 3
    local target pid elapsed=0 spin=0 sub=0 status=0 wide=0

    if (( ${COLUMNS:-80} >= 80 )) && [[ "${NEO_HUD_STYLE:-auto}" != "compact" ]]; then
        wide=1
    fi

    target="$(neo_hud_resolve_target)"
    timeout "${budget}" "$@" > "${outfile}" 2>&1 &
    pid=$!

    neo_hud_init_colors
    if (( wide )); then
        tput civis 2>/dev/null || true
        printf '\n\n\n\n'
    fi

    while kill -0 "${pid}" 2>/dev/null; do
        if (( wide )); then
            neo_hud_wide_tick "${budget}" "${label}" "${target}" "${elapsed}" "${spin}" "${sub}"
        else
            neo_hud_compact_tick "${budget}" "${label}" "${elapsed}" "${spin}"
        fi
        sleep 1
        elapsed=$((elapsed + 1))
        spin=$((spin + 1))
        sub=$((sub + 1))
    done

    if (( wide )); then
        neo_hud_clear_lines 4
        tput cnorm 2>/dev/null || true
        printf '%s%s%s\n' "${C_BRIGHT}" "  [✓] ${label} complete — findings filed." "${C_RESET}"
    else
        printf '\r%-72s\r' ' '
        tput cnorm 2>/dev/null || true
    fi

    wait "${pid}" || status=$?
    return "${status}"
}
