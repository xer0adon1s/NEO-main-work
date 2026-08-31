# Tier 2.5 — Operator Workbench (Core Loop)

**Status:** rough draft integrated · **Date:** 2026-08-31

## Delivered

| Component | Path |
|-----------|------|
| Design hub | `NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md` |
| P20 spec | `NEO-1.0-DESIGN/projects/20-operator-workbench/` |
| Operator pane | `lib/neo-operator-pane.sh` |
| Workbench loop | `lib/neo-workbench.sh` |
| Schemas | `schemas/workbench-attempt.schema.json`, `workbench-session.schema.json` |
| Notes section | `templates/investigation-notes.md` → `WORKBENCH` |
| Menu | `[t]ry`, `[o]perator shell`; `[z]` widened when attempts exist |
| Tests | `test/workbench-test.sh`, `test/menu-routing-test.sh` updated |

## Operator flow

```
[p] suggest → [t] try (y/N) → capture → analyze (Y/n) → repeat → foothold confirm → [c]
```

## Remaining

- Lab E2E → **Tier 3.13 / P18** (`NEO-1.0-DESIGN/E2E-CHECKLIST.md`)
- Auto-SSH operator pane when session known (**deferred** — operator runs SSH manually)
- Session adapter → **Prototyped** (`neo_operator_pane_offer_session_connect`, Phase 61)
- Post phase `[t]`/`[o]` → **Complete** (Wave 1)
- ELI5 `[e]` tutor → **Complete** (Phase 62)

## Verify locally (Linux lab)

```bash
./test/workbench-test.sh
./test/menu-routing-test.sh
./neo.sh <project> <target>   # interactive: [o], [p], [t], [z]
```
