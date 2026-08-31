# P06 — Typed AI Actions and Safe Execution

**Status:** review_ready · **Priority:** P0 · **Depends:** P01, P05

## Problem

Borg and legacy payload paths parsed shell from AI text. OD-008 requires schema-validated
argv arrays with explicit policy and operator confirmation.

## Action document schema

`prototype/neo-next/schemas/action.schema.json`

| Field | Values |
|-------|--------|
| schema_version | 1 |
| id | slug |
| kind | manual \| local_command |
| risk | read_only \| state_change \| invasive |
| source | builtin \| operator \| ai |
| execution.mode | advisory \| approved_local |
| execution.argv | string array (no shell metachar interpretation) |
| execution.timeout_seconds | 1–3600 |

## Policy file

`schemas/action-policy.json` — `allowed_tools` array for AI-sourced commands only.

## Execution flow

```
action.json → validate (jq) → render → confirm (run / run-state-change)
           → timeout argv[@] → capture output → evidence record
```

**Banned:** eval, bash -c, sh -c, apt/yum/pip from AI source without manual kind.

## Prototype

`prototype/neo-next/lib/neo-actions.sh` — **complete**.

## v0.5 replacements

| File | Remove | Add |
|------|--------|-----|
| lib/neo-borg.sh | eval wind-up | neo_action_execute on JSON files |
| lib/neo-payload.sh | any execute loop | advisory action file emission |
| enumerators/*.sh | — | emit action JSON not shell |

## Confirmation UX

| risk | Required typing |
|------|-----------------|
| read_only | `run` |
| state_change, invasive | `run-state-change` |

## Acceptance

- `; rm -rf /` in argv[1] stays literal, does not chain
- Denied tool blocks even after confirm
- Advisory kind never executes
- Nonzero exit preserved in evidence

## Tests

`prototype/neo-next/test/action-enumerator-test.sh`
