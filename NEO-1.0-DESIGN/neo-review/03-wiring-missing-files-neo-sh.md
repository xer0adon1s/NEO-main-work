# NEO Review — Part 3: Blast-radius of 16 missing files + neo.sh wiring audit

Repo: `/home/alexander/Work/NEO-main-work-review`
Scope: read-only. All findings verified with `bash -n`, empirical `source` tests, and
offline runs of the repo's own diagnostic. No network/target touched.

---

## BOTTOM LINE (the launch question)

**YES — `./neo.sh testproj 10.10.10.1` launches without an immediate hard crash.**

Verified empirically (offline):
- `bash neo.sh --version` → `NEO v0.5`, exit 0 (whole file parses).
- `bash neo.sh --help` → prints usage, exit 0 (reaches arg loop).
- The exact top-level startup source chain neo.sh executes — `neo-1.0-bootstrap.sh`
  (+ its 7 core libs), `notes-lib.sh`, `neo-menu.sh`, `neo-tmux.sh` — sourced under
  `set -euo pipefail` → `STARTUP-SOURCE-CHAIN-OK`.

**Why it survives** (the two "obvious" killers both miss the startup path):

1. **The 16 missing files are NOT sourced at startup.** `NEO_LIB_SCRIPTS` (neo.sh:25)
   *looks* like a source list but is **never iterated to `source`** — its only consumer
   is `neo_lib_hygiene_warn()` (neo.sh:27-49), which uses it purely as a **whitelist** to
   detect *stray* files in `lib/`. So listing all 16 missing files there is inert.
   Every real source of a missing file is either inside a function that a normal launch
   never reaches, or is guarded with `2>/dev/null || true` / `|| return 0` + a
   `declare -F` existence gate.
2. **The `neo-borg.sh` syntax error is never hit at startup.** `neo-borg.sh` is only
   sourced from *inside functions* (`neo_assimilate_at_pause`, `neo_menu_compose_pause_extras`,
   `neo_menu_conductor_nudge`), all reached only during pause menus, and the pause-path
   sources are guarded and/or call-site-swallowed (details below). Startup never sources it.

The missing files and the `neo-borg.sh` break only bite on **specific later menu paths**,
and those degrade (print an error / disable a letter) rather than crash the mission — with
two real exceptions: `--report` mode and the mission-complete tail (P1, below).

---

## SEVERITY TALLY

- **P0 (repo-wide crash / launch-blocking):** 0 in the neo.sh runtime path.
  (The 3 fatal `bash -n` syntax errors from the brief — `lib/neo-borg.sh:739`,
  `tools/doc-truth-check.sh:7`, `NEO-1.0-DESIGN/prototype/.../scope-import.sh:78` — are
  confirmed, but none is on the neo.sh cold-start path, so none is P0 for launch.)
- **P1 (feature dead-on-arrival):** 5
  - `neo.sh <proj> --report` hard-exits (missing `lib/neo-report.sh`, unguarded source).
  - Mission-complete report offer hard-exits (same cause).
  - `[b]` Borg/assimilate is broken whenever Borg is "available" (neo-borg.sh partial-load
    → `neo_borg_at_pause` undefined; also dumps the raw syntax error to the terminal).
  - `[f]` final-report letter is permanently disabled (missing lib → flag never set).
  - Standalone borg tools (`tools/borg-library-ingest.sh`, `borg-library-harvest.sh`,
    `borg-disclosure-check.sh`, `tools/neo-report.sh`) hard-exit on invocation (unguarded
    sources of missing libs). Not on the neo.sh path.
- **P2 (drift / hygiene, no crash):** several (manifest/registry/diagnostic drift, the
  other 11 missing files whose every reference is guarded no-ops).

---

# PART 1 — Per-file blast radius of the 16 missing files

Legend: **G** = guarded (missing file silently no-ops), **U** = unguarded (would fail;
subject to call-site `|| true`), **M** = manifest/metadata mention only (never sourced).

### 1. `lib/neo-handler-pane.sh` — INERT (P2)
- neo.sh:25 — **M** (NEO_LIB_SCRIPTS whitelist, not sourced).
- No runtime source anywhere. Pane "C" is not wired into any code path. `neo-tmux.sh` and
  `neo-operator-pane.sh` contain **zero** `handler-pane`/`handler_pane` references.
- Verdict: the A/B/C pane model's pane C is vestigial; a normal user never hits it.

### 2. `lib/neo-report.sh` — PARTIALLY UNGUARDED (P1)
- neo-menu.sh:102, neo-menu.sh:167 — **G** (`|| true`); `neo_report_ai_available` /
  `neo_report_menu_visible` never defined → `NEO_PAUSE_HAS_REPORT` stays false.
- **neo.sh:1121 — U.** Reached only by `NEO_REPORT_ONLY=1` i.e. `neo.sh <proj> --report`.
  `source ".../neo-report.sh"` (no `|| true`) → "No such file or directory", returns 1,
  `set -e` fires → **neo.sh exits**. `--report` is dead. **Trigger: `--report` flag.**
- **neo.sh:1224 — U.** Reached on normal **mission completion** (all phases walked, the
  `next_phase_name` "Mission complete" branch). Same unguarded source → exit before
  `neo_report_offer_mission_complete`. **Trigger: complete recon→foothold→privesc→post.**
- `neo_report_at_pause` called at neo.sh:839 & 1003 — never defined, but both are gated by
  `if ${NEO_PAUSE_HAS_REPORT:-false}` (false) **and** `|| true`, so never reached / swallowed.
- tools/neo-report.sh:20 — **U** (standalone tool; the tool file exists, the lib it sources
  does not) → crashes on invocation.

### 3. `lib/neo-conductor.sh` — ALL GUARDED (P2)
All sources guarded `2>/dev/null || true`, and every call is behind a `declare -F` gate, so
missing file = clean no-op. Call sites:
- neo.sh:760 (in `neo_post_phase_menu`), neo.sh:880 (in `walk_phase`) — G + `declare -F
  neo_conductor_on_pause_entry` / `neo_conductor_mission_state_hook` /
  `neo_conductor_on_phase_entry` gates → **never invoked**.
- neo-payload.sh:382, neo-payload.sh:860 — G.
- neo-exploit-framework.sh:218 — G.
- neo-pipeline-hooks.sh:236 — G.
- neo-ai.sh:277 — G.
- neo-ai-cli.sh:136 — G.
- neo-workbench.sh:340 — G.
- neo-borg.sh:691 — G (and this line sits *after* the borg syntax error region's
  predecessors but before it; irrelevant since it's a no-op either way).
- registry.yaml:49 — **M** (metadata entry; not a phase script — see Part 2).
- **Conductor event emitters trace:** `neo_conductor_on_phase_entry`,
  `neo_conductor_mission_state_hook`, `neo_conductor_on_pause_entry`,
  `neo_conductor_on_event` — file absent → functions never defined → each `declare -F …`
  test is false → the guarded call is skipped. Net effect: NEO runs with the AI-Conductor
  fully absent and *silent*; no error, no behavior. This is the "Tier A AI Conductor
  landed in production" claim's real status: not wired, no-ops.

### 4. `lib/neo-conductor-loop.sh` — ALL GUARDED (P2)
- neo.sh:1047 — G + `declare -F neo_conductor_on_event` gate (privesc `ingest_complete`
  emit). No-op.
- neo-borg.sh:1487 — G, but this line is *past* the neo-borg.sh syntax error (line 739),
  so it never even parses; doubly dead.

### 5. `lib/neo-conductor-privesc.sh` — INERT (P2)
- No runtime source anywhere (only test/manifest). Never referenced by neo.sh.

### 6. `lib/neo-enum-ai.sh` — GUARDED (P2)
- neo-pipeline-hooks.sh:132 — G (`|| true`). No-op.

### 7. `lib/neo-adaptive-scan.sh` — INERT (P2)
- No runtime source (only test/manifest).

### 8. `lib/neo-operator-recon-ai.sh` — ALL GUARDED (P2)
- neo-interact.sh:157 — G. recon/operator-recon.sh:81 — G (`|| true`). No-op.

### 9. `lib/neo-feedback.sh` — ALL GUARDED (P2)
- neo-menu.sh:16, neo-menu.sh:24 — G (`|| return 0`) + `declare -F neo_feedback_ack_action`
  / `neo_feedback_done` gates. Pause-menu ack/telemetry silently skipped.
- neo-workbench.sh:206 — G.
- registry.yaml:56 — **M**.

### 10. `lib/neo-ai-guard.sh` — ALL GUARDED (P2)
- neo-eli5.sh:157, neo-payload.sh:613, neo-payload.sh:633, neo-ai-cli.sh:100 — G.
- neo-borg.sh:831 — G but *past* the borg syntax error (line 739) → never parses.
- neo.sh:25 — **M**.

### 11. `lib/neo-borg-v2.sh` — GUARDED + DEAD (P2)
- neo-borg.sh:1504 — G, and *past* the borg syntax error → unreachable regardless.

### 12. `lib/neo-borg-library-batch.sh` — MIXED (P2 in neo path)
- neo-borg.sh:1492 — G, past the syntax error → dead.
- tools/borg-library-harvest.sh:117 — **U** (standalone tool) → crash on invocation.

### 13. `lib/neo-borg-disclosure.sh` — MIXED (P2 in neo path / P1 tools)
- neo-eli5.sh:119 — G. neo-payload.sh:472 — G (`|| return 0`).
- neo-borg.sh:747 — G, but its caller `neo_borg_disclosure_bundle_block` (line 744) is
  *past* the syntax error and thus **never defined** anyway.
- tools/borg-disclosure-check.sh:14 — **U** → tool crash.
- tools/borg-library-ingest.sh:20 — **U** → tool crash.
- tools/borg-library-harvest.sh:25 — **U** → tool crash.

### 14. `lib/neo-borg-library.sh` — MIXED (P2 in neo path / P1 tools)
- neo-borg.sh:699 — G, past syntax error → dead.
- tools/borg-library-ingest.sh:18 — **U** → tool crash.
- tools/borg-library-harvest.sh:19 — **U** → tool crash.

### 15. `lib/neo-borg-library-ai.sh` — UNGUARDED (P1 tool only)
- tools/borg-library-harvest.sh:23 — **U** → tool crash. No neo.sh path.

### 16. `lib/neo-borg-harvest.sh` — MIXED (P2 in neo path / P1 tool)
- neo-provider.sh:150 — G (`|| true`, inside `neo_provider_web_research_bundle_block`).
  `neo-provider.sh` IS sourced at startup (via bootstrap), but this source is inside a
  function and guarded, so startup is unaffected (confirmed by Test 1).
- tools/borg-library-harvest.sh:21 — **U** → tool crash.

**Summary Part 1:** Inside the `neo.sh` mission runtime, the *only* missing-file references
that can actually break something a normal operator hits are **`lib/neo-report.sh`** (P1:
`--report` and mission-complete) and, indirectly, the Borg pause (`[b]`) via the
`neo-borg.sh` syntax error (P1, below). All other 14 missing files are guarded no-ops within
neo.sh; several also cause the standalone `tools/borg-library-*` / `tools/neo-report.sh`
scripts to crash on manual invocation (P1 for those tools, off the neo.sh path).

---

# PART 2 — neo.sh top-to-bottom wiring audit

## 2.1 `NEO_LIB_SCRIPTS` (neo.sh:25)
- Contains all 16 missing files. **But it is never sourced** — sole consumer is the
  hygiene whitelist at neo.sh:35 (`neo_lib_hygiene_warn`). So it does NOT block startup.
- **Bug/drift (P2):** it is a stale "manifest" that disagrees with disk by 16 entries. It
  is also mirrored verbatim in `test/neo-diagnostic.sh:40` (see 2.6). Neither is a source
  list; both are inventory lists that now lie.

## 2.2 Actual startup source order (top-level execution)
1. neo.sh:23 `neo-1.0-bootstrap.sh` → sources neo-core, neo-secrets, neo-evidence,
   neo-actions, neo-mission-state, neo-scope, neo-provider (all exist, all `bash -n` clean).
2. neo.sh:49 `neo_lib_hygiene_warn` (no sourcing).
3. neo.sh:52 `notes-lib.sh`; neo.sh:54 `neo-menu.sh` (both exist, clean).
4. Function definitions only, through neo.sh:1059.
5. neo.sh:1060-1101 arg parse + project-name validation.
6. neo.sh:1104 `neo-tmux.sh`; neo.sh:1105 `neo_tmux_wrap_if_needed` (may `exec` into tmux).
7. Mission proper (boot/VPN/scope/phase walk).
None of these top-level sources is a missing file. **Startup is clean.**

## 2.3 registry.yaml vs disk
`file:` entries cross-checked against disk:
- **`lib/neo-conductor.sh` (registry.yaml:49) — MISSING.**
- **`lib/neo-feedback.sh` (registry.yaml:56) — MISSING.**
- `vendor/linpeas.sh` (:210), `vendor/LinEnum.sh` (:222) — absent, but these are vendored
  third-party payloads fetched on demand by `tools/neo-vendor.sh` (expected-absent by
  design, gitignored), not part of the 16. Note as pre-existing, low priority.
- All other `file:` entries resolve on disk.
- **Why the two missing entries don't crash the walk:** phase scripts come from
  `phases.yaml` (`recon: [babysteps, analyze-recon]`, `foothold: [ListenAssist]`,
  `privesc: [run-findprivs, run-linpeas, run-linenum]`, `post: []`) — all of which map to
  existing files. `neo-conductor`/`neo-feedback` are `phase: any` pause-menu libs, never
  selected by `neo_filter_phase_scripts`/`run_script`, so registry never tries to invoke
  them. Drift only. (P2)

## 2.4 Pause-menu letter dispatch (`neo_menu_classify`, neo-menu.sh:28-47)
Every documented letter routes to a real function; none is a raw "command not found"
dead-end. Status per letter:
- `[c]` continue, `[r]` repeat, `[s]` skip-to-step, `[k]` skip-phase, `[q]` quit — all
  handled in neo.sh (`walk_phase`/`neo_post_phase_menu`). OK.
- `[d]` deep-enum → `neo_run_deep_recon` (defined in neo.sh). OK.
- `[a]` ask-claude → `neo_ask_claude_at_pause` → sources existing `neo-ai-cli.sh`. OK
  (gated by `NEO_PAUSE_HAS_CLAUDE` = `command -v claude`).
- `[p]` payload / `[z]` analyze-failures → `neo_payload_handle_choice` (neo-payload.sh,
  exists). OK, gated by `declare -F neo_payload_*`.
- `[t]` try-it / `[o]` operator → `neo_workbench_handle_choice` (neo-workbench.sh, exists).
  OK.
- `[e]` eli5 → `neo_eli5_at_pause` → sources existing `neo-eli5.sh`. OK, gated by
  `NEO_PAUSE_HAS_ELI5`.
- **`[b]` assimilate → BROKEN (P1).** Gated by `NEO_PAUSE_HAS_BORG`. `NEO_PAUSE_HAS_BORG`
  is set true iff `neo_borg_ai_available_for_menu` (neo-borg.sh:583, which survives the
  partial load) returns true — i.e. Claude Code or `ANTHROPIC_API_KEY` present. When true,
  neo.sh:803/963 call `neo_assimilate_at_pause "$@" || true`, which at neo.sh:193 does an
  **unguarded** `source ".../neo-borg.sh"` (syntax error, prints to the terminal because
  there is no `2>/dev/null` here) then calls `neo_borg_at_pause` — which is **undefined**
  because it lives at neo-borg.sh:1498, *past* the line-739 syntax error. The `|| true` at
  the call site swallows the failure (and `set -e` is suspended for a `||`-tested command),
  so **neo.sh does not crash** — but `[b]` dumps a raw bash syntax-error line to the
  operator and does nothing. When Borg is *not* available (no API/Claude), `[b]` simply
  prints "BORG needs Claude Code or ANTHROPIC_API_KEY." (harmless).
- **`[f]` final-report → PERMANENTLY DISABLED (P1).** `NEO_PAUSE_HAS_REPORT` is set at
  neo-menu.sh:141-147 behind `declare -F neo_report_ai_available` — that function lives in
  the missing `neo-report.sh`, so the flag is never true and `[f]` always prints "Final
  report needs Claude Code or ANTHROPIC_API_KEY (post phase only)." The `[f]` handler
  itself is call-site-guarded, so no crash.

## 2.5 Conductor phase-entry hooks / event emitters
Traced precisely (neo.sh:760-763, 879-887, 1046-1051): every conductor entry is
`source ".../neo-conductor*.sh" 2>/dev/null || true` immediately followed by
`if declare -F neo_conductor_… ; then … || true; fi`. File absent → function undefined →
`declare -F` false → body skipped. **No call to any `neo_conductor_*` function ever
executes.** No "command not found", no crash. The Conductor is wired to be *optional and
silent*, and is currently entirely absent.

## 2.6 tmux auto-wrap / pane model (A/B/C)
- `neo-tmux.sh` exists and is `bash -n` clean; `neo_tmux_wrap_if_needed` (neo.sh:1105) is on
  the normal path and does not reference `neo-handler-pane.sh`.
- **Pane C (`neo-handler-pane.sh`) is not required on any normal code path** — it is not
  sourced or referenced anywhere in runtime code (only neo.sh:25 manifest + tests). Missing
  pane C has zero runtime effect.

## 2.7 Env-var consistency (`NEO_DIR`/`NEO_HOME`/`NEO_ROOT`/`NEO_SOURCE_ROOT`)
- neo.sh, the libs, and the tmux path use `NEO_DIR`/`NEO_HOME` consistently
  (`${NEO_DIR:-${NEO_HOME}}`), set once at neo.sh:11-13 and re-derived defensively in
  `neo-1.0-bootstrap.sh:4-5`. No inconsistency found on the runtime path.
- `NEO_ROOT` is used by standalone tools/tests purely as a local "compute my repo root then
  export NEO_DIR/NEO_HOME" idiom (e.g. `tools/borg-disclosure-check.sh:9-11`,
  `tools/borg-library-harvest.sh:14-16`) — consistent and correct.
- **`NEO_SOURCE_ROOT` is used only by `tools/doc-truth-check.sh`**, where line 7
  `NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-${NEO_ROOT}"` is missing the closing `}` (confirmed:
  `bash -n` → "unexpected EOF while looking for matching \`\"'" at line 135). This is the
  previously-flagged bug and it is **isolated** — the `NEO_ROOT` vs `NEO_SOURCE_ROOT` split
  does **not** recur as a runtime bug elsewhere; no other file mixes the two.

## 2.8 Other wiring notes
- The unguarded `source ".../neo-report.sh"` appears **three** times (neo.sh:1121, 1224;
  tools/neo-report.sh:20) — all lack the `2>/dev/null || true` used everywhere else. This is
  the single inconsistent-guarding pattern in neo.sh proper and the cause of the two P1
  neo.sh crashes.
- `neo_assimilate_at_pause` (neo.sh:190-195) is the only neo.sh function that sources a lib
  **without** a guard *and* without `2>/dev/null`; combined with the neo-borg.sh syntax
  error it leaks the parser error to the terminal (cosmetic P1, non-fatal due to call-site
  `|| true`).

## 2.9 `test/neo-diagnostic.sh` self-inventory (ran offline)
- The diagnostic keeps its **own** 46-entry `neo_libs` list (neo-diagnostic.sh:40) that
  includes all 16 missing files and checks `[[ -f "lib/${f}" ]] && ok || bad "missing neo
  lib: …"`.
- Running it offline: **`106 ok, 30 fail, 1 warn` → "NOT READY — fix failures above."** The
  fails include an explicit `[FAIL] missing neo lib:` line for **all 16** files
  (neo-adaptive-scan, neo-ai-guard, neo-borg-disclosure, neo-borg-harvest,
  neo-borg-library-ai, neo-borg-library-batch, neo-borg-library, neo-borg-v2,
  neo-conductor-loop, neo-conductor-privesc, neo-conductor, neo-enum-ai, neo-feedback,
  neo-handler-pane, neo-operator-recon-ai, neo-report).
- **Verdict: the diagnostic gives ACCURATE "missing" signal, not a false "all good."** It
  correctly refuses to declare the tree ready. (It does NOT, however, flag the
  `neo-borg.sh` / `doc-truth-check.sh` syntax errors as such — those surface only via the
  unit suites it shells out to, several of which also FAIL.)

---

## Appendix — evidence commands run (offline)
- `bash -n` over startup-path libs → only `lib/neo-borg.sh` fails (line 755, cascade from
  the line-739 `$'…"` mismatch); `tools/doc-truth-check.sh` fails (line 135, cascade from
  line-7 missing `}`).
- Empirical partial-load of `neo-borg.sh` under `set -euo pipefail`: `source` returns 2;
  `neo_borg_menu_fragment` (572) and `neo_borg_ai_available_for_menu` (583) **DEFINED**;
  `neo_borg_build_bundle` (686), `neo_borg_disclosure_bundle_block` (744),
  `neo_borg_at_pause` (1498), `neo_borg_system_prompt` **undefined** (all at/after the
  line-686 broken function).
- `neo.sh --version` / `--help` → exit 0. Startup source chain → OK.
- `./test/neo-diagnostic.sh` → 30 fails incl. all 16 missing libs; "NOT READY".
