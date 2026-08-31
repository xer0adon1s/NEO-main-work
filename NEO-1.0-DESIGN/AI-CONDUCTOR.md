# AI Conductor — NEO proactive orchestration

**Status:** Tier A implemented (v0.5+).  
**Related:** `MISSION-STATEMENT.md`, `OPERATOR-WORKBENCH.md`, `projects/08-ai-provider-interface/DESIGN.md`

---

## Problem

NEO has strong **advisory AI** at pause menus (`[a]`/`[b]`/`[p]`/`[t]`/`[e]`/`[f]`), but the operator must remember which letter to press and when. The mission state machine (`mission.json`) tracks phases like `borg_offer` and `foothold_planning` but does not **drive** behavior.

Result: AI feels like a feature menu, not a conductor.

---

## Design principle

> **Mechanical scripts collect evidence. AI interprets and recommends. The operator approves execution. Every phase transition should default to the next AI step unless skipped.**

This does **not** change the wind-up safety model (OD-008): nothing auto-executes.

---

## Three pillars (Tier A)

### 1. Unified mission bundle

`neo_conductor_build_bundle(project, phase, intent)` — one canonical snapshot of what NEO knows:

| Section | Source |
|---------|--------|
| Meta | project, target, phase, scan_mode, engagement_mode |
| Mission state | `mission.json` via `neo_mission_context_block` |
| Case file | STATUS, PORTS, NMAP, SERVICES, TODO |
| AI history | AI-TRIAGE, BORG, PAYLOAD, WORKBENCH (trimmed) |
| Operator notes | ATTACKPATH, FOOTHOLD, INTERACT |
| Privesc | WHOAMI, SUDO (when present) |
| MSF | `neo_msf_ai_context_block` (phase-aware) |
| Disclosure | `neo_borg_disclosure_ai_rules` |

**Intents** add headers and extra slices:

| Intent | Used by |
|--------|---------|
| `triage` | `analyze-recon`, recon bundle |
| `payload` | `[p]` suggest, failure analysis |
| `borg` | `[b]` assimilate (vector appended by caller) |
| `workbench` | `[t]` analyze output |
| `report` | `[f]` final report |
| `eli5` | `[e]` tutor |
| `ask` | `[a]` free-text question |

All existing `neo_*_build_bundle` functions delegate to the conductor core (no drift).

### 2. Conductor sequencing

After evidence events, NEO chains **Y/n prompts** (default **Y**):

```
recon triage complete
  → Assimilate pending vectors with Borg? [Y/n]
  → [p] Payload suggestion? [Y/n]  (Borg-guided when dossiers exist)
```

Borg assimilate complete already offers payload suggest (`neo_payload_offer_after_borg`); conductor coordinates so triage → Borg → payload is one guided path.

**Disable:** `NEO_CONDUCTOR=0` or non-interactive / `NEO_TEST_NONINTERACTIVE=1`.

### 3. Mission-state AI hooks

On phase entry (`walk_phase` after `neo_mission_sync_pipeline_phase`):

| Phase | Conductor action |
|-------|------------------|
| **foothold** | Pending Borg vectors? → offer assimilate. Then offer payload suggest. |
| **privesc** | Offer payload suggest (privesc-focused). |
| **post** | Nudge toward `[f]` final report. |

Recon pause menu shows a **one-line nudge** (recommended letter) without duplicate Y/n if conductor already ran after triage.

---

## Configuration

| Env | Default | Meaning |
|-----|---------|---------|
| `NEO_CONDUCTOR` | `1` | Proactive Y/n sequencing + phase hooks |
| `NEO_AI` / `ai_triage=manual` | — | Conductor skips when AI disabled |
| `NEO_TEST_NONINTERACTIVE` | `0` | Skips all conductor prompts |

## Pause letters (aligned with conductor nudges)

| Letter | Label in menu | What it does |
|--------|---------------|--------------|
| `b` | Borg research | AI assimilates attack-vector dossiers |
| `p` | payload suggestion | AI writes exact next command |
| `a` | ask AI | Free-text question + notes context |
| `t` | try it | Run suggested command in operator pane |
| `o` | operator pane | Focus tmux shell pane |
| `z` | diagnose failure | AI reviews failed foothold attempts |
| `e` | explain (ELI5) | Teach flags/evidence before you run |
| `f` | write report | Final mission report (post) |
| `s` | skip to step | Jump pipeline phase (not “suggest”) |

Full legend: `neo_menu_letter_legend` in `lib/neo-menu.sh`.

## Conductor defaults (tuned)

| Moment | Borg `[b]` | Suggest `[p]` |
|--------|--------------|---------------|
| After recon triage | Y/n if pending vectors | **n** (use pause menu `[p]`) |
| Foothold phase entry | Y/n if still pending | **Y** if not done this phase |
| Privesc phase entry | — | **Y** if not done this phase |

Conductor Y/n prompts name the matching pause letter so operator learns the mapping.

## What stays mechanical

- babysteps, FindPrivs, linpeas, ListenAssist (evidence capture)
- Wind-up y/N before any `[RUN:]` / typed argv
- Operator workbench execution in tmux pane B
- Disclosure lint hard-fail on educational report

---

## Tier B+ (partial — v0.6)

**Implemented (Wave 1–2 core):**
- Workbench automation loop (`lib/neo-conductor-loop.sh`) — guided vs assisted by `engagement_mode`
- Variable attempt cap (default 5) + batch failure review (`analyze-failures-batch`)
- AI privesc triage (`lib/neo-conductor-privesc.sh`) — jq ranker feeds bundle; operator sees **PRIVESC-PLAN** only
- Handler pane C (`lib/neo-handler-pane.sh`) for visible listeners
- Borg post-assimilate library research hook
- `neo_conductor_on_event` dispatcher

**Still planned:** adaptive babysteps, AI enum planner rank, provider web research, Borg v2 JSON.

See `NEO-1.0-DESIGN/TIER-B-PLAN.md`.

---

## Implementation map

| File | Role |
|------|------|
| `lib/neo-conductor.sh` | Bundle core, sequencing, phase hooks, nudges |
| `lib/neo-ai.sh` | `neo_ai_build_recon_bundle` → conductor |
| `lib/neo-payload.sh` | `neo_payload_build_bundle` → conductor |
| `lib/neo-borg.sh` | Borg bundle uses conductor core |
| `lib/neo-ai-cli.sh` | `neo_ai_finish_triage_run` → `neo_conductor_after_triage` |
| `neo.sh` | Phase entry hooks, pause nudge, lib load |
| `test/conductor-test.sh` | Offline bundle + gate tests |
