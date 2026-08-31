# P07 — Operator-Supplied Recon Intake Before Borg

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P14

## Problem

Operators discover things outside NEO (browser, manual nmap, writeups). Today INTERACT
section handles pre-foothold web only. Borg needs structured operator observations with
source attribution before assimilation.

## Target behavior

1. **Interactive multiline:** `operator-recon.sh add --project X` — EOF-terminated input
2. **File ingest:** `--from-file PATH` — read-only, never executed
3. **Metadata:** source=operator, timestamp, project, target, confidence=operator_reported
4. **Secret redaction:** neo_secret_redact_text before storage
5. **Borg access:** observations included in evidence bundle by hash reference only

## Prototype

`prototype/neo-next/recon/operator-recon.sh`

## Evidence events

```json
{"type": "operator_observation", "source": "operator", "summary": "...", "artifact": "artifacts/operator-recon-<hash>.txt"}
```

## Safety

- Shell-like text (`$(...)`, backticks, `;`) stored as literal bytes
- Empty input rejected
- Append-only: multiple notes never overwrite

## v0.5 bridge

- Extends `lib/neo-interact.sh` pattern to general recon
- Writes to evidence JSONL + optional OPERATOR-RECON section in notes template

## Acceptance

- Injection payloads inert in storage
- Empty rejected
- Multiple entries preserved with distinct artifacts

## Tests

Part of `workflow-prototype-test.sh`
