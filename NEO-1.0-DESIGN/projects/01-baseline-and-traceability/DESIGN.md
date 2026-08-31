# P01 — Baseline and Requirements Traceability

**Status:** review_ready · **Priority:** P0

## Deliverables (complete)

| File | Purpose |
|------|---------|
| CURRENT-STATE.md | Confirmed findings CS-001–CS-010 |
| REQUIREMENTS-TRACEABILITY.yaml | OD → project → entrypoint mapping |
| DISCREPANCIES.yaml | Doc vs code register D-001–D-013 |
| WORKFLOW-MAP.md | End-to-end mission + trust boundaries |
| HISTORY-INGESTION.md | CLAUDE-COLLAB + CURSOR-REVIEW-LOG absorbed |

## Key conclusions

1. **v0.5 is strong** on notes pipeline, pause menus, babysteps, Borg concept, tmux fixes
2. **P0 blockers:** secrets exposure, stub entrypoints, eval-based AI execution
3. **Integration order:** P05/P09 → P06/P14 → workflows → Borg/privesc → release
4. **No production edits** until NEO-at-work integration branch

## Next project after P01

Execute **P05** and **P09** in parallel per `MASTER-MANIFEST.yaml` execution_order.
