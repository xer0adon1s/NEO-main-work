# Agent Start Here — NEO-at-work Home Lab Roadmap

**Audience:** Cursor, Claude, or any implementation agent resuming on your **home Linux box**.  
**Repo:** `neo-at-work` (full copy of desktop `NEO-main` + all design work).  
**Rule:** Do **not** merge into live personal NEO git until P18 E2E passes.

---

## What this repository contains

| Area | Path | Status |
|------|------|--------|
| **v0.5 + v0.6 prototype libs** | repo root (`neo.sh`, `lib/`, `recon/`, …) | Tier 0–3 foundation **implemented**; Tier A/B **prototyped, v0.6** — see `FEATURE-STATUS.md` |
| **NEO 1.0 design workspace** | `NEO-1.0-DESIGN/` | Design docs complete; production status in FEATURE-STATUS.md |
| **1.0 prototype code** | `NEO-1.0-DESIGN/prototype/neo-next/` | Runnable on Linux; not wired to `neo.sh` |
| **Planning history** | `CLAUDE-COLLAB.md`, `CURSOR-REVIEW-LOG.md` | Operator context |
| **Professional scope template** | `NEO-1.0-DESIGN/templates/scope-policy-template.md` | Fill → `scope-import.sh` |

**Start reading:** **`NEO-1.0-DESIGN/DAILY-WORK-2026-09-01.md`** (tomorrow workload) → `AI-HANDOFF.md` → `OPERATOR-DECISIONS.md`

---

## First commands on Linux (verify)

```bash
cd neo-at-work   # or wherever you cloned
./neo.sh --version                    # expect 0.5 — production untouched

cd NEO-1.0-DESIGN
bash tests/run-all.sh                 # design workspace validation

cd prototype/neo-next
bash test/run-all.sh                  # prototype unit/workflow tests
bash test/production-integrity-gate.sh   # EXPECT FAIL on v0.5 (stubs) — correct
```

---

## What was created (2026-08-31 design session)

### P01 — Baseline
- `REQUIREMENTS-TRACEABILITY.yaml`, `DISCREPANCIES.yaml`, `WORKFLOW-MAP.md`
- History from Phases 1–60 ingested

### P02–P19 — Each has `projects/NN-*/DESIGN.md`
Key prototypes already written (not integrated):

| Lib / tool | Project |
|------------|---------|
| `neo-secrets.sh` | P05 |
| `neo-actions.sh` + schemas | P06 |
| `neo-provider.sh` | P08 |
| `neo-evidence.sh` | P14 |
| `neo-mission-state.sh` | P16 |
| `neo-scope.sh`, `scope-intake.sh`, `scope-import.sh` | P13 |
| `ListenAssist.sh`, `run-findprivs.sh` | P02, P03 |
| `borg-v2.sh` | P04 |
| `operator-recon.sh`, `plan-enum.sh` | P07, P15 |
| `neo-vpn-consent.sh` | P10 |
| `neo-operator-pane.sh`, `neo-workbench.sh` | **P20 (core loop)** |
| `production-integrity-gate.sh` | P09 |

### Cross-cutting docs
| Doc | Use |
|-----|-----|
| `INTEGRATION-PLAN.md` | File-by-file v0.5 → 1.0 migration (5 waves) |
| `IMPLEMENTATION-ROADMAP.md` | Wave checklists + time estimates |
| `PROGRESS.md` | Status board |
| `SECRETS-RUNBOOK.md` | API key handling |
| `UPGRADE-FROM-0.5.md` | Migration/rollback |
| `NEO-AT-WORK-GIT.md` | Git layout notes |
| **`AGENT-START-HERE.md`** | **This file** |

---

## Implementation order (do not skip)

From `MASTER-MANIFEST.yaml` `execution_order`:

```
P01 ✓ (design done)
  → P05 + P09        secrets + test gates
  → P06 + P13 + P14 + P16   actions, scope, evidence, state
  → P07, P08, P10, P11, P12
  → P15
  → P02, P03, P04    ListenAssist, FindPrivs, Borg
  → P20              operator workbench (core try/analyze loop)
  → P17              privesc ranker
  → P18              E2E validation → release 1.0
  → P19              GUI boundary (docs only for 1.0)
```

**Integration branch:** `neo-1.0-integration` off v0.5 tag. Follow `INTEGRATION-PLAN.md` waves.

---

## Wave 1 — Your first implementation session (suggested)

1. Tag current state: `git tag v0.5-design-baseline`
2. Branch: `git checkout -b neo-1.0-integration`
3. Copy Wave 1 files from prototype → production (see `INTEGRATION-PLAN.md`)
4. Patch `lib/neo-tmux.sh` — remove API key forwarding
5. Patch `lib/neo-ai.sh` — remove `.env` source; use `neo_secret_load`
6. Add `production-integrity-gate.sh` to `test/neo-diagnostic.sh`
7. Run tests — gate should still fail on ListenAssist/findprivs stubs until Wave 3

---

## P13 professional scope — operator workflow

1. Copy `NEO-1.0-DESIGN/templates/scope-policy-template.md` to `~/engagements/<client>/`
2. Fill with client RoE (fictional example in template §9)
3. At project create: `[P]` professional **or** import:
   ```bash
   bash NEO-1.0-DESIGN/prototype/neo-next/tools/scope-import.sh \
     --project acme-pentest --policy ~/engagements/acme/scope-policy.md
   ```
4. AI layers receive redacted `AI-SCOPE-RULES` block from policy

Educational HTB/THM: use `scope-intake.sh` with `[E]` — lighter intake.

---

## Known v0.5 gaps (must fix for 1.0)

| ID | Issue | Project |
|----|-------|---------|
| CS-001 | ListenAssist 7-line stub | P02 |
| CS-002 | run-findprivs smoke stub | P03 |
| CS-004/005 | .env + tmux key exposure | P05 |
| CS-006 | Borg eval wind-up | P04, P06 |
| CS-007 | VPN pkill without consent | P10 |

Full list: `projects/01-baseline-and-traceability/DISCREPANCIES.yaml`

---

## What differs: design vs production

```
NEO-main (v0.5)              NEO-1.0-DESIGN/prototype/neo-next
─────────────────────────────────────────────────────────────
foothold/ListenAssist.sh     foothold/ListenAssist.sh (full)
privesc/run-findprivs.sh     privesc/run-findprivs.sh (full)
lib/neo-borg.sh (eval)       borg/borg-v2.sh (JSON only)
(no scope)                   lib/neo-scope.sh + intake/import
project.meta phase only      lib/neo-mission-state.sh
notes sections only          lib/neo-evidence.sh JSONL
```

**Diff strategy for agents:** For each wave in `INTEGRATION-PLAN.md`, diff prototype file
against production target, port changes, run tests, update `CURSOR-REVIEW-LOG.md` phase entry.

---

## E2E success (P18)

Before merging to personal NEO:

- [ ] 3 easy HTB boxes completed with scope intake
- [ ] Workbench loop: `[p]` → `[t]` → analyze → foothold on at least one box
- [ ] `production-integrity-gate.sh` passes
- [ ] `neo-diagnostic.sh` passes
- [ ] Secret canary audit clean
- [ ] Professional scope import tested with template file

---

## Agent response format (required)

Per `AI-HANDOFF.md`, each integration session should report:

1. Requirements covered (by ID)
2. Files changed
3. Design deviations
4. Tests run + results
5. Remaining risks / next project ID

---

## Questions already decided — do not re-litigate

- Scope asked at **project creation** (educational + professional) — OD-009
- Same codebase for labs and pro pentests — OD-015
- No auto-execute AI commands — P06
- ListenAssist is **guided**, not autopilot — OD-003
- Production source was **not** modified during design — OD-001

---

*Generated 2026-08-31. Update this file when integration waves complete.*
