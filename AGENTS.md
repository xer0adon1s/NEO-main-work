# AGENTS.md — NEO pipeline spec

Read this before writing or modifying anything in this repo. This is the
rulebook for how tools integrate with automated reporting: every run should
leave a readable `Investigation-Notes.md`, a machine-glance `project.meta`,
and (when output is huge) files under `artifacts/`.

Keep entries concrete and short. Update `registry.yaml` and the
Extension log when you add a script.

## The four pieces

1. **`templates/investigation-notes.md`** — blank master template. Edit when
   the doc *structure* changes for all future projects. Never read during an
   engagement — only copied.
2. **`projects/<project>/Investigation-Notes.md`** — human-readable report for
   one box. Created on first `notes_init`, updated in place after. Hand-typed
   content must survive every later script run.
3. **`projects/<project>/project.meta`** — small key=value file (target, phase,
   last script, timestamp). Scripts update it; humans rarely edit it. Used by
   `status.sh` and the STATUS section blurb.
4. **`lib/notes-lib.sh`** (+ **`script-lib.sh`**) — plumbing. Section
   markers `<!-- SECTION:TAG --> ... <!-- /SECTION:TAG -->` let scripts
   surgically read/write one named section without touching the rest.

Also: **`projects/<project>/artifacts/`** — full raw output when a log entry
would be too large (see `notes_log_smart`).

Also: **`knowledge/vectors/<slug>/`** — Borg collective (canonical attack-vector
dossiers, shared across all missions). Tracked in git. Project
`assimilated/<slug>/` symlinks here. See `knowledge/README.md`.

Also: **`knowledge/resources/borg_research_index.{yaml,md}`** — hand-curated
**external research source catalog** (CVE DBs, PoC indexes, technique wikis).
Distinct from **`knowledge/INDEX.yaml`** (assimilated vector slugs). Borg should
consult the research index before ad-hoc web search; bundle wiring in `neo-borg.sh`
is planned.

## Pipeline phases

Scripts declare a phase in `registry.yaml`. Typical order:

```
connect → recon → service-enum → foothold → on-box-enum → privesc → post
```

| Phase | Examples |
|---|---|
| `connect` | connect/ovpn-connect.sh |
| `recon` | recon/babysteps.sh |
| `foothold` | foothold/ListenAssist.sh |
| `privesc` | privesc/run-findprivs.sh, run-linpeas.sh, … |
| `post` | *(future — looting, screenshots, writeups)* |

Set phase in `project.meta` via `meta_set phase <name>` or `cybersec_finish`.

## Script registry

**`registry.yaml`** lists every script: where it runs (local/target),
phase, section ownership, required tools, wrappers. Read it before adding a
script; add an entry when you're done.

Wrappers (`run-*.sh`) exist for on-target/third-party tools so you never
patch upstream — run the wrapper from your attack box, it SSHes (or pipes) and
files results through `notes-lib.sh`.

## Rule 1: local vs on-target

### Runs locally (attack box, access to `~/Neo`)

Examples: `babysteps.sh`, `ListenAssist.sh`, `status.sh`, `run-*.sh`

```bash
source "${NEO_HOME}/lib/script-lib.sh"
cybersec_need nmap tmux
cybersec_validate_project_name "${PROJECT_NAME}"
notes_init "${PROJECT_NAME}" "${TARGET}" "${OUTDIR}"   # if creating/extending project
# ... do work ...
cybersec_finish "<script>" "<phase>" "<one-line summary>" "<full raw output>"
```

- **Project argument:** optional positional, same style as existing scripts.
  Also accept `--project=name` and `--target=ip` for automation (see
  `cybersec_parse_common_flags` in `script-lib.sh`). Don't break positional
  behavior scripts already expose.
- **`notes_init`:** call when the script knows the target IP and may create
  a new project. If it has no target IP (ListenAssist), only write notes when
  `Investigation-Notes.md` already exists — never invent a bogus target.
- **Curated sections:** `notes_set_section` (one current answer) or
  `notes_append_section` (accumulates). Never edit the notes file with raw
  sed/awk from a script.
- **End of run:** always log raw output via `cybersec_finish` or
  `notes_log_smart` — LOG is the append-only source of truth; curated sections
  are the reader-friendly layer.

### Runs on-target (SSH, curl | bash — no `~/Neo`)

Examples: `FindPrivs.sh`, `linpeas.sh`

- Cannot source `notes-lib.sh`. No hardcoded project names.
- Document the attack-box wrapper in the script header and end-of-run reminder:
  ```
  ~/Neo/privesc/run-findprivs.sh <project> user@target
  ```
- **Structured output:** use `=== Section name ===` headers (FindPrivs already
  does). Ingest with:
  ```
  ssh user@target 'bash -s' < FindPrivs.sh | notes-lib.sh <project> ingest FindPrivs
  ```
- **Unstructured / huge output:** pipe to `log` or use `run-linpeas.sh`.

## Rule 2: section ownership

Only the **owner** may `set` a section. Non-owners **`append`** or write to
LOG only. Prevents clobber wars as the toolkit grows.

| Tag | Owner | Mode | Re-run behavior |
|---|---|---|---|
| `STATUS` | notes-lib (`notes_refresh_status`) | set | replaced each run |
| `PORTS` | babysteps | set | replace |
| `NMAP` | babysteps | set | replace |
| `SERVICES` | babysteps (+ future service scripts) | append | accumulate |
| `TODO` | any | append | accumulate (dedupe by hand) |
| `CREDS` | manual | set | human-owned |
| `FOOTHOLD` | manual | set | human-owned |
| `WHOAMI` | FindPrivs (ingest) | set | replace on ingest |
| `SUDO` / `SUID` / `CAPS` / `CRON` / `FILES` | FindPrivs (ingest) | set / append | see ingest map |
| `USERFLAG` / `ROOTFLAG` | manual | set | human-owned |
| `ATTACKPATH` | manual | set | human-owned |
| `LESSONS` | manual | append | human-owned |
| `AI-TRIAGE` | analyze-recon (+ manual paste) | append | accumulate; fed back into next triage bundle |
| `BORG` | borg/borg.sh | append | per-mission links; canonical dossiers in `knowledge/vectors/` |
| `PAYLOAD` | neo-payload (pause `[p]`/`[z]`) | append | Borg analysis, payload suggest, failure analysis |
| `WORKBENCH` | neo-workbench (pause `[t]`/`[o]`) | append | try/analyze loop, command attempts, captures |
| `ELI5` | neo-eli5 (pause `[e]`) | append | beginner-friendly command/evidence lessons |
| `REPORT` | neo-report (`[f]` post / mission end) | set | human-readable final report; artifact copy |
| `LOG` | every script | append | never dedupe |

`notes_set_section` / `notes_append_section` warn on stderr and return
non-zero if markers are missing. A `set` with no closing marker leaves the
file untouched.

Adding a new tag: edit `templates/investigation-notes.md` (marker pair),
add a registry + table row, extend ingest map if needed.

## Rule 3: artifacts and smart logging

- **`notes_log`** — always writes full content into LOG.
- **`notes_log_smart`** — if output exceeds `NOTES_LOG_MAX_LINES` (default
  100), saves full text to `artifacts/<source>-<timestamp>.txt` and logs a
  truncated preview + pointer. Use for babysteps findings, linpeas, etc.

## Rule 4: ingest maps

On-target scripts with `=== Header ===` blocks can be parsed into curated
sections. Default maps live in `notes-lib.sh` (`FindPrivs`) and
`registry.yaml`. Map syntax:

```
Header name:TAG          → set section TAG
Header name:+TAG         → append to TAG
```

Custom map as 4th CLI arg:
```
notes-lib.sh mybox ingest MyScript 'Custom header:WHOAMI,Other:+TODO' < out.txt
```

Ingest always also calls `notes_log_smart` with the full raw text.

## New script checklist

- [ ] Entry in `registry.yaml` (runs, phase, owns, requires)
- [ ] Local: sources `script-lib.sh`, calls `cybersec_finish` (or documented
      on-target wrapper + ingest/log)
- [ ] New section tags added to `templates/investigation-notes.md` if needed
- [ ] Section ownership row added to table above
- [ ] `README.md` updated if user-facing behavior changes
- [ ] Tested: first run, re-run, special chars in output, missing notes doc
- [ ] Run `./test/notes-lib-test.sh` after any `notes-lib.sh` change
- [ ] Legacy notes missing STATUS: `./tools/migrate-status.sh [project]`
- [ ] Extension log entry below (include operator prompt reference if from a session request)

When logging work triggered by the operator in Cursor chat, add a phase to
**`CURSOR-REVIEW-LOG.md`** with verbatim **Operator prompt(s)** blockquote(s) —
see Phase 19 convention in that file and **§ Operator prompt log** in `CLAUDE-COLLAB.md`.

## Testing

**Framework regression:**
```bash
./test/notes-lib-test.sh      # notes-lib + meta + ingest (21)
./test/recon-bundle-test.sh   # neo-ai bundle + triage parsing (18)
./test/borg-test.sh           # neo-borg helpers, collective index (12)
./test/payload-test.sh        # neo-payload suggest/analyze + Borg hook (18)
./test/interact-test.sh       # pre-foothold web detector (7)
./test/menu-routing-test.sh   # pause-menu letter routing via neo_menu_classify (27)
./test/neo-boot-test.sh       # VPN ritual stdout capture (3)
./test/neo-smoke-test.sh      # neo.sh integration (26)
./test/neo-diagnostic.sh      # full pre-review (59 checks)
```

**Legacy STATUS section:** `./tools/migrate-status.sh [project]`

**New script integration:**
1. Run against a scratch project; read `Investigation-Notes.md` in full.
2. Re-run — confirm no clobber of sections you don't own.
3. Pipe output with backslashes, backticks, and markdown fences — must survive
   (content goes through temp files, not `awk -v` string interpolation).

## Quick reference — notes-lib CLI

```
notes-lib.sh <project> init <target>
notes-lib.sh <project> set    <TAG>     < content
notes-lib.sh <project> append <TAG>     < content
notes-lib.sh <project> log    <source>  < content
notes-lib.sh <project> ingest <source> [map-spec]  < content
notes-lib.sh <project> status [summary line]
notes-lib.sh <project> meta-get  <key>
notes-lib.sh <project> meta-set  <key> <value>
```

**Glance at a project:** `./tools/status.sh` or `./neo.sh` (no args)

**Run a mission:** `./neo.sh <project> [target]`

On first boot of each mission (recon start), NEO runs the **boot sequence** on fresh
projects: rabbit intro → **A / B / C** → AI MODEL CONFIRMED → VPN ritual → lab ping.

| Choice | Mode |
|--------|------|
| **A** | Claude Pro/Max: `claude -p` subscription (pipes Investigation-Notes) |
| **B** | Claude API key: Console API via `analyze-recon.sh` |
| **C** | Neither: manual review (share `Investigation-Notes.md` with your assistant) |

Resume / `NEO_SPLASH=0` / `--no-splash` skips intro and VPN ASCII banners (A/B/C skipped if `ai_triage` already saved). **`--fresh`** still re-runs AI mode + VPN ritual but **respects** `NEO_SPLASH=0` for the decorative rabbit intro only.

Saved as `ai_triage=subscription|api|manual` in `project.meta`. **`[a]sk Claude`**
at any pause runs `claude -p` when Claude Code is installed.

**Pause menus** (every letter is case-insensitive — one meaning each):

| Group | Letter | Action |
|-------|--------|--------|
| Navigate | `[c]` | continue |
| | `[r]` | repeat phase |
| | `[s]` | skip to step |
| | `[k]` | skip phase |
| | `[q]` | quit |
| | `[d]` | deep enum (recon only) |
| Plan (AI) | `[b]` | Borg research (assimilate vector dossiers) |
| | `[p]` | payload suggestion (AI exact next command) |
| | `[a]` | ask AI (free-text) |
| | `[e]` | explain (ELI5) |
| Run | `[t]` | try it (operator pane) |
| | `[o]` | operator pane (shell focus) |
| | `[z]` | diagnose failure (foothold, after attempt) |
| Deliver | `[f]` | write report (post only) |

Menus are composed in workflow order: **plan → run → learn → deliver** (`neo_menu_compose_pause_extras` in `lib/neo-menu.sh`). **`[p]`** on recon, foothold (until shell), privesc, post; **`[t]`/`[o]`** on those phases; **`[z]`** foothold only after `foothold_attempted` or workbench try. Conductor nudges use the same letters (`NEO_CONDUCTOR=1`). Dispatch: **`neo_menu_classify()`**.

**Operator feedback (`NEO_FEEDBACK=1`, default):** pause letters that start work print an immediate
acknowledgement (`lib/neo-feedback.sh`); AI calls show a stderr progress bar + countdown
(`neo-ai-analyze.sh`); Borg keeps its ASCII HUD during assimilation. Disable with `NEO_FEEDBACK=0`.

**AI conductor (`NEO_CONDUCTOR=1`, default):** after recon triage, offers `[b]` Borg research
(if pending vectors, default Y) then `[p]` payload suggestion (default **n** — use pause menu).
Foothold/privesc entry offers `[p]` (default Y). Pause nudges list only visible letters in
workflow order. Design: `NEO-1.0-DESIGN/AI-CONDUCTOR.md`. Disable with `NEO_CONDUCTOR=0` or
`ai_triage=manual`.

**Operator workbench (P20):** NEO's conductor pane owns stdin during pauses — run suggested commands in the **operator tmux pane** (`[o]` then `[t]`), not by pasting into the menu. Safe single-line attack-box commands may run via typed argv (`local_safe` transport). Loop: suggest → try (y/N) → capture → AI analyze → repeat until foothold → `[c]` continues pipeline. See **`NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md`**.

**tmux auto-wrap (Phase 51, `lib/neo-tmux.sh`; skip-gate Phase 56; switch-client Phase 57; `--fresh` kill Phase 58):** real interactive launches (`-t 0 && -t 1`, `NEO_TMUX_WRAP` not `0`) re-exec `neo.sh` inside a named `neo-<project>` tmux session, right after project-name validation and before any heavy state (`OUTDIR`/`meta_init`) — so the wrapped process owns checkpoints. Skips wrapping only when already inside **that exact** `neo-<project>` session — **not** just "`$TMUX` is set." Being inside some other foreign tmux session (e.g. an OpenVPN session left over from `connect/ovpn-connect.sh`) is not "already wrapped": NEO **switches this terminal's view** to the mission session via `tmux new-session -d` + `switch-client` (the foreign session keeps running in the background; plain `new-session`/`attach` fail outright when already inside another tmux client — confirmed via `test/neo-tmux-integration-test.sh`). **`--fresh` with an existing `neo-<project>` session** (from outside that session) kills and recreates it so the wipe and current env-forwarding actually run; already inside the mission session → in-process wipe only. Normal resume (no `--fresh`) reattaches/switches only. Env vars a launching shell exported are **not** inherited by a fresh tmux session by default (confirmed empirically); `NEO_TMUX_ENV_FORWARD` explicitly forwards the relevant ones via `%q`-quoted prefixes on the re-exec command string. Manual exploit attempts need to happen in the same tmux session (new pane, `Ctrl-b %`) to be visible to Analyze Failures. Piped/non-interactive runs (tests, automation) never wrap.

**Pre-foothold check-in (Phase 51, `lib/neo-interact.sh`):** right before recon hands off to foothold, if an "interactable" was found (a web server today — `NEO_INTERACT_DETECTORS`, extensible), offers the operator a Y/N to manually explore and pipe findings back (free text, or **`[a]`** to ask Claude first) before foothold begins. Saved to the **`INTERACT`** notes section (`## Pre-Foothold Findings`). Framework, not web-specific — adding a future interactable is one name + a detect/rundown function pair.

**AI triage:** append-only **AI-TRIAGE**; prior triage fed back on re-runs. Live `claude -p` output + **90s stderr countdown** (`NEO_AI_TIMER=0`). Terminal brief + `[NEO]`/`[MANUAL]`/`[TOOL:name]` tags. Pre-review:
`./test/neo-diagnostic.sh`.

**BORG assimilation:** `./borg/borg.sh <project>` or **`[b]org assimilate`** at any pause.
Canonical dossiers live in **`knowledge/vectors/<slug>/`** (shared collective, committed to git).
Each mission symlinks `projects/<project>/assimilated/<slug>/` → collective. Re-assimilating
updates the collective; existing slugs offer **[u]se** (link only) or **[r]e-assimilate**.

**Wind-up model:** Borg prepares each step but executes nothing without operator **y/N** —
distro package installs, `[RUN:command]` probes, `[NEO:...]` commands. PoC repos are
**manual** (describe in dossier; operator clones after review). Technique docs avoid
ready-to-paste payloads. Scan data from the target may be adversarial — verify independently.
`NEO_BORG_HUD=0` disables ASCII.

**Payload suggest (`[p]`, redesigned Phase 51):** advisory only — no auto-execute. Operator picks
a tool from a picker (Borg manifest names first, then a generic fallback list, each flagged
installed/not); Claude writes back one exact copy-paste command for that tool (plus alternates)
under **`## Exact next command`** — the operator runs it themselves. **`[z]` analyze failures**
(foothold, after a first attempt) reviews what's been tried — NEO's own **LOG** tail, plus a tmux
terminal-log capture of manual attempts outside NEO when available (`neo_tmux_save_capture`,
saved to `artifacts/terminal-log-<ts>.txt`) — and recommends a concrete next step. Both save to
**PAYLOAD**. The old `[PAYLOAD:]`/`[RUN:]` y/N execute-loop is gone from Suggest; Borg's own
wind-up loop for **`[b]` Assimilate with Borg** is unchanged and separate.

## Extension log

- 2026-08-30 — Initial framework: template + notes-lib + babysteps +
  ListenAssist + FindPrivs docs.
- 2026-08-30 — Pipeline v3: all scripts under `neo/`; neo.sh MVP; ssh_target;
  setup.sh → neo/vendor/ (now `neo/setup.sh`).
- 2026-08-30 — Root cleanup: no root README; all docs in `neo/README.md`.
- 2026-08-30 — **Corrected:** restored thin root README, CLAUDE, AGENTS, setup.sh
  wrappers (clone/agent discoverability); canonical content stays in `neo/`.
- 2026-08-30 — **UI:** Matrix launch splash (`lib/neo-splash.sh`, `assets/`) +
  recon progress HUD (`lib/neo-hud.sh`); `NEO_SPLASH` / `NEO_HUD` env overrides.
- 2026-08-30 — **Claude AI triage:** `analyze-recon.sh` after babysteps; curated
  bundle → `AI-TRIAGE` section; `lib/neo-ai.sh`; `choice: all` recon phase.
- 2026-08-30 — **Speed vs deep recon:** babysteps `--speed` (default, 60s budgets,
  no nmap -p-/nikto) vs `--deep`; `[d]` at recon pause or `--deep-recon`.
- 2026-08-30 — **Anthropic workspace:** identity-linked Console keys need
  `anthropic-workspace-id` header; `~/.config/neo/anthropic.workspace`;
  `neo_ai_verify_setup()` tests API at recon start and prompts for `wrkspc_...`;
  `tools/neo-claude-setup.sh`.
- 2026-08-30 — **Manual AI mode + checkpoints:** Y/n prompt (superseded by A/B/C Phase 28);
  `neo_checkpoint` resume; `[s]` skip-to-step; `[k]` skip phase.
- 2026-08-30 — **Collab prompt logging:** phase entries in CURSOR-REVIEW-LOG +
  CLAUDE-COLLAB § Operator prompt log include verbatim operator prompts (Phase 19).
- 2026-08-30 — **AI triage persistence:** append `AI-TRIAGE`; bundle refer-back (Phase 21).
- 2026-08-30 — **Pre-review diagnostic:** `test/neo-diagnostic.sh` (Phase 20).
- 2026-08-30 — **AI triage UX:** ANALYZING HUD, technical brief, `[TOOL:]` install
  offers; `lib/neo-ai-analyze.sh` (Phase 22).
- 2026-08-30 — **lib/ pollution fix:** `tools/neo-lib-cleanup.sh`; startup warn (Phase 26).
- 2026-08-30 — **AI mode A/B/C:** subscription (`claude -p`), API key, or manual at first
  boot; `[a]sk Claude` at pauses; `lib/neo-ai-cli.sh` (Phase 28).
- 2026-08-30 — **babysteps stub (Phase 27)** — resolved Phase 30; diagnostic integrity check.
- 2026-08-30 — **babysteps restored** with `--speed`/`--deep`; diagnostic content check (Phase 30).
- 2026-08-30 — **Claude model ID** updated to `claude-sonnet-4-6` (Phase 30).
- 2026-08-30 — **First-launch boot:** rabbit intro, AI MODEL CONFIRMED, VPN ritual
  (`lib/neo-boot.sh`, `lib/neo-vpn.sh`); `htb-connect.sh` refactored (Phase 32).
- 2026-08-30 — **BORG assimilation:** `borg/borg.sh`, `lib/neo-borg.sh`; `[A]ssimilate` (→ **`[b]org`** Phase 48)
  at pauses; shared collective `knowledge/vectors/`; project symlinks; wind-up permission model.
- 2026-08-30 — **Payload assistant:** `lib/neo-payload.sh`; `[S]` suggest (→ **`[p]`** Phase 48) + `[z]` analyze Borg;
  phase-gated pause menus; **PAYLOAD** section (Phase 39).
- 2026-08-30 — **Payload execute loop:** `[PAYLOAD:]` y/N execution; Claude failure analysis
  on non-zero exit (Phase 40).
- 2026-08-30 — **`borg_research_index`:** merged Cursor + Claude external research catalog
  at `knowledge/resources/` — 12 categories, 77 sources, live-verified 2026-08-30 (Phase 42).
- 2026-08-30 — **Release v0.3:** `VERSION` file; `neo.sh --version`; diagnostic version banner (Phase 44).
- 2026-08-30 — **Speed scan reliability:** default `--speed` now runs **nmap -p- union** with
  ~45s/step budgets (~2–3 min); fixes rustscan missing ports on HTB VPN (Phase 46).
- 2026-08-30 — **Operator feature batch:** `[b] Assimilate with Borg` rename; `[z]` retargeted to
  **analyze failures** (foothold-only, gated on a first attempt, tmux terminal-log capture);
  `[a]sk Claude` now takes a free-text question + last `NEO_ASK_CONTEXT_LINES` (800) lines of
  notes as context; `[p]ayload suggest` redesigned to advisory tool-picker (no auto-execute);
  tmux auto-wrap (`lib/neo-tmux.sh`) so terminal capture is reliable; pre-foothold check-in
  framework (`lib/neo-interact.sh`, `INTERACT` section) (Phase 51).
- 2026-08-30 — **AI triage UX:** removed rabbit HUD; **live `claude -p` output** + **90s stderr
  countdown**; progress lines on stderr (Phase 46).
- 2026-08-30 — **babysteps pipefail fix:** empty port-scan grep no longer aborts recon under
  `set -euo pipefail`; speed `nmap -p-` **90s / `-T4`** (Phase 47).
- 2026-08-30 — **AI capture hygiene:** triage/Borg/payload runners capture stdout only — stderr
  visible live but not saved to Investigation-Notes (Phase 47).
- 2026-08-30 — **Borg assimilate UX parity:** `[b]org assimilate` uses same visible timer runner as
  recon triage (Phase 47; menu letter `[b]` since Phase 48).
- 2026-08-30 — **Pause menu cleanup (Phase 48):** `[A]`→`[b]org`, `[S]`→`[p]ayload`; all pause
  letters case-insensitive; `neo_compute_pause_extras()` shared by both menus; `--fresh` respects
  `NEO_SPLASH=0` for rabbit intro only.
- 2026-08-30 — **Menu routing test (Phase 49):** `lib/neo-menu.sh` (`neo_menu_classify`); both
  pause menus dispatch through it; `test/menu-routing-test.sh` (27); smoke worktree copy list fixed
  (`neo-borg`, `neo-payload`, `neo-menu`). Diagnostic **53** checks · unit **117** passed.
- 2026-08-30 — **Phase 51 follow-up (Phase 52):** Borg wind-up failure analysis re-wired
  (`neo_borg_offer_failure_analysis` → `neo_payload_analyze_command_failure`); `--no-tmux` in
  `neo.sh`; web detector expanded (:3000, SERVICES header); `test/interact-test.sh` (5).
  Diagnostic **59** checks · unit **128** passed.
- 2026-08-30 — **Release v0.4:** Phases 46–53 — tmux auto-wrap, `[a]` ask / `[b]` Borg / `[p]` payload /
  `[z]` analyze failures, pre-foothold check-in, menu routing test, AI/timer fixes; ship all `lib/neo-*`
  modules (were gitignored since v0.3). Diagnostic **59** · unit **132**.
- 2026-08-30 — **VPN hijack fix (Phase 54):** `htb-connect` → `ovpn-connect`; `--no-attach` for
  NEO boot ritual only; non-boot paths never invoke connect script.
- 2026-08-30 — **Phase 54 review (Phase 55):** approved; `neo-boot-test.sh` expanded (8 tests).
- 2026-08-30 — **tmux wrap skip-gate fix (Phase 56):** `neo_tmux_already_in_own_session()` —
  foreign tmux session no longer skips wrap; only exact `neo-<project>` match skips.
- 2026-08-30 — **switch-client fix (Phase 57):** `new-session -d` + `switch-client` when already
  inside a tmux client; integration test (`test/neo-tmux-integration-test.sh`).
- 2026-08-30 — **tmux `--fresh` + test/docs (Phase 58):** `--fresh` kills stale `neo-<project>`
  session from outside; switch-client messaging corrected; integration test race fixed + `--fresh`
  cases; branded wrap errors.
- 2026-08-30 — **Integration test validity fix (Phase 59):** reinstated `script` fake-attach with
  `TERM=xterm-256color`; `list-clients` + pane grep assertions; `kill-session` error on `--fresh`;
  switch-client recovery message. Diagnostic **61** checks · unit **162** passed. **v0.5**.
- 2026-08-31 — **Operator workbench (P20 / Tier 2.5):** `lib/neo-operator-pane.sh` +
  `lib/neo-workbench.sh`; pause `[t]ry` / `[o]perator shell`; suggest→try→capture→analyze loop;
  `WORKBENCH` notes section; mission `foothold_attempt` hooks; design in
  `NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md`.
- 2026-08-31 — **Toolkit preflight (Tier 3.14):** `lib/neo-toolkit.sh` LOCK & LOAD checks
  tools, SecLists/wordlist paths, vendor files after suggest/triage; optional install before `[t] try`.
- 2026-08-31 — **Attack plan waves 1–4:** post workbench, pipeline hooks (`neo-pipeline-hooks.sh`),
  MSF handler in ListenAssist, mission handler_plan stub, neo-vendor install/rollback, new tests.
- 2026-08-31 — **ELI5 tutor (`[e]`):** `lib/neo-eli5.sh` — educational mode at pauses; explains
 evidence, suggestions, and command flags before the operator runs them; **ELI5** notes section;
 optional prompt after payload suggest and workbench analyze.
- 2026-08-31 — **Borg multi-vector + payload integration (Phase 64):** `[b]org` menu gated when
 all enum/triage vectors assimilated; multi-pick (`a`, `1,3`) assimilation; `[p]` Borg-guided
 mode (option 0) pipes dossiers + wind-up actions into AI suggest; ELI5 after suggest unchanged.
- 2026-08-31 — **Borg library disclosure (Phase 65):** post-assimilate payload hook; multi-slug
 focus picker; STATUS Borg blurb; red-herring skip; `neo-borg-disclosure.sh` + check tool;
 `knowledge/library/` scaffold; design `BORG-RESEARCH-LIBRARY.md`.
- 2026-08-31 — **Final report (Phase 67):** `lib/neo-report.sh` — educational book-report vs
 professional pentest deliverable; `[f]` at post phase; mission-end prompt; `--report` flag;
 `REPORT` section + `artifacts/final-report-*.md`.
- 2026-08-31 — **Borg library ingest (Phase 66):** `tools/borg-library-ingest.sh`, walkthrough
 schema, seed entries in `knowledge/library/`; scope intake → `engagement_mode` in meta;
 professional reports pull library CVE cross-refs; educational report hard-fail on disclosure lint.
- 2026-08-31 — **AI conductor (Tier A / Phase 69):** `lib/neo-conductor.sh` — unified mission bundle,
 proactive Borg→payload sequencing after triage; foothold/privesc phase hooks; pause nudges;
 design `NEO-1.0-DESIGN/AI-CONDUCTOR.md`.
- 2026-08-31 — **Operator feedback (Phase 71):** `lib/neo-feedback.sh` — ack on pause letters;
 AI timer progress bar; wired through `neo.sh` pause menus + conductor offers.
- 2026-08-31 — **AI conductor tuning (Phase 70):** pause menu labels + workflow groups
  (plan/run/learn/deliver); conductor letter-aligned Y/n prompts; dedupe payload offers per phase.
- 2026-08-31 — **Borg library AI harvest (Phase 68):** `lib/neo-borg-library-ai.sh`;
 `--research` drives Claude + `borg_research_index`; mechanical fetch is context-only;
 `borg_research_index` wired into Borg assimilate bundle.
- 2026-08-31 — **Tier B conductor automation (Waves 1–2):** `neo-conductor-loop.sh` workbench
  playbooks (guided/educational vs assisted/professional), variable loop cap, batch failure review;
  `neo-conductor-privesc.sh` AI triage; `neo-handler-pane.sh` pane C; Borg library hook;
  `test/conductor-automation-test.sh`.
- 2026-08-31 — **Tier B Wave 3:** `neo-adaptive-scan.sh` targeted deep enum; `neo-operator-recon-ai.sh`
  structure operator text; MSF AI post suggest; babysteps `--targets-file`; locked decisions
  #6–8 (enum no-remove, aggressive deferred, P08 wave 4).
- 2026-08-31 — **Tier B Waves 4–5:** `neo-ai-guard.sh` disclosure lint on triage/Borg/payload/ELI5;
  `neo_provider_web_research_bundle_block`; Borg v2 JSON (`neo-borg-v2.sh`, `borg/borg-v2.sh`);
  batch library harvest (`neo-borg-library-batch.sh`, harvest `--batch`); `test/p18-lab-e2e.sh` harness.
- 2026-08-31 — **Phase 63 batch:** Borg HUD spam fix; SCOPE/PROGRESS/CURRENT-STATE doc sync;
