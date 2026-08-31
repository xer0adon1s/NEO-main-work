#!/usr/bin/env bash
# setup.sh — fetch third-party tools into vendor/ after cloning NEO.

set -euo pipefail

NEO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_HOME}"
VENDOR="${NEO_HOME}/vendor"
FORCE=false
CHECK=false

for arg in "$@"; do
    case "${arg}" in
        -h|--help)
            cat <<'EOF'
Usage: setup.sh [--force] [--check]

Downloads third-party tools into vendor/ from official upstream releases.
Run from the Neo repo root (~/Neo).
EOF
            exit 0
            ;;
        --force) FORCE=true ;;
        --check) CHECK=true ;;
        *) echo "Unknown option: ${arg}" >&2; exit 1 ;;
    esac
done

THIRD_PARTY=(
    'linpeas.sh|https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh|y'
    'LinEnum.sh|https://raw.githubusercontent.com/rebootuser/LinEnum/master/LinEnum.sh|y'
    'pspy32|https://github.com/DominicBreuker/pspy/releases/latest/download/pspy32|y'
    'pspy64|https://github.com/DominicBreuker/pspy/releases/latest/download/pspy64|y'
    'winPEASany.exe|https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASany.exe|n'
    'winPEASx64.exe|https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx64.exe|n'
)

if command -v curl >/dev/null 2>&1; then DOWNLOADER=curl
elif command -v wget >/dev/null 2>&1; then DOWNLOADER=wget
else echo "Need curl or wget." >&2; exit 1; fi

fetch() {
    if [[ "${DOWNLOADER}" == curl ]]; then curl -fsSL -o "$2" "$1"
    else wget -q -O "$2" "$1"; fi
}

mkdir -p "${VENDOR}"
missing=0 present=0

printf 'NEO setup — third-party tools → %s\n\n' "${VENDOR}"

for entry in "${THIRD_PARTY[@]}"; do
    IFS='|' read -r name url chmod_flag <<< "${entry}"
    dest="${VENDOR}/${name}"
    if [[ -f "${dest}" && "${FORCE}" != true ]]; then
        printf '  [ok]   %s\n' "${name}"; present=$((present + 1)); continue
    fi
    if ${CHECK}; then
        if [[ -f "${dest}" ]]; then printf '  [ok]   %s\n' "${name}"; present=$((present + 1))
        else printf '  [miss] %s\n' "${name}"; missing=$((missing + 1)); fi
        continue
    fi
    printf '  [get]  %s\n' "${name}"
    tmp="$(mktemp "${dest}.XXXXXX")"
    fetch "${url}" "${tmp}" || { rm -f "${tmp}"; exit 1; }
    mv "${tmp}" "${dest}"
    [[ "${chmod_flag}" == y ]] && chmod +x "${dest}"
    present=$((present + 1))
done

echo ""
if ${CHECK}; then
    (( missing > 0 )) && exit 1 || exit 0
fi
printf 'Done — %d tools in vendor/\n' "${present}"
