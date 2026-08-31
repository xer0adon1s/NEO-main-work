# NEO — Claude co-lab brief

**Read this entire file before proposing or implementing changes.**  
Repo path: `~/Neo` · GitHub: **Project: NEO** (private) · **NEO v0.3** · Date: 2026-08-30

This is the single briefing doc for Claude (and Cursor) co-lab on NEO. It merges
vision, what's built, review findings, install/setup, and what to do next.

---

## 1. The metaphor

| Role | Who | Job |
|------|-----|-----|
| **NEO** | Autonomous lab operator | Runs enum, scripts, privesc, files structured reports. Works the box. |
| **Operator** | Mission control / earpiece | Picks target, names project, pivots, adds creds/flags, reads STATUS + notes. Calls the shots. |

NEO is the hands. The operator is the brain. NEO reports up; the operator decides.

**Three AI layers (wind-up, not autopilot):**

| Layer | Trigger | Job |
|-------|---------|-----|
| **Triage** | After recon (`analyze-recon` / mode A) | Broad scout — attack paths, vuln leads, next steps |
| **Borg** | `[b]org assimilate` | Deep-dive **one vector** — dossier, verification, wind-up actions |
| **Payload** | `[p]` / `[z]` (phase-gated) | Advisory tool-picker + copy-paste commands; analyze failures at foothold |

Each layer proposes; the operator approves every executable step.

---

## 2. Repo layout

```
~/Neo/                              ← GitHub: Project: NEO
├── neo.sh, setup.sh, phases.yaml, registry.yaml
├── README.md, AGENTS.md, CLAUDE.md
├── lib/                            ← notes-lib, script-lib, neo-ai*, neo-boot, neo-vpn, neo-borg, neo-payload, …
├── assets/                         ← NEO + BORG splash ASCII
├── recon/                          ← babysteps, analyze-recon
├── borg/                           ← borg.sh (vector assimilation)
├── knowledge/                      ← Borg collective (shared across missions)
│   ├── README.md, INDEX.yaml       ← assimilated vector slugs (auto-maintained)
│   ├── resources/                  ← borg_research_index.{yaml,md} (external research catalog)
│   └── vectors/<slug>/             ← canonical dossiers (+ vendor/ clones, gitignored)
├── foothold/, privesc/, connect/, tools/, test/, vendor/
├── projects/                       ← per-box notes + assimilated/ symlinks (gitignored)
├── templates/, wordlists/, vpn/, results/
├── CLAUDE-COLLAB.md                ← THIS FILE (gitignored)
└── CURSOR-REVIEW-LOG.md            ← gitignored dev log
```

**Architecture rule:** scripts live at repo root by phase folder. `neo.sh`
orchestrates — it never reimplements them.

---

## 3. Install / clone flow (important for GitHub push)

Third-party tools are **NOT in git**. After clone:

```bash
git clone <neo-repo> ~/Neo
cd ~/Neo
./setup.sh              # downloads into vendor/
./setup.sh --check      # verify all 6 present
```

| File | Fetched from |
|------|----------------|
| `linpeas.sh`, `winPEASany.exe`, `winPEASx64.exe` | github.com/peass-ng/PEASS-ng/releases/latest → `vendor/` |
| `LinEnum.sh` | raw.githubusercontent.com/rebootuser/LinEnum/master → `vendor/` |
| `pspy32`, `pspy64` | github.com/DominicBreuker/pspy/releases/latest → `vendor/` |

Also gitignored (separate from setup.sh): `projects/*`, `vpn/*`, `wordlists/*.txt`, `results/*`, `knowledge/vectors/*/vendor/` (Borg PoC clones).

**NEO custom code** (babysteps, FindPrivs, libs, wrappers, docs, **knowledge dossiers**,
**`knowledge/resources/borg_research_index.*`**) **is** tracked and pushed.

---

## 4. What's built today (NEO v0.3 — pipeline v7 — flat ~/Neo + BORG collective + payload + research index)

### Reporting stack
- `Investigation-Notes.md` — marker sections `<!-- SECTION:TAG -->`
- `notes_set_section` / `notes_append_section` / `notes_get_section` / `notes_log_smart`
- `STATUS` section — auto tl;dr at top of report
- `LOG` — append-only raw trail; spills to `artifacts/` when >100 lines
- `notes_ingest` — parses `=== Header ===` (FindPrivs) → WHOAMI/SUDO/SUID/…
- **`AI-TRIAGE`** — Claude recon analysis (`analyze-recon.sh`); **append-only** history; prior triage fed back into later runs
- **`BORG`** — per-mission assimilation notes; canonical dossiers in **`knowledge/vectors/<slug>/`**
- **`PAYLOAD`** — payload suggest / analyze-failures runs from pause **`[p]`** / **`[z]`**
- **`ASK`** — free-text **`[a]`sk Claude** Q&A log (Phase 51)
- **`INTERACT`** — pre-foothold check-in findings, "Pre-Foothold Findings" (Phase 51)

### Per-project metadata
- `project.meta` — key=value: project, target, phase, last_script, last_updated, ssh_target, scan_mode, **ai_triage**, **neo_checkpoint**
- `status.sh` — list all projects or show one

### Conductor + UX
- **`neo.sh`** — phase walk from `phases.yaml`; resume/`--from=`/`--deep-recon`
- **First-launch boot** — `lib/neo-boot.sh`: rabbit intro → A/B/C → **AI MODEL CONFIRMED** → VPN ritual → target ping (fresh recon only; skipped on resume / `NEO_SPLASH=0`)
- **OpenVPN helpers** — `lib/neo-vpn.sh` (shared by `neo.sh` boot + `connect/htb-connect.sh`)
- **Matrix splash** — `lib/neo-splash.sh` + `assets/` (`NEO_SPLASH=0`, `--no-splash`)
- **Recon HUD** — `lib/neo-hud.sh` countdown during babysteps (`NEO_HUD=0`)
- **AI ANALYZING HUD** — `lib/neo-ai-analyze.sh` animation while Claude loads (`NEO_AI_HUD=0`)
- **Claude Code CLI** — `lib/neo-ai-cli.sh` — Pro/Max subscription triage via `claude -p`
- **BORG assimilation** — `borg/borg.sh`, `lib/neo-borg.sh` — deep-dive one vector; shared **`knowledge/`** collective
- **Payload assistant** — `lib/neo-payload.sh` — **`[p]`** suggest payload (tool-picker, advisory) · **`[z]`** analyze failures (foothold, after a first attempt) (Phase 51)
- **Pause menu routing** — `lib/neo-menu.sh` — `neo_menu_classify()`; single source of truth for letter→action (Phase 49)
- **tmux auto-wrap** — `lib/neo-tmux.sh` — re-execs into `neo-<project>` tmux session on real interactive launches; captures scrollback for Analyze Failures (Phase 51)
- **Pre-foothold check-in** — `lib/neo-interact.sh` — Y/N pause before the foothold handoff when something "interactable" (web server today) was found in recon (Phase 51)

### Scripts (local = attack box)
| Script | Phase | Notes |
|--------|-------|-------|
| `htb-connect.sh` | connect | VPN; stages `.ovpn`, tmux openvpn; uses `lib/neo-vpn.sh` (`connect/`) |
| `babysteps.sh` | recon | rustscan + nmap; **`--speed`** default, **`--deep`** full enum (`recon/`) |
| `analyze-recon.sh` | recon | AI triage → `AI-TRIAGE`; subscription (A) or API (B) or skip (C) |
| `borg.sh` | any | Vector assimilation → `knowledge/vectors/<slug>/` + project symlink (`borg/`) |
| `ListenAssist.sh` | foothold | tmux listener; pane IDs not indices (`foothold/`) |
| `status.sh` | meta | glance at projects (`tools/`) |
| `neo-claude-setup.sh` | meta | test API key + save workspace ID (`tools/`) |
| `neo-lib-cleanup.sh` | meta | remove accidental pollution under `lib/` (`tools/`) |

### AI analysis modes (first boot — pipeline v4)

Asked **once per mission** at recon start (before phase walk). Saved in `project.meta` as **`ai_triage`**.

| Choice | `ai_triage` | Behavior |
|--------|-------------|----------|
| **A** | `subscription` | Pipe Investigation-Notes into **`claude -p`** (Pro/Max login, not metered API) |
| **B** | `api` | Console API via **`analyze-recon.sh`** (metered credits; workspace ID may be required) |
| **C** | `manual` | No built-in analysis — operator reviews `Investigation-Notes.md` with own AI or by hand |

**At any pause:** **`[a]sk Claude`** (Phase 51) prompts for a free-text question, attaches the
last `NEO_ASK_CONTEXT_LINES` (default 800) lines of Investigation-Notes.md as context, runs
`claude -p` when Claude Code is on PATH, and logs Q&A to the **`ASK`** section.
**At any pause:** **`[b]` Assimilate with Borg** runs BORG on one attack vector when Claude or API key available.
**Phase-gated pauses:** **`[p]`** payload suggest — recon, foothold (until shell), privesc.
**`[z]`** analyze failures — **foothold only, and only after a first attempt has been made there**
(`project.meta`'s `foothold_attempted`, set by ListenAssist or Suggest running — Phase 51).

**Menu letter rule (Phase 48):** every pause-menu letter means exactly one action; case does not matter (`a`/`A`, `b`/`B`, `p`/`P`, `s`/`S`, etc.). Boot AI mode **A/B/C** is separate from pause menus.

Legacy: `ai_triage=builtin` loads as **api**. Skip prompt: `NEO_AI=0` (forces manual).

### BORG assimilation (`borg/borg.sh`, `lib/neo-borg.sh`)

Deep-dives **one vector** from AI triage (or manual entry). Uses same AI stack as triage
(`claude -p` preferred, Console API fallback).

| Output | Location |
|--------|----------|
| Canonical dossier | `knowledge/vectors/<slug>/` (SUMMARY, EXPLOIT, TOOLS, manifest.yaml) |
| Project link | `projects/<box>/assimilated/<slug>/` → symlink to collective |
| Notes section | `BORG` in Investigation-Notes.md |

**Collective memory:** existing slug → **[u]se** (link only, no AI) or **[r]e-assimilate** (updates collective).
**Wind-up model:** Borg walks **Proposed wind-up actions** — `[RUN:]` / `[NEO:]` / `[MANUAL]` / `[TOOL:]` — each step needs **y/N** before execution. PoC git repos are **manual** (describe in dossier; operator clones after review). Technique docs avoid ready-to-paste payloads. Scan/banner data from the target may be adversarial (prompt injection) — verify independently.
Cloned repos: `knowledge/vectors/<slug>/vendor/` (gitignored).
ASCII HUD phases: VECTOR LOCK → NEURAL LINK → ASSIMILATING → DOSSIER COMPILE → COLLECTIVE SYNC → ACQUISITION.
Disable: `NEO_BORG_HUD=0`.

**Research index (`knowledge/resources/borg_research_index.{yaml,md}`):** merged Cursor + Claude
catalog of **external** CVE/exploit/technique sources (12 categories, 77 resources, live-verified
2026-08-30). Borg consults this before ad-hoc web search. **Not** the same as `knowledge/INDEX.yaml`
(assimilated vector slugs). Notable URL drift captured: AttackerKB → Rapid7 VulnDB (2026-08-18),
GTFOBins → gtfobins.org, Packet Storm → packetstorm.news. **TODO:** wire index into `neo-borg.sh` AI bundle.

### Payload assistant (`lib/neo-payload.sh`) — redesigned Phase 51

Uses Borg dossiers + mission notes. Same AI stack as triage/Borg (`claude -p` preferred, Console API fallback). **Advisory only — nothing auto-executes anymore** (the old `[PAYLOAD:]`/`[RUN:]` y/N execute loop is gone from this file; Borg's own wind-up loop for `[b]` Assimilate is separate and unchanged).

| Key | Action |
|-----|--------|
| **`[p]`** | **Payload suggest** — operator picks a tool from a picker (Borg manifest names first, then a generic fallback list, each flagged installed/not); Claude writes back one exact copy-paste command for that tool (`## Exact next command`) plus alternates — operator runs it themselves |
| **`[z]`** | **Analyze failures** — reviews what's been tried: NEO's own **LOG** tail, plus (when available) a tmux terminal-log capture of manual attempts made *outside* NEO in the same tmux session (`neo_tmux_save_capture`, saved to a uniquely-named `artifacts/terminal-log-<ts>.txt`) — treated as ground truth over any summary. Recommends a concrete next step. |

**Visibility:** `[p]` — recon · foothold (until `FOOTHOLD` has real content) · privesc. `[z]` — **foothold only, and only after `project.meta`'s `foothold_attempted` is set** (ListenAssist running, or a prior Suggest, flips it — `neo_payload_mark_foothold_attempted`). Not useful before anything's been tried; that's the point of Analyze Failures.

Notes section: **PAYLOAD** in Investigation-Notes.md. Offline tests: `test/payload-test.sh`.

### Claude API + AI triage UX

**Subscription path (`lib/neo-ai-cli.sh`)**
- **`neo_ai_cli_call()`** — pipes bundle to `claude -p`; temporarily unsets `ANTHROPIC_API_KEY` so subscription login wins
- **`neo_ai_run_cli_triage()`** — same structured output sections as API path; saves to **AI-TRIAGE**. Still used by `analyze-recon.sh`'s automatic post-babysteps triage only.
- **`neo_ai_cli_ask_claude()`** (Phase 51) — the actual **`[a]sk Claude`** pause-menu handler now: prompts for a free-text question, tails the last `NEO_ASK_CONTEXT_LINES` (800) lines of Investigation-Notes.md as context, calls `claude -p`, prints + saves the answer to **`ASK`** (`neo_ai_save_ask()`). `neo_ai_cli_pause_review()` now just forwards to it.
- Stdin cap ~10MB — large dumps referenced by file path in prompt if needed

**API path (`lib/neo-ai.sh`, `tools/neo-claude-setup.sh`)**
- Key: `ANTHROPIC_API_KEY`, `~/.config/neo/anthropic.key`, or `~/Neo/.env`
- **Workspace ID** (identity-linked Console keys): `~/.config/neo/anthropic.workspace`
- **`neo_ai_verify_setup()`** — API ping + workspace prompt when mode B selected
- **`neo_ai_save_triage()`** — append each run to `AI-TRIAGE`; bundle includes prior triage + ATTACKPATH/FOOTHOLD/WHOAMI

**Conductor (`neo.sh`)**
- **`neo_boot_should_run()`** — fresh recon + TTY + splash + no saved `ai_triage` → full boot sequence
- **`neo_prompt_ai_mode()`** — A/B/C at first boot (recon start, TTY or piped stdin)
- **`lib/neo-boot.sh`** — rabbit intro (`NEO_BOOT_INTRO_SEC`), AI confirm banner, VPN ritual (`NEO_BOOT_VPN_RITUAL`), lab ping
- **`lib/neo-vpn.sh`** — `tun0` detect, stage `.ovpn` from Downloads/`vpn/`, tmux connect, wait for interface (`NEO_VPN_WAIT`)
- **`neo_compute_pause_extras()`** — builds `[a]sk Claude` / `[b]org` / payload fragment for **both** post-phase and `pause_before` menus (Phase 48)
- **`neo_menu_classify()`** (`lib/neo-menu.sh`) — both menu loops dispatch on canonical action names, not raw letters (Phase 49)
- **`neo_splash_enabled()`** — rabbit intro opt-out; `--fresh` forces boot sequence but not splash if `NEO_SPLASH=0` (Phase 48)
- **`neo_checkpoint`** — quit/Ctrl-C saves position; **`[s]`** skip-to-step; **`[k]`** skip phase
- **`neo_lib_hygiene_warn()`** — warns if `lib/` polluted; run `./tools/neo-lib-cleanup.sh`
- **`neo_tmux_wrap_if_needed()`** (`lib/neo-tmux.sh`, Phase 51; skip-gate Phase 56; switch-client Phase 57; `--fresh` kill Phase 58) — called right after project-name validation, before `OUTDIR`/`meta_init`. Re-execs (`exec`, same PID slot) into a tmux session `neo-<project>` when the launch is genuinely interactive (`-t 0 && -t 1`) and `NEO_TMUX_WRAP` isn't `0`. Reattaches if the session already exists (no `--fresh`). Skips wrapping only when already inside **that exact** `neo-<project>` session (`neo_tmux_already_in_own_session()`) — **not** just "any `$TMUX` is set." Being inside some unrelated foreign tmux session (confirmed live: operator's OpenVPN session from `connect/ovpn-connect.sh`) → **switches this terminal's view** to the mission session via `tmux new-session -d` + `switch-client` (foreign session keeps running in the background). **`--fresh` from outside** kills an existing `neo-<project>` session first so wipe + current env-forwarding run; **already inside the mission session** → in-process wipe only (no kill). Env vars are not inherited by a fresh tmux session by default — `NEO_TMUX_ENV_FORWARD` forwards them via `%q`-quoted prefixes. Branded errors on `new-session -d` / `switch-client` failure. Piped/non-interactive runs always no-op. **`neo_tmux_capture_recent()`** / **`neo_tmux_save_capture()`** dump scrollback for Analyze Failures.
- **`neo_interact_pause_before_foothold()`** (`lib/neo-interact.sh`, Phase 51) — called once, right after `walk_phase(recon)` returns success and `next == foothold`, before the phase-index advance. No-op if nothing in `NEO_INTERACT_DETECTORS` matched (web today), not a TTY, or notes don't exist. Otherwise: rundown, Y/N to explore manually, free-text findings (or **`[a]`** to ask Claude first) → **`INTERACT`** section (`neo_interact_save`). Reusable framework — a future interactable is one detector name plus a `detect_<name>`/`rundown_<name>` pair, no change to the pause flow itself.

**Triage presentation (`lib/neo-ai-analyze.sh`, `recon/analyze-recon.sh`)**
- **Live `claude -p` output** + **90s stderr countdown** (`NEO_AI_TIMER=0`; `NEO_AI_HUD=0` alias)
- **Structured output:** `## Technical observations` + tagged `## Operator next steps`
- Step tags: **`[NEO]`** · **`[MANUAL]`** · **`[TOOL:name]`**
- **Terminal brief** after triage; **tool check** — pacman/apt install offers

### Scripts (on-target → wrappers from attack box)
| Script | Wrapper | Filing |
|--------|---------|--------|
| `FindPrivs.sh` | `run-findprivs.sh` | `ingest` → curated sections |
| `linpeas.sh` | `run-linpeas.sh` | `log` smart → artifacts if huge |
| `LinEnum.sh` | `run-linenum.sh` | `log` smart |

### Recon scan modes
| Mode | How | Behavior |
|------|-----|----------|
| **speed** (default) | `neo.sh`, babysteps `--speed` | rustscan + nmap `-p-` union (~90s, `-T4`); ~45s/step; no nikto |
| **deep** | recon pause `[d]`, `--deep-recon`, babysteps `--deep` | Full timeouts; nmap `-p-` (`-T3`); nikto; full wordlist |

### Mission flow today

```
neo.sh MyBox 10.10.11.23
     ↓
Fresh boot (recon, no ai_triage, TTY, splash on):
  rabbit intro → A/B/C AI mode → AI MODEL CONFIRMED
  → VPN ritual (detect / connect / confirm) → lab IP + ping
     ↓
A: babysteps → analyze-recon (claude -p)
B: babysteps → analyze-recon (Console API)
C: babysteps only (manual review mode)
     ↓
foothold → privesc → post (pauses; [c/r/a/b/p/z/s/q]; [d] deep recon; [k] skip phase)
     ↓
Optional: [b]org assimilate vector → knowledge/vectors/<slug>/ (collective)
Optional: [z] analyze Borg / [p] payload suggest (when phase-relevant)
     ↓
Investigation-Notes.md + project.meta + STATUS (+ AI-TRIAGE when A or B; + BORG when assimilated; + PAYLOAD when [p]/[z])
```

Resume (`neo.sh MyBox`, `--from=`, or saved `ai_triage`) skips rabbit intro and VPN ASCII;
uses `resolve_target_ip` + simple VPN check. `NEO_SPLASH=0` / `--no-splash` disables full boot.
**`--fresh`** forces AI mode + VPN ritual but still respects `NEO_SPLASH=0` for the rabbit intro.
Between pauses in **manual mode (C)**, share `Investigation-Notes.md` with an external AI,
paste replies into **AI Triage**, then return to NEO. Any mode can press **`[a]`** at a
pause to run `claude -p` if Claude Code is installed, **`[b]`** to BORG-assimilate a
vector, or **`[p]`** / **`[z]`** for payload work when the phase allows. Quit (`[q]` or Ctrl-C) saves `neo_checkpoint`; `neo.sh MyBox` resumes at the pause
menu or mid-script sequence.

Or run individual scripts under `recon/`, `foothold/`, etc.

### Pause menu keys (neo.sh)

All keys below are **case-insensitive** (e.g. `a` and `A` both ask Claude). Boot AI mode **A/B/C** is a separate prompt.

| Key | When | Action |
|-----|------|--------|
| c | post-phase menu | Continue to next phase |
| r | post-phase menu | Repeat current phase |
| a | both menus | Ask Claude — `claude -p` review of Investigation-Notes (if installed) |
| b | both menus | **Borg assimilate** — BORG deep-dive one vector (if Claude or API key) |
| p | both menus (phase-gated) | **Payload suggest** — Borg + notes → payload rationale + execute loop |
| z | both menus (phase-gated) | **Analyze Borg** — readiness ranking before payload work |
| s | both menus | Skip to step — pick recon/foothold/privesc/post |
| q | anywhere | Quit — saves `neo_checkpoint`, resume later |
| d | recon post-phase only | Deep enum (full nmap/nikto) |
| k | pause_before only | Skip this phase (advance without running) |

Note: boot AI mode uses **A/B/C** (subscription / API / manual) — unrelated to pause **`[b]org`**.

### Tests
```bash
bash test/notes-lib-test.sh      # 21/21
bash test/recon-bundle-test.sh   # 18/18
bash test/borg-test.sh           # 12/12 — collective + wind-up helpers (no AI)
bash test/payload-test.sh        # 10/10 — menu visibility + tag parsing
bash test/neo-boot-test.sh       # 3/3 — VPN ritual stdout capture
bash test/menu-routing-test.sh   # 27/27 — pause-menu letter routing (neo_menu_classify + drift guard)
bash test/neo-smoke-test.sh      # 26/26 (NEO_SPLASH=0, NEO_HUD=0)
bash test/neo-diagnostic.sh      # 53 ok — runs all suites + integrity checks
```
**Total unit tests:** 117 · **Diagnostic checks:** 53

### Operator state (2026-08-30 evening)
- **`~/Neo/projects/HTB-Reactor` deleted** — operator requested fresh start; re-run with new target IP
- API key on disk: `~/.config/neo/anthropic.key` (108-char Console key)
- Workspace file **removed** — operator must paste `wrkspc_...` from Console workspace **Neo** on next run
- `~/cybersec` empty — NEO fully lives in `~/Neo`

---

## 5. Review history (Cursor + Claude — condensed)

Full detail in `CURSOR-REVIEW-LOG.md` (local, gitignored). Summary:

### Phase 1 — Correctness fixes
- notes-lib awk safety (corrupt/missing markers no longer truncate file)
- babysteps PROBE_PORTS union (VPN lossy link port drops)
- ListenAssist project name validation; docs synced

### Phase 2 — Pipeline expansion
- script-lib.sh, registry.yaml, project.meta, artifacts, ingest, STATUS
- run-* wrappers, status.sh, test harness, AGENTS.md rewrite, git init

### Phase 3 — Claude review (verified)
- **21/21** notes-lib tests, **15/15** smoke, **11/11** recon-bundle (offline)
- **Fixed:** `status.sh` blank STATUS for legacy projects (pre-STATUS template)
- **Fixed:** `meta_init` default `phase=recon` (was `connect`, broke fresh reset)
- **Fixed:** HUD/splash color vars when babysteps already set `C_GREEN`
- **Cleaned:** test debris in projects/
- **Noted, not fixed:**
  - Section ownership is convention in AGENTS.md, not code-enforced
  - Old projects lack STATUS section until manual add or re-init
  - Wrappers not end-to-end tested on live HTB box yet
  - `cybersec_print_banner` padding cosmetic only

### Phase 4 — Claude AI + workspace (2026-08-30 evening)
- **`analyze-recon.sh`** + **`lib/neo-ai.sh`** — curated bundle → `AI-TRIAGE`
- **Speed vs deep scan** — default speed; `[d]` / `--deep-recon` for full enum
- **Anthropic multi-workspace keys** — HTTP 400 without `anthropic-workspace-id`;
  operator created Console workspace **Neo**; `neo_ai_verify_setup()` prompts at runtime
- **HTB-Reactor wiped** for operator fresh start (not in `projects/` anymore)

### Phase 5 — Manual AI mode, checkpoints, skip-to-step (2026-08-30 late)
- **Y/n built-in triage prompt** at recon (superseded by A/B/C in Phase 28)
- **`neo_checkpoint=phase:state:idx`** — resume at menu or mid-script; Ctrl-C saves too
- **`[s]kip to step`** jumps between phases; **`[k]`** skip phase at pause_before

### Phase 9 — A/B/C AI modes + `claude -p` (Phase 28)
- **A** Claude Pro/Max → `lib/neo-ai-cli.sh` / `claude -p`
- **B** Console API key → `analyze-recon.sh`
- **C** Manual review — no built-in analysis
- **`[a]sk Claude`** at any pause when Claude Code installed

### Phase 10 — lib/ pollution fix (Phase 26)
- **`tools/neo-lib-cleanup.sh`** — 5.7GB `/usr/lib` copy removed from `lib/`

### 🔴 Open blocker — babysteps stub (Phase 27) — **RESOLVED Phase 30**

- **`recon/babysteps.sh`** restored from git baseline + `--speed`/`--deep` support
- **`test/neo-diagnostic.sh`** now checks content (rustscan, gobuster, line count), not just file existence

### Phase 6 — AI persistence in Investigation-Notes (Phase 21)
- **`neo_ai_save_triage()`** — append-only `AI-TRIAGE`; prior triage in next bundle
- Bundle includes ATTACKPATH, FOOTHOLD, WHOAMI as case progresses
- **`analyze-recon.sh` restored** (had been corrupted to stub)

### Phase 7 — ANALYZING HUD, terminal brief, tool offers (Phase 22)
- **`lib/neo-ai-analyze.sh`** — ANALYZING animation, terminal brief, `[TOOL:]` install prompts
- Claude output: **Technical observations** + tagged **Operator next steps** (`[NEO]`/`[MANUAL]`/`[TOOL:]`)

### Phase 8 — Pre-review diagnostic (Phase 20)
- **`test/neo-diagnostic.sh`** — one-command health check before co-lab review
- Fixed `ai_triage=manual` persistence; smoke test lib copy hygiene

See **§ Operator prompt log** for verbatim prompts that created each phase.

---

## 6. Design principles (do not violate)

1. Scripts stay composable — one job, file via notes-lib/script-lib.
2. Human edits to Investigation-Notes.md survive every re-run.
3. `projects/` is mission memory — gitignored, don't duplicate under neo/.
4. Never patch third-party tools — wrappers only (`run-*.sh`).
5. Only section **owner** may `set`; others `append` or LOG (see AGENTS.md table).
6. Build conductor (`neo.sh`) last — execution + reporting exist first. **Done 2026-08-30.**
7. Don't modify `projects/` (live findings) unless operator asks.
8. **Log operator prompts** in `CURSOR-REVIEW-LOG.md` phase entries (verbatim blockquote + what was done).

---

## 5b. Operator prompt log (session 2026-08-30)

**Convention:** Every significant change logs the operator's exact prompt in
`CURSOR-REVIEW-LOG.md` so co-lab AIs can see intent, not just diffs. See that file's
**Operator prompt log — convention** header.

Chronological prompts that shaped the current workflow:

### Prompt 1 — Neo workspace + fresh project (→ Phase 17)

> ok i created a workspace called Neo and the api key i have copy pasted can u fix the code, then delete the project folder so i can run Neo fresh and give it my code again

**Result:** `neo_ai_verify_setup()`, workspace prompt at runtime, wiped `projects/HTB-Reactor`,
cleared `anthropic.workspace`, kept `anthropic.key`.

### Prompt 2 — Update collab docs (→ Phase 17 docs pass)

> of course update all the logs and info for collab AI's to review

**Result:** Updated `AGENTS.md`, `README.md`, `CLAUDE-COLLAB.md`, `CURSOR-REVIEW-LOG.md`,
`CLAUDE.md`, `registry.yaml`, `phases.yaml`.

### Prompt 3 — Manual AI mode, resume, skip-to-step (→ Phase 18)

> ok lets also program in where it ASKS if you have Claude API and gives a y/n and if you pick NO it will go into a mode that removes all the AI triage and just goes through the normal motions and steps with pause points. it tells the user to PIPE their INVESTIGATION_NOTES into AI as the project continues (use better verbiage than me) to have AI examine and then pick up at each point.
>
> QUITTING NEO while in the middle of a step should somehow SAVE that location and when run again on that project it should PICK UP at the step it was on before, --- AND i want you to add an [s] option at the pause point which is skip to step and allows u to bounce between the steps of this process as needed.

**Result:** `neo_prompt_ai_mode()`, manual review banner, `ai_triage` + `neo_checkpoint` in
`project.meta`, `[s]` skip-to-step, `[k]` skip phase, interrupt trap, smoke tests extended.

### Prompt 4 — Log prompts in collab docs (→ Phase 19)

> after you're done update all of the collab docs with this and moving forward INCLUDE the prompts that i gave you in those logs so other AI can examine the work that was done as well as the PROMPT that created the workflow.

**Result:** This section + retrofitted phase entries in `CURSOR-REVIEW-LOG.md`; convention
for all future phases.

### Prompt 5 — AI output lives in Investigation-Notes (→ Phase 21)

> also anything AI generates should save within the investigation notes and certainly be referred back to as the case progresses can you ensure this works like that?

**Result:** `neo_ai_save_triage()` append-only; bundle includes prior AI triage + case sections;
manual mode paste into **AI Triage**; `analyze-recon.sh` restored.

### Prompt 6 — ANALYZING HUD, technical brief, tool install (→ Phase 22)

> also, once it runs the scan through AI i want it to do a cool "ANALYZING" graphic ascii thingy while the AI is loading its response, I want the AI to spit our everything it "noticed" in more techincal terms, and the also pipe out from the AI specific steps for the end-user to move forward with. If the AI determines we need to download a program, have NEO check and see if that program exists, and if not, then offer to download it. if the action needed is something outside the script (like opening a webpage as an example) have the AI pipe out specific instructions, or ask it for that

**Result:** `lib/neo-ai-analyze.sh` — HUD, terminal brief, `[NEO]`/`[MANUAL]`/`[TOOL:]` tags,
pacman/apt install offers, TODO on skip.

### Prompt 7 — Full diagnostic before Claude review (→ Phase 20)

> do a full diganostic and run tests all the program and everythign we've done before i have claude reovew

**Result:** `test/neo-diagnostic.sh`; fixed meta persistence + smoke lib copy; **58/58** tests green.

### Prompt 8 — Update collab docs (→ Phase 23)

> of course, update collab docs

**Result:** This pass — Phases 20–22 in `CLAUDE-COLLAB.md` §5/§5b; `AGENTS.md` extension log;
`CURSOR-REVIEW-LOG.md` Phase 23 entry.

### Prompt 9 — Claude review findings + claude -p epiphany (→ Phases 25–26)

> ok ill have claude review all this-- it found 1 critical thing to fix and noted it in the collab docs. also we're gonna do this after: theres notes about this as well in collab docs
>
> [Pro/Max `claude -p` subscription billing epiphany — pipe scan output at pause points, no API key unless env set or `--bare`; usage pool shared with interactive sessions]

**Result:** Phase 25 lib/ pollution flagged by Claude review; Phase 26 fixed via
`neo-lib-cleanup.sh` (39k paths removed). Phase 24 expanded with subscription epiphany.

### Prompt 10 — A/B/C AI mode at first boot (→ Phase 28)

> lets have NEO ask the user if it has A) CLaude pro/max B) Claude API Key C) Neither … [pipe investigation notes into claude -p / API / manual] … SPECIFICALLY AT THE START WHEN U FIRST BOOT IT

**Result:** `neo_prompt_ai_mode()` A/B/C menu; `lib/neo-ai-cli.sh`; `[a]sk Claude` at pauses;
`ai_triage=subscription|api|manual`. Tests green at time (see § Tests for current counts).

### Prompt 11 — Sync all docs (→ Phase 29)

> make sure all documents are up to date like collabs readmes and the like

**Result:** This pass — CLAUDE-COLLAB, CURSOR-REVIEW-LOG Phases 28–29, README, AGENTS, CLAUDE.

### Prompt 12 — Restore babysteps + diagnostic + model ID (→ Phase 30)

> Claude finished a full review … [CRITICAL babysteps stub rebuild; diagnostic content check; stale model ID]

**Result:** Full `recon/babysteps.sh` restored + `--speed`/`--deep`; diagnostic integrity grep; `claude-sonnet-4-6` default.

---

## 7. Planned (neo/ layer)

| Item | Purpose | Status |
|------|---------|--------|
| `neo.sh` | Mission runner: phases, pauses, calls neo/ scripts | **Built** (2026-08-30) |
| `phases.yaml` | Mission view of connect→recon→foothold→privesc→post | **Built** |
| `neo.conf` | Operator defaults (timeouts, auto vs manual phases) | Deferred |
| `claude -p` subscription triage | Pro/Max login via Claude Code CLI | **Built** — Phase 28 (`lib/neo-ai-cli.sh`, mode A, `[a]` at pauses) |
| Restore `recon/babysteps.sh` | Real rustscan/nmap/gobuster recon | **Built** — Phase 30 |
| **BORG assimilation** | Deep-dive vectors + shared `knowledge/` collective | **Built** — Phase 37 (`borg/borg.sh`, **`[b]org`** at pauses since Phase 48) |
| **Payload assistant** | **`[p]`** suggest + **`[z]`** analyze Borg; execute loop + failure analysis | **Built** — Phases 39–40 (`lib/neo-payload.sh`; letter rename Phase 48) |
| **`borg_research_index`** | External CVE/exploit/technique source catalog for Borg research | **Built** — Phase 42 (`knowledge/resources/`) |

**✅ Fixed (Phase 26):** `~/Neo/lib/` held a 5.7GB recursive copy of `/usr/lib` (~39k paths).
Cleaned with `./tools/neo-lib-cleanup.sh`; `neo.sh` now warns on startup if lib/ is polluted again.

### Open questions — resolved 2026-08-30 (Claude, as architect)
- [x] `neo.sh` vs repo-root symlink? → **`neo.sh`, no symlink.** A symlink
  adds a fragile moving part for zero real benefit; `neo/` stays self-contained.
- [x] Pause UX: menu vs read-line vs tmux? → **Plain `read -p` prompts**, same
  style babysteps.sh/ListenAssist.sh already use. A TUI is a v2 idea at best —
  disproportionate complexity for an MVP.
- [x] Next-phase suggestion: heuristic vs strict order? → **Strict `phases.yaml`
  order for MVP.** STATUS/TODO-content heuristics are real but are a v2 idea,
  not a blocker for a working conductor.
- [x] Rename AGENTS.md → NEO-AGENTS.md? → **Keep `AGENTS.md` as-is.** It's the
  emerging cross-tool convention name (Claude Code, Cursor, others look for it
  by that exact name) — renaming makes it *less* likely to get auto-discovered,
  for no gain.
- [x] `run-winpeas.sh` wrapper for Windows boxes? → **Out of scope for the MVP.**
  No phase/script targets Windows yet; add it alongside a real Windows privesc
  phase later, not speculatively now.
- [x] Wire registry.yaml ingest_map for real, or drop duplicate? → **Dropped.**
  `registry.yaml`'s copy was documentation-only (nothing parses this YAML) and
  had already drifted from the real map in `notes-lib.sh`. Removed the
  duplicate; left a pointer comment in its place.

Full MVP design: see **section 11** below. `phases.yaml` and `neo.sh`
implement that design — review behavior against section 11 on next co-lab pass.

---

## 8. Co-lab agenda (when operator asks Claude to help)

1. Read **§ Operator prompt log** + `CURSOR-REVIEW-LOG.md` — prompts explain *why*.
2. Review **`borg/borg.sh` + `lib/neo-borg.sh`**: collective sync, reuse prompt, wind-up permission model, **`borg_research_index.yaml`** usage (when wired).
3. Review **`lib/neo-payload.sh`**: phase gating, `[PAYLOAD:]` execute loop, failure analysis on non-zero exit.
4. Review `neo.sh` + **`lib/neo-menu.sh`**: first-launch boot, A/B/C AI mode, checkpoints, **`neo_menu_classify()`** pause routing, **`[c/r/a/b/p/z/s/q/d/k]`** menus (case-insensitive; Phase 48–49).
5. Review **`lib/neo-ai-cli.sh` + `analyze-recon.sh` + `lib/neo-ai-analyze.sh`**: subscription vs API, HUD, tool offers.
6. End-to-end test on **fresh project** on live HTB.
7. Verify mode **A**: `claude -p` → `AI-TRIAGE`; mode **B**: API + workspace; mode **C**: manual + `[a]`/`[b]`/`[p]`/`[z]` optional.
8. Run **`./test/neo-diagnostic.sh`** — expect READY (53 checks, 117 unit tests).
9. Pre-push checklist for private GitHub (gitignore verified, setup.sh tested).
10. `neo.conf` — only if operator hits real friction with hardcoded pauses.

---

## 9. Files to read (in order)

1. `CLAUDE-COLLAB.md` — this file (incl. **§ Operator prompt log**)
2. `CURSOR-REVIEW-LOG.md` — full changelog with verbatim operator prompts
3. `AGENTS.md` — reporting integration rules + new script checklist
4. `registry.yaml` — script index
5. `tools/THIRD-PARTY.md` + `setup.sh` — install story
6. `phases.yaml` + `neo.sh` — conductor spec + implementation
7. `lib/neo-menu.sh` — pause-menu letter routing (`neo_menu_classify`)
8. `lib/neo-boot.sh` + `lib/neo-vpn.sh` — first-launch intro + VPN ritual
9. `lib/neo-ai.sh` + `lib/neo-ai-cli.sh` + `lib/neo-ai-analyze.sh` + `recon/analyze-recon.sh` — triage UX
10. `lib/neo-borg.sh` + `borg/borg.sh` + `knowledge/` — BORG collective + **`knowledge/resources/borg_research_index.yaml`**
11. `lib/neo-payload.sh` — payload suggest/analyze/execute
12. `tools/neo-claude-setup.sh` — Claude API + workspace setup (mode B)
13. `tools/neo-lib-cleanup.sh` — lib/ hygiene
14. `recon/babysteps.sh` — full recon script
15. `test/neo-diagnostic.sh` — pre-review health check + babysteps integrity
16. `test/menu-routing-test.sh` — pause-menu routing regression suite

---

## 10. Constraints for any implementation

- Authorized lab targets only (HTB/THM-style).
- No changes under `projects/` without operator request.
- No edits to downloaded third-party files in `vendor/`.
- All runs file through `notes-lib` / `cybersec_finish`.
- Run `test/notes-lib-test.sh` after notes-lib changes; `test/recon-bundle-test.sh` after neo-ai changes.
- Run `test/borg-test.sh` after neo-borg changes.
- Run `test/payload-test.sh` after neo-payload changes.
- Run `test/menu-routing-test.sh` after `neo.sh` or `lib/neo-menu.sh` pause-menu changes.
- Run `test/neo-diagnostic.sh` before co-lab handoff.
- Only git commit when operator explicitly asks.
- **New phases:** log verbatim operator prompt(s) in `CURSOR-REVIEW-LOG.md` per convention (see Phase 19).

---

## 11. neo.sh MVP spec (Claude design — implemented 2026-08-30)

This is the answer to co-lab agenda item 4. Cursor built `neo.sh` against
this spec; Claude should review implementation vs spec on next pass. Read
alongside `phases.yaml`, which implements the phase/pause table as data.

### Invocation

```
neo.sh <project> [target]        # start a new project, or resume an existing one
neo.sh <project> --from=<phase>  # jump straight to a phase (e.g. re-run privesc)
neo.sh                           # no args: list projects (delegate to status.sh), then exit
```

- `<project>` with no `project.meta` yet + a `target` given → this is a new
  mission; the first phase (`recon`) will create it via `babysteps.sh`'s own
  `notes_init` call — neo.sh does not pre-create anything itself.
- `<project>` with an existing `project.meta` → resume at `meta_get phase`
  (the phase that project last completed/paused at), ignoring any `target`
  argument (already on record).
- `--from=<phase>` overrides resume position — for re-running a phase
  out of the normal walk order (e.g. privesc after a fresh shell as a
  different user).

### Startup preflight (not a phase, not in phases.yaml)

**Fresh first launch** (recon, no saved `ai_triage`, interactive TTY, splash enabled — see
`neo_boot_should_run()` in `neo.sh`):

1. **Rabbit intro** — `lib/neo-boot.sh` (`NEO_BOOT_INTRO_SEC`, default 7s): matrix rain,
   white-rabbit ASCII, typed quotes, NEO splash art.
2. **A/B/C AI mode** — saved to `project.meta` as `ai_triage`.
3. **`AI MODEL CONFIRMED`** ASCII banner (mode-specific subtitle).
4. **VPN ritual** (`NEO_BOOT_VPN_RITUAL=1`, `lib/neo-vpn.sh`):
   - If `tun0` up → **`VPN CONNECTION DETECTED`** → keep `[Y]` or new profile `[n/new]`
     from Downloads or `~/Neo/vpn`.
   - New profile → tmux openvpn (detached) → **`ATTEMPTING TO CONNECT`** spinner →
     **`NEW VPN CONNECTION CONFIRMED`** (or **`VPN CONNECTION CONFIRMED`** if keeping existing).
   - Prompt for lab target IP if not on CLI → ping → **`LAB TARGET REACHABLE`** (or continue anyway).
5. Mission banner → phase walk.

**Resume / automation** (`NEO_SPLASH=0`, `--no-splash`, existing `ai_triage`, or non-recon start):
resolve target from CLI/meta, then simple VPN check — if `tun0` down, offer
`connect/htb-connect.sh` `[y/N]` (legacy `vpn_preflight` behavior via `neo_boot_vpn_flow`).

Standalone VPN connect (outside boot ritual): `connect/htb-connect.sh` — same `lib/neo-vpn.sh`
helpers, but attaches tmux at the end for sudo password entry.

### The phase walk

For each phase in `phases.yaml`, starting from the resume point:

1. If `pause_before: true`, print `prompt_before` and the phase's `scripts`
   list as a numbered menu (or just the single script name if there's only
   one). Read a choice: a script number, `s` (skip this phase entirely,
   advance without running anything — e.g. "already have a shell"), or `q`
   (quit — see below). Default on bare Enter is choice `1`.
2. Run the chosen script directly (`bash "${NEO_DIR}/<file-from-registry>"`
   or its `wrapper` if registry.yaml declares one — for `privesc`, that
   means invoking `run-findprivs.sh <project> <user@target>` etc., **not**
   `FindPrivs.sh` directly, since that one requires the SSH wrapper). If the
   registry entry needs an SSH target string and `project.meta` doesn't have
   one cached yet, prompt for it once (`user@10.10.11.x`) and offer to save
   it to `project.meta` as e.g. `ssh_target=` so later phases/re-runs don't
   ask again. This key doesn't exist yet in `notes-lib.sh`'s `meta_init` —
   add it as an empty default there, mirroring `platform=`.
3. Check the script's exit code. **Non-zero stops here** — print the error,
   do **not** advance `project.meta`'s phase, do **not** run `pause_after`.
   The mission is exactly where it was; `neo.sh <project>` retries the same
   phase next time.
4. On success, if `pause_after: true`, print `prompt_after`.
5. Show the uniform post-phase menu: `[c]ontinue / [r]epeat / [a]sk Claude / [b]org assimilate / [p]ayload suggest / [z] analyze Borg / [s]kip to step / [q]uit`
   (recon also has `[d]eep enum`). `[p]`/`[z]` appear on recon, foothold (until shell), and privesc only. Default on bare Enter is `c`. `r` re-runs the phase.
   `s` lists phases 1–4 to jump. `q` saves `neo_checkpoint` and exits — resume with
   `neo.sh <project>`. **`a`** asks Claude Code (`claude -p`) to review Investigation-Notes
   when installed. **`b`** runs BORG vector assimilation. **`[p]`** / **`[z]`** run payload suggest/analyze when phase-gated. **`pause_before` menus share the same extras** via `neo_compute_pause_extras()`. **Menu letters case-insensitive since Phase 48.**
6. `c` advances to the next phase in `phases.yaml`'s order and loops back to
   step 1. After the last phase (`post`) completes, print a short "mission
   complete" line and exit 0 — no further phase to advance to.

### What this MVP explicitly does NOT do

- No automatic SSH connection guessing, no automatic "you have a shell now"
  detection — the operator always confirms via the menu.
- No exploitation of any kind, automated or otherwise — matches
  `FindPrivs.sh`'s own stated philosophy ("this does NOT exploit anything for
  you — it's a radar, not an autopilot").
- No parsing of `Investigation-Notes.md` content to auto-suggest anything —
  that's the deferred STATUS/TODO heuristic (open question, resolved above
  as out of scope for MVP).
- No `neo.conf` yet — no configurable defaults (auto-continue on Enter, which
  phases pause, etc.) beyond what's hardcoded in `phases.yaml` above. If that
  turns out to be annoying in practice, `neo.conf` is the natural place to
  make `phases.yaml`'s `pause_before`/`pause_after` overridable per-operator
  — but don't build it speculatively before hitting that friction for real.

### One new thing needed in `notes-lib.sh` — **DONE (2026-08-30, Cursor)**

`meta_init` now includes `ssh_target=` (empty default, same pattern as
`platform=`). Confirmed by `neo/test/notes-lib-test.sh` (10/10 pass).

### Testing this MVP before trusting it

1. Run it against a **fresh** project end-to-end with a real or scratch
   target — confirm the recon → foothold → privesc → post walk, both the
   `c` (continue) and `r` (repeat) paths at least once, and that `q` really
   does let `neo.sh <project>` pick back up at the right phase afterward.
2. Force a failing script (e.g. give `run-findprivs.sh` a bad SSH target) —
   confirm neo.sh stops with the error and does **not** silently advance
   `project.meta`'s phase.
3. Run it against `HTB-Reactor` (the one real pre-existing project) in
   `--from=recon` — confirms resume logic works against a project that
   predates `phases.yaml`/`ssh_target` entirely, not just fresh ones.

## Extension log

- 2026-08-30 — NEO vision; neo/ as orchestration layer; neo.sh deferred.
- 2026-08-30 — Pipeline v2 (Cursor): reporting, meta, ingest, wrappers, tests.
- 2026-08-30 — Claude review Phase 3; status.sh legacy STATUS fix.
- 2026-08-30 — setup.sh + gitignore third-party tools for GitHub push.
- 2026-08-30 — This CLAUDE-COLLAB.md created as single co-lab briefing.
- 2026-08-30 — Claude (architect): resolved all open questions in section 7;
  added full neo.sh MVP spec (section 11) with the pause-point product
  decision (recon: pause after; foothold: pause before, skippable; privesc:
  pause before and after, tool choice + cached ssh_target; post: manual,
  informational). Created `phases.yaml` (data only) implementing it.
  Dropped `registry.yaml`'s duplicate/drifted `ingest_map` for FindPrivs.
- 2026-08-30 — Cursor: review fixes (#1–4), docs under neo/; root cleanup
  (deleted stub AGENTS/CLAUDE, moved setup.sh → neo/setup.sh). Phase 8–9 log.
- 2026-08-30 — Relocated to flat `~/Neo`; Phase 12–14 in CURSOR-REVIEW-LOG.
- 2026-08-30 — Claude AI triage, speed/deep recon, Anthropic workspace verify;
  HTB-Reactor wiped for fresh operator run. Phase 15–17 in CURSOR-REVIEW-LOG.
- 2026-08-30 — Manual AI mode (Y/n), checkpoints, `[s]` skip-to-step. Phase 18.
- 2026-08-30 — **Operator prompt logging convention** in collab docs. Phase 19.
- 2026-08-30 — AI triage persistence + refer-back in Investigation-Notes. Phase 21.
- 2026-08-30 — Pre-review diagnostic script. Phase 20.
- 2026-08-30 — ANALYZING HUD, technical brief, `[TOOL:]` install offers. Phase 22.
- 2026-08-30 — Collab docs sync Phases 20–23. Phase 23.
  All future phase entries include verbatim operator prompts.
- 2026-08-30 — lib/ pollution fix; `neo-lib-cleanup.sh`. Phase 26.
- 2026-08-30 — **babysteps stub blocker** on disk. Phase 27.
- 2026-08-30 — **A/B/C AI modes** + `claude -p`; `[a]` at pauses. Phase 28.
- 2026-08-30 — **babysteps restored** + diagnostic integrity check + model ID. Phase 30.
- 2026-08-30 — Collab docs verification pass. Phase 31.
- 2026-08-30 — **First-launch boot sequence:** rabbit intro, AI MODEL CONFIRMED, VPN ritual
  (`lib/neo-boot.sh`, `lib/neo-vpn.sh`); `htb-connect.sh` refactored. Phase 32.
- 2026-08-30 — **Boot bugfixes:** TARGET stdout leak + ai_triage persistence; `neo-boot-test`. Phase 35–36.
- 2026-08-30 — **BORG assimilation:** `borg/borg.sh`, `lib/neo-borg.sh`, `[A]ssimilate` (→ **`[b]org`** Phase 48), shared
  `knowledge/vectors/` collective. Phase 37.
- 2026-08-30 — **Docs sync:** README, AGENTS, CLAUDE, CLAUDE-COLLAB through Phase 38.
- 2026-08-30 — **Payload assistant:** `[S]` suggest (→ **`[p]`** Phase 48) + `[z]` analyze Borg; phase-gated menus. Phase 39.
- 2026-08-30 — **Payload execute + failure analysis:** `[PAYLOAD:]` y/N loop; Claude on failure. Phase 40.
- 2026-08-30 — **Docs sync for Claude review:** pipeline v6, test counts, Phases 39–41. Phase 41.
- 2026-08-30 — **`borg_research_index`:** merged external research catalog (Cursor + Claude). Phase 42.
- 2026-08-30 — **Docs sync:** pipeline v7, research index, Phases 42–43. Phase 43.
- 2026-08-30 — **Release v0.3:** `VERSION` file, `neo.sh --version`, diagnostic banner. Phase 44.
- 2026-08-30 — **Speed scan reliability:** default `--speed` runs **nmap -p- union** (~2–3 min).
  Phase 46.
- 2026-08-30 — **AI triage UX:** live `claude -p` output + **90s stderr countdown** (rabbit HUD
  removed). Phase 46.
- 2026-08-30 — **babysteps pipefail crash fix:** empty grep under `pipefail` no longer kills
  recon; speed `nmap -p-` 90s/`-T4`; Borg assimilate uses same visible timer runner; stderr
  excluded from saved triage/dossiers. Phase 47.
- 2026-08-30 — **Pause menu cleanup:** `[b]org` / `[p]ayload`; case-insensitive letters;
  `neo_compute_pause_extras()`; `--fresh` respects `NEO_SPLASH=0` for rabbit intro. Phase 48.
- 2026-08-30 — **Menu routing test:** `lib/neo-menu.sh`, `test/menu-routing-test.sh` (27);
  both pause menus dispatch via `neo_menu_classify()`; smoke worktree lib copy list fixed. Phase 49.
- 2026-08-30 — **RETURN-trap crash fix:** `trap ... RETURN` isn't function-scoped — a trap set
  inside one function fires on the *next* function return anywhere in the call stack unless
  cleared; fixed in `lib/neo-ai.sh` and `lib/neo-ai-cli.sh` (Cursor-confirmed root cause). Phase 50.
- 2026-08-30 — **Operator feature batch:** `[b] Assimilate with Borg` rename; `[z]` retargeted to
  **analyze failures** (foothold-only, gated on `foothold_attempted`, tmux terminal-log capture);
  `[a]sk Claude` free-text question + last 800 lines of notes as context (`ASK` section);
  `[p]ayload suggest` redesigned to advisory tool-picker (auto-execute wind-up removed); tmux
  auto-wrap (`lib/neo-tmux.sh`) for reliable terminal capture, with empirically-verified env
  forwarding; pre-foothold check-in framework (`lib/neo-interact.sh`, `INTERACT` section) —
  general, not web-specific. `registry.yaml`, `templates/investigation-notes.md`,
  `test/payload-test.sh` updated to match. Phase 51.
- 2026-08-30 — **Cursor's Phase 51 review follow-up:** wired the dead Borg wind-up failure
  hook (`neo_borg_offer_failure_analysis()` → `neo_payload_analyze_command_failure()`); added
  `--no-tmux`; expanded the web detector for `:3000`/SERVICES header. Phase 52.
- 2026-08-30 — **Claude's review of Phase 52:** confirmed the Borg wind-up path and
  `--no-tmux` ordering were correct; found and fixed two real bugs Phase 52 introduced — the
  expanded web detector matched nmap's own banner text (`https://nmap.org`), false-positiving
  "web server found" on **every** mission regardless of target; and
  `neo_payload_analyze_failures_at_pause()` called `neo_tmux_save_capture()` twice per run
  (once directly, once via the shared context-block helper), creating two different
  timestamped artifact files with the wrong one referenced in the printed/logged filename.
  Both confirmed via isolated repro before and after the fix, not just static reading. Phase 53.
- 2026-08-30 — **VPN hijack fix (Cursor, Phase 54):** `connect/htb-connect.sh` →
  `connect/ovpn-connect.sh`, `--no-attach`; non-boot mission-resume paths never invoke it.
- 2026-08-30 — **Reviewed Phase 54 (Phase 55):** confirmed correct, no bugs; closed a real
  test gap (`neo-boot-test.sh` had zero coverage of the non-boot no-invoke guard) with 5 new
  assertions.
- 2026-08-30 — **Fixed a VPN-hijack lookalike in tmux auto-wrap (Phase 56):** operator's
  shell was inside their own OpenVPN tmux session (`connect/ovpn-connect.sh` leftover) when
  launching `neo.sh`; the wrap gate skipped on *any* `$TMUX` being set, so the whole boot
  ritual ran inline inside the VPN's pane — looked exactly like a re-hijack, and silently
  broke Analyze Failures' terminal capture too. Fixed: skip only when already inside *that
  exact* `neo-<project>` session (`neo_tmux_already_in_own_session()`); any other foreign
  session gets nested into its own dedicated mission session instead. New
  `test/neo-tmux-test.sh` (4).
- 2026-08-30 — **Found and fixed a second bug inside the Phase 56 fix itself (Phase 57):**
  Cursor's review flagged that the pure gate-function test never exercised the actual
  `exec tmux new-session` mechanics; building the missing integration test found that plain
  `new-session`/`attach` (undetached) fail outright when already inside another attached
  tmux client — tmux's own nested-session safety check — so the Phase 56 fix decided
  correctly to wrap but the wrap itself would have silently failed. Fixed with
  `tmux new-session -d` + `switch-client` whenever already inside some tmux client. New
  `test/neo-tmux-integration-test.sh` (5) — fully isolated tmux server, fakes a *genuinely
  attached* client via `script` (a bare detached session isn't enough to catch this — it's
  what let the bug slip through unnoticed initially). Docs synced: `$TMUX`-must-be-unset
  claims in AGENTS/README were stale, fixed; test counts corrected to 61/146; VPN profile
  path concern checked against the operator's actual filesystem — not currently an issue.

### Prompt 13 — Docs up to date? (→ Phase 31)

> kk are all colab docs updated and readmes and shit?

**Result:** Final sync — removed stale blocker notes; Phases 1–31 / Prompts 1–12 pointers aligned.

### Prompt 14 — Matrix boot + VPN ritual (→ Phase 32)

> actually lets make a change to Neo. when you first launch the program, have it greet you with some fun matrix/chasing the rabbit themed intro ascii or text or something. (maybe 5-10 seconds of coolness) before it launches into questions about cluade api and stuff. after selecting do a cool "AI MODEL CONFIRMED" ascii thing
>
> After that- NEO should look to determine if we're connect to an oVPN, if we are then do a cool **VPN CONNECTION DETECTED** in ASCII - let the user know and CONFIRM that they want to stay connected, or ask if they want Neo to connect to a new oVPN from the downloads folder?
>
> If the VPN we're connected to is confirmed then confirm with a cool ASCII, if we connect to a new one do then have it do an **ATTEMPTING TO CONNECT** and **NEW VPN CONNECTION CONFIRMED** type of thing before then asking for the IP to ping to confirm. if it needs the ip address earlier thats fine make it work as i describe.

**Result:** `lib/neo-boot.sh`, `lib/neo-vpn.sh`; `neo.sh` startup reordered; `htb-connect.sh` uses shared VPN helpers.

### Prompt 15 — Docs sync (→ Phase 33)

> make sure all collab and readme are up to date

**Result:** This pass — README, CLAUDE-COLLAB, AGENTS, CLAUDE, CURSOR-REVIEW-LOG through Phase 32/33.

### Prompt 16 — BORG concept + build (→ Phase 37)

> After AI analysis, new attack vectors need assimilating — tools, exploits, info. Make BORG that
> assimilates escalation paths, downloads tools, prepares next steps via claude -p. Button:
> **[A]ssimilate**. Cool ASCII. Human confirm before downloads.

**Result:** `lib/neo-borg.sh`, `borg/borg.sh`, **`[b]org assimilate`** at pauses (was **`[A]`** until Phase 48), Matrix HUD, gated
pacman/apt/git/pip, `BORG` notes section, `test/borg-test.sh`.

### Prompt 17 — Shared collective repo (→ Phase 37 addendum)

> It should definitely create a shared repo for all future neo use.

**Result:** Canonical dossiers in `knowledge/vectors/<slug>/`; project symlinks; `INDEX.yaml` +
auto `knowledge/README.md`; collective memory **[u]se** / **[r]e-assimilate**; prior collective
in Borg AI bundle.

### Prompt 18 — Docs sync to current model (→ Phase 38)

> pls review and all readmes and collab docs and make sure they're up to date with the current model

**Result:** This pass — README, AGENTS, CLAUDE, CLAUDE-COLLAB, CURSOR-REVIEW-LOG aligned with
BORG, knowledge collective, test counts (83 unit + 49 diagnostic), full lib layout.

### Prompt 19 — Payload suggest + analyze Borg (→ Phase 39)

> can we build into NEO a way to [s]uggest payload and an analy[z]e Borg outputs (which helps us
> determine what payload to suggest) that uses the claude -p and things learned from Borg
> assimilation process? and hit me with the suggest payload and analyze buttons after the recon
> stage but make them go away once we get our footholds. any time they are RELEVANT to have on
> the screen (like during priv esc) then have them there. otherwise, don't.

**Result:** `lib/neo-payload.sh`; pause **`[p]`** suggest · **`[z]`** analyze (was **`[S]`** until Phase 48 — **`[s]`/`[S]`** is skip-to-step only); phase gating via `neo_payload_has_foothold()`;
**PAYLOAD** notes section; `test/payload-test.sh`; diagnostic includes payload-test.

### Prompt 20 — Execute suggested payload + failure analysis (→ Phase 40)

> cool then a y/n prompt to execute the suggested payload. if it doesnt work ask if i want
> claude -p to analyze it.

**Result:** `neo_payload_execute_windup()` — **`[PAYLOAD:cmd]`** primary attempt with y/N;
captures stdout/stderr; on non-zero exit offers Claude failure analysis → **PAYLOAD** section.
Suggest prompt updated for `[PAYLOAD:]` tag. `[z]` analyze keeps generic Borg wind-up.

### Prompt 21 — Docs sync for Claude review (→ Phase 41)

> update all docs for claude reivew

**Result:** Full doc pass — README, AGENTS, CLAUDE, CLAUDE-COLLAB (pipeline v6), CURSOR-REVIEW-LOG
Phases 39–41; corrected counts (49 diagnostic · 83 unit).

### Prompt 22 — Borg research source index (→ Phase 42)

> Build a "start here" library of CVE/exploit/technique **resource directories** (not CVE data)
> for Borg to reference when researching vectors — deep search of CVE libraries, GitHub PoC
> indexes, and web resources; Cursor + Claude each produce a draft for merge.

**Result:** `knowledge/resources/borg_research_index.cursor.*` (Cursor) and
`borg_research_index.claude.*` (Claude, live-verified 2026-08-30). Complementary coverage:
Cursor broader (prioritization, vendor advisories, CLIs); Claude richer query patterns + HTB/CTF
indices. Drift caught: AttackerKB sunset → Rapid7 VulnDB; GTFOBins.org; packetstorm.news.

### Prompt 23 — Name + merge convention (→ Phase 42)

> yeah lets do borg_research_index and delete the original research files to prevent bloat
> after the merge

**Result:** Canonical **`borg_research_index.{yaml,md}`**; drafts deleted after merge.
Distinct from `knowledge/INDEX.yaml` (assimilated vectors).

### Prompt 24 — Docs sync after research index (→ Phase 43)

> update all the readmes and the collab files

**Result:** README, AGENTS, CLAUDE, CLAUDE-COLLAB, CURSOR-REVIEW-LOG — pipeline v7,
research index documented; co-lab agenda + files-to-read updated.

### Prompt 25 — Release v0.3 for Claude review (→ Phase 44)

> and update to v0.3 and ill have claude review.

**Result:** `VERSION` (`0.3`); `neo.sh --version`; diagnostic prints **NEO v0.3 — READY for Claude review**;
docs synced (README, CLAUDE, CLAUDE-COLLAB, AGENTS, CURSOR-REVIEW-LOG).

### Prompt 26 — IP prompt behavior (→ informational, no code)

> if i run neo without the IP will it prompt me for it?

**Result:** Documented: `neo.sh <project>` prompts for IP during boot (fresh) or via
`resolve_target_ip` on resume; cached `target=` in `project.meta` skips prompt.

### Prompt 27 — “Stuck” after babysteps at bundle build (→ Phase 46 diagnosis)

> seemed to get stuck here after babysteps… `Building mission bundle…` something broke?

**Result:** Not a bundle hang (~40ms). Was **`claude -p`** wait with poor UX. Led to stderr
progress lines and visible streaming output (Phase 46).

### Prompt 28 — Rabbit HUD request then revert (→ Phase 46)

> MUST do the analyzing ascii thing… ASCII rabbit that hops…

**Result:** Rabbit HUD added briefly, then **removed** per Prompt 29 — operator wanted live
`claude -p` text + countdown instead.

### Prompt 29 — Speed scan too fast / missing :3000 + triage UX revert (→ Phase 46)

> scan NOT finding :3000… too fucking fast… 30-60 sec per section… remove rabbit… visible
> claude -p… 90 second timer counting down

**Result:** Speed mode now runs **nmap -p- union** (~2–3 min); rabbit HUD removed; **90s stderr
countdown** + streamed `claude -p` output. See **Phase 46** in `CURSOR-REVIEW-LOG.md`.

### Prompt 30 — Changelog + Claude review brief (→ Phase 46 docs)

> update the change logs and give me a copy/pastable thing for claude to review

**Result:** Phase 46 log entry; this prompt log; operator-facing review brief in session output.

### Prompt 31 — Claude: Phase 46 review fixes + live nmap crash (→ Phase 47)

> can you fix all of these
>
> [terminal: nmap -p- hit 60s budget, then `neo: script failed in phase recon` with no error]
>
> my nmap failed which has never happened before. can u fix all of this and then update the
> changelog for cursor to review

**Result:** **Phase 47** — `babysteps.sh` pipefail/`grep` empty-result crash fixed (`|| true` on
port extractions); speed `nmap -p-` **90s + `-T4`**; Borg AI calls migrated to visible timer
runner; triage capture drops `2>&1` so stderr never pollutes saved markdown. See
`CURSOR-REVIEW-LOG.md` Phase 47.

### Prompt 32 — Collab doc sync after Phase 47 (→ this pass)

> yes that would be good to sync everything.

**Result:** Prompt 31 + Phase 47 bullets in `AGENTS.md`; test counts (90 unit / 50 diagnostic /
26 smoke); README speed-scan + triage notes; `CLAUDE.md` pointer updates.

### Prompt 33 — Cursor docs sync after Phase 48 (→ this pass)

> Claude reviewed neo.sh, fixed splash/--fresh, menu letters, shared pause extras — please
> docs-sync README, AGENTS, CLAUDE-COLLAB; sanity-check the refactor.

**Result:** All current-state docs updated to **`[b]org`** / **`[p]ayload`**; case-insensitive
menu rule documented; Phase 48 entry in logs; templates/registry/knowledge placeholders synced.

### Prompt 34 — Menu routing test + Phase 48 verification (→ Phase 49)

> Review Cursor's Phase 48 follow-up; build automated menu-routing test — diagnostic suite,
> not launch-time.

**Result:** **`lib/neo-menu.sh`** (`neo_menu_classify`); both `neo.sh` menu loops refactored;
**`test/menu-routing-test.sh`** (27) with drift guard; wired into diagnostic (**53** checks);
smoke worktree copy list fixed (`neo-borg`, `neo-payload`, `neo-menu`). Unit total **117**.

### Prompt 35 — Docs sync after Phase 49 (→ this pass)

> Sync docs for new test counts (53 diagnostic / 117 unit) and Phase 49 entries.

**Result:** README, AGENTS, CLAUDE, CLAUDE-COLLAB, CURSOR-REVIEW-LOG updated; `neo-menu.sh`
added to repo layout and co-lab file list.

### Prompt 36 — Cursor: Phase 51 review follow-up fixes (→ Phase 52)

> yes fix these mistakes and make a note about it in the collab logs and ill have claude review

**Context:** Cursor reviewed Claude's Phase 51 batch and flagged three gaps — dead Borg failure
hook, unwired `--no-tmux`, web detector missing `:3000`/babysteps SERVICES header.

**Result (Phase 52):**

- **`neo_borg_offer_failure_analysis()`** + **`neo_payload_analyze_command_failure()`** —
  Borg wind-up RUN/PAYLOAD failures now offer y/N Claude analysis (replaces dead
  `neo_payload_analyze_failure` call).
- **`neo.sh --no-tmux`** — sets `NEO_TMUX_WRAP=0` (README already documented it).
- **`neo_interact_detect_web()`** — ports 3000/5000/9000, `### Web —` SERVICES header,
  babysteps log strings, bare URLs.
- **`test/interact-test.sh`** (5) wired into diagnostic; payload-test +1 assertion.

**Verification:** `./test/neo-diagnostic.sh` — **59 ok** · unit **128 passed**.

**For Claude review — copy/paste:**

```
Review Cursor Phase 52 follow-up on your Phase 51 batch (~/Neo):

1. lib/neo-borg.sh — neo_borg_offer_failure_analysis() + project/phase through neo_windup_loop;
   confirm Borg wind-up failure path is wired correctly and doesn't double-prompt.
2. lib/neo-payload.sh — neo_payload_analyze_command_failure() vs neo_payload_analyze_failures_at_pause();
   shared neo_payload_failure_context_block(); any duplication or missing foothold_attempted gates?
3. neo.sh — --no-tmux branch; confirm it runs before neo_tmux_wrap_if_needed().
4. lib/neo-interact.sh — neo_interact_detect_web() heuristics (:3000, SERVICES header); false-positive risk?
5. test/interact-test.sh + payload-test assertion — coverage gaps?

Run: bash -n on changed files; ./test/neo-diagnostic.sh (expect 59 ok).

Log your verdict in CURSOR-REVIEW-LOG.md Phase 53 (or append to Phase 52) and note any fixes.
```

### Prompt 37 — Cursor: VPN hijack fix + ovpn-connect rename (→ Phase 54)

> weird. when i run neo.sh against htb-reactor its change my terminal to a vpn terminal
>
> [operator paste: OpenVPN tmux scrollback]
>
> yeah neo should only use htb-connect at the VPN stage … rename to ovpn-connect … ask y/n
> … otherwise never run the vpn connect script ever

**Result (Phase 54):**

- **Problem:** non-boot `neo_boot_vpn_flow()` called `htb-connect.sh` on resume when tun0
  looked down; `htb-connect` ends with `exec tmux attach` → terminal hijacked by VPN logs.
- **Fix:** renamed to **`connect/ovpn-connect.sh`**; added **`--no-attach`** for NEO boot;
  ovpn-connect invoked **only** during boot VPN ritual when VPN down + operator confirms
  Downloads prompt; non-boot paths never shell out to connect script.
- Docs/registry/phases.yaml synced.

**For Claude review — copy/paste:**

```
Review Cursor Phase 54 VPN fix (~/Neo):

1. lib/neo-boot.sh — neo_boot_vpn_flow(): confirm non-boot path never invokes ovpn-connect;
   boot path only calls ovpn-connect --no-attach after y/N Downloads prompt when tun0 down.
   Any edge cases (VPN up → user picks n/new → falls through to interactive picker without
   ovpn-connect — correct?)?
2. connect/ovpn-connect.sh — --no-attach vs default attach; any leak of attach into NEO path?
3. Deleted htb-connect.sh — grep for stale references; registry/phases/README consistent?
4. Operator UX: boot declined (N) returns 1 — right failure mode? Non-boot VPN-down hint
   only (no prompt) — sufficient?
5. neo-boot-test.sh still only covers VPN-already-up path — worth an offline test for
   non-boot no-invoke guard?

Run: bash -n connect/ovpn-connect.sh lib/neo-boot.sh; ./test/neo-boot-test.sh

Log verdict in CURSOR-REVIEW-LOG.md Phase 55 (or append to Phase 54).
```

### Prompt 38 — Cursor: Phase 58 TENTATIVE plan review (→ Phase 58, not implemented)

**Context:** After Phase 57 (switch-client), Cursor reviewed the tmux wrap work and found
three blocking issues: integration-test race, misleading “nested tmux” banner (leftover Phase
56 draft), and `--fresh` silently ignored when `neo-<project>` already exists (pre-Phase 51,
elevated now). Claude independently verified all claims read-only (6/6 test passes locally,
but agrees the race is real in code). Operator approved **Option A** for `--fresh`: kill and
recreate mission session.

**Full plan:** `PHASE-58-TENTATIVE-PLAN.md` (repo root)

**For Claude review — copy/paste:**

```
Review the TENTATIVE Phase 58 plan at ~/Neo/PHASE-58-TENTATIVE-PLAN.md (not implemented yet).

Confirm or challenge:
1. --fresh should kill neo-<project> when session exists (not when already inside it)
2. Normal resume still attach/switch-only — no behavior change
3. Integration test fix: client assertion timing + new --fresh replace case
4. Messaging: no "nested tmux" / "double-tap prefix"; switch-client described accurately
5. new-session -d / switch-client branded failure messages
6. Anything missing, over-scoped, or wrong in priority order?

After your review, log verdict in CURSOR-REVIEW-LOG.md (Phase 58 review section or append to Phase 57).
Do NOT implement until operator approves.
```

**Result (Phase 58 — Cursor implementation):**

- **`neo_tmux_args_want_fresh()`** — exact `--fresh` argv token match.
- **`--fresh` kill-and-recreate** — from outside mission session, kills `neo-<project>` before
  create path; never kills when already inside own session; never touches foreign sessions.
- **Branded errors** on `new-session -d` / `switch-client` failure.
- **Messaging** — "switch-client / foreign keeps running" replaces all "nested / double-tap"
  wording (`lib/neo-tmux.sh`, `AGENTS.md`, `README.md`, `CLAUDE-COLLAB.md`).
- **Integration test** — race fix (`remain-on-exit`), `--fresh` replace + inside-own-session
  negative case; dropped flaky `script` fake-attach (detached pane `$TMUX` exercises switch path).
- **`neo-tmux-test.sh`** — 3 `want_fresh` assertions (7 total).
- **VERSION** → v0.4.1. Diagnostic **61 ok / 0 fail** (3×); integration **12 assertions** (10×).

**Manual acceptance still pending:** M1–M5 from `PHASE-58-TENTATIVE-PLAN.md`.

**Result (Phase 59 — Cursor implementation):**

- Reinstated `script` fake-attach with **`TERM=xterm-256color`** (required on util-linux 2.42 /
  tmux 3.7 — without it attach fails with "terminal does not support clear").
- `attach_fake_client()` fail-fast; `list-clients` + pane grep (`neo: could not …`) assertions;
  dropped misleading fallthrough marker check.
- `neo_tmux_switch_client_or_die()` recovery message; `kill-session` error on `--fresh`.
- Negative regression verified: Phase 56 broken path → **6 failures**; correct code → **18/18 × 10**.
- **VERSION → v0.5**. Diagnostic **61 ok / 0 fail** (3×); unit **162** (integration 18).


