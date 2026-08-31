# NEO 1.0 — Full Scope & Tier Status

**Updated:** 2026-08-31  
**Shipped version:** `0.5` (`VERSION`) · **Target:** `1.0.0-rc`  
**Vision:** [`MISSION-STATEMENT.md`](MISSION-STATEMENT.md) — NEO orchestrates the **whole engagement**; Metasploit is one tool among many.

This is the long-form status board. For item checkboxes see [`HARD-CODE-BACKLOG.md`](HARD-CODE-BACKLOG.md).

---

## Status legend

| Label | Meaning |
|-------|---------|
| **Complete** | Integrated in production tree; unit tests exist; expected to pass on Linux lab |
| **Prototyped** | Code landed and partially wired; not lab-validated or design gaps remain |
| **Incomplete** | Started; significant work still open |
| **Not started** | Design/docs only, or blocked on lab validation |
| **Deferred** | Explicitly post-1.0 |

---

## Overall picture

| Tier | Name | Overall |
|------|------|---------|
| 0 | Core dependencies | **Complete** |
| 1 | P0 safety | **Complete** |
| 2 | P1 workflows | **Complete** (helpers exist but some not pipeline-wired) |
| 2.5 | Operator workbench | **Prototyped** |
| 3 | Release polish | **Incomplete** |
| 4 | P2 hardening | **Not started** |
| 5 | Post-1.0 / GUI | **Deferred** |

**What blocks `1.0.0-rc`:** P18 lab E2E on 3 HTB boxes (Tier 3.13), operator sign-off, VERSION bump (3.12). Linux lab required — Windows work PC cannot run bash suites.

---

# TIER 0 — Core dependencies

Foundation libraries, schemas, bootstrap, and release gates. Everything else depends on this tier.

## 0.A — Shared primitives & bootstrap

| ID | Component | Path | Status | Notes |
|----|-----------|------|--------|-------|
| C0 | Shared primitives | `lib/neo-core.sh` | **Complete** | Project name validation, secure tmp, die helpers |
| C13 | Bootstrap loader | `lib/neo-1.0-bootstrap.sh` | **Complete** | Sources all CORE libs in order |
| C13 | Entry wiring | `neo.sh` (early source) | **Complete** | Bootstrap before heavy state |

## 0.B — Secrets & credential safety

| ID | Component | Path | Status | Notes |
|----|-----------|------|--------|-------|
| C1 | Secret broker | `lib/neo-secrets.sh` | **Complete** | `~/.config/neo/secrets/` 600 files |
| C2 | Gitignore patterns | `.gitignore` | **Complete** | `.env`, `.env.*`, `*.pem`, `*.key` |
| C3 | AI key via broker | `lib/neo-ai.sh` | **Complete** | No repo `.env` sourcing |
| C4 | Tmux no key forward | `lib/neo-tmux.sh` | **Complete** | API keys removed from `NEO_TMUX_ENV_FORWARD` |

## 0.C — Evidence & provenance

| ID | Component | Path | Status | Notes |
|----|-----------|------|--------|-------|
| C5 | Evidence JSONL | `lib/neo-evidence.sh` | **Complete** | Append-only events under state dir |
| — | Notes pipeline | `lib/notes-lib.sh` | **Complete** | v0.5; section markers, LOG, artifacts |
| — | Investigation template | `templates/investigation-notes.md` | **Complete** | Includes WORKBENCH section (1.0) |

## 0.D — Typed actions & JSON schemas

| ID | Component | Path | Status | Notes |
|----|-----------|------|--------|-------|
| C6 | Action executor | `lib/neo-actions.sh` | **Complete** | Schema-validated local commands |
| C6 | Action policy | `schemas/action-policy.json` | **Complete** | Whitelist paths, network rules |
| C6 | Supporting schemas | `schemas/*.json` (7 files) | **Complete** | dossier, service, privesc-facts, vendor, workbench |
| — | Wind-up argv bridge | `lib/neo-windup-actions.sh` | **Complete** | Borg `[RUN:]` → typed argv (Tier 1) |

## 0.E — Mission state machine

| ID | Component | Path | Status | Notes |
|----|-----------|------|--------|-------|
| C7 | State machine | `lib/neo-mission-state.sh` | **Complete** | `preflight → recon → … → complete` |
| — | State persistence | `~/.local/state/neo/projects/<p>/mission.json` | **Complete** | Parallel to legacy `project.meta phase` |
| — | MSF session adapter | mission.json session fields | **Not started** | P21 / Tier 4 — meterpreter/shell tracking |

## 0.F — Engagement scope policy

| ID | Component | Path | Status | Notes |
|----|-----------|------|--------|-------|
| C8 | Scope checks | `lib/neo-scope.sh` | **Complete** | CIDR validation; educational vs professional |
| — | Scope schema | `schemas/engagement-scope.schema.json` | **Complete** | |
| — | State file | `engagement-scope.json` per project | **Complete** | Created by intake/import |

## 0.G — AI provider abstraction

| ID | Component | Path | Status | Notes |
|----|-----------|------|--------|-------|
| C9 | Provider layer | `lib/neo-provider.sh` | **Complete** | `anthropic-api` + `claude-cli` adapters |
| — | Subscription mode | `lib/neo-ai-cli.sh` | **Complete** | `[a]sk Claude` at pauses |
| — | API mode | `lib/neo-ai.sh`, `neo-ai-analyze.sh` | **Complete** | Routed through provider |

## 0.H — Test infrastructure & release gates

| ID | Component | Path | Status | Notes |
|----|-----------|------|--------|-------|
| C10 | Production integrity gate | `test/production-integrity-gate.sh` | **Complete** | Stub checks, eval ban, lib presence |
| C11 | Test aggregate | `test/run-all.sh` | **Complete** | CORE + v0.5 + 1.0 suites |
| C12 | Diagnostic hook | `test/neo-diagnostic.sh` | **Complete** | 61 checks (v0.5 baseline) |
| — | CORE unit tests | `test/core-secrets-test.sh`, `mission-state-test.sh` | **Complete** | |

---

# TIER 1 — P0 safety

Eliminate command injection and secret leakage from AI/Borg execution paths.

## 1.A — Command injection elimination

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 1.2 | Injection payload tests | `test/injection-payload-test.sh` | **Complete** | `; rm -rf /` rejected |
| 1.3 | Borg eval removal | `lib/neo-borg.sh` | **Complete** | Wind-up → `neo-windup-actions.sh` |
| 1.4 | Payload action JSON only | `lib/neo-payload.sh` | **Complete** | No auto-execute loop; advisory suggest |
| — | Integrity gate eval check | `production-integrity-gate.sh` | **Complete** | No eval/bash -c in borg/payload/windup |

## 1.B — Secret exposure prevention

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 1.1 | Secret canary tests | `test/secret-canary-test.sh` | **Complete** | Canary must not appear in notes/artifacts |
| 1.8 | Secret CLI | `tools/neo-secret.sh` | **Complete** | store / remove / audit / redact |
| — | Tmux forward audit | gate + `neo-tmux.sh` | **Complete** | No API keys in env forward list |

## 1.C — AI call hardening

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 1.5 | AI CLI → provider | `lib/neo-ai-cli.sh` | **Complete** | |
| 1.6 | AI analyze → provider | `lib/neo-ai-analyze.sh` | **Complete** | stderr live; stdout saved |
| 1.7 | analyze-recon → provider | `recon/analyze-recon.sh` | **Complete** | Bundle → AI-TRIAGE section |

---

# TIER 2 — P1 workflows

Scope intake, stub replacement, Borg v2, VPN consent, recon/privesc helper scripts.

## 2.A — Engagement scope intake (P13)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.1 | Interactive wizard | `tools/scope-intake.sh` | **Complete** | [E]ducational / [P]rofessional |
| 2.2 | Policy import | `tools/scope-import.sh` | **Complete** | From `templates/scope-policy-template.md` |
| 2.3 | neo.sh bootstrap | `neo.sh` `neo_scope_ensure` | **Complete** | Before phase walk |
| 2.11 | Scope workflow test | `test/workflow-scope-test.sh` | **Complete** | |

## 2.B — Foothold & listener (P02)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.4 | ListenAssist full script | `foothold/ListenAssist.sh` | **Complete** | ncat/nc/socat; ~170 lines; in pipeline |
| — | Integrity gate stub check | gate | **Complete** | Passes substantive marker |
| — | MSF handler pairing | ListenAssist + msfconsole | **Not started** | P21 — `exploit/multi/handler` workflow |

## 2.C — Post-foothold enum / FindPrivs (P03)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.5 | FindPrivs wrapper | `privesc/run-findprivs.sh` | **Complete** | SSH / ingest / existing-shell |
| — | On-target script | `privesc/FindPrivs.sh` | **Complete** | v0.5; unchanged |
| — | Notes ingest map | `notes-lib.sh` | **Complete** | WHOAMI, SUDO, SUID, etc. |

## 2.D — Borg assimilation (P04)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.6 | Borg v2 JSON pipeline | `borg/borg-v2.sh` | **Complete** | Dossier schema; no execution |
| 2.6 | `--v2` flag | `borg/borg.sh --v2` | **Complete** | Delegates to borg-v2 |
| — | Borg v1 at pause menu | `lib/neo-borg.sh` | **Complete** | `[b]` assimilate — legacy vector flow |
| — | Live web research | Borg capability flag | **Deferred** | Default off; post-1.0 |
| — | Research index auto-consult | `knowledge/resources/borg_research_index.*` | **Prototyped** | Index exists; runtime wiring TBD |

## 2.E — VPN lifecycle & consent (P10)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.7 | VPN consent | `lib/neo-vpn-consent.sh` | **Complete** | k/a/q before killing OpenVPN |
| 2.7 | VPN patch | `lib/neo-vpn.sh` | **Complete** | Uses consent, not blind pkill |
| — | Boot ritual connect | `lib/neo-boot.sh`, `connect/ovpn-connect.sh` | **Complete** | v0.5; `--no-attach` for boot only |

## 2.F — Recon & service enumeration helpers (P07, P15)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.8 | Operator recon intake | `recon/operator-recon.sh` | **Prototyped** | Script complete; **not wired** into `neo.sh` phase walk |
| 2.9 | Service enum planner | `recon/plan-enum.sh` | **Prototyped** | Emits action JSON; **not auto-invoked** after babysteps |
| 3.3 | Enum plan reviewer | `recon/review-plan.sh` | **Prototyped** | Interactive review/execute; **standalone only** |
| — | Core recon pipeline | `recon/babysteps.sh` | **Complete** | v0.5; speed/deep; in phases.yaml |
| — | AI triage | `recon/analyze-recon.sh` | **Complete** | v0.5 + provider (Tier 1) |
| — | Pre-foothold interact | `lib/neo-interact.sh` | **Complete** | Web detector; INTERACT section |

## 2.G — Privesc workflow helpers (P17)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.10 | FindPrivs normalizer | `privesc/normalize-findprivs.sh` | **Prototyped** | → `privesc-facts.json`; manual invoke |
| 2.10 | Privesc ranker | `privesc/rank-privesc-plan.sh` | **Prototyped** | Ranked hypotheses; **not surfaced** at privesc pause |
| — | Privesc pipeline scripts | `run-linpeas.sh`, `run-linenum.sh` | **Complete** | v0.5 wrappers; in phases.yaml |
| 2.12 | Integrity gate stubs | gate | **Complete** | ListenAssist + FindPrivs pass |

---

# TIER 2.5 — Operator workbench (core product loop)

The main NEO 1.0 product differentiator: suggest → verify → try → capture → analyze → repeat.

## 2.5.A — Design & documentation

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.5.1 | Design hub | `NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md` | **Complete** | Universal loop every phase |
| 2.5.1 | P20 project spec | `projects/20-operator-workbench/` | **Complete** | |
| — | Mission statement | `MISSION-STATEMENT.md` | **Complete** | Full engagement conductor vision |

## 2.5.B — Operator tmux pane

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.5.2 | Operator pane lib | `lib/neo-operator-pane.sh` | **Complete** | send-keys, capture, pane ensure |
| — | Tmux auto-wrap | `lib/neo-tmux.sh` | **Complete** | v0.5 Phase 51–59; switch-client, `--fresh` |
| — | Auto-SSH to target | operator pane | **Deferred** | Operator opens SSH manually today |

## 2.5.C — Try / analyze orchestration

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.5.3 | Workbench loop | `lib/neo-workbench.sh` | **Complete** | Extract command, classify transport, capture |
| — | Transport modes | workbench | **Complete** | `local_safe`, `operator_pane`, `manual_only` |
| — | Mission hooks | workbench + mission-state | **Complete** | `foothold_attempt`, `session_established` |
| — | Post phase `[t]`/`[o]` | `neo_workbench_visible_phase` | **Incomplete** | Currently recon/foothold/privesc only — post pause exists but workbench menu hidden |

## 2.5.D — Pause menu integration

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.5.4 | `[t]ry` / `[o]perator shell` | `lib/neo-menu.sh`, `neo.sh` | **Complete** | Via `neo_workbench_handle_choice` |
| 2.5.4 | Widened `[z]` analyze | `lib/neo-payload.sh` | **Complete** | After any workbench attempt |
| — | Menu routing tests | `test/menu-routing-test.sh` | **Complete** | 27 tests |
| — | Payload suggest hook | `lib/neo-payload.sh` | **Complete** | Advisory tool picker; no auto-run |

## 2.5.E — Notes & state persistence

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.5.5 | WORKBENCH section | `templates/investigation-notes.md` | **Complete** | Append-only attempt log |
| 2.5.5 | Attempt schema | `schemas/workbench-attempt.schema.json` | **Complete** | |
| 2.5.5 | Session schema | `schemas/workbench-session.schema.json` | **Complete** | |
| — | Attempt JSON files | `~/.local/state/neo/.../workbench/attempts/` | **Complete** | Per-try record |

## 2.5.F — Unit tests

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.5.6 | Workbench tests | `test/workbench-test.sh` | **Complete** | |
| 2.5.6 | Integrity gate libs | `production-integrity-gate.sh` | **Complete** | operator-pane, workbench present |

## 2.5.G — Lab validation

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 2.5.7 | E2E try→analyze loop | `E2E-CHECKLIST.md` | **Not started** | 3 HTB boxes; home Linux only |
| — | Session adapter | reverse shell → workbench target | **Prototyped** | `neo_operator_pane_offer_session_connect` |

---

# TIER 3 — Release polish

Docs, vendor tooling, toolkit preflight, MSF foundation, version bump, E2E gate.

## 3.A — Documentation truth (P12)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 3.1 | Doc truth checker | `tools/doc-truth-check.sh` | **Prototyped** | Verifies key files exist; lab pass not recorded |
| 3.7 | Design doc alignment | WORKFLOW-MAP, P02–P18, etc. | **Complete** | P20 core loop reflected |
| 3.8 | Manifest updates | `MASTER-MANIFEST.yaml` | **Complete** | P20; P21 in progress |
| 3.10 | run-all integration | `test/run-all.sh` | **Complete** | Includes doc-truth-check |

## 3.B — Vendor & tool acquisition (P11)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 3.2 | Vendor manifest CLI | `tools/neo-vendor.sh` | **Prototyped** | inventory / verify / init / install-vendor |
| 3.2 | Manifest file | `vendor/manifest.json` | **Prototyped** | Schema present; may be empty until populated |
| — | Per-tool install | `neo-vendor install <name>` | **Not started** | Design in P11; only `./setup.sh` wrapper today |
| — | Rollback | `neo-vendor rollback` | **Not started** | Design only |

## 3.C — Enumeration plan review (P15)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 3.3 | Plan reviewer | `recon/review-plan.sh` | **Prototyped** | Review [r] / execute [e] / skip [s] |
| — | Pipeline auto-hook | neo.sh after babysteps | **Not started** | plan-enum output not consumed automatically |

## 3.D — Release artifacts

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 3.4 | Release notes | `RELEASE-NOTES.md` | **Prototyped** | Draft for 1.0-rc |
| 3.5 | Known limitations | `KNOWN-LIMITATIONS.md` | **Complete** | |
| 3.6 | E2E checklist | `E2E-CHECKLIST.md` | **Complete** | Written; runs not done |
| 3.11 | Registry entries | `registry.yaml` | **Complete** | Tier 3 tools registered |
| 3.9 | Integrity gate | gate | **Complete** | workbench, toolkit, exploit-framework libs |

## 3.E — Toolkit LOCK & LOAD (3.14)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 3.14 | Toolkit preflight | `lib/neo-toolkit.sh` | **Prototyped** | Parse commands for bins/paths/[TOOL:] tags |
| — | After suggest/triage | `neo-payload.sh`, `neo-ai-analyze.sh` | **Complete** | "Verify tools & wordlists? [Y/n]" |
| — | Before `[t]` try | `neo-workbench.sh` | **Complete** | Default Y |
| — | Install offers | toolkit | **Prototyped** | pacman/apt, SecLists clone, setup.sh |
| — | Unit tests | `test/toolkit-test.sh` | **Complete** | |
| — | Lab validation | operator box | **Not started** | SecLists path rewrite untested on real box |

## 3.F — Exploit framework foundation (P21)

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 3.15 | MSF detection & AI context | `lib/neo-exploit-framework.sh` | **Prototyped** | When MSF applies — not MSF-centric product |
| — | MSF in tool picker | `neo-payload.sh` | **Complete** | Alongside nmap, gobuster, etc. |
| — | MSF install in toolkit | `neo-toolkit.sh` | **Complete** | metasploit package mapping |
| — | Unit tests | `test/exploit-framework-test.sh` | **Complete** | Offline detection + classify |
| — | Handler + ListenAssist | P21 | **Not started** | Guided handler workflow |
| — | Post-phase MSF menu | P21 | **Not started** | Post modules via workbench |
| — | Meterpreter session adapter | P21 | **Prototyped** | `neo_mission_record_msf_session` + post menu |
| — | MSF resource script runner | P21 | **Not started** | |
| — | Module search automation | P21 | **Not started** | Beyond AI-suggested `search cve:` |

## 3.G — Version & E2E release gate

| ID | Item | Path | Status | Notes |
|----|------|------|--------|-------|
| 3.12 | VERSION bump | `VERSION` | **Not started** | Still `0.5`; target `1.0.0-rc` |
| 3.13 | P18 lab E2E | `E2E-CHECKLIST.md` | **Not started** | 3 boxes: web foothold, service enum, privesc |
| — | Full test aggregate pass | `test/run-all.sh` + diagnostic | **Not started** | Not recorded on Linux lab this session |

---

# TIER 4 — P2 hardening (not started)

Lower priority; extends 1.0 after release gate. Items inferred from design docs and deferred lists — not yet numbered in backlog.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 4.1 | Wire `plan-enum` → `review-plan` after babysteps | **Not started** | P15 pipeline integration |
| 4.2 | Surface privesc ranker at privesc pause | **Not started** | P17 UX |
| 4.3 | Wire `operator-recon.sh` before Borg handoff | **Not started** | P07 |
| 4.4 | Workbench `[t]`/`[o]` on **post** phase | **Not started** | `neo_workbench_visible_phase` gap |
| 4.5 | Session adapter (shell → operator pane target) | **Prototyped** | P16 + P21 |
| 4.6 | `neo-vendor install <tool>` + rollback | **Not started** | P11 full design |
| 4.7 | Borg live web research adapter | **Not started** | Capability flag; post-1.0 candidate |
| 4.8 | P21 full MSF conductor (handler, post, sessions) | **Not started** | Beyond 3.15 foundation |

---

# TIER 5 — Post-1.0 (deferred)

| Item | Project | Status | Notes |
|------|---------|--------|-------|
| GUI 2.0 boundary doc | P19 | **Deferred** | API shapes; no GUI code in 1.0 |
| NEO 2.0 GUI | OD-014 | **Deferred** | After stable CLI interfaces |
| Auto-SSH operator pane | KNOWN-LIMITATIONS | **Deferred** | |
| Borg research auto-consult | KNOWN-LIMITATIONS | **Deferred** | |

---

# v0.5 baseline (shipped — pre-1.0 tier work)

These existed before the 1.0 integration waves and remain operational.

## Pipeline & conductor

| Component | Path | Status |
|-----------|------|--------|
| Main entry | `neo.sh` | **Complete** |
| Phase data | `phases.yaml` | **Complete** | recon → foothold → privesc → post |
| Script registry | `registry.yaml` | **Complete** |
| Checkpoints / resume | `neo_checkpoint` in neo.sh | **Complete** |
| Skip phase / skip to step | `[k]`, `[s]` menus | **Complete** |

## Recon phase

| Component | Path | Status |
|-----------|------|--------|
| Port scan | `recon/babysteps.sh` | **Complete** | speed (default) / deep |
| AI triage | `recon/analyze-recon.sh` | **Complete** |
| AI mode A/B/C | `lib/neo-boot.sh` | **Complete** | subscription / API / manual |
| Deep enum `[d]` | babysteps `--deep-recon` | **Complete** |

## Borg, payload, interact

| Component | Path | Status |
|-----------|------|--------|
| Borg v1 assimilate | `borg/borg.sh`, `lib/neo-borg.sh` | **Complete** |
| Payload suggest `[p]` | `lib/neo-payload.sh` | **Complete** | Advisory redesign Phase 51 |
| Analyze failures `[z]` | `lib/neo-payload.sh` | **Complete** | Foothold; after first attempt |
| Pre-foothold interact | `lib/neo-interact.sh` | **Complete** | Web detector |

## UX & environment

| Component | Path | Status |
|-----------|------|--------|
| Matrix splash | `lib/neo-splash.sh` | **Complete** |
| Recon HUD | `lib/neo-hud.sh` | **Complete** |
| Pause menu routing | `lib/neo-menu.sh` | **Complete** | Case-insensitive letters |
| Tmux wrap | `lib/neo-tmux.sh` | **Complete** | Phases 56–59 |
| Boot / VPN ritual | `lib/neo-boot.sh`, `lib/neo-vpn.sh` | **Complete** |

## Testing (v0.5 suites)

| Suite | Path | Tests | Status |
|-------|------|-------|--------|
| notes-lib | `test/notes-lib-test.sh` | 21 | **Complete** |
| recon bundle | `test/recon-bundle-test.sh` | 18 | **Complete** |
| borg | `test/borg-test.sh` | 12 | **Complete** |
| payload | `test/payload-test.sh` | 18 | **Complete** |
| interact | `test/interact-test.sh` | 7 | **Complete** |
| menu routing | `test/menu-routing-test.sh` | 27 | **Complete** |
| neo boot | `test/neo-boot-test.sh` | 8 | **Complete** |
| neo smoke | `test/neo-smoke-test.sh` | 26 | **Complete** |
| tmux | `test/neo-tmux-test.sh` + integration | — | **Complete** |
| neo diagnostic | `test/neo-diagnostic.sh` | 61 checks | **Complete** |
| **Total unit + diagnostic** | | **~162+** | Verify on Linux |

---

# Pipeline phases — step-by-step status

Maps end-to-end engagement flow. "Target" = 1.0 design intent; "Today" = current repo.

## Phase 0 — Bootstrap

| Step | Today | Target | Status |
|------|-------|--------|--------|
| Project name validation | neo.sh | neo_core | **Complete** |
| Engagement scope (E/P) | scope-intake | engagement-scope.json | **Complete** |
| AI mode A/B/C | neo-boot | provider + broker | **Complete** |
| tmux wrap (no secrets) | neo-tmux | same | **Complete** |
| mission.json init | neo_mission_bootstrap | state machine | **Complete** |
| Checkpoint resume | project.meta + checkpoint | mission.json primary | **Prototyped** | Both coexist |

## Phase 1 — Connect (VPN)

| Step | Today | Status |
|------|-------|--------|
| tun0 detection | neo-vpn.sh | **Complete** |
| OpenVPN consent (k/a/q) | neo-vpn-consent | **Complete** |
| Boot-only connect | ovpn-connect `--no-attach` | **Complete** |
| Not a walked phase | phases.yaml | **Complete** | By design |

## Phase 2 — Recon

| Step | Today | Status |
|------|-------|--------|
| babysteps speed/deep | pipeline | **Complete** |
| AI triage | analyze-recon | **Complete** |
| Pause menu extras | [d][a][b][p][t][o] | **Complete** |
| operator-recon intake | standalone script | **Prototyped** | Not auto-offered |
| plan-enum → review-plan | standalone | **Prototyped** | Not wired |
| LOCK & LOAD after suggest | neo-toolkit | **Prototyped** |

## Phase 3 — Borg (pre-foothold)

| Step | Today | Status |
|------|-------|--------|
| `[b]` Borg v1 | pause menu | **Complete** |
| Borg v2 JSON | `--v2` flag | **Complete** |
| Wind-up safe argv | neo-windup-actions | **Complete** |
| Research index | knowledge/resources | **Prototyped** | Manual consult |

## Phase 4 — Exploit / foothold

| Step | Today | Status |
|------|-------|--------|
| ListenAssist | pipeline one_of | **Complete** |
| Workbench [p][t][o][z] | recon/foothold/privesc | **Prototyped** | Lab E2E pending |
| MSF when relevant | exploit-framework hints | **Prototyped** | Foundation only |
| MSF handler workflow | — | **Not started** | P21 |
| Shell confirm → session_established | workbench hook | **Complete** | Code path exists |

## Phase 5 — Post-foothold enum

| Step | Today | Status |
|------|-------|--------|
| run-findprivs | pipeline | **Complete** |
| linpeas / linenum wrappers | pipeline | **Complete** |
| Evidence + notes ingest | notes-lib | **Complete** |

## Phase 6 — Privesc

| Step | Today | Status |
|------|-------|--------|
| FindPrivs curated sections | ingest | **Complete** |
| normalize + rank scripts | manual | **Prototyped** |
| Workbench validation tries | [t] at pause | **Prototyped** |
| MSF local modules when justified | AI hints | **Prototyped** |

## Phase 7 — Post-exploitation

| Step | Today | Status |
|------|-------|--------|
| Post phase in phases.yaml | conductor-guided | **Complete** | No automated scripts |
| [p][t] workbench on post | — | **Incomplete** | Post pause exists; [t]/[o] hidden |
| Flags / creds sections | manual notes | **Complete** |
| Mission → complete | mission state | **Prototyped** | Operator-driven |

---

# Projects P01–P21 (detailed)

| ID | Title | Priority | Overall | Production deliverables | Remaining |
|----|-------|----------|---------|----------------------|-----------|
| **P01** | Baseline & traceability | P0 | **Complete** | WORKFLOW-MAP, traceability YAML, discrepancies | None (docs) |
| **P02** | ListenAssist | P1 | **Complete** | Full `ListenAssist.sh` in pipeline | MSF handler pairing (P21) |
| **P03** | Post-foothold / FindPrivs | P1 | **Complete** | Wrapper + ingest + on-target script | — |
| **P04** | Borg assimilation | P1 | **Prototyped** | v1 pause + v2 JSON `--v2` | Live research; v2 as default? |
| **P05** | Secrets | P0 | **Complete** | Broker, gitignore, neo-secret CLI, canary tests | — |
| **P06** | Safe actions | P0 | **Complete** | neo-actions, windup bridge, schemas | Scope enforcement on every action (partial) |
| **P07** | Operator recon intake | P1 | **Prototyped** | `operator-recon.sh` | Wire into recon handoff |
| **P08** | AI provider | P1 | **Complete** | neo-provider; all AI libs routed | — |
| **P09** | Test integrity | P0 | **Complete** | integrity gate, run-all, diagnostic hook | — |
| **P10** | VPN consent | P1 | **Complete** | neo-vpn-consent + patch | — |
| **P11** | Tool acquisition | P2 | **Prototyped** | neo-vendor inventory/verify/init | Per-tool install, rollback |
| **P12** | Doc / release truth | P1 | **Prototyped** | doc-truth-check.sh | CI/lab pass recorded |
| **P13** | Engagement scope | P1 | **Complete** | intake, import, neo.sh gate, schema | — |
| **P14** | Evidence & notes | P1 | **Complete** | evidence JSONL + notes-lib | Optional EVIDENCE-INDEX section |
| **P15** | Service enumeration | P1 | **Prototyped** | plan-enum, review-plan | Pipeline auto-hook |
| **P16** | Mission / session state | P1 | **Prototyped** | mission.json state machine | MSF session adapter |
| **P17** | Privesc workflow | P1 | **Prototyped** | normalizer, ranker | Surface at pause; workbench integration |
| **P18** | CLI 1.0 validation | P1 | **Not started** | E2E-CHECKLIST written | 3 lab boxes + sign-off |
| **P19** | GUI 2.0 boundary | P3 | **Deferred** | DESIGN.md only | All GUI work post-1.0 |
| **P20** | Operator workbench | P1 | **Prototyped** | Full core loop integrated | Lab E2E; post phase [t]/[o] |
| **P21** | Exploit framework (MSF when relevant) | P1 | **Prototyped** | neo-exploit-framework foundation | Handler, post, sessions |

---

# Recommended next coding (priority order)

1. **Post phase workbench** — show `[t]`/`[o]` on post pause (Tier 4.4; quick win)
2. **P21 handler + ListenAssist** — MSF when that step needs it (Tier 4.8)
3. **Pipeline wire plan-enum** after babysteps (Tier 4.1)
4. **Privesc ranker at pause** (Tier 4.2)
5. **P18 E2E** on home Linux when available (Tier 3.13)

---

# Home lab verification commands

```bash
./test/run-all.sh
./test/neo-diagnostic.sh
./tools/doc-truth-check.sh
./test/workbench-test.sh
./test/toolkit-test.sh
./test/exploit-framework-test.sh
./neo.sh <project> <target>   # interactive: [p], [t], [o], [z]
# Full sign-off: NEO-1.0-DESIGN/E2E-CHECKLIST.md
```
