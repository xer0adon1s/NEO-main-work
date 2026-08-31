# History Ingestion — P01 Closeout

Ingested: 2026-08-31 from workspace root `CLAUDE-COLLAB.md` and `CURSOR-REVIEW-LOG.md`.

## Summary

Both files are now available locally. CS-010 / D-010 is **resolved**. Requirements
traceability incorporates phase history from Phases 1–60.

## CLAUDE-COLLAB.md — key facts absorbed

| Topic | Fact | Routed to |
|-------|------|-----------|
| Product metaphor | NEO = hands, operator = brain | P18 operator UX |
| AI layers | Triage, Borg, Payload — wind-up not autopilot | P04, P06, P08 |
| Install flow | setup.sh fetches 6 vendor tools, not in git | P11 |
| AI modes | A=subscription, B=API, C=manual in project.meta | P08 |
| Pause letters | Case-insensitive; boot A/B/C separate | P16, P18 |
| Borg collective | knowledge/vectors/ canonical + symlinks | P04 |
| Payload redesign | [p] advisory picker; [z] analyze failures | P06 (no auto-exec) |
| tmux wrap | neo-<project> session; env forwarding caveat | P05, P09 |
| Pre-foothold | INTERACT section framework | P07 |
| Section tags | AI-TRIAGE, BORG, PAYLOAD, ASK, INTERACT | P14 |

## CURSOR-REVIEW-LOG.md — phase timeline

| Phases | Theme | Design impact |
|--------|-------|---------------|
| 1 | notes-lib awk safety | P14 section markers remain; add JSONL alongside |
| 2 | Pipeline v2 registry, script-lib, ingest | P14, P09 registry parity |
| 12 | Relocate to ~/Neo flat layout | P12 doc truth |
| 28–32 | A/B/C AI, boot, VPN ritual | P08, P10 |
| 37–42 | Borg, payload, research index | P04, P11 |
| 44 | Release v0.3 | P12 version source |
| 46–47 | Speed scan fix, AI stderr hygiene | P12 scan mode docs |
| 48–49 | Menu letters, neo_menu_classify tests | P18 validation |
| 51 | Operator batch: tmux, ask, payload, interact | P02, P05, P16 |
| 52–53 | Borg hook, --no-tmux, web detector | P04, P09 |
| 54–55 | VPN hijack fix ovpn-connect | P10 |
| 56–59 | tmux skip-gate, switch-client, integration tests, v0.5 | P09, P10 |
| 60 | Operator testing: stubs confirmed | P02, P03, P09 acceptance |

## Operator prompt log (selected)

Phase 51 operator intent (paraphrased from CURSOR-REVIEW-LOG):

- Rename Borg menu to `[b]`
- `[z]` = analyze failures at foothold after first attempt
- `[a]` = free-text ask with notes context
- `[p]` = tool-picker payload suggest, no auto-execute
- tmux auto-wrap for terminal capture
- Pre-foothold check-in when web server found

All captured in OPERATOR-DECISIONS OD-003 through OD-008 and project requirements.

## Remaining P01 acceptance checklist

- [x] Every production entry point classified (REQUIREMENTS-TRACEABILITY.yaml)
- [x] Every operator decision linked to projects
- [x] Documentation vs code compared (DISCREPANCIES.yaml)
- [x] Historical inputs ingested (this file)
- [x] Confirmed vs proposed distinguished in all artifacts

**P01 status:** ready for `review_ready`.
