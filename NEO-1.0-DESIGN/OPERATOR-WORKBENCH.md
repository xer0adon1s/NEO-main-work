# Operator Workbench — NEO 1.0 Core Loop

This document is the **product definition** for NEO's primary operator experience.

**Scope:** The workbench loop is **phase-universal** — recon, exploit/foothold, privesc,
and post all use the same `[p]` → LOCK & LOAD → `[t]` → analyze cycle. See
`MISSION-STATEMENT.md` (end-to-end Metasploit-class conduction).

## Why this exists

NEO is not a scanner that dumps a report. It is a **conductor** for the **full engagement**:

1. Runs enum and collects leads
2. Feeds context to AI and Borg
3. Produces **actionable commands**
4. **Executes them with operator permission** in the right place
5. **Interprets output** and suggests the next step
6. Repeats until the **current phase goal** is met → continues pipeline
7. Covers **Metasploit + peer tools** — msfconsole/msfvenom are first-class (P21)

Without a dedicated execution surface, step 4 fails — the conductor pane cannot run shell
commands while displaying pause menus.

## Operator surfaces

```
┌─────────────────────────┬─────────────────────────┐
│  Pane A: NEO conductor  │  Pane B: neo-operator   │
│  pause menus, AI HUD    │  ssh, curl, msf, etc.   │
│  [p] [t] [z] [c]        │  commands land here     │
└─────────────────────────┴─────────────────────────┘
         neo-<project> tmux session
```

Launch NEO normally (tmux auto-wrap). Use **`[o]perator shell`** once if the right pane
is missing.

## Typical foothold session

1. Recon completes → AI triage + optional Borg
2. **`[p]ayload suggest`** → pick tool → get `## Exact next command`
3. **`[t]ry`** → confirm → command runs in pane B (or attack box if safe)
4. Press Enter when done → capture → **Analyze? Y**
5. Read brief → **`[t]ry`** again with new command
6. When analysis says foothold likely → confirm → **`[c]ontinue`**

## Integration map

| Existing | Workbench role |
|----------|----------------|
| `neo-tmux.sh` wrap | Ensures session exists for pane split |
| `neo-payload.sh` | Suggest + analyze prompts; shares AI runner |
| `neo-borg.sh` wind-up | Borg local steps still use typed actions; remote via `[t]` |
| `neo-mission-state.sh` | Tracks foothold_attempt → session_established |
| `Investigation-Notes.md` | WORKBENCH + PAYLOAD sections |

## Configuration

| Env | Default | Meaning |
|-----|---------|---------|
| `NEO_TMUX_WRAP` | `1` | Must stay on for operator pane |
| `NEO_OPERATOR_SPLIT_PCT` | `45` | Width of operator pane |
| `NEO_WORKBENCH_CAPTURE_LINES` | `300` | Scrollback lines after try |

## LOCK & LOAD (`lib/neo-toolkit.sh`)

After **[p]ayload suggest**, AI triage, or workbench analyze, NEO asks:

> Verify tools & wordlists for this suggestion? **[Y/n]**

If yes, it checks:

- Binaries on PATH (`gobuster`, `ffuf`, …)
- `[TOOL:name]` tags in AI output
- File paths in suggested commands (`-w`, `--wordlist`, `/usr/share/seclists/...`)
- `vendor/` tools via `./setup.sh`

Missing items can be fixed with your permission (pacman/apt, SecLists clone, `./setup.sh`).

Before **[t]ry**, the same check is offered (default **Y**).

## Related design

- P16 Foothold/session state machine
- P06 Safe action execution
- P20 project folder: `projects/20-operator-workbench/DESIGN.md`
