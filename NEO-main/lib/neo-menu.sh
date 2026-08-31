#!/usr/bin/env bash
# neo-menu.sh — single source of truth for pause-menu letter routing.
#
# Both of neo.sh's menu loops (neo_post_phase_menu and the pause_before script-choice
# block in walk_phase) dispatch on neo_menu_classify()'s canonical action name instead
# of matching raw letters directly, so the letter→action mapping exists in exactly one
# place. Pure function, no side effects — safe to source and call directly from
# test/menu-routing-test.sh without pulling in neo.sh's own top-level executable code.
#
# Every letter maps to exactly one action regardless of case (Phase 48 — before this,
# [a]sk-Claude/[A]ssimilate and [s]kip/[S]uggest meant different things by case, which
# made a stray Shift or caps-lock a real risk of triggering the wrong menu action).

neo_menu_classify() {
    local choice="$1"
    case "${choice}" in
        c|C) echo continue ;;
        a|A) echo ask-claude ;;
        b|B) echo assimilate ;;
        p|P) echo payload-suggest ;;
        z|Z) echo analyze-failures ;;
        d|D) echo deep-enum ;;
        r|R) echo repeat ;;
        s|S) echo skip-to-step ;;
        k|K) echo skip-phase ;;
        q|Q) echo quit ;;
        *) echo unmatched ;;
    esac
}
