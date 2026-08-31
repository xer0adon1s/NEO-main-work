# Phase 58 — TENTATIVE plan (IMPLEMENTED — v0.4.1)

**Status:** IMPLEMENTED (2026-08-30) — manual M1–M5 acceptance still pending operator  
**Date:** 2026-08-30  
**Repo:** `~/Neo` · base tag **v0.4** (Phases 54–57 local/uncommitted)  
**Authors:** Cursor review + operator + Claude independent verification (read-only)

---

## Purpose

Close the remaining gaps after Phase 57 (switch-client tmux wrap) so Phase 57 can be called
done: fix the integration-test race, correct misleading “nested tmux” messaging, implement
`--fresh` kill-and-recreate for stale mission sessions, and polish error handling + docs.

**Do not implement until Claude reviews and the operator says go.**

---

## Verification consensus (Cursor + Claude, read-only)

| # | Claim | Cursor | Claude | Locked verdict |
|---|-------|--------|--------|----------------|
| 1 | Integration test race (`client_now` after mission `sleep 5`) | Fails here (4/5) | 6/6 pass here, race real in code | **Fix the test** — don't trust env luck |
| 2 | “Nested tmux” banner/docs | Wrong | Wrong — leftover Phase 56 draft | **Fix in 4 places** |
| 3 | `--fresh` + stale `neo-<project>` → attach only, no wipe | High (operator workflow) | Confirmed; pre-Phase 51, elevated now | **Option A: kill + recreate** |
| 4 | No branded error on `new-session -d` failure | Low | `set -e` in `neo.sh` → hard crash, not silent switch | **Add branded error anyway** |
| 5 | Boot VPN prompt says “Downloads” only | Cosmetic | Confirmed; `ovpn-connect` also checks `~/Neo/vpn/` | **P3 backlog** |
| 6 | Docs drift / uncommitted since v0.4 | Yes | Extension log stops at Phase 54 | **Sync after green tests** |
| 7 | Phase 54–57 core logic (switch-client, foreign-session gate, non-boot VPN) | Solid | Solid | **Keep; don't rewrite** |

---

## Priority tiers

### P0 — Must fix before calling Phase 57 done

1. **`--fresh` kill-and-recreate** (`lib/neo-tmux.sh`)
2. **Fix integration test race** (`test/neo-tmux-integration-test.sh`)
3. **Correct operator messaging** (`lib/neo-tmux.sh`, `AGENTS.md`, `README.md`, `CLAUDE-COLLAB.md`)

### P1 — Should fix soon (same pass as P0 where coupled)

4. Branded wrap failure on `new-session -d` / `switch-client`
5. Update stale `neo.sh` comment (~943–945) about wrap behavior

### P2 — Polish / ship (only after diagnostic green)

6. `CURSOR-REVIEW-LOG.md` Phase 58 entry, `CLAUDE-COLLAB.md` prompt, `AGENTS.md` extension log Phases 55–58
7. `chmod +x` on `connect/ovpn-connect.sh`, `test/neo-tmux*.sh` if still missing
8. Version **v0.4.1** — commit locally; operator pushes separately when ready

### P3 — Backlog (not blocking Phase 58)

9. Boot VPN prompt: mention Downloads **or** `~/Neo/vpn/`
10. `neo_windup_loop` dead `mode==payload` branches
11. “Previous session found” silent-exit (needs `/tmp/neo-debug.log`)

---

## Implementation spec (order matters)

Items **1** and **3** both touch `lib/neo-tmux.sh` — do them in **one pass**.

### 1. `neo_tmux_args_want_fresh()` + kill-and-recreate (P0-A)

**File:** `lib/neo-tmux.sh`

```
neo_tmux_wrap_if_needed(project, script, args...)
  │
  ├─ wrap disabled / non-TTY → return 0
  ├─ already in neo-<project> → return 0          # in-process --fresh wipe handles project/
  │
  ├─ IF want_fresh(args) AND has-session neo-<project>:
  │     print "[*] --fresh: replacing existing session neo-<project>"
  │     tmux kill-session -t neo-<project>
  │
  ├─ IF has-session neo-<project> AND NOT want_fresh:
  │     reattach path (switch-client if $TMUX, else attach) — unchanged
  │
  └─ ELSE create path:
        IF $TMUX: new-session -d ... || { branded error; exit 1 }
                switch-client
        ELSE:     exec new-session ...
```

**Rules:**

- Only ever kill `neo-<slug(project)>`, never VPN session names (e.g. `machines_us-4`).
- `--fresh` + existing mission session → **never** attach/switch-only.
- `--fresh` + already inside own mission session → **don't kill** (in-process `neo_session_fresh_start()` wipes `project/`).
- Normal resume (no `--fresh`) → attach/switch-only, unchanged.

**New test:** In `neo-tmux-integration-test.sh` — seed mission session, call wrap with `--fresh`
in args, assert old session gone and new session runs cmd.

### 2. Fix integration test race (P0-B)

**File:** `test/neo-tmux-integration-test.sh`

**Change:** Move `client_now` assertion to **immediately** after `has-session` for mission
succeeds (inside or right after that poll loop), **before** waiting for `MARKER` / mission
`sleep 5`.

**Optional hardening (pick one):**

- `tmux set-option -t "${MISSION_SESSION}" remain-on-exit on` before asserting client, **or**
- shorten fake mission `sleep` to `0.5` (marker poll still valid).

**Gate:** Run integration test **10×** standalone + **3×** full `./test/neo-diagnostic.sh` — all green.

### 3. Banner + docs (P0-C)

**Replace everywhere** “nested / double-tap prefix” with wording like:

> Switching this terminal to mission session `neo-<project>` (`<foreign>` keeps running in the background).

**Files:**

- `lib/neo-tmux.sh` — `nesting_note` + any “nest” comments
- `AGENTS.md` — tmux auto-wrap paragraph
- `README.md` — tmux sentence
- `CLAUDE-COLLAB.md` — pipeline bullet

### 4. Branded wrap failure (P1)

On `tmux new-session -d` failure:

```text
neo: could not create tmux session 'neo-htb-reactor' (is tmux running?)
```

Then `exit 1` — don't `switch-client`. Same if `switch-client` fails (rare but worth one line).

### 5. Small cleanups (P1)

- `neo.sh` ~943–945 comment: stop saying “already in tmux” → “already in own mission session, or wrap disabled”.
- `chmod +x` on `connect/ovpn-connect.sh`, `test/neo-tmux*.sh` if still missing.

### 6. Docs / ship (P2 — only after diagnostic green)

- `CURSOR-REVIEW-LOG.md` — **Phase 58** (implementation notes)
- `CLAUDE-COLLAB.md` — next prompt entry + review brief
- `AGENTS.md` extension log — Phases **55, 56, 57, 58**
- `CLAUDE.md` — test counts from **actual** `./test/neo-diagnostic.sh` run
- Version **v0.4.1** — commit locally

---

## Out of scope (Phase 58)

- Boot VPN “Downloads or ~/Neo/vpn/” wording (P3)
- `neo_windup_loop` dead branches (P3)
- “Previous session found” silent exit (P3)
- `--fresh` from inside own session → kill/recreate (in-process wipe is enough)

---

## Manual acceptance (operator, after implementation)

| # | Scenario | Pass if |
|---|----------|---------|
| **M1** | Inside `machines_us-4`, no mission session | `--fresh` → `neo-htb-reactor`, not VPN logs |
| **M2** | Inside `machines_us-4`, mission session exists | `--fresh` → “replacing existing session”, wipe + boot |
| **M3** | Outside tmux, mission session exists | Same as M2 |
| **M4** | No `--fresh` | Reattach only, no kill |
| **M5** | In `neo-htb-reactor`, manual echo in split pane | `[z]` capture has echo, not OpenVPN |

---

## Grade target

| Before Phase 58 | After Phase 58 (if above lands) |
|-----------------|----------------------------------|
| B+ (logic good, `--fresh` broken, test/docs sloppy) | **A-** (green diagnostic + M1/M2) |

---

## Claude review brief (copy/paste)

```
Review the TENTATIVE Phase 58 plan at ~/Neo/PHASE-58-TENTATIVE-PLAN.md (not implemented yet).

Confirm or challenge:
1. --fresh should kill neo-<project> when session exists (not when already inside it)
2. Normal resume still attach/switch-only — no behavior change
3. Integration test fix: client assertion timing + new --fresh replace case
4. Messaging: no "nested tmux" / "double-tap prefix"; switch-client described accurately
5. new-session -d / switch-client branded failure messages
6. Anything missing, over-scoped, or wrong in priority order?

After your review, log verdict in CURSOR-REVIEW-LOG.md (Phase 58 review section or append to Phase 57).
Do NOT implement until operator approves.
```

---

## Key files (expected edits)

| File | Change |
|------|--------|
| `lib/neo-tmux.sh` | `--fresh` kill, messaging, error handling |
| `test/neo-tmux-integration-test.sh` | Race fix + `--fresh` test |
| `neo.sh` | Comment only |
| `AGENTS.md`, `README.md`, `CLAUDE-COLLAB.md` | switch-client wording |
| `CURSOR-REVIEW-LOG.md`, `CLAUDE.md` | Post-implementation (P2) |
