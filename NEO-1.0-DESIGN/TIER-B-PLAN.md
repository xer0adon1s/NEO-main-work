# Tier B — AI Conductor Automation & Phase Intelligence

**Status:** Waves 1–3 **implemented** (v0.6); Waves 4–5 pending (disclosure lint all, P08 provider, Borg v2 JSON).  
**Builds on:** `AI-CONDUCTOR.md` (Tier A), `OPERATOR-WORKBENCH.md`, `WORKFLOW-MAP.md`  
**Version target:** v0.6 → v1.0-rc (Tier B is the bridge)

---

## Executive summary

Tier A made NEO **ask the right questions at the right time** — unified bundles, Y/n sequencing after triage, phase-entry hooks, pause nudges.

**Tier B makes NEO run the engagement loop for you** — still with human gates on every action that touches the target, but the operator stops hunting for menu letters. AI interprets evidence, proposes the next step, prepares the operator pane, and chains suggest → verify → try → analyze until the phase goal is met or the operator says stop.

> **Mechanical scripts collect. AI interprets. Conductor automates the loop. Operator approves execution.**

This is not “auto-hack the box.” It is **auto-conduct the mission** — the same way a good lead pentester would keep the junior on track without making them memorize which tool comes next.

---

## What Tier B is (and is not)

| Tier B **is** | Tier B **is not** |
|---------------|-------------------|
| Event-driven conductor chains after evidence arrives | Removing y/N before target interaction |
| AI-ranked enum/privesc plans replacing jq case tables | Replacing babysteps/FindPrivs with AI-only guessing |
| Adaptive scan targeting (AI picks deep enum focus) | Blind full-port scans on every box |
| Structured operator input → notes sections | Executing operator paste as shell |
| MSF module suggestions with operator-pane delivery | `msfconsole -j` auto-jobs from conductor pane |
| Full suggest→try→analyze automation **with gates** | Autopilot that runs exploits while you get coffee |
| Disclosure lint on **all** educational AI output | Only linting the final report |

**Safety invariant (unchanged, OD-008):** nothing hits the target without explicit operator approval. Conductor automation may auto-invoke **AI calls** and **local prep** (LOCK & LOAD, bundle build, plan JSON); execution stays in operator tmux pane B or typed `local_safe` argv.

---

## Architecture: three layers

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3 — CONDUCTOR AUTOMATION (Tier B focus)                  │
│  Playbooks, event hooks, auto-chains, mission DAG, mode profiles │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│  Layer 2 — AI INTERPRETATION (Tier B + existing)                │
│  Triage, Borg, payload, workbench analyze, privesc triage, enum  │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│  Layer 1 — MECHANICAL EVIDENCE (unchanged)                      │
│  babysteps, FindPrivs, linpeas, ListenAssist, notes ingest      │
└─────────────────────────────────────────────────────────────────┘
```

Tier A wired Layer 3 **lightly** (offers + nudges). Tier B wires Layer 3 **deeply** (playbooks that call Layer 2 repeatedly until a stop condition).

---

## Conductor automation — deep design

This is the centerpiece. The goal: **you approve direction once; NEO keeps the loop moving.**

### Automation spectrum

| Level | Name | Operator experience | Default |
|-------|------|---------------------|---------|
| **0** | Manual | Every AI step via pause letter | `ai_triage=manual` |
| **1** | Guided | Y/n at **every** step; teaches the loop | **`engagement_mode=educational`** |
| **2** | Assisted loop | Chains p→LOCK→t→analyze after loop consent; fewer gates | **`engagement_mode=professional`** |
| **3** | Aggressive loop | Auto-suggest after each analyze; one Y to enter loop | **deferred v1.1** — env falls back to assisted |
| **4** | Phase autopilot | Entire phase goal until success/skip | **not in Tier B** — 1.1+ |

**Engagement-driven default:** educational missions stay **guided** (slower, pedagogical). Professional missions default **assisted** (results-focused, large engagements). Operator can override per mission via `conductor_mode` in `project.meta` or a one-time picker at first loop entry.

Level 4 is explicitly out of scope: foothold success detection is too box-specific and too risky without constant human eyes.

### Conductor playbooks

A **playbook** is a named, phase-aware state machine stored in `mission.json` under `conductor`:

```json
{
  "conductor": {
    "mode": "assisted",
    "active_playbook": "foothold_loop",
    "playbook_state": "awaiting_try",
    "loop_count": 2,
    "last_command_hash": "sha256:…",
    "stopped_reason": null
  }
}
```

**Built-in playbooks (Tier B):**

| Playbook | Trigger | Steps (auto unless noted) | Stop when |
|----------|---------|---------------------------|-----------|
| `post_triage` | recon triage done | Borg? → payload suggest? | Operator declines or recon pause |
| `foothold_loop` | foothold phase + loop Y | suggest → LOCK&LOAD → try? → capture → analyze → repeat | session_established, operator `[c]`, max loops |
| `privesc_loop` | privesc enum ingested | privesc AI triage → ranked plan → suggest → try → analyze | privileged, decline, max loops |
| `enum_deepen` | speed scan + AI triage | AI picks 1–3 deep targets → materialize plan-enum actions → offer top N via workbench | actions exhausted or skip |
| `post_msf` | post phase entry | MSF context block → suggest post modules → try in pane | operator continues phase |
| `borg_library` | post-assimilate, no library entry | offer AI library research | entry created or skip |

Playbooks are **composable**: `post_triage` may hand off to `foothold_loop` at phase boundary without re-prompting if operator chose “yes to full foothold assistance.”

### Event bus (conductor hooks)

Today hooks are scattered (`neo_conductor_after_triage`, `neo_pipeline_*`, phase entry). Tier B centralizes on **`neo_conductor_on_event`**:

```
EVENT                    → DEFAULT PLAYBOOK / ACTION
─────────────────────────────────────────────────────
recon.triage_complete    → post_triage
recon.deep_requested     → enum_deepen (adaptive targets)
recon.interact_saved     → operator_recon_structure (AI)
foothold.phase_entry     → foothold_loop offer
foothold.try_complete    → analyze offer (if loop active)
foothold.analyze_done    → foothold_loop continue or nudge [c]
privesc.ingest_complete  → privesc_ai_triage → privesc_loop offer
privesc.try_complete     → analyze → re-rank plan
borg.assimilate_complete → library_hook? → payload suggest
workbench.analyze_fail   → diagnose (z-path) offer
post.phase_entry         → post_msf + report nudge
```

Implementation: thin dispatcher in `lib/neo-conductor.sh` calling existing modules — **no monolith**.

### The workbench loop (guided vs assisted)

**Loop entry (both modes):**

```
1. [NEO] Run workbench loop for <phase>? [Y/n]
2. [NEO] How many attempts before we pause for a full review? [5]
   → saved to mission.json conductor.max_loops (default 5; operator may enter any N)
```

**Guided** (`engagement_mode=educational` default) — separate Y at every step:

```
3. [NEO] Payload suggestion? [Y/n]  → AI → PAYLOAD
4. [NEO] LOCK & LOAD? [Y/n]
5. [NEO] Send to operator pane and run? [Y/n]  → pane B
6. [NEO] Press Enter when command finishes… → capture → artifact
7. [NEO] Analyze output? [Y/n] → WORKBENCH
8. Loop to 3 until success, cap, or operator stop
```

**Assisted** (`engagement_mode=professional` default) — fewer gates inside the loop:

```
3–7. Auto: suggest → LOCK & LOAD (Y/n once at loop start optional) → send to pane B
     → Enter when done → auto-analyze
8. Loop until success, cap, or operator stop
```

| Step | Guided | Assisted |
|------|--------|----------|
| Payload suggest | Y/n each iteration | Auto |
| LOCK & LOAD | Y/n each iteration | Y/n at loop start (or auto if operator chose) |
| Send to pane B | **Y/n each command** | Auto (loop consent covers try) |
| Analyze | Y/n each iteration | Auto (`NEO_CONDUCTOR_AUTO_ANALYZE=1`) |

**Key UX:** guided teaches the menu letters; assisted optimizes for speed on large pro engagements.

Pause menu letters **remain** for override: `[p]` mid-loop, `[o]` fix typo, `[z]` when stuck.

### Post-loop failure review (assisted + guided)

When the loop hits **max_loops** without phase success (no shell, no privesc, etc.), NEO runs a **batch failure review** — not just the last capture:

1. **Accumulated attempts** — every command + exit context from `WORKBENCH` / `PAYLOAD` this loop
2. **Per-try captures** — `artifacts/workbench-capture-*.txt` from each iteration
3. **tmux transcript** — `neo_tmux_capture_recent` on panes B (+ C handler when active); saved to `artifacts/terminal-log-<ts>.txt` (same path `[z]` diagnose failures uses today)
4. **AI intent `analyze-failures-batch`** — Claude reads the full bundle: “here’s everything we tried and what the terminals showed; recommend a concrete pivot”

Offer automatically in assisted mode at cap; in guided mode offer `[z]` with pre-built bundle. Operator can accept review, extend loop (“try 5 more?”), or `[c]` continue / change phase.

**Yes — Claude can review the tmux transcript.** NEO already captures scrollback for Analyze Failures; Tier B extends that to **all loop attempts + full session tail**, not one pane snapshot.

### Conductor modes (env + per-mission)

| Setting | Values | Meaning |
|---------|--------|---------|
| `NEO_CONDUCTOR` | `0`/`1` | Master switch (existing) |
| `NEO_CONDUCTOR_MODE` | `guided` / `assisted` / `aggressive` | How eagerly chains run |
| `NEO_CONDUCTOR_LOOP` | `0`/`1` | Allow multi-step playbooks |
| `NEO_CONDUCTOR_MAX_LOOPS` | `5` | Default cap; operator sets N at loop entry |
| `NEO_CONDUCTOR_AUTO_TRY` | guided `0`, assisted `1` | Auto-send to pane B |
| `NEO_CONDUCTOR_AUTO_ANALYZE` | guided `0`, assisted `1` | Auto-analyze after try |
| `NEO_CONDUCTOR_AUTO_ELIS5` | `0`/`1` | After suggest, offer ELI5 (existing pattern, default off) |

Persist per mission in `project.meta`:

```
conductor_mode=guided|assisted     # default from engagement_mode if unset
conductor_loop_enabled=1
conductor_max_loops=5              # set at loop entry prompt
```

Default `conductor_mode` from scope intake: **educational → guided**, **professional → assisted**. Optional override picker at first loop entry.

### Mission DAG integration

`mission.json` today tracks states (`triage`, `foothold_planning`, …) but Tier A only nudges. Tier B **drives transitions from playbook outcomes**:

| Playbook outcome | Mission transition |
|------------------|-------------------|
| `foothold_loop` session confirmed | `foothold_attempt` → `session_established` |
| `privesc_loop` root confirmed | `privesc_attempt` → `privileged` |
| `post_triage` Borg done | `borg_offer` → `borg_assimilation` or `foothold_planning` |
| Operator `[c]` from pause | playbook `stopped_reason=operator_continue` |

Conductor reads **and writes** mission state — still through `neo_mission_try_transition`, never bypassing the ledger.

### AI collaboration in automation

Every automated step uses **`neo_conductor_build_bundle(project, phase, intent)`** — no ad-hoc prompts. New intents for Tier B:

| Intent | Used by |
|--------|---------|
| `privesc-triage` | After FindPrivs/linpeas ingest |
| `enum-plan` | AI enum planner rank/review |
| `adaptive-scan` | Pick deep enum targets from speed scan |
| `operator-recon` | Structure INTERACT / free-text |
| `msf-suggest` | Post/aux/exploit module ranking |
| `conductor-next` | “What should the loop do next?” meta-step |
| `analyze-failures-batch` | Post-cap review of all loop attempts + tmux transcript |

**Subscription vs API:** automation respects `ai_triage` mode. `manual` → playbooks degrade to mechanical hooks only (enum plan JSON, privesc ranker) + pause nudges.

**Provider web research (`NEO_PROVIDER_WEB_RESEARCH=1`):** Tier B **design** includes capability flag; live web is Tier B wave 4 (depends on P08 adapter). Until then, Borg/library use `borg_research_index` + model knowledge — same as today.

### Feedback UX in loops

`neo-feedback.sh` acks apply to **every** automated step (“Suggesting…”, “Capturing pane…”, “Analyzing…”). Long AI calls keep the progress bar from `neo-ai-analyze.sh`. Operator never wonders if NEO froze.

---

## tmux & session architecture

**Rule 0:** Conductor pane A owns stdin for menus and Y/n prompts. **Anything that runs shell, ssh, msfconsole, listeners, or handlers runs in pane B** (or a dedicated child session — see below).

### Surface map

```
neo-<project> tmux session
┌──────────────────────────────┬──────────────────────────────┐
│ Pane A: neo-conductor        │ Pane B: neo-operator         │
│ neo.sh pause menus           │ bash — attack box commands   │
│ AI HUD / feedback            │ ssh, curl, msfconsole, etc.  │
│ NEVER: send-keys exploit     │ [t]ry targets this pane      │
└──────────────────────────────┴──────────────────────────────┘

┌──────────────────────────────┐
│ Pane C: neo-handler          │  ListenAssist / msf handler (REQUIRED wave 3)
│ titled neo-handler           │  visible callback pickup + live activity
└──────────────────────────────┘
```

**Pane C rationale (locked):** operators must **see** the listener pick up connections while running curl/exploit commands in pane B — always-on visual feedback beats a hidden background job.

### Session rules by activity

| Activity | Where it runs | Tier B automation |
|----------|---------------|-------------------|
| babysteps, analyze-recon | attack box shell (conductor invokes) | OK from pane A spawn |
| AI triage/Borg/payload | conductor (no target IO) | Auto |
| `[t]` workbench command | **pane B** via `neo_operator_pane_send_command` | Auto in loop |
| `msfconsole` interactive | **pane B** (preferred) or pane C | Suggest in A, run in B/C |
| `msfconsole -q -x '...; exit'` one-shot | pane B | Auto-try candidate |
| Reverse shell listener | **pane C** or B | ListenAssist creates pane C |
| SSH to target | pane B | Session adapter records `user@host` |
| Foreign tmux (OpenVPN) | switch-client to `neo-<project>` | Existing Phase 57 behavior |

### Session adapter (Tier 4.5 → Tier B wave 3)

Extend `lib/neo-operator-pane.sh` + `neo-mission-state.sh`:

```json
"session": {
  "transport": "ssh|msf_meterpreter|msf_shell|raw_tcp",
  "ssh_target": "user@10.10.11.1",
  "msf_session_id": 3,
  "handler": { "pane": "%2", "lhost": "10.10.14.5", "lport": 4444 },
  "operator_pane": "%1"
}
```

Conductor loop **before try** asks: “Run in operator pane as-is?” vs “Prefix with ssh wrapper?” when `session.transport=ssh`.

**MSF handler visibility:** long-running handlers must not block conductor stdin. Tier B: `neo_handler_pane_ensure` splits pane C, starts listener, returns control to A. Capture for analyze uses handler pane + operator pane tails.

### tmux requirements checklist

- [ ] `NEO_TMUX_WRAP=1` on interactive missions (warn loudly if 0)
- [ ] `[o]` creates pane B if missing (existing)
- [ ] Automated `[t]` always calls `neo_operator_pane_ensure` first
- [ ] Analyze failures merges pane B + optional pane C capture
- [ ] Env forward list includes new `NEO_CONDUCTOR_*` vars (`NEO_TMUX_ENV_FORWARD`)
- [ ] Tests: fake tmux via `script` + pane title grep (extend integration test)

---

## Per-phase workflow (Tier B target)

### Connect (unchanged mechanical; conductor minimal)

VPN ritual stays boot-only. Conductor: none (or future “lab reachable?” ping offer).

### Recon

```
babysteps (speed) → notes
    → AI triage [auto]
    → conductor post_triage [Borg?, payload?]
    → adaptive enum offer: AI picks ports/services for deep work
        → plan-enum materialize OR AI enum planner actions
    → operator interact check-in (web) [existing]
    → operator-recon structurer if free text saved
    → pause: assisted enum loop can run top 3 actions via workbench
    → [c] → foothold
```

**Adaptive babysteps:** AI reads PORTS + triage; outputs JSON `deep_targets: [{port, proto, reason}]`. Conductor passes to `babysteps --deep --ports=...` or spawns targeted nmap scripts — **not** full `-p-` by default.

### Foothold

```
phase entry → foothold_loop offer [Y/n]
    → ListenAssist handler pane if needed
    → loop until session_established
pre-foothold interact already done at recon handoff
```

### Privesc

```
run-findprivs → ingest → privesc AI triage [auto]
    → PRIVESC-PLAN section (AI prose + structured JSON artifact)
    → privesc_loop offer
    → ranker validates AI didn't overclaim (deterministic floor)
```

### Post

```
phase entry → post_msf playbook
    → loot/flag prompts
    → [f] report offer (existing)
```

---

## Tier B feature catalog

Each item: **problem → design → files → tests → wave**

### B1 — Conductor automation core

**Problem:** Operator must choreograph `[p]`/`[t]`/analyze manually.  
**Design:** Playbooks, event bus, assisted loop, mission.json conductor block, mode profiles.  
**Files:** `lib/neo-conductor.sh` (major), `lib/neo-workbench.sh` (loop glue), `neo.sh` (event emitters), `lib/neo-mission-state.sh`  
**Tests:** `test/conductor-automation-test.sh` — mock TTY, assert playbook state transitions  
**Wave:** **1 (first)** — unlocks value for all other items

### B2 — AI privesc triage

**Problem:** Raw SUDO/SUID walls after FindPrivs; jq ranker has no narrative context.  
**Design:** After ingest, mechanical pipeline still runs: normalize → `privesc-facts.json` → **`rank-privesc-plan.sh` (jq)**. Operator sees **AI triage only** in notes (**PRIVESC-PLAN** + **AI-TRIAGE** append) — but the AI bundle **must include full jq ranker output + privesc-facts.json** so the model grounds on every mechanical finding. No side-by-side UI for jq vs AI.  
**Files:** `lib/neo-conductor-privesc.sh` (or section in conductor), prompt template, `templates/investigation-notes.md` (PRIVESC-PLAN markers)  
**Tests:** fixture FindPrivs → jq rank in bundle → mock AI → section parse  
**Wave:** 2

### B3 — AI enum planner

**Problem:** `plan-enum.sh` case statement is brittle; can't prioritize from triage narrative.  
**Design:** Hybrid — mechanical planners emit **candidate** actions; AI ranks/filters/adds advisory actions into `enum-plans/actions/*.json` with `"source":"ai"`. Review via `review-plan.sh` or conductor `enum_deepen` playbook. **No packets during planning.**  
**Files:** `lib/neo-enum-ai.sh`, hook in `neo-pipeline-hooks.sh`, extend `recon/plan-enum.sh` consumer  
**Tests:** fixture PORTS+SERVICES+triage → ranked JSON list  
**Wave:** 2

### B4 — Adaptive babysteps

**Problem:** Speed scan misses; blind deep scan wastes 20+ minutes.  
**Design:** Post-triage, AI outputs `deep_targets`; conductor offers “Run targeted deep enum? [Y/n]” → babysteps flag or wrapper script.  
**Files:** `recon/babysteps.sh` (`--targets-file`), `lib/neo-conductor.sh`  
**Tests:** mock targets file → babysteps dry-run args  
**Wave:** 3

### B5 — Operator-recon structurer

**Problem:** INTERACT free text stays unstructured; Borg bundle wastes tokens.  
**Design:** On save (interact or `operator-recon` intake), AI maps to TODO, SERVICES hints, ATTACKPATH bullets — **append only**, never overwrite operator sections.  
**Files:** extend `lib/neo-interact.sh`, intent `operator-recon`  
**Tests:** injection payloads inert; structured output in notes  
**Wave:** 3

### B6 — MSF AI module suggest

**Problem:** Static `neo_pipeline_offer_msf_post` catalog.  
**Design:** intent `msf-suggest` with `neo_msf_ai_context_block`; AI emits module paths + exact `msfconsole -x` or interactive steps; workbench `[t]` sends to pane B.  
**Files:** `lib/neo-exploit-framework.sh`, `lib/neo-pipeline-hooks.sh`, payload prompt MSF section  
**Tests:** `test/exploit-framework-test.sh` expansion  
**Wave:** 3 (parallel with session adapter)

### B7 — Post-assimilate library hook

**Problem:** Vectors assimilated but library empty — missed research moment.  
**Design:** `borg.assimilate_complete` → check `knowledge/library/<topic>` → offer `neo_borg_library_ai_research`  
**Files:** `lib/neo-borg.sh`, existing `neo-borg-library-ai.sh`  
**Tests:** `test/borg-library-ai-test.sh` scenario  
**Wave:** 2

### B8 — Post-AI disclosure lint (all surfaces)

**Problem:** Educational report hard-fails; triage/Borg/payload/ELI5 can leak walkthrough spoilers.  
**Design:** `neo_borg_disclosure_lint_text` on every AI append when `engagement_mode=educational`; warn + redact or block save (configurable strictness).  
**Files:** `lib/neo-borg-disclosure.sh`, call sites in AI runners  
**Tests:** fixture spoiler text → lint fail  
**Wave:** 4

### B9 — Borg live web research

**Problem:** Model may hallucinate CVE details without fresh sources.  
**Design:** P08 `neo_provider_capability web_research`; when enabled, provider fetches from `borg_research_index` URLs; Claude synthesizes — **no** mechanical HTML strip pipeline as primary.  
**Files:** `lib/neo-provider.sh` (migrate from prototype), Borg bundle header  
**Tests:** mock provider capability off → graceful degrade  
**Wave:** 4 (depends P08 migration)

### B10 — Borg v2 structured JSON pipeline

**Problem:** Dossiers are prose; hard to validate/automate.  
**Design:** AI emits `dossier.json` matching schema (facts/hypotheses/unknowns/actions); validate before BORG append; wind-up reads typed actions only.  
**Files:** `schemas/borg-dossier.schema.json`, `lib/neo-borg.sh`  
**Tests:** schema validation fixtures  
**Wave:** 5

### B11 — Batch library harvest

**Problem:** Manual one-off library research.  
**Design:** Queue from assimilated slugs; `tools/borg-library-harvest.sh --batch` overnight; conductor not required.  
**Files:** harvest tool, `knowledge/library/INDEX.yaml`  
**Tests:** dry-run queue  
**Wave:** 5

### B12 — Lab E2E validation (P18)

**Problem:** No confidence on real HTB flow with automation.  
**Design:** 3-box harness script; documents conductor loop on live lab.  
**Blocks:** 1.0.0-rc tag, not Tier B architecture.  
**Wave:** parallel track on home Linux

---

## Implementation waves (recommended order)

```
Wave 1 — Conductor automation core (B1)
    ↓
Wave 2 — Intelligence on evidence (B2, B3, B7)
    ↓
Wave 3 — Targeted execution + MSF (B4, B5, B6, session adapter)
    ↓
Wave 4 — Safety + provider (B8, B9, P08 adapter migration)
    ↓
Wave 5 — Structure at scale (B10, B11)
    ║
    ╚══ P18 lab E2E (B12) anytime after Wave 1 on Linux
```

**Estimated touch:** ~15–25 sessions for Waves 1–4 to reach “feels like AI conducts the box”; Wave 5 is polish for 1.0.

### Wave 1 deliverables (MVP automation)

1. `neo_conductor_on_event` dispatcher
2. `foothold_loop` playbook end-to-end
3. `NEO_CONDUCTOR_MODE=assisted` + meta persistence
4. Mission.json `conductor` block + loop caps
5. `test/conductor-automation-test.sh`
6. Doc update in `AI-CONDUCTOR.md` → “Tier B implemented”

**Operator-visible win:** foothold phase feels like pair-programming with AI.

---

## What stays mechanical

| Component | Why keep it |
|-----------|-------------|
| babysteps port scan | Repeatable, auditable, fast |
| FindPrivs / linpeas | Ground truth for privesc facts |
| notes-lib section markers | Human edits must survive |
| jq rank-privesc-plan | Mechanical input to AI privesc triage (not shown separately) |
| plan-enum case planners | Baseline candidates without API cost |
| WIND-UP y/N on Borg actions | Safety |
| LOCK & LOAD | Tooling truth on attack box |

AI **sits on top** — never replaces evidence capture.

---

## Testing strategy

| Layer | Tests |
|-------|-------|
| Playbook state | `conductor-automation-test.sh` — mock inputs, assert JSON state |
| Event dispatch | table-driven: event → handler called |
| Loop cap | N+1 iteration stops; batch failure review at cap |
| Post-loop review | tmux B+C capture + all workbench artifacts in bundle |
| tmux | extend `neo-tmux-integration-test.sh` — pane B send_keys |
| Privesc/enum AI | fixture notes → mock AI stdout → section ingest |
| Disclosure | spoiler strings blocked in educational mode |
| Regression | `./test/neo-diagnostic.sh` + full unit count after each wave |
| E2E | P18 manual on Linux — one box per wave milestone |

**CI constraint:** Windows dev machine cannot run tmux tests; Linux lab is source of truth before merge.

---

## Configuration summary (Tier B additions)

| Env | Default | Meaning |
|-----|---------|---------|
| `NEO_CONDUCTOR_MODE` | from `engagement_mode` | educational→guided, professional→assisted |
| `NEO_CONDUCTOR_LOOP` | `1` | Enable multi-step playbooks |
| `NEO_CONDUCTOR_MAX_LOOPS` | `5` | Default; operator sets N at loop entry |
| `NEO_CONDUCTOR_AUTO_TRY` | guided `0`, assisted `1` | Auto-send to pane B |
| `NEO_CONDUCTOR_AUTO_ANALYZE` | guided `0`, assisted `1` | Auto-analyze after try |
| `NEO_PROVIDER_WEB_RESEARCH` | `0` | Live web (wave 4) |
| `NEO_DISCLOSURE_LINT_ALL` | `1` | Lint all AI outputs (educational) |

---

## Resolved decisions (operator, 2026-08-31)

| # | Decision | Resolution |
|---|----------|------------|
| 1 | Default conductor mode | **Educational → guided** (pedagogical). **Professional → assisted** (speed, large engagements). |
| 2 | Y/n granularity | **Guided:** separate Y every step. **Assisted:** automate inside loop; at cap run **batch failure review** (all attempts + tmux B/C transcript via `analyze-failures-batch`). |
| 3 | Loop cap | **Default 5**; prompt at loop entry: *“How many attempts?”* — variable N stored in `mission.json`. |
| 4 | Privesc display | **AI triage only** in notes; jq ranker + `privesc-facts.json` are **bundle inputs**, not operator-facing duplicate lists. |
| 5 | Handler pane C | **Yes — required.** Listener visible for callback pickup and live activity while pane B runs commands. |
| 6 | Enum AI vs mechanical | **Never remove** mechanical `actions/*.json`; AI **ranks + may add** advisory entries only. Sidecar `ranked-order.md` for operator review. |
| 7 | Aggressive conductor mode | **Deferred to v1.1.** `NEO_CONDUCTOR_MODE=aggressive` falls back to **assisted** with stderr notice. |
| 8 | P08 provider migration | **Automation + disclosure ship first** (Waves 1–3). Full `neo-provider.sh` adapter migration is **Wave 4** — not a blocker for conductor loop. |

---

## Success criteria (Tier B done)

- [ ] Operator can enter foothold phase, accept one “assisted loop” prompt, and reach analyze/suggest cycles with **no manual `[p]`/`[t]`** unless they choose to override
- [ ] Privesc enum triggers AI triage + ranked plan without operator asking
- [ ] Adaptive deep enum runs **targeted** scans, not full deep by default
- [ ] MSF suggestions land in operator pane with LOCK & LOAD
- [ ] All automated execution respects tmux pane separation
- [ ] Educational missions lint AI output before notes append
- [ ] `neo-diagnostic.sh` green; unit tests +30 over Tier A baseline
- [ ] P18 documents at least one full box driven primarily by conductor automation

---

## Related docs

| Doc | Role |
|-----|------|
| `AI-CONDUCTOR.md` | Tier A spec (update when B1 lands) |
| `OPERATOR-WORKBENCH.md` | Pane model + loop semantics |
| `projects/17-privesc-workflow/DESIGN.md` | B2 alignment |
| `projects/15-service-enumeration/DESIGN.md` | B3 alignment |
| `projects/21-exploit-framework-conductor/DESIGN.md` | B6 alignment |
| `projects/08-ai-provider-interface/DESIGN.md` | B9 adapter |
| `HARD-CODE-BACKLOG.md` | Track Tier B IDs after approval |

---

## Next step

Decisions locked. Implementation starts with **Wave 1 — conductor automation core**: engagement-mode defaults, loop entry + variable N, guided vs assisted gates, post-cap batch failure review (`foothold_loop` first).
