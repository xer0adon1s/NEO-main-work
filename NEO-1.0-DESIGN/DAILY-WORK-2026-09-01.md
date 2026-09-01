# NEO Daily Work — 2026-09-01

> **Start here tomorrow.** Canonical workload for continuing development after the
> 2026-08-31 sprint, code review, doc-truth pass, and partial live dry-run.
>
> **Prior doc:** `NEO-CODE-REVIEW-2026-08-31.md` (Blocks A–H — many items done; see below)  
> **Dry-run evidence:** `DRY-RUN-TRACE-2026-08-31.md`  
> **Status board:** `FEATURE-STATUS.md`

---

## Executive summary (read first)

| Signal | Verdict |
|--------|---------|
| **Offline tests** | `./test/run-all.sh` green (39 suites after setup-baseline) |
| **Live AI (`claude -p`)** | **Verified** — analyze-recon triage completed, saved to notes (`dryrun-sim-01`) |
| **Live recon orchestration** | **Verified** — babysteps against `192.0.2.1`, expected empty ports, no crash |
| **LOCK & LOAD toolkit** | **Verified live** — awk fix at `neo-toolkit.sh:104` |
| **Full mission loop** | **Not verified** — dry-run stopped mid-ELI5; foothold/privesc/post/`[b]`/`[t]`/`[o]`/`[f]` still open |
| **Live VPN smoke (`scratch-tierb-test`)** | **Shelved → later phase** — offline verify green 2026-09-01; run with VPN + real HTB target when Block H opens (see `FEATURE-STATUS.md` § Deferred verification) |
| **Piped-input automation** | **Do not use** for E2E — wrong tool; see § Dry-run methods |
| **Tmux send-keys dry-run** | **Works** — already ran once; resume/extend, don't reinvent |

**Bottom line:** NEO is credible for a **real HTB session with VPN up**. Finish the
dry-run (or first real box) to sign off `[b]`/`[t]`/`[o]`/mission-complete before
calling Tier A/B "integrated."

---

## Dry-run methods compared (Cursor + Claude reconciliation)

Two different approaches ran on 2026-08-31 evening. **Do not conflate them.**

| | **Claude (tmux send-keys)** | **Cursor (piped stdin)** |
|---|---------------------------|--------------------------|
| **How** | `./neo.sh` auto-wraps into tmux; agent reads `capture-pane`, sends keys | `script < inputs.txt` or pipe into neo.sh |
| **TTY** | Real interactive session | stdin often not a TTY → **tmux self-wrap disabled** (`lib/neo-tmux.sh:20-24`) |
| **`[o]` / `[t]`** | Can exercise (inside tmux) | Fails: "not inside tmux" |
| **Prompt handling** | Adaptive — responds to what NEO actually asks | Blind letter sequence — **desyncs** on Y/n hooks, Borg vectors, SSH prompts |
| **Result** | Boot, scope, recon, real `claude -p` triage, toolkit — **success** | Partial; died at privesc when `c` ran `run-findprivs` and got no `user@host` |
| **Verdict** | **Correct E2E harness pattern** — extend this | **Wrong for E2E** — fine for `neo-smoke-test.sh` stub missions only |

**Cursor correction:** "Not worth automating with a pipe-driven agent" applies to
**pipes only**. Tmux-driven dry-run already worked in one pass; **resume it** (same
project `dryrun-sim-01` or fresh `192.0.2.1` target) rather than deprioritizing E2E
automation entirely.

### Menu input reference (keep for any future harness)

| Input | Context | Meaning |
|-------|---------|---------|
| `c` | **pause_after** menu (recon done, privesc done) | Continue to next phase |
| `c` | **pause_before** menu (foothold, privesc script pick) | **Runs script 1** — not continue! |
| `k` | pause_before | Skip phase |
| `s` | recon pause_after | Skip-to-step (phase jump) — **not** "skip Borg" |
| `f` | post pause only | Final report (needs AI on PATH) |
| `n` | pipeline Y/n hooks | Decline optional hook (plan-enum, privesc rank, etc.) |

---

## Convergent finding — bump priority: first-boot VPN gate

**Both** Claude's live run and Cursor's analysis hit this independently.

- **Where:** `neo.sh:1170-1175`, `lib/neo-boot.sh` `neo_boot_vpn_flow()`
- **What:** On `--fresh` / first boot, declining VPN (`N` at connect prompt) **hard-exits**
  even when target IP is already on the CLI (`192.0.2.1`, local lab, etc.).
- **Workaround today:** Re-run same project **without** `--fresh` after AI mode + target
  cached in `project.meta` → boot sequence skipped → non-fatal VPN warning only.
- **Decision needed (tomorrow Block 0):**
  - **A)** Intentional for HTB/THM — document workaround in `AGENTS.md` + E2E checklist
  - **B)** Add `--no-vpn` or `NEO_BOOT_VPN_RITUAL=0` escape for offline/synthetic targets
  - **C)** If CLI target supplied + educational scope, soft-skip VPN ritual on first boot

**Not a blocker for real HTB** (VPN will be up). **Is a blocker for cheap synthetic dry-runs**
unless workaround documented or flag added.

---

## Live-verified tonight (update FEATURE-STATUS when signed off)

| Feature | Evidence |
|---------|----------|
| AI triage via `claude -p` | `projects/dryrun-sim-01/Investigation-Notes.md` → AI Triage section |
| Recon / babysteps orchestration | `BabySteps-findings.txt`, empty ports on 192.0.2.1 |
| Scope intake | `~/.local/state/neo/projects/dryrun-sim-01/engagement-scope.json` |
| LOCK & LOAD preflight | Live `[ok] nmap` during dry-run |
| Boot + AI mode selection | `project.meta` → `ai_triage=subscription` |

**Still unverified live:** `[b]` Borg, `[t]`/`[o]` workbench, `[p]`, `[e]` ELI5 complete,
`[f]` report, foothold → privesc → post, mission-complete offer, conductor stubs.

---

## Code tweak already applied (2026-08-31 late)

- `lib/neo-tmux.sh` — forward `NEO_STATE_ROOT` in `NEO_TMUX_ENV_FORWARD` so isolated
  state dirs survive tmux re-exec (Cursor finding; helps future harnesses).

---

## What's already done from `NEO-CODE-REVIEW-2026-08-31.md`

| Block | Status |
|-------|--------|
| **A** Operator hygiene | A2/A3 largely done (`run-all` green, `setup.sh --check` 15/15 vendor) |
| **B** Doc truth | **Done** — `FEATURE-STATUS.md`, recap/tier docs, `doc-truth-check.sh` |
| **C–G** Integration / polish | **Not started** — tomorrow's main work |
| **H** Integration smoke | **Partial** — dry-run covered recon + AI only |

---

## Tomorrow's workload (ordered)

### Block 0 — Decisions + resume dry-run (1–2 hr) **START HERE**

- [ ] **0.1** Decide VPN gate: document workaround (A) vs `--no-vpn` flag (B) — see above
- [ ] **0.2** Resume `dryrun-sim-01` **or** fresh project on `192.0.2.1`:
  ```bash
  cd /home/alexander/Work/NEO-main-work-review
  ./neo.sh dryrun-sim-01          # resume (skips boot/VPN ritual)
  # OR with VPN connected for full fresh-boot path:
  ./neo.sh dryrun-sim-02 192.0.2.1 --fresh
  ```
- [ ] **0.3** Complete recon pause menu: `[b]` → `[t]`/`[o]` → `[p]` → `[c]` → foothold
- [ ] **0.4** Foothold: `[k]` skip or run ListenAssist; privesc/post: `[k]` skip or minimal
- [ ] **0.5** Confirm mission-complete + report offer — no crash (`neo-report.sh:63`)
- [ ] **0.6** Append results to `DRY-RUN-TRACE-2026-08-31.md` or new trace section

**Harness note:** Use tmux send-keys + capture-pane (Claude method), not piped stdin.

### Block A — Operator hygiene (15 min)

- [ ] **A1.** Confirm `claude` on PATH (`claude -p` for subscription mode — no API key needed)
- [ ] **A2.** `./test/run-all.sh` → 0 failures
- [ ] **A3.** `./test/neo-diagnostic.sh` + `./setup.sh --check`

### Block C — Conductor integration (3–4 hr)

From review doc — unchanged priority after dry-run proves mechanical wiring:

- [ ] **C1.** Flesh out `neo_conductor_on_phase_entry` per `AI-CONDUCTOR.md`
- [ ] **C2.** Wire `neo_conductor_after_triage` from `neo-ai-cli.sh`
- [ ] **C3.** Implement `neo_conductor_on_event` cases (triage, borg, privesc ingest)
- [ ] **C4.** Assisted loop opt-in only
- [ ] **C5.** Expand `neo_conductor_build_bundle`
- [ ] **C6.** `test/conductor-test.sh`, `conductor-automation-test.sh`

### Block D — Borg library + disclosure (3–4 hr)

- [ ] **D1–D5** Per `NEO-CODE-REVIEW-2026-08-31.md` Block D
- [ ] **Priority:** `[b]` live verification depends on this + dry-run resume

### Block E — Report + feedback (2 hr)

- [ ] **E1.** Implement `neo_report_generate` (currently stub `neo-report.sh:58-61`)
- [ ] **E2.** `[f]` on post + mission-complete offer end-to-end

### Block F — Workbench + MSF polish (2 hr)

- [ ] **F1–F4** Per review doc
- [ ] **Priority:** `[t]`/`[o]` live in tmux — confirm pane model A/B/C

### Block G — P2 hardening (as time allows)

- [ ] **G1–G6** Per review doc

### Block H — Real lab E2E (when VPN available)

Use `NEO-1.0-DESIGN/E2E-CHECKLIST.md` — 3 HTB boxes. Synthetic dry-run is **not**
a substitute; it's the cheap preflight before burning lab time.

### Block I — Changelog / session log naming (1–2 hr, doc hygiene)

**Goal:** One uniform convention for agent/session/dev logs across the repo — no more
ad-hoc `CURSOR-REVIEW-LOG`, `CLAUDE-COLLAB`, `DAILY-RECAP-*`, `DRY-RUN-TRACE-*` mix.

- [ ] **I1.** Pick convention (draft below — adjust tomorrow if you prefer):
  - **Pattern:** `Changelogs_<SOURCE>[_<topic>].md` (lowercase dir optional: `changelogs/`)
  - **Examples:**
    | Current | Proposed |
    |---------|----------|
    | `CURSOR-REVIEW-LOG.md` | `Changelogs_CURSOR.md` |
    | `CLAUDE-COLLAB.md` | `Changelogs_CLAUDE.md` |
    | `NEO-1.0-DESIGN/DAILY-RECAP-2026-08-31.md` | `Changelogs_CURSOR_daily-2026-08-31.md` or `changelogs/daily-2026-08-31.md` |
    | `NEO-1.0-DESIGN/DRY-RUN-TRACE-2026-08-31.md` | `Changelogs_CLAUDE_dry-run-2026-08-31.md` |
    | `NEO-1.0-DESIGN/CURSOR-SESSION-UPDATE-*.md` | `Changelogs_CURSOR_session-2026-08-31.md` |
    | `NEO-1.0-DESIGN/NEO-CODE-REVIEW-*.md` | `Changelogs_CLAUDE_code-review-2026-08-31.md` |
  - **Rule of thumb:** `<SOURCE>` = `CURSOR` \| `CLAUDE` \| `NEO` (operator/tool); optional
    `_<topic>` = snake or kebab date/topic slug. All caps source segment for quick `ls Changelogs_*`.
- [ ] **I2.** Inventory every review/recap/trace/collab file in repo root + `NEO-1.0-DESIGN/`
- [ ] **I3.** Rename (or move under `changelogs/`) + leave stub redirects at old paths for one release, or grep-update all references in `AGENTS.md`, `ATTACK-PLAN.md`, `doc-truth-check.sh`, etc.
- [ ] **I4.** Add one-line convention to `AGENTS.md` (where phase logging is documented) so future entries use the new names only
- [ ] **I5.** Optional: extend `tools/doc-truth-check.sh` to flag non-conforming log filenames

**Do not start tonight** — list only; implement tomorrow after convention sign-off.

---

## Suggested session arc (single day)

1. **Morning:** Block 0 (finish dry-run) + Block A  
2. **Midday:** Block C or D (pick one — conductor *or* Borg, not both half-done)  
3. **Afternoon:** Block E or F + update `FEATURE-STATUS.md` for anything live-verified  
4. **Slack time:** Block I (changelog rename pass) — can slip to next session if lab runs long  
5. **Evening (VPN):** Block H Box 1 from E2E checklist — **deferred** (see `FEATURE-STATUS.md` § Deferred verification; not until later live-lab phase)

---

## Files to read before coding

1. `FEATURE-STATUS.md` — don't overclaim "implemented"
2. `DRY-RUN-TRACE-2026-08-31.md` — what's already live-proven
3. `NEO-CODE-REVIEW-2026-08-31.md` — Blocks C–G detail
4. `AI-CONDUCTOR.md` + `OPERATOR-WORKBENCH.md` — integration targets
5. `projects/dryrun-sim-01/Investigation-Notes.md` — real AI output sample

---

## Do not repeat

- ❌ Piped stdin "logic sim" against real `neo.sh` with tmux features enabled
- ❌ Treat Cursor pipe failure as "NEO can't E2E"
- ❌ `--fresh` dry-run on `192.0.2.1` without VPN decision/workaround
- ❌ Commit `projects/dryrun-sim-01/` or `knowledge/vectors/*LOGIC-SIM*` unless intentional
- ❌ Rename changelog files ad hoc without Block I convention agreed first
