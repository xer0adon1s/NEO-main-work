#!/usr/bin/env bash

PASS=0
FAIL=0

pass() { printf '  [ok] %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  [FAIL] %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

assert_true() {
    local label="$1"; shift
    if "$@"; then pass "${label}"; else fail "${label}"; fi
}

assert_false() {
    local label="$1"; shift
    if "$@"; then fail "${label}"; else pass "${label}"; fi
}

finish_tests() {
    printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
    (( FAIL == 0 ))
}
