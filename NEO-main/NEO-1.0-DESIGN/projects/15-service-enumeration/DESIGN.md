# P15 — Service-Specific Enumeration Framework

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P06, P14

## Problem

babysteps embeds ad hoc HTTP/FTP/SMB logic. 1.0 needs normalized services → reviewable
enumeration plans → typed actions.

## Service normalization

`schemas/service.schema.json`:

```json
{"host": "10.10.11.1", "port": 80, "protocol": "tcp", "name": "http", "product": "Apache", "version": "2.4.49"}
```

Input: babysteps NMAP/SERVICES sections or rustscan output parser.

## Planners

| Script | Services | Output |
|--------|----------|--------|
| plan-enum.sh | All discovered | action JSON files per check |
| review-plan.sh | Operator | Sorted plan display |

Built-in planners: HTTP/HTTPS, SSH, SMB, FTP, DNS, generic fallback.

## Planning rules

- Planners are deterministic (no AI required for baseline)
- AI may suggest additional checks as advisory actions only
- Unknown service → generic banner/title probe plan
- **No network activity during planning phase**

## Execution path

```
plan-enum.sh → actions/http-001.json → neo_action_execute (operator confirm)
            → results → service-finding JSON → evidence
```

## Prototype

- `enumerators/plan-enum.sh`
- `enumerators/review-plan.sh`
- `schemas/service.schema.json`

## v0.5 bridge

Optional post-babysteps hook: `neo_enum_plan_from_notes PROJECT`

## Acceptance

- Unknown service gets safe generic plan
- Planning emits no packets
- Execution goes through P06

## Tests

`action-enumerator-test.sh`
