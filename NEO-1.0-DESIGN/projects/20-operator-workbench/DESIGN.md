# P20 — Operator Workbench (Core Use Loop)

**Status:** in_progress · **Priority:** P0 · **Depends:** P06, P08, P16

## Problem

NEO's pause menu owns stdin in the conductor pane. Operators paste AI-suggested commands
into that same terminal and nothing runs — the menu is waiting for `[c]`/`[p]`/`[t]`, not
a shell. The **core product loop** was advisory-only: suggest → copy/paste manually →
maybe analyze failures later. That breaks the intended workflow.

## Core loop (foothold-first, extensible)

```
Enum → leads in notes
  → AI triage / Borg / [p]ayload suggest → usable command ideas
  → [t] try (permission gate) → execute in operator pane OR safe local argv
  → capture output → AI interprets → next command in notes
  → repeat until foothold confirmed → mission → session_established → resume pipeline
```

Same loop applies on **recon** (probe leads) and **privesc** (elevation attempts).

## Architecture

| Module | Role |
|--------|------|
| `lib/neo-operator-pane.sh` | tmux split, pane title `neo-operator`, send-keys, capture |
| `lib/neo-workbench.sh` | try/analyze orchestration, attempt JSON, mission hooks |
| `lib/neo-payload.sh` | AI suggest + failure analyze (unchanged API; widened `[z]` gate) |
| `lib/neo-windup-actions.sh` | `local_safe` transport — argv execution, no eval |
| `lib/neo-mission-state.sh` | `foothold_planning` → `foothold_attempt` → `session_established` |

## Pause menu letters

| Letter | Action | Phases |
|--------|--------|--------|
| `[p]` | Payload suggest (tool picker → exact command) | recon, foothold, privesc |
| `[t]` | Try last/suggested command with permission | recon, foothold, privesc |
| `[o]` | Open/focus operator shell pane | recon, foothold, privesc |
| `[z]` | Analyze failures / workbench output | foothold after first attempt |

Routing: `neo_menu_classify()` → `neo_workbench_handle_choice()` / `neo_payload_handle_choice()`.

## Transport classification

| Class | When | Execution |
|-------|------|-----------|
| `local_safe` | No shell metacharacters; single-line | `neo_windup_execute_safe` + double confirm |
| `operator_pane` | SSH, pipes, multi-line, listeners | `tmux send-keys` to operator pane |
| `manual_only` | Browser / physical steps | Print command; operator acts alone |

## State storage

- Attempts: `~/.local/state/neo/projects/<project>/workbench/attempts/<id>.json`
- Schema: `schemas/workbench-attempt.schema.json`
- Notes: `WORKBENCH` section (human log) + `PAYLOAD` (AI next steps)

## Permission model

1. Show command + transport
2. `[y/N]` execute
3. For `local_safe`: second confirm (attack-box argv)
4. For `operator_pane`: send-keys; operator presses Enter when done → capture
5. Optional immediate analyze `[Y/n]`
6. Foothold: if AI returns `FOOTHOLD_LIKELY`, offer mission advance

## Mission state hooks

- First `[t]` in foothold while `foothold_planning` → `foothold_attempt`
- Operator confirms foothold after analysis → `session_established` + append `FOOTHOLD`
- Pipeline `[c]ontinue` resumes post-foothold enum as today

## Future (not P20)

- Auto-SSH operator pane when `ssh_target` known and shell up
- Session adapter: switch operator pane transport after reverse shell
- GUI 2.0 event stream for workbench attempts

## Tests

- `test/workbench-test.sh` — extract, classify, menu letters, attempt JSON (offline)
- `test/menu-routing-test.sh` — `[t]`/`[o]` routing
- Lab: full tmux try → capture → analyze E2E (P18)

## Acceptance

- Operator never needs to paste into the conductor pane
- Every try leaves artifact + structured attempt record
- AI analysis produces next `## Exact next command` in notes
- Foothold loop exits cleanly into existing pipeline
