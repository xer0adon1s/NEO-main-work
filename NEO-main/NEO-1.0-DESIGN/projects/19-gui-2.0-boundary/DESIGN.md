# P19 — GUI 2.0 Boundary and API Readiness

**Status:** review_ready · **Priority:** P3 · **Depends:** P08, P14, P16, P18

## Goal

NEO 2.0 GUI consumes the same domain services as CLI. No business logic trapped in
terminal prompts or AI prose strings.

## Layer separation

```
┌─────────────────────────────────────┐
│  Presentation (CLI today, GUI 2.0)  │
├─────────────────────────────────────┤
│  Application services               │
│  - MissionService (P16)             │
│  - EvidenceService (P14)            │
│  - ActionService (P06)              │
│  - ProviderService (P08)            │
│  - BorgService (P04)                │
├─────────────────────────────────────┤
│  Domain state + schemas             │
├─────────────────────────────────────┤
│  Infrastructure (secrets, fs, vpn)  │
└─────────────────────────────────────┘
```

## CLI as thin client

neo.sh becomes:
- Parse argv → call MissionService
- Render menus from structured Prompt objects
- Never embed phase rules in echo strings alone

## Structured events (19c)

Replace terminal scraping with event stream:

```json
{"event": "phase_changed", "from": "recon", "to": "foothold_planning"}
{"event": "approval_required", "prompt_id": "uuid", "action_id": "http-001", "expires_at": "..."}
```

## Long-running operations (19b)

| Field | Purpose |
|-------|---------|
| operation_id | UUID |
| status | pending/running/succeeded/failed/cancelled |
| progress | 0-100 or step name |
| cancel_token | Cooperative cancel |

## Credentials (19e)

GUI never receives raw API keys. Backend broker only. UI gets `has_anthropic_key: true`.

## Versioning (19f)

- mission.json schema_version
- dossier schema_version
- action schema_version
- Migration functions per bump

## 1.0 prep work (this phase)

- Document service boundaries in INTEGRATION-PLAN.md
- Ensure all state in JSON files under ~/.local/state/neo
- No new GUI code in 1.0

## Acceptance

- Every workflow step reachable via JSON API shape (documented)
- No rule exists only in read -p string

## Future repo

`neo-gui/` separate package importing domain libs or REST shim.
