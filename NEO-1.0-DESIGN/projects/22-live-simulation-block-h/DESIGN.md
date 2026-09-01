# P22 — LIVE SIMULATION: Block H

**Codename:** `SIM-H` · **Priority:** P1 · **Gate:** post–Phase 74 offline verify  
**Status:** `review_ready` — run when VPN + target are ready  
**Depends:** P18 (E2E), P20 (workbench), offline green (`linux-phase1-verify.sh` 6/6)

---

```
╔══════════════════════════════════════════════════════════════════╗
║  N E O   L I V E   F I R E   S I M U L A T I O N   —   B L O C K   H  ║
║  Authorized lab only · Human in the loop · No autopilot            ║
╚══════════════════════════════════════════════════════════════════╝
```

You are not “testing bash scripts.” You are **booting the conductor** on a real target and
confirming the machine behaves like the design docs promise. Offline tests already proved the
wiring exists; this sim proves the **operator experience** works.

---

## Simulation premise

| Role | You |
|------|-----|
| **Environment** | Home Linux attack box, HTB/THM VPN up (`tun0`) |
| **Target** | One easy/medium disposable box (real IP) |
| **Session** | tmux — NEO auto-wraps to `neo-<project>` |
| **Mission name** | `scratch-tierb-test` (or any fresh project name) |
| **Win condition** | Full pipeline run + debrief table signed |
| **Fail condition** | Crash, silent no-op on a core letter, or false “success” |

**Out of scope for this sim** (known limitations — see § Sim limitations):
assisted auto-loop, enum AI planner, handler pane C, disclosure lint on every AI save.

---

## MODULE 0 — Pre-sim boot (5 min)

Run on the attack box **before** connecting to the target.

```bash
cd ~/NEO-main-work    # or your clone path
unset NEO_TEST_NONINTERACTIVE    # critical — dev shells may export this

# Optional sanity (you already passed 6/6 — quick re-check OK)
bash tools/linux-phase1-verify.sh
# OR: ./test/run-all.sh

./setup.sh --check    # fix missing tools/wordlists if red
```

| Checkpoint | Pass? | Notes |
|------------|-------|-------|
| VPN config file present (`~/Neo/vpn/` or your path) | ☐ | |
| `claude` or `ANTHROPIC_API_KEY` ready | ☐ | Mode A or B |
| `tmux` installed | ☐ | |
| `NEO_TEST_NONINTERACTIVE` unset | ☐ | `echo $NEO_TEST_NONINTERACTIVE` empty |
| Offline verify green (recent) | ☐ | |

---

## MODULE 1 — Enter the chamber (boot sequence)

```bash
./neo.sh scratch-tierb-test <TARGET_IP>
```

**Expected sim behavior:**

1. tmux session `neo-scratch-tierb-test` appears (unless `NEO_TMUX_WRAP=0`)
2. Rabbit intro (unless `NEO_SPLASH=0`)
3. **A / B / C** AI mode prompt → pick your mode
4. VPN ritual — connect or use workaround below
5. Scope intake — educational recommended for first sim

### VPN ritual workaround

If first boot **hard-exits** when you decline VPN but you already have `tun0`:

- **Option A:** Connect VPN first: `./connect/ovpn-connect.sh` (or your profile)
- **Option B:** Re-run **without** `--fresh` after AI mode is saved in `project.meta`

| Checkpoint | Pass? | Notes |
|------------|-------|-------|
| tmux mission session exists | ☐ | `tmux ls` shows `neo-scratch-tierb-test` |
| AI mode saved in `project.meta` | ☐ | |
| Scope intake completed | ☐ | |
| Target IP in notes/meta | ☐ | |

---

## MODULE 2 — Recon sweep (sensor array)

Let recon run (`babysteps` + `analyze-recon` unless manual mode).

**At recon pause menu**, exercise:

| Input | Sim action | Pass? |
|-------|------------|-------|
| `[d]` | Deep enum (optional) | ☐ |
| `[b]` | Borg — assimilate **at least one** vector | ☐ |
| `[p]` | Payload suggest — exact command in PAYLOAD section | ☐ |
| `[e]` | ELI5 — lesson saved to ELI5 section | ☐ |
| `[a]` | Ask Claude one short question | ☐ |
| `[c]` | Continue to foothold | ☐ |

**Pre-foothold check-in:** If web server detected, Y/n interact prompt → optional notes in **INTERACT**.

| Checkpoint | Pass? | Evidence |
|------------|-------|----------|
| PORTS / NMAP sections populated | ☐ | |
| AI-TRIAGE appended | ☐ | |
| BORG section has assimilate entry | ☐ | |
| PAYLOAD has `## Exact next command` | ☐ | |

---

## MODULE 3 — Foothold breach (operator pane)

**At foothold pause** (before/after ListenAssist per menu):

| Input | Sim action | Pass? |
|-------|------------|-------|
| `[o]` | Operator pane B visible and focused | ☐ |
| `[p]` | New payload suggestion for foothold | ☐ |
| `[t]` | Try command in pane B — y/N confirm | ☐ |
| LOCK & LOAD | Toolkit verify when offered | ☐ |
| Manual attempt | Run suggested command; capture in WORKBENCH | ☐ |
| `[z]` | Analyze failures (after **first** attempt) | ☐ |
| `[c]` | Continue when shell obtained (or document stop) | ☐ |

**Rules of engagement:**

- Do **not** paste exploits into the **conductor** pane (pane A) — use `[t]` or pane B
- Listener/handler: use ListenAssist; **pane C is not wired** — MSF runs in pane B for this sim

| Checkpoint | Pass? | Evidence |
|------------|-------|----------|
| WORKBENCH section has try/analyze entries | ☐ | |
| FOOTHOLD section updated (manual OK) | ☐ | |
| `foothold_attempted` or shell noted | ☐ | |

---

## MODULE 4 — On-box enum (privesc sensors)

Pick **run-findprivs** (or linpeas) when prompted.

Accept pipeline hooks when offered:

- Rank privesc hypotheses (Y/n) → ATTACKPATH or TODO
- AI privesc triage (Y/n) → **PRIVESC-PLAN** section

| Checkpoint | Pass? | Notes |
|------------|-------|-------|
| WHOAMI / SUDO / SUID ingested | ☐ | |
| privesc rank ran (optional) | ☐ | |
| PRIVESC-PLAN populated (if accepted) | ☐ | |

---

## MODULE 5 — Privesc ascent

| Input | Sim action | Pass? |
|-------|------------|-------|
| `[p]` | Privesc-focused payload suggest | ☐ |
| `[t]` / `[o]` | Validation command in pane B | ☐ |
| `[c]` | Continue to post when root/user flag path clear | ☐ |

| Checkpoint | Pass? | Notes |
|------------|-------|-------|
| Privesc attempt documented | ☐ | WORKBENCH or manual notes |
| USERFLAG / ROOTFLAG (manual set OK) | ☐ | |

---

## MODULE 6 — Post phase & extraction report

At **post** pause:

| Input | Sim action | Pass? |
|-------|------------|-------|
| `[f]` | Write final report → REPORT section + artifact | ☐ |
| `[p]` / `[t]` / `[o]` | Still visible on menu | ☐ |
| Mission complete hint | Printed at end | ☐ |

Optional CLI report:

```bash
./neo.sh scratch-tierb-test --report
```

| Checkpoint | Pass? | Evidence |
|------------|-------|----------|
| REPORT section exists | ☐ | `artifacts/final-report-*.md` |
| Mission reached post without crash | ☐ | |

---

## MODULE 7 — Debrief (sign-off)

Fill after the sim. Copy to `projects/scratch-tierb-test/SIM-H-DEBRIEF.md` if you want a record.

| Field | Value |
|-------|-------|
| Date | |
| Operator | |
| Target (box name + IP) | |
| AI mode (A/B/C) | |
| Modules 0–6 all attempted | ☐ |
| Core letters verified: b p t o e a c f | ☐ |
| Blockers hit | |
| Promote to FEATURE-STATUS? | |

### Letter sign-off matrix

| Letter | Worked as designed? | Notes |
|--------|---------------------|-------|
| `[b]` Borg | ☐ Y ☐ N | |
| `[p]` Payload | ☐ Y ☐ N | |
| `[t]` Try | ☐ Y ☐ N | |
| `[o]` Operator pane | ☐ Y ☐ N | |
| `[e]` ELI5 | ☐ Y ☐ N | |
| `[a]` Ask | ☐ Y ☐ N | |
| `[z]` Analyze failure | ☐ Y ☐ N | |
| `[f]` Report | ☐ Y ☐ N | |
| `[c]` Continue | ☐ Y ☐ N | |

### After debrief (optional)

```bash
NEO_P18_LAB=1 ./test/p18-lab-e2e.sh
```

Marks B12 checklist — run **after** this sim, not instead of it.

---

## Sim limitations (do not fail the run for these)

These are **Tier B prototypes** — code exists, offline tests pass, but they are **not**
required to pass SIM-H:

| Feature | What you'll see | Why it's "incomplete" |
|---------|-----------------|------------------------|
| **Assisted loop** | Conductor won't auto-run 5 tries for you | Loop exists but `neo.sh` never calls it |
| **Enum AI** | plan-enum hook works; no AI review of the plan | `neo-enum-ai.sh` prints a bundle, never calls Claude |
| **Handler pane C** | No third tmux pane for MSF | `neo-handler-pane.sh` unwired — use pane B |
| **Full disclosure lint** | AI output not auto-scanned unless env set | Guard is off unless `NEO_DISCLOSURE_LINT_ALL=1` |

Failing to see these features **does not mean SIM-H failed**.

---

## Abort / emergency

| Situation | Action |
|-----------|--------|
| Stuck in menu | `[q]` quit — checkpoint saves |
| Wrong pane | `Ctrl-b` arrow keys between panes |
| Resume later | `./neo.sh scratch-tierb-test` (no `--fresh`) |
| Wipe mission | `./neo.sh scratch-tierb-test --fresh` |

---

## Related docs

| Doc | Role |
|-----|------|
| `NEO-1.0-DESIGN/E2E-CHECKLIST.md` | Multi-box P18 matrix |
| `NEO-1.0-DESIGN/FEATURE-STATUS.md` | Promotion truth board |
| `DRY-RUN-TRACE-2026-08-31.md` | Partial dry-run — resume pattern |
| `tools/LINUX-PHASE1-INSTRUCTIONS.txt` | Offline gate (already passed) |

---

```
[ END SIM BRIEFING — good hunting ]
```
