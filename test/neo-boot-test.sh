#!/usr/bin/env bash
# neo-boot-test.sh — non-interactive checks for boot/VPN ritual stdout capture.
# Forces NEO_BOOT_VPN_RITUAL=1 without a real TTY so banner leakage into TARGET
# is caught before operator runs.

set -euo pipefail

REAL_NEO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${REAL_NEO}"
export NEO_DIR="${REAL_NEO}"

pass=0
fail=0

assert() {
    local desc="$1"
    shift
    if "$@"; then
        printf '  [ok] %s\n' "${desc}"
        pass=$((pass + 1))
    else
        printf '  [FAIL] %s\n' "${desc}" >&2
        fail=$((fail + 1))
    fi
}

capture_has_no_newlines() {
    [[ "${1}" != *$'\n'* ]]
}

capture_has_no_box_chars() {
    [[ ! "${1}" =~ [╔║╚═│┌└┐┘] ]]
}

contains() {
    [[ "$1" == *"$2"* ]]
}

not_contains() {
    [[ "$1" != *"$2"* ]]
}

# shellcheck source=lib/notes-lib.sh
source "${NEO_DIR}/lib/notes-lib.sh"
# shellcheck source=lib/neo-boot.sh
source "${NEO_DIR}/lib/neo-boot.sh"

neo_vpn_up() { return 0; }
neo_vpn_ip() { printf '%s\n' '10.10.14.2'; }
ping() { return 0; }

export NEO_BOOT_VPN_RITUAL=1
LAB_IP="10.99.88.77"

# Keep existing VPN (default Y), target on CLI — same capture pattern as neo.sh:743
captured="$(
    printf '\n' | neo_boot_vpn_flow "neo-boot-test-box" "${LAB_IP}"
)"

assert "vpn flow returns exact lab IP" test "${captured}" = "${LAB_IP}"
assert "vpn flow capture has no newlines" capture_has_no_newlines "${captured}"
assert "vpn flow capture has no box-drawing chars" capture_has_no_box_chars "${captured}"

# --- non-boot path must never invoke ovpn-connect (Phase 54 hijack-fix regression) ---
# The bug Phase 54 fixed: on mission resume (non-boot), NEO shelled into htb-connect.sh,
# which ended in `exec tmux attach` — replacing the operator's shell mid-mission. Covers
# both directions the original neo-boot-test.sh left untested: VPN down (hint only, no
# invoke) and VPN up (silent, no hint needed either).

neo_vpn_up() { return 1; }
export NEO_BOOT_VPN_RITUAL=0
nonboot_down_err="$(neo_boot_vpn_flow "neo-boot-test-box" "" 2>&1 1>/dev/null)"
nonboot_down_rc=$?
assert "non-boot, VPN down: returns 0 (never blocks mission resume)" test "${nonboot_down_rc}" -eq 0
assert "non-boot, VPN down: hint points at ovpn-connect.sh (manual, not auto)" \
    contains "${nonboot_down_err}" "connect/ovpn-connect.sh"
assert "non-boot, VPN down: never claims to be starting the VPN itself" \
    not_contains "${nonboot_down_err}" "Starting VPN"

neo_vpn_up() { return 0; }
export NEO_BOOT_VPN_RITUAL=0
nonboot_up_err="$(neo_boot_vpn_flow "neo-boot-test-box" "" 2>&1 1>/dev/null)"
nonboot_up_rc=$?
assert "non-boot, VPN up: returns 0" test "${nonboot_up_rc}" -eq 0
assert "non-boot, VPN up: prints nothing (no hint needed)" test -z "${nonboot_up_err}"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
