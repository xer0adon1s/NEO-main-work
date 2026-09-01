# NEO — Claude Code Review + Cursor Remediation, 2026-08-31

**Original reviewer:** Claude (4 parallel Opus sub-agents + direct verification), review-only.  
**Repo:** `xer0adon1s/NEO-main-work` @ branch `main`  
**Cursor session:** Same evening — P0/P1 bug fixes + 16 missing lib prototypes + test hardening.  
**Sub-reports:** `NEO-1.0-DESIGN/neo-review/01-tier0-core.md` … `04-tests-docs-drift.md`

---

## READ THIS FIRST

### Headline (unchanged from Claude review)

The Daily Recap claimed **Tier A (AI Conductor)** and **Tier B Waves 1–5** landed in production. **16 `lib/` files were missing** from git — design docs and tests existed; implementations did not. `neo.sh` still launched because every reference was guarded or unreachable at cold start.

**After this Cursor session:** all 16 files exist as **rough-draft prototypes** (pass offline tests; not production-complete). `./test/run-all.sh` is **green in a clean environment** (39-suite aggregate + `bash -n`).

### Integration status update (2026-09-01 — Phases 73–74)

| Block | Offline code | Live sign-off |
|-------|----------------|---------------|
| **C** Conductor | `after_triage`, `on_phase_entry`, expanded bundle — **done**; `on_pause_entry` / `mission_state_hook` — **stub** | SIM-H |
| **D** Library + disclosure | research + harvest + disclosure meta — **done**; default-on lint — **open** | SIM-H |
| **E** Report + feedback | `neo_report_generate` — **done**; feedback JSONL — **open** | SIM-H |
| **F** Handler pane C | tmux helpers — **unwired** | SIM-H / post-1.0 |
| **G** P2 hardening | Mostly **open** | — |
| **H** Live E2E | Offline verify **6/6** | **`projects/22-live-simulation-block-h/DESIGN.md`** |

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

- [x] **B1.** Update `NEO-1.0-DESIGN/DAILY-RECAP-2026-08-31.md` — change "expect all green" to reflect actual gate; note prototypes vs production
- [x] **B2.** Update `TIER-B-PLAN.md` wave markers — distinguish **prototype** vs **integrated**
- [x] **B3.** Trim `AGENTS.md` extension log entries that claim undelivered files (or mark "prototype 2026-08-31")
- [x] **B4.** Run `tools/doc-truth-check.sh` after edits; wire into pre-commit or nightly if desired
- [x] **B5.** Fix `registry.yaml` — only list libs that exist or mark `status: prototype`

### Block C — Conductor integration (3–4 hr)

- [x] **C1.** `neo_conductor_on_phase_entry` — Phase 74 (foothold/privesc/post)
- [x] **C2.** `neo_conductor_after_triage` from `neo-ai-cli.sh`
- [x] **C3.** `neo_conductor_on_event` cases (assisted loop not invoked from `neo.sh`)
- [x] **C4.** Assisted loop opt-in only (`neo_conductor_run_assisted_loop`)
- [x] **C5.** Expanded `neo_conductor_build_bundle` / mission core
- [x] **C6.** Conductor tests in `run-all`
- [ ] **C7.** `on_pause_entry` / `mission_state_hook` still no-ops

### Block D — Borg library + disclosure (3–4 hr)

- [x] **D1.** Disclosure patterns + meta `engagement_mode` (Phase 73)
- [ ] **D2.** `neo_ai_guard_output` on every AI save path (default-off today)
- [x] **D3.** `neo_borg_library_ai_research` (Phase 74)
- [x] **D4.** `borg-library-harvest.sh` wired (dry-run in linux-phase1-verify)
- [x] **D5.** Library/disclosure tests in `run-all`

### Block E — Report + feedback (2 hr)

- [x] **E1.** `neo_report_generate` — Claude + REPORT artifact (Phase 74)
- [x] **E2.** `[f]` / `--report` wired (live sign-off pending)
- [ ] **E3.** Feedback JSONL persistence
- [x] **E4.** `neo-report-test.sh`

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
- [ ] **G6.** ~~Update `CLAUDE.md` test counts~~ — **done 2026-09-01** (doc hygiene pass); keep counts dynamic via runner banners

### Block H — Integration smoke (1 hr)

**Runbook:** `NEO-1.0-DESIGN/projects/22-live-simulation-block-h/DESIGN.md` (**SIM-H**)

- [x] **H0.** Partial live dry-run — `DRY-RUN-TRACE-2026-08-31.md` (Claude, tmux send-keys):
  boot, scope, recon, `claude -p` triage, LOCK & LOAD verified; stopped mid-ELI5
- [x] **H-offline.** `linux-phase1-verify.sh` **6/6** (2026-09-01 home Linux)
- [ ] **H1.** Finish SIM-H — `[b]`/`[t]`/`[o]`/`[f]`, foothold→post
- [ ] **H2.** Assimilate one vector — confirm no syntax dump
- [ ] **H3.** Complete mission to post — report + mission-complete offer
- [ ] **H4.** Promote FEATURE-STATUS rows + tag `1.0.0-rc` discussion

---

## Live dry-run (2026-08-31 evening) — Claude + Cursor reconciliation

**Full trace:** `NEO-1.0-DESIGN/DRY-RUN-TRACE-2026-08-31.md`  
**Tomorrow plan:** `NEO-1.0-DESIGN/DAILY-WORK-2026-09-01.md`

Claude ran `./neo.sh dryrun-sim-01 192.0.2.1` in a **tmux send-keys** session (adaptive,
not piped stdin). Cursor's piped-input attempt is a **different, weaker harness** — it
cannot drive `[o]`/`[t]` and desynced on interactive prompts; that failure is not evidence
NEO's loop is broken.

**Live-verified:** AI triage (`claude -p`), recon orchestration, scope intake, toolkit awk fix.  
**Not yet live-verified:** Borg, workbench, ELI5 complete, foothold→post, report offer.  
**Convergent P2:** first-boot VPN decline hard-exits even with CLI target — bump to Block 0
in tomorrow doc (document vs `--no-vpn` flag).

**Code tweak (Cursor):** `NEO_STATE_ROOT` added to `NEO_TMUX_ENV_FORWARD` in `lib/neo-tmux.sh`.

## Original Claude findings (reference)

Full P0/P1/P2 detail, repro steps, and "solid" checklist remain in the sub-reports. Key original P0/P1 items are addressed above unless marked for Block G.

### Suggested order (Claude, updated)

1. ~~Restore API key~~ (operator)
2. ~~Fix P0 `local` bugs~~ ✅
3. ~~Fix `neo-borg.sh:739`~~ ✅
4. ~~Fix `doc-truth-check.sh`~~ ✅
5. ~~Guard `neo-report.sh` sources~~ ✅
6. ~~Recreate missing 16 files~~ ✅ prototypes
7. **Tomorrow:** `DAILY-WORK-2026-09-01.md` — finish dry-run (Block 0), then Blocks C–G integrate prototypes

---

## Appendix — sub-report index

| File | Focus |
|---|---|
| `neo-review/01-tier0-core.md` | Secrets, scope, mission-state, P0-1/P0-2 |
| `neo-review/02-tiers1-3-workbench-msf.md` | Workbench, toolkit, MSF, pipeline |
| `neo-review/03-wiring-missing-files-neo-sh.md` | 16-file blast radius, neo.sh trace |
| `neo-review/04-tests-docs-drift.md` | Test matrix, doc drift citations |
