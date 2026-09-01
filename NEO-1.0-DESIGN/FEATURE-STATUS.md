# NEO Feature Status — canonical truth board

**Updated:** 2026-09-01  
**Repo:** `NEO-main-work` · shipped `VERSION` = **0.5** · prototype milestone = **prototyped, v0.6**

This file is the **single source of truth** for whether a feature is live in mission flow or still a prototype. All other docs (`AGENTS.md`, `DAILY-RECAP`, `TIER-B-PLAN`, `registry.yaml`, project YAMLs) must agree with this file.

---

## Status labels (use exactly these)

| Label | Meaning | When to use |
|-------|---------|-------------|
| **implemented** | Operator has used it in a real lab session and signed off; wired into `neo.sh` mission flow; behavior matches design intent. | Tier 0 CORE, workbench `[t]`/`[o]`, Borg `[b]` (core), payload `[p]`, ELI5 `[e]`, pipeline hooks, scope, secrets, tmux wrap, etc. |
| **prototyped, v0.6** | `lib/` file (and/or tests) exist; offline unit tests may pass; **not** fully integrated or **not** human-approved for live missions. | All 16 Tier A/B libs added 2026-08-31 evening; guarded no-ops or printf-only at runtime until integration Blocks C–E. |
| **design only** | Spec / project doc / checklist only — no production lib or not started. | P19 GUI, aggressive conductor v1.1, full P08 provider migration. |
| **review_ready** | **Design** doc ready for review — **not** production shipped. | `NEO-1.0-DESIGN/projects/*/project.yaml` status field. |

**Rule:** Nothing is **implemented** until a human operator marks it so in this file (or in a dated note below the feature row). Passing offline tests alone is **not** implementation.

**Promotion checklist** (prototype → implemented):

1. Wired from `neo.sh` or pause menu without guarded silent no-op  
2. Lab smoke on home Linux (see Block H in `NEO-CODE-REVIEW-2026-08-31.md`)  
3. Operator sign-off line added under the feature row in this doc  

---

## Tier 0 CORE — **implemented**

| Component | Path | Status |
|-----------|------|--------|
| Bootstrap + shared primitives | `lib/neo-1.0-bootstrap.sh`, `neo-core.sh` | implemented |
| Secret broker | `lib/neo-secrets.sh`, `lib/neo-ai.sh` | implemented |
| Evidence + actions | `lib/neo-evidence.sh`, `neo-actions.sh`, `neo-windup-actions.sh` | implemented |
| Mission state | `lib/neo-mission-state.sh` | implemented (MSF edges fixed 2026-08-31) |
| Scope enforcement | `lib/neo-scope.sh` | implemented |
| Provider / AI infra | `lib/neo-provider.sh` | implemented |
| Production integrity gate | `test/production-integrity-gate.sh` | implemented (gate runs; was broken P0) |
| Doc truth tool | `tools/doc-truth-check.sh` | implemented (existence + doc checks; see below) |

---

## Tiers 1–3 foundation — **implemented** (mechanical + pause UX)

| Component | Path | Status |
|-----------|------|--------|
| Operator workbench `[t]`/`[o]` | `lib/neo-workbench.sh`, `neo-operator-pane.sh` | implemented |
| LOCK & LOAD toolkit | `lib/neo-toolkit.sh` | implemented |
| Pipeline hooks (plan-enum, privesc rank) | `lib/neo-pipeline-hooks.sh` | implemented |
| ELI5 `[e]` | `lib/neo-eli5.sh` | implemented |
| Borg assimilate `[b]` (core) | `lib/neo-borg.sh`, `borg/borg.sh` | implemented |
| Payload suggest `[p]` / analyze `[z]` | `lib/neo-payload.sh` | implemented |
| MSF advisory strings + session adapter | `lib/neo-exploit-framework.sh` | implemented (foundation; not full conductor) |
| tmux auto-wrap | `lib/neo-tmux.sh` | implemented |
| Pre-foothold interact | `lib/neo-interact.sh` | implemented |
| Recon / foothold / privesc scripts | `recon/`, `foothold/`, `privesc/` | implemented |

---

## Tier A — AI Conductor — **prototyped, v0.6**

| Component | Path | Status | Notes |
|-----------|------|--------|-------|
| Unified bundle + phase hooks | `lib/neo-conductor.sh` | prototyped, v0.6 | Stubs; guarded wiring in `neo.sh` |
| Conductor design spec | `NEO-1.0-DESIGN/AI-CONDUCTOR.md` | design only | Intent doc — not status claim |

---

## Tier B Waves 1–5 — **prototyped, v0.6** (files + offline tests; integration pending)

| Wave | Component | Path | Status |
|------|-----------|------|--------|
| B1 | Conductor automation loop | `lib/neo-conductor-loop.sh` | prototyped, v0.6 |
| B2 | AI privesc triage hook | `lib/neo-conductor-privesc.sh` | prototyped, v0.6 |
| B3 | AI enum planner | `lib/neo-enum-ai.sh` | prototyped, v0.6 |
| B4 | Adaptive scan hints | `lib/neo-adaptive-scan.sh` | prototyped, v0.6 |
| B5 | Operator-recon AI structurer | `lib/neo-operator-recon-ai.sh` | prototyped, v0.6 |
| B6 | MSF AI post suggest | `neo-exploit-framework.sh` (partial) | implemented (strings); AI post chain **prototyped, v0.6** |
| B7 | Borg library hook | `lib/neo-borg-library.sh` | prototyped, v0.6 |
| B8 | Disclosure lint all surfaces | `lib/neo-ai-guard.sh`, `neo-borg-disclosure.sh` | prototyped, v0.6 |
| B9 | Provider web research block | `neo-provider.sh` (partial) | prototyped, v0.6 |
| B10 | Borg v2 integration | `lib/neo-borg-v2.sh` | prototyped, v0.6 · standalone `borg/borg-v2.sh` = **implemented** |
| B11 | Batch library harvest | `lib/neo-borg-library-batch.sh`, `neo-borg-harvest.sh` | prototyped, v0.6 |
| B12 | P18 lab E2E harness | `test/p18-lab-e2e.sh` | prototyped, v0.6 (checklist script; not live E2E sign-off) |

---

## Other Tier B / UX libs — **prototyped, v0.6**

| Component | Path | Status |
|-----------|------|--------|
| Operator feedback (ack / progress) | `lib/neo-feedback.sh` | prototyped, v0.6 |
| Final report `[f]` / `--report` | `lib/neo-report.sh` | prototyped, v0.6 (degrades gracefully; no full generate) |
| Handler pane C | `lib/neo-handler-pane.sh` | prototyped, v0.6 |
| Borg library AI parse | `lib/neo-borg-library-ai.sh` | prototyped, v0.6 |

---

## Tools & knowledge (mixed)

| Component | Path | Status |
|-----------|------|--------|
| Library ingest CLI | `tools/borg-library-ingest.sh` | implemented |
| Library harvest CLI | `tools/borg-library-harvest.sh` | prototyped, v0.6 (depends on prototype libs) |
| Report CLI | `tools/neo-report.sh` | implemented (standalone); lib integration **prototyped, v0.6** |
| Seed library INDEX | `knowledge/library/INDEX.yaml` | implemented (scaffold) |
| Borg research index | `knowledge/resources/borg_research_index.*` | implemented |

---

## Doc-truth-check scope

`tools/doc-truth-check.sh` validates:

- VERSION, `.gitignore`, workbench docs, ELI5, pipeline hooks  
- **Presence** of prototype lib files (not that they are implemented)  
- This file exists and lists all prototype libs under `lib/`

It does **not** mean “feature works in live mission” — see status column above.

---

## Live dry-run evidence (2026-08-31 — partial, not sign-off)

**Trace:** `DRY-RUN-TRACE-2026-08-31.md` · **Method:** tmux send-keys (Claude), target `192.0.2.1`, project `dryrun-sim-01`

| Observation | Status |
|-------------|--------|
| `claude -p` analyze-recon / AI triage → notes | **Observed working** — not yet operator sign-off |
| Recon / babysteps orchestration | **Observed working** |
| Scope intake → `engagement-scope.json` | **Observed working** |
| LOCK & LOAD toolkit preflight | **Observed working** (awk fix live) |
| `[b]`/`[t]`/`[o]`/`[f]`, foothold→post | **Not exercised** (run stopped mid-ELI5) |

Piped stdin automation (Cursor) is **not** valid evidence against tmux/workbench features.

---

## Human sign-off log

| Date | Feature | Operator | Notes |
|------|---------|----------|-------|
| 2026-08-31 | AI triage (`claude -p`) | dry-run only | Saved to `dryrun-sim-01` notes — pending operator confirm |
| — | *(Tier A/B)* | — | Promote rows here after lab smoke |

---

## Deferred verification (later phase)

**Shelved 2026-09-01** — do **not** run until a dedicated live-lab phase (after offline
verify is green and operator has VPN + target ready).

| Item | Command | Prerequisite | Phase gate |
|------|---------|--------------|------------|
| **Live Tier B scratch mission** | `./neo.sh scratch-tierb-test <HTB_IP>` | HTB/THM VPN up (`tun0`); real reachable target; tmux session (not piped stdin) | **Block H / post–Phase 74** — not Phase 74 sign-off |
| **P18 lab E2E checklist** | `NEO_P18_LAB=1 ./test/p18-lab-e2e.sh` | Same VPN + one full box run; manual checklist in script | **B12 live sign-off** |

**Offline status (2026-09-01):** `linux-phase1-verify.sh` 6/6 pass; `neo-smoke-test.sh` 24/24;
`scratch-tierb-test` against synthetic IP exercises real babysteps/ListenAssist but SSH privesc
fails as expected without a live shell — **not** a substitute for VPN smoke.

**Reminder:** Unset `NEO_TEST_NONINTERACTIVE` in the shell before live runs (Cursor/dev env may export it).

---

## Related docs

| Doc | Role |
|-----|------|
| **`DAILY-WORK-2026-09-01.md`** | **Start here tomorrow** — ordered workload |
| `DRY-RUN-TRACE-2026-08-31.md` | Partial live dry-run evidence |
| `NEO-CODE-REVIEW-2026-08-31.md` | Bug fixes + integration blocks |
| `NEO-AT-WORK-README.md` | Honest v0.5 baseline note |
| `registry.yaml` | Per-script `integration_status` must match this file |
| `AGENTS.md` | Pipeline spec + extension log (prototype entries qualified) |
