# P03 — Post-Foothold Enumeration Transport and FindPrivs

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P14, P16

## Problem

`privesc/run-findprivs.sh` ingests a hard-coded smoke verdict (CS-002). Real workflow
must support open shells, optional SSH, and file paste without executing untrusted content.

## Target behavior

### Transport modes

| Mode | When | NEO action |
|------|------|------------|
| `existing-shell` | Operator already has shell in tmux pane | Print copy/paste instructions for `bash -s < FindPrivs.sh` |
| `ssh` | ssh_target in meta | Run wrapper: `ssh target 'bash -s' < FindPrivs.sh \| ingest` |
| `file-ingest` | Operator saved output | `notes-lib ingest` or evidence ingest from path |

### Safety rules

- Ingest path never `eval`s file contents
- SSH host validated (no spaces, no command injection in user@host)
- Raw output → artifact with SHA-256 before curated sections
- Smoke stub string rejected by production gate

## Prototype

`prototype/neo-next/privesc/run-findprivs.sh` — design skeleton with transport selection.

## Production integration

| File | Change |
|------|--------|
| `privesc/run-findprivs.sh` | Full wrapper per modes above |
| `privesc/FindPrivs.sh` | Unchanged on-target script |
| `lib/notes-lib.sh` | ingest map unchanged |
| `neo.sh` privesc phase | Require `session_established` state |

## Data flow

```
FindPrivs.sh stdout → neo_evidence_save_artifact → events.jsonl
                   → notes_ingest → WHOAMI/SUDO/SUID/...
                   → mission state post_foothold_enum
```

## Acceptance mapping

| Req | Design |
|-----|--------|
| 3a open-shell default | existing-shell mode first in menu |
| 3b copy/paste | Printed heredoc instructions |
| 3c file ingest | --from-file PATH |
| 3d raw + hash | neo_evidence_save_artifact |
| 3e observations vs findings | ingest maps to sections; AI separate |
| 3f refuse smoke stub | production-integrity-gate.sh |

## Tests

- Stub v0.5 file fails gate
- Prototype wrapper ≥30 lines with ssh|ingest|FindPrivs markers
- File ingest with `$(id)` in content stays inert
