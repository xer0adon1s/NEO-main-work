# P16 — Foothold and Session State Machine

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P06, P14

## Problem

Mission progress inferred from `project.meta phase` and filesystem accidents. Skipped
foothold, stale sessions, and invalid ordering are invisible.

## States

```
preflight → recon → operator_recon → triage → borg_offer
  → borg_assimilation (optional)
  → foothold_planning → foothold_attempt → session_established
  → post_foothold_enum → privesc_planning → privesc_attempt
  → privileged → post → complete
```

## Transition rules

- Invalid transition → stderr error, state unchanged (fail closed)
- `session_established` requires operator confirmation event from P02
- Session record: transport, user, host, shell_type, confirmed_at
- Stale session: if `updated_at` > NEO_SESSION_STALE_HOURS → flag reverification

## Storage

`~/.local/state/neo/projects/<project>/mission.json` — mode 600, atomic mv writes.

`mission.json` also references `scope_file` (engagement-scope.json from P13).
Recon and network scripts refuse to run if scope is missing on new projects.

## History

Append-only `history[]` in mission.json for audit.

## v0.5 bridge

- `meta_set phase` becomes derived from mission.state for backward compat
- `neo_checkpoint` reads mission.json state name
- neo.sh phase walk consults mission state before offering scripts

## Prototype

`prototype/neo-next/lib/neo-mission-state.sh` — **complete**.

## Acceptance

- Invalid transitions rejected
- Stale session marked in status output
- Resume loads state without assuming foothold from old meta alone

## Tests

`mission-state-test.sh`
