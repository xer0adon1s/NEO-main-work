# P02 — Interactive ListenAssist Workflow

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P14, P16

## Problem

v0.5 `foothold/ListenAssist.sh` is a 7-line placeholder (CS-001). Operators expect
listener guidance, separate-window commands, and session confirmation before foothold
advances.

## Target behavior

1. **Intake:** project, target, callback IP (auto-detect via `ip route get`), port,
   tool (ncat/nc/socat), mode (reverse/bind).
2. **Planning mode (default):** print exact argv for operator's listener pane; record
   plan to evidence; no listener launch.
3. **Optional `--start`:** detached tmux session only after `start-listener` typed.
4. **Session gate:** operator answers y/N/not-yet; never auto-advance mission state.
5. **Evidence:** foothold_plan artifact (JSON) + observation events.

## Prototype

`prototype/neo-next/foothold/ListenAssist.sh` — **complete for design phase**.

## Production integration (later)

| v0.5 file | Change |
|-----------|--------|
| `foothold/ListenAssist.sh` | Replace with prototype logic; source neo-evidence |
| `neo.sh` foothold phase | Call mission transition on session confirm |
| `registry.yaml` | Update owns: FOOTHOLD evidence events |
| `templates/investigation-notes.md` | FOOTHOLD section fed from evidence summary |

## Interface

```
ListenAssist.sh --project NAME --target HOST [--callback-ip IP] [--port PORT]
                [--tool ncat|nc|socat] [--mode reverse|bind] [--start]
```

## Mission state transitions (P16)

- `foothold_planning` → `foothold_attempt` when plan recorded
- `foothold_attempt` → `session_established` on operator y/yes
- `foothold_attempt` → `foothold_planning` on retry

## Acceptance mapping

| Criterion | Prototype evidence |
|-----------|-------------------|
| Invalid ports/names rejected | neo_core_valid_port, neo_core_require_project |
| Planning mode no launch | Default path; --start gated |
| start-listener deliberate | neo_core_confirm start-listener |
| Outcomes transition state | P16 hooks in integration plan |

## Tests (Linux lab)

- Invalid project name → exit 1
- Port 0, 99999 → exit 1
- Default run → plan JSON in evidence, no tmux
- `--start` without confirm → no session

## Non-goals

- Payload generation (operator reviews separately)
- Auto-exploit or reverse shell delivery
