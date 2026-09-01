# Final Report — Design Document

**Status:** **prototyped, v0.6** · **Phase:** 67 · **Depends:** P08 AI provider, P13 disclosure, P14 notes

## Problem

`Investigation-Notes.md` is **agent-oriented internal jargon** — section markers, LOG dumps,
workbench captures. Operators and employers need a **human-readable final artifact** when a
mission is done.

## Solution

`lib/neo-report.sh` pipes the full mission bundle into AI and writes:

1. **`REPORT` section** in Investigation-Notes.md (curated, replaced each run)
2. **`artifacts/final-report-<timestamp>.md`** — full deliverable copy
3. **`project.meta`** keys: `final_report_at`, `final_report_artifact`

## Disclosure modes (same as Borg library)

| Mode | Output style |
|------|----------------|
| **Educational** (default) | Learning “book report”: techniques tried, dead ends, lessons — **no lab box title spoilers** |
| **Professional** | Client pentest deliverable: executive summary, findings with severity, full attack narrative including vectors that failed or were safe/locked, recommendations, appendices |

Mode from `engagement_mode` in `project.meta`, `engagement-scope.json`, or `NEO_ENGAGEMENT_MODE`.

Post-generation **educational lint** warns if `neo_borg_disclosure_check` flags box-name leakage.

## Workflow integration

```
post phase pause menu ──▶ [f]inal report
mission pipeline ends  ──▶ Y/n "Generate final report?"
neo.sh <project> --report ──▶ regenerate without full mission
./tools/neo-report.sh <project> ──▶ same
```

`[f]` only appears in **post** phase (when AI available).

Mission state transitions to `complete` after successful report generation (best-effort).

## Bundle contents

All curated sections (PORTS, SERVICES, BORG, PAYLOAD, WORKBENCH, privesc, flags, LESSONS, ELI5)
+ LOG tail (20k) + mission.json context + Borg skipped red herrings + disclosure AI rules.

## Section ownership

| Tag | Owner | Mode |
|-----|-------|------|
| `REPORT` | neo-report | set (replace on regenerate) |

## Future enhancements

- PDF/HTML export via pandoc
- Professional template with client logo placeholder
- Include `knowledge/library/` cross-refs in professional reports only
- Sign-off block (operator name, date) from engagement-scope.json

---

*See also: `BORG-RESEARCH-LIBRARY.md` (Phase 65), P13 engagement scope policy.*
