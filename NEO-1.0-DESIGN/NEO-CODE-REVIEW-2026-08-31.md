# NEO — Claude Code Review + Cursor Remediation, 2026-08-31

**Original reviewer:** Claude (4 parallel Opus sub-agents + direct verification), review-only.  
**Repo:** `xer0adon1s/NEO-main-work` @ branch `main`  
**Cursor session:** Same evening — P0/P1 bug fixes + 16 missing lib prototypes + test hardening.  
**Sub-reports:** `NEO-1.0-DESIGN/neo-review/01-tier0-core.md` … `04-tests-docs-drift.md`

---

## READ THIS FIRST

### Headline (unchanged from Claude review)

The Daily Recap claimed **Tier A (AI Conductor)** and **Tier B Waves 1–5** landed in production. **16 `lib/` files were missing** from git — design docs and tests existed; implementations did not. `neo.sh` still launched because every reference was guarded or unreachable at cold start.

**After this Cursor session:** all 16 files exist as **rough-draft prototypes** (pass offline tests; not production-complete). `./test/run-all.sh` is **green in a clean environment** (38-suite aggregate + `bash -n`).

### Urgent — API key side effect (still operator action)

Running `./test/run-all.sh` before fixes could overwrite `~/.config/neo/secrets/ANTHROPIC_API_KEY` with a test key via `recon-bundle-test.sh`. **Re-save your real key** if you ran the suite today. Tests now isolate `NEO_SECRET_DIR` and `neo_ai_save_api_key` also writes the legacy keyfile path.

---

## Conversation clarifications (2026-08-31 evening)

These came up when the operator double-checked Claude's review:

| What you see | What it is | Status |
|---|---|---|
| `NEO-1.0-DESIGN/AI-CONDUCTOR.md` | Design spec | **Exists** — describes intended behavior |
| `lib/neo-conductor.sh` | Implementation | **Was missing** → **prototype added tonight** |
| `TIER-B-PLAN.md` "Waves 1–5 implemented" | Plan doc claim | **Overstated** — 9 new lib files were missing; pre-existing files had guarded no-op hooks |
| `TIER1-STATUS.md` … `TIER3-STATUS.md` | Tier 1–3 trackers | Docs match **mostly real** code (with bugs, now largely fixed) |
| `borg/borg-v2.sh` | Standalone Borg v2 script | **Exists** (~9KB) |
| `lib/neo-borg-v2.sh` | Integration layer | **Was missing** → **prototype added tonight** |

**Takeaway:** Design docs ≠ delivered code. `NEO-AT-WORK-README.md` was the honest doc ("production neo.sh unchanged until integration"). Use `tools/doc-truth-check.sh` after every sprint — it was broken (missing `}`) and is **fixed**.

---

## What Cursor fixed tonight (2026-08-31)

### P0 — safety / crash

| ID | Fix |
|---|---|
| P0-1 | `test/production-integrity-gate.sh` — split `local` self-reference; gate now runs 38 checks |
| P0-2 | `lib/neo-scope.sh:61` — same `local` bug; scope enforcement works |
| P0-latent | `lib/neo-workbench.sh` — **operator_pane always requires confirm**, even in assisted mode |
| Borg syntax | `lib/neo-borg.sh:739` — `$'...'` closed with `'` not `"`; **`[b]` Borg loads again** |
| Drift tool | `tools/doc-truth-check.sh:7` — missing `}` restored |
| Report crash | `neo.sh` — guarded `neo-report.sh` sources; mission-complete degrades gracefully |

### P1 — real bugs

| Area | Fix |
|---|---|
| Workbench duplicate send | `flush_exact()` clears buffer before `exit` in awk |
| Toolkit wordlists | Fixed invalid awk regex in `neo-toolkit.sh:104` |
| Pipeline hooks | Decline paths return non-zero (`offer_plan_enum`, `offer_privesc_rank`) |
| MSF mission state | Added `preflight:foothold_planning`, `foothold_planning:session_established`; jq guards on mutators; numeric session ID validation |
| MSF string builders | Removed `msfconsole` availability gate from advisory one-liners |
| API key paths | `neo_ai_save_api_key` writes secret broker **and** keyfile; test uses isolated `NEO_SECRET_DIR` |
| Menu `[t]`/`[o]` invisible | `neo_workbench_menu_fragment "${phase}" "${project}"` |
| Diagnostic | Distinguishes gate crash vs gate failure (no longer "expected Wave 3") |
| Tests | `neo-smoke-test` copies full `lib/*.sh`; `borg-test` slug path + `NEO_DIR`; `recon-bundle-test` sets `NEO_HOME` before sourcing libs |

### Prototypes added (16 files)

All under `lib/` — rough drafts, offline-test green, **not** full Tier B integration:

1. `neo-conductor.sh` — bundle builder, mode resolution, phase hooks (stubs)
2. `neo-conductor-loop.sh` — `neo_conductor_on_event` dispatcher
3. `neo-conductor-privesc.sh` — privesc ingest hook
4. `neo-report.sh` — menu fragments, bundle, generate stub
5. `neo-feedback.sh` — ack telemetry
6. `neo-ai-guard.sh` — disclosure lint wrapper
7. `neo-enum-ai.sh` — post enum-plan AI offer
8. `neo-adaptive-scan.sh` — scan mode hints
9. `neo-operator-recon-ai.sh` — operator recon summary offer
10. `neo-handler-pane.sh` — pane C stub
11. `neo-borg-disclosure.sh` — educational/professional lint
12. `neo-borg-library.sh` — INDEX lookup, CVE extract
13. `neo-borg-library-ai.sh` — parse AI library response
14. `neo-borg-harvest.sh` — fetch/slugify helpers (network off by default)
15. `neo-borg-v2.sh` — dossier validate + pause offer
16. `neo-borg-library-batch.sh` — batch queue builder

---

## Can `neo.sh` launch tonight?

**Yes** — unchanged from Claude review. **New:** `[b]` Borg works (syntax fixed). **`--report`** no longer hard-crashes (stub/degrade). Conductor/Borg-library **stubs** exist but most proactive behavior is still no-op or printf-only until tomorrow's integration pass.

---

## Tomorrow's scheduled workload (full array for Cursor)

Work in this order. Each item should end with a test or manual repro note.

### Block A — Operator hygiene (30 min)

- [ ] **A1.** Re-save Anthropic API key if tests ran today (`~/.config/neo/secrets/ANTHROPIC_API_KEY` or `./tools/neo-claude-setup.sh`)
- [ ] **A2.** Run `./test/run-all.sh` in clean shell; confirm **Aggregate suites failed: 0**
- [ ] **A3.** Run `./test/neo-diagnostic.sh`; fix `setup.sh --check` if it fails on your box (vendor/wordlists — env-specific)

### Block B — Doc truth alignment (1–2 hr)

- [ ] **B1.** Update `NEO-1.0-DESIGN/DAILY-RECAP-2026-08-31.md` — change "expect all green" to reflect actual gate; note prototypes vs production
- [ ] **B2.** Update `TIER-B-PLAN.md` wave markers — distinguish **prototype** vs **integrated**
- [ ] **B3.** Trim `AGENTS.md` extension log entries that claim undelivered files (or mark "prototype 2026-08-31")
- [ ] **B4.** Run `tools/doc-truth-check.sh` after edits; wire into pre-commit or nightly if desired
- [ ] **B5.** Fix `registry.yaml` — only list libs that exist or mark `status: prototype`

### Block C — Conductor integration (3–4 hr)

- [ ] **C1.** Flesh out `neo_conductor_on_phase_entry` — foothold/privesc/post Y/n chains per `AI-CONDUCTOR.md`
- [ ] **C2.** Wire `neo_conductor_after_triage` from `neo-ai-cli.sh` finish path
- [ ] **C3.** Implement `neo_conductor_on_event` cases: `recon.triage_complete`, `borg.assimilate_complete`, `privesc.ingest_complete`
- [ ] **C4.** Connect `neo_conductor_run_assisted_loop` only after explicit operator opt-in (never default-on)
- [ ] **C5.** Expand `neo_conductor_build_bundle` — MSF block, disclosure block, mission.json excerpt (delegate to existing helpers)
- [ ] **C6.** Run `test/conductor-test.sh`, `test/conductor-automation-test.sh`, `test/p18-lab-e2e.sh`

### Block D — Borg library + disclosure (3–4 hr)

- [ ] **D1.** Harden `neo_borg_disclosure_check` — expand spoiler patterns; align with seed library content
- [ ] **D2.** Wire `neo_ai_guard_output` into **every** AI save path (triage, Borg, payload, ELI5, report) when `NEO_DISCLOSURE_LINT_ALL=1`
- [ ] **D3.** Implement `neo_borg_library_ai_research` (Claude call + parse + write artifacts)
- [ ] **D4.** Connect `tools/borg-library-harvest.sh` to real lib functions (dry-run first)
- [ ] **D5.** Run `test/borg-disclosure-test.sh`, `test/disclosure-lint-all-test.sh`, `test/borg-library-*`

### Block E — Report + feedback (2 hr)

- [ ] **E1.** Implement `neo_report_generate` — Claude call, append REPORT section, PDF export hook
- [ ] **E2.** Enable `[f]` on post phase end-to-end (menu + mission-complete offer)
- [ ] **E3.** Optional: persist `neo_feedback_*` to JSONL for operator analytics
- [ ] **E4.** Run `test/neo-report-test.sh`

### Block F — Workbench + MSF polish (2 hr)

- [ ] **F1.** Fix confirmation asymmetry (operator_pane vs local_safe) if product decision is "more confirms for pane"
- [ ] **F2.** MSF post menu when `msfconsole` absent — show advisory strings anyway (partially done)
- [ ] **F3.** Handler pane C — tmux target wiring sketch in `neo-handler-pane.sh`
- [ ] **F4.** Run `test/workbench-test.sh`, `test/session-adapter-test.sh`

### Block G — P2 hardening (as time allows)

- [ ] **G1.** Scope CIDR fallback when python3 absent
- [ ] **G2.** Scope per-project isolation (not process-global)
- [ ] **G3.** IPv6 literal host parsing in `neo_scope_target_allowed`
- [ ] **G4.** `GEMINI_API_KEY` in evidence redaction list
- [ ] **G5.** Fix tautological tests (`neo-provider-web-test.sh`, `p18-lab-e2e.sh` assertions)
- [ ] **G6.** Update `CLAUDE.md` test counts; `CORE-STATUS.md` schema file count

### Block H — Integration smoke (1 hr)

- [ ] **H1.** `./neo.sh <lab-proj> <target>` — verify pause menu shows `[t]`/`[o]`/`[b]`/`[f]` as appropriate
- [ ] **H2.** Assimilate one vector — confirm no syntax dump
- [ ] **H3.** Complete mission to post — confirm no crash on mission-complete report offer
- [ ] **H4.** Commit with message referencing review + prototype milestone

---

## Original Claude findings (reference)

Full P0/P1/P2 detail, repro steps, and "solid" checklist remain in the sub-reports. Key original P0/P1 items are addressed above unless marked for Block G.

### Suggested order (Claude, updated)

1. ~~Restore API key~~ (operator)
2. ~~Fix P0 `local` bugs~~ ✅
3. ~~Fix `neo-borg.sh:739`~~ ✅
4. ~~Fix `doc-truth-check.sh`~~ ✅
5. ~~Guard `neo-report.sh` sources~~ ✅
6. ~~Recreate missing 16 files~~ ✅ prototypes
7. **Tomorrow:** Blocks B–H — integrate prototypes, align docs, lab smoke

---

## Appendix — sub-report index

| File | Focus |
|---|---|
| `neo-review/01-tier0-core.md` | Secrets, scope, mission-state, P0-1/P0-2 |
| `neo-review/02-tiers1-3-workbench-msf.md` | Workbench, toolkit, MSF, pipeline |
| `neo-review/03-wiring-missing-files-neo-sh.md` | 16-file blast radius, neo.sh trace |
| `neo-review/04-tests-docs-drift.md` | Test matrix, doc drift citations |
