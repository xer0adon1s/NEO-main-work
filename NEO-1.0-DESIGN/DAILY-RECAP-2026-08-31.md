# NEO Daily Recap — 2026-08-31

**Repo:** `NEO-main-work` (flattened work tree — not live personal NEO)  
**Starting version:** v0.5 (`VERSION`)  
**End-of-day target:** v0.6 prototype → v1.0-rc after Linux lab sign-off  
**Environment:** Windows work PC (design + bash written; **no bash/tmux execution here**)

---

## How to use this document

1. **Operator (tonight):** Run every test in [§ Linux test matrix](#linux-test-matrix) on home Linux.
2. **Claude (code review):** Read this recap + linked docs, then sweep **all files in [§ Complete file inventory](#complete-file-inventory)** for bugs, wiring gaps, and prototype-vs-production mismatches **before** merging into main NEO build.
3. **Cross-reference:** Per-phase verbatim prompts live in `CURSOR-REVIEW-LOG.md` (Phases 61–72 today).

---

## Executive summary

Today was a **full-stack sprint** from NEO 1.0 design-only work through **production-tree prototypes**:

| Block | What happened |
|-------|----------------|
| **Morning — Codex + Cursor design** | Completed P01–P20 design bundle (`NEO-1.0-DESIGN/`), integration plan, scope policy (educational vs professional), agent roadmap, pushed to `NEO-main-work` GitHub repo |
| **Midday — Tier 0 CORE** | 14 foundation libs/schemas landed in production `lib/` (secrets broker, evidence, actions, mission-state, scope, provider, bootstrap) |
| **Afternoon — Tiers 1–3 + workbench** | Operator workbench `[t]`/`[o]`, LOCK & LOAD toolkit, pipeline hooks, MSF foundation, session adapter, ELI5 `[e]`, Borg library AI harvest |
| **Late afternoon — Tier A conductor** | Unified AI bundle, post-triage sequencing, phase hooks, pause menu tuning, operator feedback UX |
| **Evening — Tier B (Waves 1–5)** | Full long-form plan + implementation: conductor automation loop, privesc AI triage, adaptive scan, disclosure lint all surfaces, Borg v2 JSON, batch library harvest, P18 harness |

**Safety invariant unchanged (OD-008):** nothing hits the target without operator approval. Conductor may auto-chain **AI calls** and **local prep**; execution stays in tmux pane B (or `local_safe` argv).

---

## Session timeline

| Time (approx) | Actor | Milestone |
|---------------|-------|-----------|
| 12:34–13:08 | Cursor | Pick up Codex design bundle; “go ham” on all planning docs |
| 13:08–13:17 | Operator + Cursor | **P13 scope policy** — educational vs professional intake at project creation |
| 13:17–13:32 | Cursor | Professional scope template; `AGENT-START-HERE.md`; GitHub publish `NEO-main-work` |
| 13:37–13:47 | Cursor | Hard-code backlog map; **Tier 0 CORE** rough drafts (C0–C13) |
| 13:47–14:04 | Cursor | Tier 1–2 workflows; **P20 operator workbench** design + implementation |
| 14:04–14:11 | Cursor | Workflow alignment pass; Tier 3; **LOCK & LOAD toolkit** (`neo-toolkit.sh`) |
| 14:11+ | Cursor | Attack plan waves 1–4; MSF foundation; session adapter; ELI5; Borg library |
| ~15:00+ | Cursor | Phases 61–63: session adapter, ELI5, Borg HUD fix, doc truth, neo-vendor |
| ~16:00+ | Cursor | Phases 68–70: Borg library AI harvest, **Tier A AI conductor**, pause menu tuning |
| ~16:06+ | Cursor | **Phase 71:** operator feedback (`neo-feedback.sh`) — ack + progress bar |
| ~16:11+ | Cursor | **Tier B long-form plan** (`TIER-B-PLAN.md`); operator locked decisions #1–8 |
| ~17:00+ | Cursor | **Tier B Waves 1–3** implementation (conductor loop, privesc triage, adaptive scan) |
| ~17:20+ | Cursor | Operator pushed commit; **Tier B Waves 4–5** prototype completed |
| EOD | Cursor | This daily recap |

---

## Pre-work: Codex design bundle (before Cursor session)

Codex had started the **NEO 1.0 design workspace** before usage limits. Cursor continued and finished it.

### What Codex / early session created (design-only → later integrated)

| Artifact | Path | Purpose |
|----------|------|---------|
| Master manifest | `NEO-1.0-DESIGN/MASTER-MANIFEST.yaml` | 20 projects P01–P20 |
| Per-project DESIGN.md | `NEO-1.0-DESIGN/projects/*/DESIGN.md` | Spec for each 1.0 feature |
| Prototype tree | `NEO-1.0-DESIGN/prototype/neo-next/` | Runnable drafts (source for CORE migration) |
| Integration plan | `NEO-1.0-DESIGN/INTEGRATION-PLAN.md` | 6-wave migration v0.5 → 1.0 |
| Requirements traceability | `NEO-1.0-DESIGN/projects/01-baseline-and-traceability/REQUIREMENTS-TRACEABILITY.yaml` | OD-001→OD-014 mapped |
| Discrepancies | `NEO-1.0-DESIGN/projects/01-baseline-and-traceability/DISCREPANCIES.yaml` | Doc vs code gaps |
| Workflow map | `NEO-1.0-DESIGN/projects/01-baseline-and-traceability/WORKFLOW-MAP.md` | Mission flow + mermaid |
| History ingestion | `NEO-1.0-DESIGN/projects/01-baseline-and-traceability/HISTORY-INGESTION.md` | Phases 1–60 from review log |
| Operator decisions | `NEO-1.0-DESIGN/OPERATOR-DECISIONS.md` | Locked design choices |
| Agent handoff | `NEO-1.0-DESIGN/AGENT-START-HERE.md` | Home lab roadmap |
| AI handoff | `NEO-1.0-DESIGN/AI-HANDOFF.md` | Context for implementation agents |
| Scope template | `NEO-1.0-DESIGN/templates/scope-policy-template.md` | Professional RoE intake |
| Borg research library design | `NEO-1.0-DESIGN/projects/04-borg-assimilation/BORG-RESEARCH-LIBRARY.md` | Library disclosure model |
| Mission statement | `NEO-1.0-DESIGN/MISSION-STATEMENT.md` | End-to-end Metasploit-class conductor vision |
| Operator workbench spec | `NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md` | Pane model + suggest→try→analyze loop |
| Status boards | `SCOPE-STATUS.md`, `HARD-CODE-BACKLOG.md`, `PROGRESS.md`, `TIER*-STATUS.md` | Tier tracking |
| Attack plan | `NEO-1.0-DESIGN/ATTACK-PLAN.md` | EOD execution waves |
| E2E checklist | `NEO-1.0-DESIGN/E2E-CHECKLIST.md` | Lab validation steps |

**Note:** Some status docs may lag the code (known gap — Phase 63 attempted doc-truth sweep).

---

## Tier 0 — CORE dependencies (C0–C13)

**Doc:** `NEO-1.0-DESIGN/CORE-STATUS.md`

| ID | File | Role |
|----|------|------|
| C0 | `lib/neo-core.sh` | Shared primitives, project validation |
| C1 | `lib/neo-secrets.sh` | Secret broker (no repo `.env`) |
| C2 | `.gitignore` | Blocks `.env`, keys |
| C3 | `lib/neo-ai.sh` | AI via broker |
| C4 | `lib/neo-tmux.sh` | No API keys in tmux forward |
| C5 | `lib/neo-evidence.sh` | Evidence JSONL |
| C6 | `lib/neo-actions.sh` + `schemas/*.json` | Typed action policy |
| C7 | `lib/neo-mission-state.sh` | Mission JSON state machine |
| C8 | `lib/neo-scope.sh` | Engagement scope / CIDR |
| C9 | `lib/neo-provider.sh` | AI provider abstraction |
| C10 | `test/production-integrity-gate.sh` | Safety gate |
| C11 | `test/run-all.sh` | Aggregate runner |
| C12 | `test/neo-diagnostic.sh` | Pre-review diagnostic |
| C13 | `lib/neo-1.0-bootstrap.sh` | Early neo.sh bootstrap |

**Tests:** `test/core-secrets-test.sh`, `test/mission-state-test.sh`, `test/secret-canary-test.sh`, `test/injection-payload-test.sh`, `test/workflow-scope-test.sh`

---

## Tiers 1–3 — Workflows, workbench, toolkit, MSF

### P20 Operator workbench (core product loop)

**Docs:** `OPERATOR-WORKBENCH.md`, `projects/20-operator-workbench/DESIGN.md`  
**Code:**

| File | Role |
|------|------|
| `lib/neo-operator-pane.sh` | tmux pane B — send commands without killing conductor |
| `lib/neo-workbench.sh` | suggest → try → capture → analyze loop |
| `lib/neo-windup-actions.sh` | y/N before target actions |
| `neo.sh` | `[t]`/`[o]` pause dispatch |

**Tests:** `test/workbench-test.sh`, `test/menu-routing-test.sh`

### Tier 3.14 — LOCK & LOAD toolkit

| File | Role |
|------|------|
| `lib/neo-toolkit.sh` | Verify tools, SecLists paths, wordlists before `[t]` try |

**Tests:** `test/toolkit-test.sh`

### Attack plan waves 1–4 (ATTACK-PLAN.md)

| Wave | Deliverable | Key files |
|------|-------------|-----------|
| 1 | Post phase `[t]`/`[o]` visible | `neo-workbench.sh` |
| 2 | Pipeline hooks (plan-enum, operator-recon, privesc rank) | `neo-pipeline-hooks.sh`, `recon/plan-enum.sh`, `recon/operator-recon.sh`, `privesc/normalize-findprivs.sh`, `privesc/rank-privesc-plan.sh` |
| 3 | MSF handler + session adapter | `neo-exploit-framework.sh`, `neo-handler-pane.sh`, `foothold/ListenAssist.sh`, `neo-mission-state.sh` |
| 4 | neo-vendor install/rollback | `tools/neo-vendor.sh` |

**Tests:** `test/plan-enum-hook-test.sh`, `test/privesc-rank-hook-test.sh`, `test/exploit-framework-test.sh`, `test/session-adapter-test.sh`, `test/vendor-test.sh`

---

## CURSOR-REVIEW-LOG phases (today)

| Phase | Topic | Primary doc pointer |
|-------|-------|---------------------|
| **61** | Session adapter + MSF post menu | `CURSOR-REVIEW-LOG.md` § Phase 61 |
| **62** | ELI5 educational mode `[e]` | `lib/neo-eli5.sh`, `test/eli5-test.sh` |
| **63** | Borg HUD fix, doc truth, neo-vendor rollback, ELI5 hooks | `tools/doc-truth-check.sh` |
| **68** | Borg library AI-first harvest | `lib/neo-borg-library-ai.sh`, `tools/borg-library-harvest.sh` |
| **69** | AI conductor Tier A | `NEO-1.0-DESIGN/AI-CONDUCTOR.md`, `lib/neo-conductor.sh` |
| **70** | Pause menu + conductor tuning | `lib/neo-menu.sh` |
| **71** | Operator feedback (ack + progress bar) | `lib/neo-feedback.sh`, `test/neo-feedback-test.sh` |
| **72** | Tier B Waves 4–5 | This doc § Tier B |

*(Phases 64–67 landed in earlier commits per `AGENTS.md` extension log: Borg multi-vector, library disclosure, library ingest, final report.)*

---

## Tier A — AI Conductor (proactive orchestration)

**Doc:** `NEO-1.0-DESIGN/AI-CONDUCTOR.md`

| Feature | Implementation |
|---------|----------------|
| Unified mission bundle | `neo_conductor_build_bundle()` in `lib/neo-conductor.sh` |
| Post-triage sequencing | Borg Y/n → payload Y/n after `neo_ai_finish_triage_run` |
| Phase entry hooks | `neo_conductor_on_phase_entry` in `neo.sh` |
| Pause nudges | `neo_menu_conductor_nudge` |
| Wiring | `neo-ai.sh`, `neo-payload.sh`, `neo-borg.sh`, `neo-workbench.sh`, `neo-ai-cli.sh` |

**Tests:** `test/conductor-test.sh`

---

## Tier B — AI Conductor Automation (Waves 1–5)

**Master plan:** `NEO-1.0-DESIGN/TIER-B-PLAN.md`  
**Status:** Waves 1–5 **implemented (prototype)**; B12 live E2E = harness only until lab.

### Operator decisions locked (#1–8)

| # | Decision |
|---|----------|
| 1 | Educational → **guided**; professional → **assisted** |
| 2 | Guided: Y every step; assisted: auto loop; at cap → **batch failure review** |
| 3 | Default **5** attempts; prompt for variable N at loop start |
| 4 | Privesc: **AI-only display**; jq ranker is bundle input only |
| 5 | **Pane C** (`neo-handler-pane`) required for visible listeners |
| 6 | Enum: never remove mechanical actions; AI ranks + sidecar only |
| 7 | Aggressive mode **deferred v1.1** (falls back to assisted) |
| 8 | P08 full provider migration deferred; automation shipped first |

### tmux pane model (Tier B)

| Pane | Role |
|------|------|
| **A** | Conductor / pause menus / stdin owner |
| **B** | Operator commands (`[t]` try, `[o]` shell) |
| **C** | Listeners / handlers (`neo-handler-pane.sh`) |

Auto-wrap: `lib/neo-tmux.sh` (Phases 56–59 from prior session; unchanged today but required for capture).

---

### Wave 1 — B1 Conductor automation core

| File | Role |
|------|------|
| `lib/neo-conductor-loop.sh` | Playbooks, `neo_conductor_on_event`, guided vs assisted loops, variable max loops |
| `lib/neo-mission-state.sh` | `neo_mission_conductor_*` helpers, `mission.json` conductor block |
| `lib/neo-workbench.sh` | `neo_workbench_try_loop_step` |
| `lib/neo-payload.sh` | `neo_payload_suggest_loop_step` |
| `neo.sh` | Event emitters, lib list |

**Tests:** `test/conductor-automation-test.sh`

---

### Wave 2 — B2, B3, B7 Intelligence on evidence

| ID | Feature | Files |
|----|---------|-------|
| B2 | AI privesc triage | `lib/neo-conductor-privesc.sh` → **PRIVESC-PLAN** section |
| B3 | AI enum planner | `lib/neo-enum-ai.sh` (rank artifacts, `ranked-order.md`) |
| B7 | Post-assimilate library hook | `lib/neo-borg-library.sh` → `neo_borg_library_offer_research_hook` |

**Template:** `templates/investigation-notes.md` — **PRIVESC-PLAN** markers

**Tests:** `test/conductor-automation-test.sh` (privesc path), `test/borg-library-ai-test.sh`

---

### Wave 3 — B4, B5, B6 Targeted execution + MSF

| ID | Feature | Files |
|----|---------|-------|
| B4 | Adaptive babysteps | `lib/neo-adaptive-scan.sh`, `recon/babysteps.sh` `--targets-file` |
| B5 | Operator-recon structurer | `lib/neo-operator-recon-ai.sh`, `recon/operator-recon.sh`, `neo-interact.sh` |
| B6 | MSF AI post suggest | `neo_msf_ai_suggest_post` in `neo-exploit-framework.sh`, `neo-pipeline-hooks.sh` |

**Tests:** extend `test/exploit-framework-test.sh`

---

### Wave 4 — B8, B9 Safety + provider

| ID | Feature | Files | Env |
|----|---------|-------|-----|
| B8 | Disclosure lint all AI outputs | `lib/neo-ai-guard.sh`, `lib/neo-borg-disclosure.sh` | `NEO_DISCLOSURE_LINT_ALL=1`, `NEO_DISCLOSURE_STRICT=1` |
| B9 | Borg live web research | `neo_provider_web_research_bundle_block` in `neo-provider.sh` | `NEO_PROVIDER_WEB_RESEARCH=1`, `NEO_BORG_HARVEST=1` |

**Guard wired in:** `neo-payload.sh`, `neo-borg.sh`, `neo-ai-cli.sh` (triage), `neo-eli5.sh`

**Tests:** `test/disclosure-lint-all-test.sh`, `test/neo-provider-web-test.sh`, `test/borg-disclosure-test.sh`

---

### Wave 5 — B10, B11, B12 Structure at scale

| ID | Feature | Files |
|----|---------|-------|
| B10 | Borg v2 structured JSON | `borg/borg-v2.sh`, `lib/neo-borg-v2.sh`, `schemas/borg-dossier.schema.json` |
| B11 | Batch library harvest | `lib/neo-borg-library-batch.sh`, `tools/borg-library-harvest.sh --batch` |
| B12 | P18 lab E2E harness | `test/p18-lab-e2e.sh` |

**Tests:** `test/borg-v2-test.sh`, `test/borg-library-batch-test.sh`, `test/p18-lab-e2e.sh`

---

## Complete file inventory

### New production libs (today / this sprint)

```
lib/neo-core.sh
lib/neo-secrets.sh
lib/neo-evidence.sh
lib/neo-actions.sh
lib/neo-mission-state.sh
lib/neo-scope.sh
lib/neo-provider.sh
lib/neo-1.0-bootstrap.sh
lib/neo-windup-actions.sh
lib/neo-operator-pane.sh
lib/neo-handler-pane.sh
lib/neo-workbench.sh
lib/neo-toolkit.sh
lib/neo-exploit-framework.sh
lib/neo-pipeline-hooks.sh
lib/neo-eli5.sh
lib/neo-report.sh
lib/neo-conductor.sh
lib/neo-conductor-loop.sh
lib/neo-conductor-privesc.sh
lib/neo-enum-ai.sh
lib/neo-adaptive-scan.sh
lib/neo-operator-recon-ai.sh
lib/neo-feedback.sh
lib/neo-ai-guard.sh
lib/neo-borg-v2.sh
lib/neo-borg-library-batch.sh
lib/neo-borg-disclosure.sh      (extended Wave 4)
lib/neo-borg-library.sh
lib/neo-borg-library-ai.sh
lib/neo-borg-harvest.sh
```

### Schemas

```
schemas/action-policy.json
schemas/action.schema.json
schemas/engagement-scope.schema.json
schemas/dossier.schema.json
schemas/service.schema.json
schemas/privesc-facts.schema.json
schemas/vendor-manifest.schema.json
schemas/borg-dossier.schema.json    (Wave 5)
```

### Tools / scripts

```
tools/neo-vendor.sh
tools/borg-library-harvest.sh     (--research, --batch)
tools/borg-library-ingest.sh
tools/doc-truth-check.sh
tools/windows-static-check.ps1
borg/borg-v2.sh
privesc/normalize-findprivs.sh
privesc/rank-privesc-plan.sh
recon/plan-enum.sh
recon/operator-recon.sh
```

### Templates / notes

```
templates/investigation-notes.md   (ELI5, PRIVESC-PLAN, WORKBENCH, REPORT, …)
```

### Major wiring touchpoints

```
neo.sh                             (lib hygiene list, pause menus, phase hooks, tmux wrap)
lib/neo-borg.sh                    (guard, web research, batch offer, v2 offer)
lib/neo-payload.sh                 (guard, LOCK&LOAD, MSF block)
lib/neo-ai-cli.sh                  (triage guard, conductor after triage)
lib/neo-menu.sh                    (pause letter routing)
registry.yaml                      (script registry)
AGENTS.md                          (extension log)
```

---

## Linux test matrix

Run from repo root on **home Linux** (bash required). Order: quick suites → aggregate → diagnostic → optional live.

### One-shot aggregate (start here)

```bash
cd ~/Neo-main-work   # or your clone path
chmod +x test/*.sh tools/*.sh neo.sh

./test/run-all.sh
```

Expected: all suites green; `bash -n` over all `.sh` passes. Note any `production-integrity-gate` stub warnings (ListenAssist/FindPrivs stubs may still fail gate by design until Wave 3 stub replacement on live NEO).

### Full diagnostic (pre-review gate)

```bash
./test/neo-diagnostic.sh
```

Historically **61 checks** + unit count **162+** (count grows with new suites — verify banner at end).

### Doc truth

```bash
./tools/doc-truth-check.sh
```

### Per-suite (run individually if aggregate fails)

#### CORE / safety (Tier 0)

```bash
./test/core-secrets-test.sh
./test/mission-state-test.sh
./test/secret-canary-test.sh
./test/injection-payload-test.sh
./test/workflow-scope-test.sh
./test/production-integrity-gate.sh
```

#### Workbench + toolkit + MSF (Tiers 2.5 / 3)

```bash
./test/workbench-test.sh
./test/toolkit-test.sh
./test/exploit-framework-test.sh
./test/plan-enum-hook-test.sh
./test/privesc-rank-hook-test.sh
./test/vendor-test.sh
./test/session-adapter-test.sh
./test/eli5-test.sh
```

#### Borg + library + disclosure

```bash
./test/borg-test.sh
./test/borg-disclosure-test.sh
./test/borg-library-ingest-test.sh
./test/borg-library-ai-test.sh
./test/disclosure-lint-all-test.sh      # Wave 4
./test/borg-library-batch-test.sh       # Wave 5
./test/borg-v2-test.sh                  # Wave 5
```

#### Conductor + menu + feedback (Tier A / B)

```bash
./test/conductor-test.sh
./test/conductor-automation-test.sh     # Tier B Wave 1
./test/neo-feedback-test.sh             # Phase 71
./test/menu-routing-test.sh
./test/payload-test.sh
./test/neo-report-test.sh
```

#### Integration / smoke / tmux

```bash
./test/neo-boot-test.sh
./test/interact-test.sh
./test/neo-tmux-test.sh
./test/neo-tmux-integration-test.sh     # needs tmux + script(1)
./test/neo-smoke-test.sh
```

#### Notes / recon bundle

```bash
./test/notes-lib-test.sh
./test/recon-bundle-test.sh
```

#### P18 lab E2E (offline + live)

```bash
./test/p18-lab-e2e.sh                   # offline harness always

# After one full HTB box with conductor:
NEO_P18_LAB=1 ./test/p18-lab-e2e.sh
```

#### Provider web (Wave 4 — offline)

```bash
./test/neo-provider-web-test.sh
```

### Live manual smoke (recommended after unit green)

```bash
# Fresh scratch project — educational mode
./neo.sh scratch-tierb-test <HTB_TARGET_IP>

# Exercise at each pause:
# [b] Borg  [p] payload  [t] try  [o] operator pane  [e] ELI5  [a] ask
# Accept conductor loop once on foothold (guided or assisted per engagement_mode)

# Optional Wave 4 Borg web block:
NEO_PROVIDER_WEB_RESEARCH=1 NEO_BORG_HARVEST=1 ./neo.sh scratch-tierb-test <IP>

# Batch library dry-run:
./tools/borg-library-harvest.sh --batch --from-project scratch-tierb-test --dry-run

# Borg v2 experimental:
./borg/borg-v2.sh --project scratch-tierb-test
```

### tmux integration (Tier B critical path)

```bash
# From OUTSIDE any tmux session:
./neo.sh myproject <target>            # should auto-wrap to neo-myproject

# Inside foreign tmux (e.g. leftover OpenVPN):
# Should switch-client to neo-myproject, not skip wrap

./test/neo-tmux-integration-test.sh
```

---

## Claude code review checklist

Use this as a **sweeping review prompt** after reading this doc:

### 1. Wiring & import graph

- [ ] Every `lib/neo-*.sh` in `lib/` appears in `neo.sh` `NEO_LIB_SCRIPTS` **or** is intentionally loaded on-demand only
- [ ] `test/neo-diagnostic.sh` `neo_libs` array matches `lib/` (no false hygiene warnings)
- [ ] No circular `source` loops (`neo-conductor-loop.sh` ↔ `neo-conductor.sh` guarded?)
- [ ] `registry.yaml` entries match real scripts

### 2. Conductor automation (Tier B)

- [ ] `neo_conductor_on_event` handles all documented events
- [ ] Guided vs assisted: correct Y/n gates per `engagement_mode`
- [ ] Loop cap + variable N persisted in `mission.json`
- [ ] Batch failure review at cap includes tmux B+C capture + workbench artifacts
- [ ] `NEO_CONDUCTOR_MODE=aggressive` falls back to assisted with notice

### 3. Safety & disclosure

- [ ] `neo_ai_guard_output` on **every** AI notes append (triage, Borg, payload, ELI5, report)
- [ ] Educational mode blocks spoiler patterns; professional mode allows
- [ ] Wind-up y/N still required before target actions
- [ ] No API keys in tmux env forward

### 4. tmux / panes

- [ ] Pane A owns stdin during pauses
- [ ] `[t]` sends to pane B only
- [ ] Handler pane C started when MSF/listener needed
- [ ] `neo_tmux_already_in_own_session` skip-gate correct (foreign session ≠ skip)

### 5. Prototype quality

- [ ] `set -euo pipefail` / empty grep failures in babysteps recon path
- [ ] Temp files for notes content (no awk injection via `-v`)
- [ ] Interactive prompts respect `neo_conductor_skip_interactive` / `NEO_TEST_NONINTERACTIVE`
- [ ] Borg v2 JSON validation before notes append

### 6. Tests

- [ ] Each new lib has at least one offline test
- [ ] Mock/fixture tests don't require network or Claude
- [ ] `run-all.sh` includes all new suites

### 7. Docs vs code drift

- [ ] `SCOPE-STATUS.md`, `PROGRESS.md`, `TIER2.5-STATUS.md` — flag stale claims
- [ ] `TIER-B-PLAN.md` success criteria checkboxes — honest status
- [ ] `AGENTS.md` extension log matches reality

### 8. Known deferred (do not block review on these)

- Full P08 provider migration (AI callers still split)
- Aggressive conductor mode (v1.1)
- P18 live 3-box E2E on HTB
- `VERSION` → `1.0.0-rc` (operator decision after lab)
- neo-vendor real URL download + rollback on live network

---

## Known gaps & risks (honest)

| Item | Risk | Mitigation |
|------|------|------------|
| **No bash run on work PC** | Tests unverified until tonight | Run full matrix on Linux |
| **Docs lag code** | False "not started" in status boards | `doc-truth-check.sh` + manual pass |
| **Circular source risk** | Infinite loop if guard removed | Review `neo-conductor-loop.sh` guards |
| **Disclosure strict default** | AI triage may refuse save on borderline text | `NEO_DISCLOSURE_STRICT=0` or professional mode |
| **Borg v2 experimental** | May fail without provider | Offer is Y/n default-n |
| **Batch harvest** | Can invoke many AI calls | Dry-run default prompt; operator confirm |
| **integrity gate stubs** | ListenAssist/FindPrivs stubs may fail gate | Expected until live NEO stub replacement |

---

## Related documentation index

| Doc | When to read |
|-----|--------------|
| `NEO-1.0-DESIGN/TIER-B-PLAN.md` | Tier B architecture + waves |
| `NEO-1.0-DESIGN/AI-CONDUCTOR.md` | Tier A + Tier B+ status |
| `NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md` | Pane model + loop semantics |
| `NEO-1.0-DESIGN/MISSION-STATEMENT.md` | Product vision |
| `NEO-1.0-DESIGN/ATTACK-PLAN.md` | EOD waves 1–5 |
| `NEO-1.0-DESIGN/AGENT-START-HERE.md` | Clone + first commands |
| `NEO-1.0-DESIGN/INTEGRATION-PLAN.md` | v0.5 → 1.0 migration waves |
| `NEO-1.0-DESIGN/projects/04-borg-assimilation/BORG-RESEARCH-LIBRARY.md` | Library disclosure |
| `NEO-1.0-DESIGN/projects/08-ai-provider-interface/DESIGN.md` | P08 provider (partial) |
| `NEO-1.0-DESIGN/projects/17-privesc-workflow/DESIGN.md` | Privesc AI triage |
| `NEO-1.0-DESIGN/projects/20-operator-workbench/DESIGN.md` | Workbench spec |
| `NEO-1.0-DESIGN/projects/21-exploit-framework-conductor/DESIGN.md` | MSF conductor |
| `AGENTS.md` | Pipeline rules + extension log |
| `CURSOR-REVIEW-LOG.md` | Phases 61–72 verbatim prompts |
| `README.md` | User-facing NEO overview |
| `registry.yaml` | Script registry |

---

## Suggested Claude review prompt (copy-paste)

```
Read NEO-1.0-DESIGN/DAILY-RECAP-2026-08-31.md in full, then perform a sweeping code review of ALL production changes from today's session (Tier 0 CORE through Tier B Waves 1–5).

Focus areas:
1. Wiring bugs (missing sources, wrong phase hooks, menu letter dispatch)
2. Conductor loop state machine correctness (guided vs assisted, loop cap, batch failure review)
3. Disclosure guard coverage on all AI save paths
4. tmux pane separation (A/B/C) and capture reliability
5. Test gaps and false positives in offline suites
6. Doc vs code drift flagged in the recap

Do NOT merge to live NEO yet. Output: prioritized bug list (P0/P1/P2), file:line references, and suggested fixes.
```

---

## Version / release notes

- **Shipped in tree:** v0.5 baseline + v0.6 prototype features (not tagged yet)
- **Tag `1.0.0-rc`:** Operator decision after `./test/run-all.sh` + `./test/neo-diagnostic.sh` green + at least one P18 box with conductor loop

---

*Generated: 2026-08-31 EOD · Cursor session · Operator: push this doc, then hand to Claude for pre-merge review.*
