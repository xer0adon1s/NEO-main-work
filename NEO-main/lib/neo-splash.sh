#!/usr/bin/env bash
# neo-splash.sh — Matrix launch splash for neo.sh

neo_splash_init_colors() {
    C_RESET="${C_RESET:-$'\033[0m'}"
    C_GREEN="${C_GREEN:-$'\033[0;32m'}"
    C_DIM="${C_DIM:-$'\033[2;32m'}"
    C_BRIGHT="${C_BRIGHT:-$'\033[1;32m'}"
}

neo_splash_rain_frame() {
    local i
    neo_splash_init_colors
    for ((i = 0; i < 4; i++)); do
        printf '\r%s%s%s' "${C_DIM}" \
            " ｱ010ｲ110ｳ010 010ｱ101ｲ010 110010ｱ010 010110ｱ101 01001110 01000101 01001111 " \
            "${C_RESET}"
        sleep 0.12
    done
    printf '\r%-72s\r' ' '
}

neo_splash_pick_asset() {
    local style="${NEO_SPLASH:-wide}"
    case "${style}" in
        0|off|no|false) return 1 ;;
        compact|min)    printf '%s/assets/splash-launch-compact.txt' "${NEO_DIR:-${NEO_HOME}}" ;;
        *)              printf '%s/assets/splash-launch-%s.txt' "${NEO_DIR:-${NEO_HOME}}" \
                            "$(( ${COLUMNS:-100} >= 80 ? wide : compact ))" ;;
    esac
}

neo_splash_color_line() {
    local line="$1"
    neo_splash_init_colors
    case "${line}" in
        010*|*ｱ*|*ｲ*|*ｳ*|*ｴ*|*ｵ*)
            printf '%s%s%s\n' "${C_DIM}" "${line}" "${C_RESET}"
            ;;
        *PROJECT*|*NEO*|*█*|*▓*|*░*|*╔*|*║*|*╚*|*│*|*└*|*┌*)
            printf '%s%s%s\n' "${C_GREEN}" "${line}" "${C_RESET}"
            ;;
        *)
            printf '%s\n' "${line}"
            ;;
    esac
}

neo_splash_print() {
    local asset style="${NEO_SPLASH:-auto}"
    [[ "${style}" == "0" || "${style}" == "off" ]] && return 0

    if [[ "${style}" == "auto" ]]; then
        if (( ${COLUMNS:-100} >= 80 )); then
            asset="${NEO_DIR:-${NEO_HOME}}/assets/splash-launch-wide.txt"
        else
            asset="${NEO_DIR:-${NEO_HOME}}/assets/splash-launch-compact.txt"
        fi
    elif [[ "${style}" == "compact" ]]; then
        asset="${NEO_DIR:-${NEO_HOME}}/assets/splash-launch-compact.txt"
    else
        asset="${NEO_DIR:-${NEO_HOME}}/assets/splash-launch-wide.txt"
    fi

    [[ -f "${asset}" ]] || return 0

    neo_splash_rain_frame
    while IFS= read -r line || [[ -n "${line}" ]]; do
        neo_splash_color_line "${line}"
    done < "${asset}"
    printf '\n'
}

neo_splash_mission_line() {
    local project="$1" target="${2:-}"
    neo_splash_init_colors
    if [[ -n "${target}" ]]; then
        printf '%s%s%s mission: %s @ %s %s\n\n' \
            "${C_BRIGHT}" "»" "${C_RESET}" "${project}" "${target}" "${C_RESET}"
    else
        printf '%s%s%s mission: %s %s\n\n' \
            "${C_BRIGHT}" "»" "${C_RESET}" "${project}" "${C_RESET}"
    fi
}

neo_splash_hold() {
    local secs="${NEO_SPLASH_HOLD:-1.2}"
    read -r -t "${secs}" -n 1 2>/dev/null || sleep "${secs}"
}
