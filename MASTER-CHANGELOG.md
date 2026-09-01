# MASTER CHANGELOG — NEO

**For all agents:** read this first for current project state. Append **major** milestones here
(one short entry per phase or release). Verbatim operator prompts and full phase notes live in
[`docs/collab/CURSOR-REVIEW-LOG.md`](docs/collab/CURSOR-REVIEW-LOG.md).

**Release:** v0.5 (`VERSION`) · target 1.0.0-rc after SIM-H sign-off  
**Canonical feature board:** [`NEO-1.0-DESIGN/FEATURE-STATUS.md`](NEO-1.0-DESIGN/FEATURE-STATUS.md)  
**Doc index:** [`docs/INDEX.md`](docs/INDEX.md)

---

## How to log work

| What | Where |
|------|--------|
| Major milestone (phase, release, integration batch) | **This file** — 3–8 bullets max |
| Verbatim operator prompt + full implementation notes | `docs/collab/CURSOR-REVIEW-LOG.md` |
| Co-lab / Claude session agenda | `docs/collab/CLAUDE-COLLAB.md` |
| Day/session handoffs | `docs/collab/sessions/` |

---

## 2026-09-01 — Phase 76: Docs consolidation (logs only)

- Moved collab logs, session notes, code reviews, and historical phase plans into `docs/` (see `docs/INDEX.md`).
- **`NEO-1.0-DESIGN/` left in place** — `tools/doc-truth-check.sh` and tests depend on its paths.
- Root `MASTER-CHANGELOG.md` introduced as forward-looking agent entry point.

---

## 2026-09-01 — Phase 75: Doc hygiene

- Synced README, AGENTS, FEATURE-STATUS, SIM-H runbook refs with Phase 74 reality.
- Offline gate: `linux-phase1-verify.sh` **6/6**, `neo-smoke-test.sh` **24/24**.

---

## 2026-09-01 — Phase 74: P1 integration batch

- Conductor phase entry, privesc AI triage, report generate, library AI, adaptive scan, handler pane helpers.
- Prototype libs remain **prototyped, v0.6** until SIM-H sign-off.

---

## 2026-09-01 — Phase 73: P0 prototype fixes

- Feedback ack, disclosure meta from `project.meta`, conductor prompt defaults, privesc bundle leak fix.

---

## 2026-08-30 — v0.5 shipped

- tmux auto-wrap, operator workbench `[t]`/`[o]`, Borg `[b]`, payload `[p]`, analyze failures `[z]`, menu routing tests.
- Pre-review: `./test/neo-diagnostic.sh` + `./test/run-all.sh`.

---

## Next verification (operator)

```bash
bash tools/linux-phase1-verify.sh
```

Live lab: `NEO-1.0-DESIGN/projects/22-live-simulation-block-h/DESIGN.md` (SIM-H / Block H).
