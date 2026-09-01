# NEO documentation index

Single catalog for design specs, collab logs, reviews, and archives.  
**Production code** stays in repo root (`lib/`, `neo.sh`, `test/`, etc.).

---

## Start here (agents)

| Doc | Purpose |
|-----|---------|
| [`../MASTER-CHANGELOG.md`](../MASTER-CHANGELOG.md) | **Forward-looking** milestones — update on every major phase |
| [`../AGENTS.md`](../AGENTS.md) | Pipeline rules for scripts |
| [`../CLAUDE.md`](../CLAUDE.md) | Agent entry + test gates |
| [`../NEO-1.0-DESIGN/FEATURE-STATUS.md`](../NEO-1.0-DESIGN/FEATURE-STATUS.md) | Implemented vs prototyped (canonical) |
| [`../NEO-1.0-DESIGN/AGENT-START-HERE.md`](../NEO-1.0-DESIGN/AGENT-START-HERE.md) | Home-lab implementation roadmap |

---

## `collab/` — session & dev logs

| Path | Description |
|------|-------------|
| [`collab/CURSOR-REVIEW-LOG.md`](collab/CURSOR-REVIEW-LOG.md) | Full dev changelog (Phases 1–75+); verbatim operator prompts |
| [`collab/CLAUDE-COLLAB.md`](collab/CLAUDE-COLLAB.md) | Co-lab agenda + operator prompt log |
| [`collab/sessions/DAILY-RECAP-2026-08-31.md`](collab/sessions/DAILY-RECAP-2026-08-31.md) | EOD handoff (2026-08-31) |
| [`collab/sessions/DAILY-WORK-2026-09-01.md`](collab/sessions/DAILY-WORK-2026-09-01.md) | Day plan (2026-09-01) |
| [`collab/sessions/CURSOR-SESSION-UPDATE-2026-08-31.md`](collab/sessions/CURSOR-SESSION-UPDATE-2026-08-31.md) | Session update + review pointers |

---

## `reviews/` — code & architecture reviews

| Path | Description |
|------|-------------|
| [`reviews/NEO-CODE-REVIEW-2026-08-31.md`](reviews/NEO-CODE-REVIEW-2026-08-31.md) | Master code review (Blocks A–H) |
| [`reviews/neo-review/01-tier0-core.md`](reviews/neo-review/01-tier0-core.md) | Tier 0 review |
| [`reviews/neo-review/02-tiers1-3-workbench-msf.md`](reviews/neo-review/02-tiers1-3-workbench-msf.md) | Workbench / MSF review |
| [`reviews/neo-review/03-wiring-missing-files-neo-sh.md`](reviews/neo-review/03-wiring-missing-files-neo-sh.md) | neo.sh wiring gaps |
| [`reviews/neo-review/04-tests-docs-drift.md`](reviews/neo-review/04-tests-docs-drift.md) | Test/doc drift audit |

---

## `archive/` — historical / superseded

| Path | Description |
|------|-------------|
| [`archive/PHASE-58-TENTATIVE-PLAN.md`](archive/PHASE-58-TENTATIVE-PLAN.md) | tmux `--fresh` plan (implemented) |
| [`archive/PHASE-59-PROPOSED-FIX.md`](archive/PHASE-59-PROPOSED-FIX.md) | Integration test fix plan (implemented) |
| [`archive/DRY-RUN-TRACE-2026-08-31.md`](archive/DRY-RUN-TRACE-2026-08-31.md) | Dry-run trace log |
| [`archive/README-1.0design.md`](archive/README-1.0design.md) | Old README copy |
| [`archive/NEO-AT-WORK-README.md`](archive/NEO-AT-WORK-README.md) | Git worktree push how-to |

---

## `../NEO-1.0-DESIGN/` — active design workspace (not moved)

Still at repo root because **`tools/doc-truth-check.sh`** and tests reference fixed paths.

| Area | Key files |
|------|-----------|
| Status | `FEATURE-STATUS.md`, `SCOPE-STATUS.md`, `PROGRESS.md` |
| Architecture | `OPERATOR-WORKBENCH.md`, `AI-CONDUCTOR.md`, `TIER-B-PLAN.md` |
| Projects | `projects/*/DESIGN.md`, `MASTER-MANIFEST.yaml` |
| Prototype | `prototype/neo-next/` (runnable drafts + tests) |
| SIM-H | `projects/22-live-simulation-block-h/DESIGN.md` |

**Phase 2 (future):** relocate `NEO-1.0-DESIGN` → `docs/design/neo-1.0` after updating `doc-truth-check.sh` and README links.

---

## Root docs (stay in place)

| File | Role |
|------|------|
| `README.md` | Operator + agent overview |
| `RELEASE-NOTES.md` | 1.0-rc release draft |
| `KNOWN-LIMITATIONS.md` | Operator limitations |
| `phases.yaml` | Mission phase data (`neo.sh` reads this) |
| `registry.yaml` | Script registry |
