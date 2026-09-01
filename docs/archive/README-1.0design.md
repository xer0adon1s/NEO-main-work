# NEO — autonomous lab operator

<pre align="center">
 ｱ0ｲ1ｳ1ｴ0ｵ1 01001110 01000101 01001111 ｱ1ｲ0ｳ1ｴ1ｵ0
 010ｱ101ｲ010ｳ110ｴ010ｵ101 110010ｱ010ｲ101ｳ010ｴ110 010110

     ███╗   ██╗███████╗ ██████╗ 
     ████╗  ██║██╔════╝██╔═══██╗
     ██╔██╗ ██║█████╗  ██║   ██║
     ██║╚██╗██║██╔══╝  ██║   ██║
     ██║ ╚████║███████╗╚██████╔╝
     ╚═╝  ╚═══╝╚══════╝ ╚═════╝ 

          ▓▒░  P R O J E C T :  N E O  ░▒▓
        autonomous lab operator · authorized labs only

 01001110 01000101 01001111   mission control awaits the operator
 ｲ010ｱ101ｳ110ｴ010ｵ101 110010ｱ010 010110ｱ101ｲ010ｳ110
</pre>

HTB/THM-style CTF toolkit. **NEO v0.5** runs the enum; you call the shots from mission control.

Authorized lab use only.

**AI agents:** read `CLAUDE.md` and `AGENTS.md` in this folder before changing scripts.

**Version:** `0.4` (`VERSION` file; `neo.sh --version`). Pre-review: `./test/neo-diagnostic.sh`.

## Setup

```bash
git clone <repo> ~/Neo && cd ~/Neo
./setup.sh
./setup.sh --check
```

## AI recon triage (Claude)

After babysteps, NEO sends a **curated** bundle from `Investigation-Notes.md` to Claude. Results **append** to **AI Triage** (each run kept — later runs read prior triage back in). STATUS points you to that section after each triage.

**Credentials** (checked in order):

| Source | Path / env |
|--------|------------|
| Env | `ANTHROPIC_API_KEY` |
| Key file | `~/.config/neo/anthropic.key` |
| Repo env | `~/Neo/.env` |
| Workspace ID | `~/.config/neo/anthropic.workspace` (`wrkspc_...`) |

**Multi-workspace Console keys (mode B):** Create workspace **Neo**, copy `wrkspc_...` ID. When you pick **B** at first boot, NEO prompts for the workspace ID if it is not saved yet (Enter to skip if the key is already workspace-scoped). Or save up front:

```bash
./tools/neo-claude-setup.sh wrkspc_...   # optional: pass ID as arg
./neo.sh MyBox 10.x.x.x                  # prompts for key and/or workspace if missing
./recon/analyze-recon.sh MyBox           # manual re-run
```

Alternative: create an API key **scoped to one workspace** at key creation time (no workspace file needed).

**AI analysis modes** — asked once at first boot of each mission (recon start), after the Matrix intro on fresh projects:

| Choice | Mode | Behavior |
|--------|------|----------|
| **A** | Claude Pro/Max | Pipes Investigation-Notes into `claude -p` (subscription login) |
| **B** | Claude API key | Console API via `analyze-recon.sh` (metered credits) |
| **C** | Neither | Pauses only — share `Investigation-Notes.md` with your own AI or review manually |

After you pick A/B/C, NEO shows an **AI MODEL CONFIRMED** ASCII banner, then runs the VPN ritual (see below).

At any pause, **`[a]sk Claude`** runs `claude -p` on demand when Claude Code is installed (all modes).

See **BORG — vector assimilation** below for **`[b]org assimilate`**.

Skip the startup prompt: `NEO_AI=0 ./neo.sh ...` (forces manual). Model (API path): `NEO_AI_MODEL` (default `claude-sonnet-4-6`).

## Pause menu letters (case-insensitive)

Every pause-menu letter means **one action** — upper and lower case are equivalent (`a`/`A`, `b`/`B`, `p`/`P`, etc.). Boot AI mode **A/B/C** is a separate prompt (pick subscription / API / manual).

## BORG — vector assimilation (shared collective)

After AI triage surfaces attack paths, **BORG** deep-dives **one vector** at a time.

| Trigger | Command |
|---------|---------|
| Pause menu | **`[b]org assimilate`** (b/B — same as uppercase) |
| Standalone | `./borg/borg.sh <project>` or `--vector="description"` |

**Where data lives:**

```
knowledge/vectors/<slug>/     ← canonical dossier (tracked in git, shared forever)
projects/<box>/assimilated/<slug>/  → symlink into collective
```

Each dossier: `SUMMARY.md`, `EXPLOIT.md`, `TOOLS.md`, `manifest.yaml`, `raw-response.md`.
Cloned PoCs go under `knowledge/vectors/<slug>/vendor/` (gitignored).

**Collective memory:** if slug already exists → **[u]se** (link, no AI) or **[r]e-assimilate** (updates collective for this target).

**Wind-up automation:** Borg walks **Proposed wind-up actions** one-by-one — install this tool?
Run this command? — you say **y/N** at each step. PoCs are describe-only (you clone manually).
Technique docs explain the vector; executable steps need your approval.

Browse assimilated vectors: `knowledge/README.md` · **`knowledge/resources/borg_research_index.md`** — external CVE/exploit/technique source catalog (Borg "start here") · Disable ASCII: `NEO_BORG_HUD=0`

## Payload assistant — suggest + analyze (advisory only)

After Borg assimilation (or with AI triage alone), use pause-menu payload tools when the phase is relevant. Nothing here auto-executes — every action hands you text to copy/paste and run yourself.

| Key | Action |
|-----|--------|
| **`[p]ayload`** | **Suggest payload** — pick a tool from a picker (Borg manifest tools first, then a generic fallback list, each flagged installed/not); Claude writes back one exact copy-paste command for that tool, plus alternates |
| **`[z]`** | **Analyze failures** — reviews what's been tried (NEO's log, plus a tmux terminal-log capture of manual attempts when available) and recommends a concrete next step |

**When visible:** `[p]` — recon · foothold (until `FOOTHOLD` section has real shell content) · privesc. `[z]` — **foothold only, and only after you've made a first attempt there** (running ListenAssist, or a prior Suggest, unlocks it).

Both save to **Payload suggestions** in notes.

## First launch boot sequence

On a **fresh mission** (recon start, no saved `ai_triage`, interactive TTY, splash enabled):

1. **Rabbit intro** (~7s) — matrix rain, white-rabbit ASCII, typed quotes — **skipped** if `NEO_SPLASH=0` / `--no-splash` even when `--fresh` forces AI mode + VPN ritual
2. **A/B/C** AI mode prompt
3. **`AI MODEL CONFIRMED`** banner (mode-specific)
4. **VPN ritual** — detect `tun0` / OpenVPN:
   - Connected → **`VPN CONNECTION DETECTED`** → keep `[Y]` or connect new profile `[n/new]` from `~/downloads` or `~/Neo/vpn`
   - New profile → **`ATTEMPTING TO CONNECT`** → **`NEW VPN CONNECTION CONFIRMED`**
   - Stay on existing → **`VPN CONNECTION CONFIRMED`**
5. **Lab target IP** (if not on CLI) → ping check → **`LAB TARGET REACHABLE`**
6. Mission banner → phase walk

**Resume / automation** skips the intro and VPN ASCII (`NEO_SPLASH=0`, `--no-splash`, or existing `ai_triage` in `project.meta`). Uses a simple VPN check instead.

Tunables: `NEO_BOOT_INTRO_SEC=7` · `NEO_VPN_WAIT=90` · `NEO_SPLASH=0` or `./neo.sh --no-splash ...`

## Run a mission

```bash
./neo.sh MyBox 10.10.11.23    # new mission — rabbit intro + AI/VPN ritual + recon HUD
./neo.sh MyBox                 # resume where you left off (skips intro)
./neo.sh                       # list projects
```

Disable visuals: `NEO_SPLASH=0 NEO_HUD=0 ./neo.sh ...` or `./neo.sh --no-splash ...`  
During AI triage and **`[b]org assimilate`**, `claude -p` output streams to the terminal; a **90s countdown** runs on stderr (`NEO_AI_TIMER=0` to disable). Only stdout is saved to Investigation-Notes.

**Speed scan (default):** rustscan + **nmap -p- cross-check** (90s, `-T4`) + sC/sV + quick gobuster (~2–3 min; union catches ports rustscan drops on HTB VPN). Survives thin/empty scan phases without aborting. **Deep enum:** `[d]` at recon pause, or `./neo.sh MyBox --deep-recon --from=recon` (nikto, full wordlist, `-T3`, longer budgets).

**Pause menus:** `[c]` continue · `[r]` repeat · `[a]` ask Claude · `[b]` Assimilate with Borg · `[p]`ayload suggest · `[z]` analyze failures · `[s]` skip to step · `[q]` quit (recon also **`[d]`** deep enum; foothold/privesc script-choice menus offer the same extras).

**`[p]`** appears after **recon**, during **foothold** (until FOOTHOLD section is filled), and during **privesc**. **`[z]`** appears in **foothold only, once you've made a first attempt there** — running ListenAssist, or a prior Suggest, unlocks it.

**`[a]sk Claude`** now prompts for a free-text question and attaches the last `NEO_ASK_CONTEXT_LINES` (default 800) lines of Investigation-Notes.md as context — Q&A logs to a running **Ask Claude Log** section.

**tmux:** a real interactive launch auto-wraps `neo.sh` into a named `neo-<project>` tmux session (opt out with `NEO_TMUX_WRAP=0` or `--no-tmux`) so **`[z]` analyze failures** can capture manual attempts made outside NEO — split a pane (`Ctrl-b %`) rather than opening a separate terminal, or they won't be visible to it. If your terminal is already inside some *other* tmux session (e.g. one left over from `connect/ovpn-connect.sh`) when you launch, NEO **switches this terminal's view** to the mission session (`switch-client`) — the foreign session keeps running in the background. **`--fresh`** kills and recreates an existing `neo-<project>` session when you're launching from outside it.

**Pre-foothold check-in:** right before recon hands off to foothold, if something worth poking at by hand was found (a web server today), NEO offers a Y/N to go explore manually and pipe findings back — free text, or **`[a]`** to ask Claude first — before foothold begins.

## Repo layout (`~/Neo`)

```
~/Neo/
├── neo.sh, setup.sh, phases.yaml, registry.yaml
├── AGENTS.md, CLAUDE.md, README.md
├── lib/                ← notes-lib, script-lib, neo-ai, neo-ai-cli, neo-ai-analyze, neo-splash, neo-hud, neo-vpn, neo-boot, neo-borg, neo-payload, neo-menu
├── assets/             ← splash ASCII art
├── recon/              ← babysteps, analyze-recon (AI triage)
├── borg/               ← borg.sh (vector assimilation)
├── knowledge/          ← Borg collective (shared across all missions)
│   ├── INDEX.yaml      ← assimilated vector slugs (auto-maintained)
│   ├── resources/      ← borg_research_index.{yaml,md} — external research catalog
│   └── vectors/<slug>/ ← canonical dossiers + vendor clones
├── foothold/           ← ListenAssist
├── privesc/            ← FindPrivs + run-* wrappers
├── connect/            ← ovpn-connect
├── tools/              ← status.sh, neo-claude-setup.sh, neo-lib-cleanup.sh
├── test/               ← neo-diagnostic.sh, notes-lib-test, borg-test, payload-test, menu-routing-test, smoke, boot
├── vendor/             ← linpeas, etc. (gitignored)
├── projects/           ← per-box notes (gitignored)
├── templates/
├── wordlists/
├── vpn/
└── results/
```

Spec: `AGENTS.md` · Co-lab brief (local): `CLAUDE-COLLAB.md` · Dev log: `CURSOR-REVIEW-LOG.md`

**Pre-review:** `./test/neo-diagnostic.sh` (59 checks) · **Unit tests:** 132 total — notes-lib 21 · recon-bundle 18 · borg 12 · payload 18 · boot 3 · menu-routing 27 · interact 7 · smoke 26

## wordlists/

- `rockyou.txt`, `10k-most-common-passwords.txt`, `directory-list-2.3-medium.txt`, …

Example: `gobuster dir -u http://target -w ~/Neo/wordlists/directory-list-2.3-medium.txt`

## vpn/

Drop HTB/THM `.ovpn` files in `~/Neo/vpn/` or your Downloads folder. On first launch, NEO can pick from either and connect in tmux (detached — no attach during the boot ritual). Standalone connect: `connect/ovpn-connect.sh` (finds newest `.ovpn`, stages under `vpn/`, attaches tmux when run interactively).

## System tools (attack box — not shipped here)

nmap, rustscan, gobuster, hydra, impacket, tmux, openvpn, etc. — install via your distro.
