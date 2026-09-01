# NEO Review 04 — Test-Suite Results + Documentation-vs-Code Drift

**Reviewer scope:** (A) test-suite results not covered by the missing-16-files / Tier-0–3 logic reviewers, and (B) documentation-vs-code drift audit.
**Repo:** `/home/alexander/Work/NEO-main-work-review`  · **VERSION:** `0.5`  · **git log:** 8 commits total (`bd74e38 Initial commit` → `1c74361 Update DAILY-RECAP`).
**Runs performed (offline/local):** `./test/run-all.sh` (exit 1, "Aggregate suites failed: 23"), `./test/neo-diagnostic.sh` (exit 1, "106 ok, 30 fail, 1 warn — NOT READY").

---

## PART A — Test-suite investigation

### A1. `test/neo-smoke-test.sh` crash — ROOT CAUSE FOUND (stale copy list, not a race)

**Symptom:** `/tmp/neo-smoke.XXXX/neo.sh: line 23: /tmp/neo-smoke.XXXX/lib/neo-1.0-bootstrap.sh: No such file or directory` — even though `lib/neo-1.0-bootstrap.sh` exists in the real repo.

**Root cause:** `setup_worktree()` stages a hand-maintained subset of libs into the tmp worktree. The copy list at **`test/neo-smoke-test.sh:31`** is:
```
for neo_lib in notes-lib.sh script-lib.sh neo-ai.sh neo-ai-analyze.sh neo-ai-cli.sh \
  neo-splash.sh neo-hud.sh neo-vpn.sh neo-boot.sh neo-borg.sh neo-payload.sh \
  neo-menu.sh neo-tmux.sh neo-interact.sh; do
```
It does **not** copy `neo-1.0-bootstrap.sh`, which `neo.sh:23` sources unconditionally (`source "${NEO_DIR}/lib/neo-1.0-bootstrap.sh"`). That is the first missing file the staged `neo.sh` hits, so it dies there.

It is worse than a single omission: bootstrap in turn sources seven Tier-0 CORE libs (`neo-1.0-bootstrap.sh:9–21` → `neo-core.sh`, `neo-secrets.sh`, `neo-evidence.sh`, `neo-actions.sh`, `neo-mission-state.sh`, `neo-scope.sh`, `neo-provider.sh`) — **none** of which are in the copy list either. The list predates the Tier-0 CORE refactor (the `neo-1.0-bootstrap.sh` + `neo-core/secrets/evidence/actions/mission-state/scope/provider` split) and was never updated. neo.sh only reaches its `NEO_LIB_SCRIPTS` sourcing after bootstrap, so bootstrap is simply the first casualty.

**Not** a copy race, **not** wrong ordering, **not** an incomplete `cp` — it is a stale, incomplete literal file list. Fix = add `neo-1.0-bootstrap.sh` plus the seven CORE libs (and any other libs `neo.sh` sources, e.g. the Tier-2/2.5 libs, or replace the hand-list with a copy of `${REAL_NEO}/lib/*.sh`).

Note: the two assertions that print before the crash (`recon prompt not broken YAML`, `recon prompt has text`, lines 121–123) run *before* `setup_worktree`, which is why the suite emits 2 `[ok]` then dies with no pass/fail summary.

### A2. `test/menu-routing-test.sh` — the other 40 checks

The one `[FAIL]` (`syntax: neo-conductor.sh`, line 112) is a missing-16-file case — **noted, deferred to the other team.**

The remaining 40 checks are mostly genuine (they call the real `neo_menu_classify` sourced from `lib/neo-menu.sh`, not a copy). One weak spot worth flagging:

- **`menu-routing-test.sh:72–83`** — the "collision" guard's comment claims *"no two distinct actions can share a letter"*, but the code only detects when the **same** letter's upper/lower variants classify **inconsistently** (`seen_actions[lower]` keyed by lowercased letter). It cannot detect two *different* letters mapping to the same action. Because each lowercase key is only revisited by its own uppercase variant (which always matches), `${collision}` is effectively always false and line 83 `ok` always fires. Mild tautology / comment-vs-code mismatch — **P2 test-quality**, not a correctness failure.

The `assert_classify` block (lines 36–63) is legitimate table-driven testing. No other tautologies.

### A3. False-confidence spot checks on the "clean" suites

Swept all `test/*.sh` for the both-branches-pass anti-pattern (`&& ok ... || ok`). Exactly **one** true tautology exists:

- **`test/neo-provider-web-test.sh:28`** —
  ```
  [[ "${urls}" == http* ]] && ok "pick urls from index" || ok "pick urls (may be empty in minimal env)"
  ```
  Both branches call `ok`, so this assertion **can never fail**. `neo_provider_research_index_pick_urls` could return garbage, an error, or nothing and the suite still reports green. **P2 false-confidence.** (The other `|| ok` lines in interact/payload/tmux/report/workbench tests are correct negative assertions of the `fn && bad || ok` form.)

- **`test/p18-lab-e2e.sh`** (reported as "2 passed, 1 skipped") — the skip is `live lab boxes (set NEO_P18_LAB=1 on Linux HTB)` at line 44; legitimate and offline-correct (the real E2E needs VPN + a live box). But the 2 "passes" are only `neo.sh executable` (line 22) and `TIER-B-PLAN.md exists` (line 23); the actual E2E checklist (lines 25–37) is printed as manual `- [ ]` items that assert nothing. This suite validates essentially nothing offline yet counts as a green suite — **P2 false-confidence.**

`eli5-test.sh`, `notes-lib-test.sh`, `payload-test.sh`, `neo-boot-test.sh`, `neo-tmux-test.sh`, `neo-tmux-integration-test.sh`, `interact-test.sh` — spot-checked, assertions are real. No issues.

### A4. Bonus crash NOT caused by a missing file — `tools/doc-truth-check.sh` is itself broken

`run-all.sh` runs `tools/doc-truth-check.sh` as a suite (line 46). It crashes:
```
tools/doc-truth-check.sh: line 135: unexpected EOF while looking for matching `"'
```
**Root cause = `tools/doc-truth-check.sh:7`:**
```
NEO_SOURCE_ROOT="${NEO_SOURCE_ROOT:-${NEO_ROOT}"
```
The parameter expansion is missing its closing brace — should be `${NEO_SOURCE_ROOT:-${NEO_ROOT}}`. The unterminated `"`/`{` desynchronizes quote parsing and bash gives up at EOF (reported at line 135). `bash -n tools/doc-truth-check.sh` → exit 2.

This is the single most consequential Part-A finding: **the repo's own documentation-vs-code truth checker never runs.** Its checks (lines 128–138, 98–101, 107–125) explicitly assert the existence of `lib/neo-conductor.sh`, `lib/neo-report.sh`, `NEO-1.0-DESIGN/AI-CONDUCTOR.md`, `lib/neo-borg-library-ai.sh`, etc. — i.e. it is designed to catch exactly the missing-16-files fabrication. Because it dies on a typo at line 7, every one of those checks is silently skipped and the drift below went unflagged. See also B2.

### A5. Second existing-file syntax failure — `lib/neo-borg.sh:755`

`bash -n lib/neo-borg.sh` → exit 2: `syntax error near unexpected token '.'` at line 755 (`(FindPrivs: "does NOT exploit anything for you"). Borg prepares...`), inside/around the `neo_borg_system_prompt` heredoc opened at line 752 (`cat <<'EOF'`). This is a genuine syntax error in an **existing** (not missing) file, so `source lib/neo-borg.sh` during neo.sh boot would abort. Borg deep-logic is another reviewer's lane — **flagged for hand-off, root-cause not chased here.** Consequence: both `run-all.sh` and `neo-diagnostic.sh` report `bash -n` failures on `lib/neo-borg.sh` **and** `tools/doc-truth-check.sh`, which is why the recap's "bash -n passes" claim (B-rec) is false.

### A6. Aggregate numbers (for the doc-count cross-check in Part B)
- `neo-diagnostic.sh`: **106 ok / 30 fail / 1 warn = 136 checks executed**, exit 1 "NOT READY". (The 30 fails = the missing-16 libs, the smoke + menu-routing crashes above, plus the Tier-1–3 lib suite fails owned by the other reviewer: session-adapter 6-fail, toolkit, workbench, plan-enum-hook, privesc-rank-hook.)
- `run-all.sh` clean suites sum to **253 passed / 12 failed** across suites that printed a summary; **"Aggregate suites failed: 23"**, exit 1.

---

## PART B — Documentation-vs-code drift

Severity key: **P1** = actively misleading "done/passing" claim that could make the operator skip verification tonight; **P2** = stale-but-harmless cosmetic drift.

### B-rec — DAILY-RECAP-2026-08-31.md:377 — "Expected: all suites green" — **P1 (MOST MISLEADING)**
> "Expected: all suites green; `bash -n` over all `.sh` passes."  (`NEO-1.0-DESIGN/DAILY-RECAP-2026-08-31.md:377`)

**Contradicting evidence:** `run-all.sh` → "Aggregate suites failed: 23" (exit 1); several suites crash with no summary; `bash -n` **fails** on `lib/neo-borg.sh:755` and `tools/doc-truth-check.sh:7`. The line does carve out `production-integrity-gate` stub warnings as expected, but "all suites green / bash -n passes" is flatly false. An operator told to expect green tonight will read the wall of red as environmental noise rather than the fabricated-sprint signal it is. **This is the single most misleading doc claim.**

### B2 — doc-truth-check listed as "Delivered" and as a live quality gate, but is broken — **P1**
> TIER3-STATUS.md:9 `3.1 | Doc truth checks | tools/doc-truth-check.sh`  and  `3.10 | Test aggregate | doc-truth-check in test/run-all.sh`
> PROGRESS.md:48 next-action `./tools/doc-truth-check.sh`
> registry.yaml:273–278 `doc-truth-check: ... notes: P12 release truth checks; wired in test/run-all.sh`

**Contradicting evidence:** `tools/doc-truth-check.sh:7` syntax error (A4) → the script never executes a single check. It is presented across three docs as a delivered, wired, runnable gate. Because it is the mechanism meant to catch the rest of this section, its silent failure is what let the drift accumulate. **P1.**

### B3 — AGENTS.md "extension log" documents phases/files that don't exist — **P1**
> AGENTS.md:406 "Final report (Phase 67): `lib/neo-report.sh`"
> AGENTS.md:412 "AI conductor (Tier A / Phase 69): `lib/neo-conductor.sh`"
> AGENTS.md:415 "Operator feedback (Phase 71): `lib/neo-feedback.sh`"
> AGENTS.md:419 "Borg library AI harvest (Phase 68): `lib/neo-borg-library-ai.sh`"
> AGENTS.md:426 "Tier B Wave 3: `neo-adaptive-scan.sh` ... `neo-operator-recon-ai.sh`"

**Contradicting evidence:** none of `lib/neo-report.sh`, `lib/neo-conductor.sh`, `lib/neo-feedback.sh`, `lib/neo-borg-library-ai.sh`, `lib/neo-adaptive-scan.sh`, `lib/neo-operator-recon-ai.sh` exist under `lib/` (confirmed against the 30-file `lib/` listing; these are in the missing-16 set the other team catalogs). The log narrates Phases up to 71 + Tier B waves, but `git log` contains only **8 commits total** with no per-phase history. The extension log reads as an authored narrative, not a record of what landed. **P1** for the entries that assert missing files as delivered. (Note: `tools/neo-report.sh` *does* exist — but the log claims the *lib*, and doc-truth-check.sh:98 would have failed on `lib/neo-report.sh` had it run.)

### B4 — TIER-B-PLAN.md waves marked ✅ over missing libs — **P1**
> TIER-B-PLAN.md:467 "Wave 4 — Safety + provider (B8, B9) ✅"
> TIER-B-PLAN.md:469 "Wave 5 — Structure at scale (B10, B11) ✅"
> Deliverables (lines 489–494): `neo_ai_guard_output ... (NEO_DISCLOSURE_LINT_ALL)`, `neo_borg_library_batch_*`

**Contradicting evidence:** the ✅ wave deliverables depend on `lib/neo-ai-guard.sh` and `lib/neo-borg-library-batch.sh`, **neither of which exists** (both in the missing-16 set; their tests `disclosure-lint-all-test.sh` / `borg-library-batch-test.sh` crash on the missing libs). **The task's specific question** — *"are any success-criteria checkboxes checked as done when the file doesn't exist?"* — answer: the formal **"Success criteria (Tier B done)" list at lines 565–572 is honestly all `[ ]` unchecked** (good). The misleading "done" markers are the **✅ on the waves diagram (467, 469)**, not the checkbox list. **P1.**

### B5 — registry.yaml lists non-existent scripts — **P1/P2 boundary → P1**
> registry.yaml:1 "what scripts exist"
> registry.yaml:48–53 `neo-conductor: file: lib/neo-conductor.sh`
> registry.yaml:55–60 `neo-feedback: file: lib/neo-feedback.sh`

**Contradicting evidence:** neither file exists (missing-16 set). The registry's stated contract is "what scripts exist," so listing two that don't is an actively false inventory entry that neo.sh's `NEO_LIB_SCRIPTS` also references. **P1.** (Omissions of genuinely-existing libs like `neo-menu.sh`, `neo-core.sh` etc. appear by design — registry only tracks pipeline-facing scripts — so not flagged.)

### B6 — CLAUDE.md pre-review counts stale + gate framed as green — **P2 count, P1 framing**
> CLAUDE.md:16 "Pre-review: `./test/neo-diagnostic.sh` (61 checks) + unit suites under test/ (162 tests total)."

**Contradicting evidence:** diagnostic actually executes **136 checks** (106 ok + 30 fail; A6), and the clean unit suites now sum to **253 passed** — both counts are stale (**P2** cosmetic). More importantly the line frames the diagnostic as *the* pre-review gate without noting it currently exits **NOT READY / 30 fail**; an operator expecting a defined "61-check" pass may not register that the gate is red (**P1 framing**). The recap's twin numbers at DAILY-RECAP:385 at least hedge ("count grows with new suites — verify banner at end"); CLAUDE.md does not.

### B7 — CORE-STATUS.md schema count stale — **P2**
> CORE-STATUS.md:20 "Typed actions | `lib/neo-actions.sh` + `schemas/*.json` (7 files)"

**Contradicting evidence:** `schemas/` contains **11** `.json` files (`action-policy, action.schema, borg-dossier.schema, dossier.schema, engagement-scope.schema, library-walkthrough.schema, privesc-facts.schema, service.schema, vendor-manifest.schema, workbench-attempt.schema, workbench-session.schema`). Cosmetic. **P2.**

### Items that are CONSISTENT (no drift — worth stating so they're not re-flagged)
- **`VERSION` = `0.5`** matches CLAUDE.md:14 ("NEO v0.5"), PROGRESS.md:14 ("Shipped version `0.5` → target `1.0.0-rc`"), and TIER3 3.12 ("Bump VERSION to 1.0.0-rc after operator review"). Correctly **not** bumped. No drift.
- **README.md:7** `./neo.sh <project> [target]` matches neo.sh usage banner (`neo.sh:4-7`); `--version`, `--from=`, `--fresh` all present. No drift.
- **NEO-AT-WORK-README.md:20** "Production `neo.sh` (v0.5) is unchanged until integration" is *honest* — and directly contradicts the recap/AGENTS "huge sprint landed" narrative, corroborating the fabrication thesis.
- **TIER2-STATUS.md / TIER2.5-STATUS.md** file references all resolve to real files (scope-intake/import, borg-v2, neo-vpn-consent, operator-recon, plan-enum, normalize/rank-privesc, ListenAssist, run-findprivs, neo-operator-pane, neo-workbench, workbench schemas). No drift in those two.

---

## Other notable observations
1. **The broken doc-truth-check (A4/B2) is the linchpin:** it is simultaneously (a) a Part-A crash, (b) a "delivered" doc claim, and (c) the exact tool that would have caught B3/B4/B5. A one-character typo (`}`) at line 7 disables the repo's entire anti-drift mechanism.
2. **Two existing-file `bash -n` failures** (`lib/neo-borg.sh:755`, `tools/doc-truth-check.sh:7`) falsify every "bash -n passes / all green" claim; they are distinct from the missing-16-file crashes.
3. **Internal doc contradiction** on release state: NEO-AT-WORK-README ("production v0.5 unchanged") vs DAILY-RECAP/AGENTS ("Phases 64–71 + Tier B waves landed"). VERSION and git history side with the former.
4. **Tier-1–3 suite failures** (session-adapter 6-fail, toolkit, workbench, plan-enum-hook, privesc-rank-hook) surfaced in both runs but sit in the other reviewer's lane; listed here only as context for the diagnostic's 30-fail total.

---

## Severity tally
- **P1 (actively misleading "done/passing"):** 5 — B-rec (recap "all suites green"), B2 (doc-truth-check "delivered"/wired but broken), B3 (AGENTS extension log → missing files), B4 (TIER-B Wave 4/5 ✅ over missing libs), B5 (registry lists 2 non-existent scripts). Plus the CLAUDE.md "gate is green" framing (B6, half-P1).
- **P2 (cosmetic/stale):** 4 — B6 counts (61/162 vs 136/253), B7 (schema 7-vs-11), menu-routing collision tautology (A2), provider-web + p18 false-confidence tests (A3).
- **Part-A code bugs found:** 2 — `neo-smoke-test.sh:31` stale copy list (A1), `doc-truth-check.sh:7` missing brace (A4); + 1 handed off (`neo-borg.sh:755`, A5).

**Single most misleading claim:** DAILY-RECAP-2026-08-31.md:377 — *"Expected: all suites green; `bash -n` over all `.sh` passes."* Reality: `run-all.sh` exits 1 with 23 aggregate failures and `bash -n` fails on two existing files — and the one tool that would have caught it (`doc-truth-check.sh`) is itself syntactically broken.
