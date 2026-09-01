# NEO 1.0 — End-of-Day Attack Plan

**Created:** 2026-08-31  
**Goal:** Move every open item to **Complete** or **Prototyped** by end of session.  
**Operator says go → execute waves in order without re-planning.**

---

## Success definition (EOD)

| Target | Meaning for today |
|--------|-------------------|
| **Complete** | Code integrated, unit tests added/updated, backlog `[x]`, integrity gate expects it |
| **Prototyped** | Code integrated, may lack lab E2E — backlog `[~]`, documented in SCOPE-STATUS |
| **Blocked** | Requires home Linux + HTB VPN — stays **Not started** but checklist + scripts ready |

**Honest constraint:** Work PC is Windows — bash suites are written here, **verified on home Linux tonight or later**. P18 (3 HTB boxes) cannot reach Complete today from this machine.

**Version bump (`3.12` → `1.0.0-rc`):** Operator decision **after** Linux smoke pass — not automatic EOD.

---

## Current gaps → EOD targets

| Gap | Start | EOD target | Wave |
|-----|-------|------------|------|
| Post phase `[t]`/`[o]` hidden | Incomplete | **Complete** | 1 |
| plan-enum not auto-offered | Prototyped | **Complete** (opt-in hook) | 2 |
| operator-recon not offered | Prototyped | **Complete** (opt-in hook) | 2 |
| privesc ranker not at pause | Prototyped | **Complete** (opt-in hook) | 2 |
| MSF handler + ListenAssist | Not started | **Prototyped** | 3 |
| MSF session adapter | Not started | **Prototyped** (stub fields) | 3 |
| Post-phase MSF AI context | Not started | **Prototyped** | 3 |
| neo-vendor `install <name>` | Not started | **Prototyped** | 4 |
| neo-vendor rollback | Not started | **Prototyped** (stub) | 4 |
| P21 resource script runner | Not started | **Prototyped** (minimal) | 3 |
| Tier 4 items 4.1–4.4 | Not started | **Complete** via waves 1–2 | 1–2 |
| Tier 4 items 4.5–4.8 | Not started | **Prototyped** via wave 3 | 3 |
| P18 E2E 3 boxes | Not started | **Blocked** — checklist only | 5 |
| Toolkit/doc-truth lab pass | Not started | **Blocked** — tests ready | 5 |
| VERSION 1.0.0-rc | Not started | **Blocked** — operator after lab | 5 |

---

## Execution waves (~6–8 hours agent time)

### Wave 1 — Quick wins: universal loop on post (≈45 min)

**Objective:** Tier 4.4 + Tier 2.5.C gap closed.

| Task | Files | Done when |
|------|-------|-----------|
| Add `post` to `neo_workbench_visible_phase` | `lib/neo-workbench.sh` | `[t]`/`[o]` show on post pause |
| Confirm payload `[p]`/`[z]` already on post | `lib/neo-payload.sh` | verify `neo_payload_menu_fragment` |
| Unit tests: post phase menu fragment | `test/workbench-test.sh`, `test/menu-routing-test.sh` | tests pass on Linux |
| Update SCOPE-STATUS 2.5.C + Phase 7 | docs | post = Complete |

**Acceptance:** Post pause prompt includes `[t]ry` / `[o]perator shell` same as privesc.

---

### Wave 2 — Pipeline hooks: recon + privesc helpers (≈2 h)

**Objective:** Tier 4.1, 4.2, 4.3 — wire standalone scripts into conductor with **Y/n opt-in** (NEO wind-up model).

#### 2A — plan-enum after recon scripts

| Task | Files | Done when |
|------|-------|-----------|
| After babysteps (+ analyze-recon if run), offer plan-enum | `neo.sh` or `recon/babysteps.sh` tail | `[Y/n] Generate service enum plan?` |
| Run `recon/plan-enum.sh` → state dir actions | existing script | JSON actions under project state |
| Offer review-plan if plan dir non-empty | `neo.sh` recon pause or post-babysteps | `[Y/n] Review enum plan?` |
| Log to notes SERVICES/TODO | `notes-lib.sh` append | pointer in Investigation-Notes |
| Test: plan-enum hook (mock/non-interactive) | new `test/plan-enum-hook-test.sh` | **Complete** |

#### 2B — operator-recon before foothold handoff

| Task | Files | Done when |
|------|-------|-----------|
| After interact check-in, offer operator-recon | `neo.sh` (recon→foothold block) | `[Y/n] Capture operator recon notes?` |
| Invoke `recon/operator-recon.sh --project` | existing | evidence + notes |
| Test stub | `test/workflow-scope-test.sh` or new | **Complete** |

#### 2C — privesc ranker at privesc pause

| Task | Files | Done when |
|------|-------|-----------|
| Before privesc script menu, if FindPrivs ingested | `neo.sh` walk_phase privesc | detect WHOAMI/SUDO sections or facts file |
| Offer normalize + rank | call normalize + rank scripts | print top 3 hypotheses |
| Optional `[Y/n] Save ranked plan to notes` | notes append ATTACKPATH or TODO | **Complete** |
| Test | `test/privesc-rank-hook-test.sh` | **Complete** |

**Acceptance:** Operator never forced — every hook is Y/n default-n or Y/n default-Y per NEO convention (recon = default Y for plan-enum).

---

### Wave 3 — P21 foundation: MSF when relevant (≈2.5 h)

**Objective:** Tier 3.15 + 4.8 → **Prototyped** (not MSF-centric product).

| Task | Files | Done when |
|------|-------|-----------|
| `neo_msf_handler_plan(lhost,lport,payload)` | `lib/neo-exploit-framework.sh` | returns msfconsole -x handler string |
| ListenAssist `--handler msf\|ncat` auto-detect | `foothold/ListenAssist.sh` | MSF multi/handler block in output + notes |
| Session stub: transport, lhost, lport, payload | `lib/neo-mission-state.sh`, schema | `neo_mission_record_handler` |
| Post-phase MSF hint in payload bundle | `lib/neo-payload.sh` | phase=post includes exploit-framework block |
| Minimal resource script writer (temp .rc) | `lib/neo-exploit-framework.sh` | operator-pane hint only; no auto-run |
| Tests | `test/exploit-framework-test.sh`, extend ListenAssist grep test | **Prototyped** |
| Fix P21 DESIGN wording (MSF analogy) | `projects/21-exploit-framework-conductor/DESIGN.md` | aligned with MISSION-STATEMENT |

**Acceptance:** Operator on foothold gets handler command (MSF or ncat) in notes; post pause AI bundle mentions post modules when session_established.

**Not in Wave 3 (defer):** meterpreter session ID tracking, auto `exploit -j`, module search automation.

---

### Wave 4 — neo-vendor + toolkit hardening (≈1 h)

**Objective:** P11 + Tier 3.2 → **Prototyped**.

| Task | Files | Done when |
|------|-------|-----------|
| `neo-vendor install <name>` | `tools/neo-vendor.sh` | lookup manifest entry OR map to apt/pacman/setup.sh |
| `neo-vendor rollback <name>` stub | same | clear message if no previous entry |
| Manifest seed entries for common tools | `vendor/manifest.json` | nmap, gobuster, seclists placeholders |
| Toolkit: MSF path verify uses neo_msf_framework_root | already mostly done | verify + test |
| Test | `test/vendor-test.sh` | **Prototyped** |

---

### Wave 5 — Docs, backlog, release prep (≈45 min)

| Task | Files |
|------|-------|
| Update HARD-CODE-BACKLOG all touched IDs → `[x]` or `[~]` | `HARD-CODE-BACKLOG.md` |
| Refresh SCOPE-STATUS tier tables | `SCOPE-STATUS.md` |
| PROGRESS.md P20 complete, P21 prototyped | `PROGRESS.md` |
| MASTER-MANIFEST P20/P21 status | `MASTER-MANIFEST.yaml` |
| CURSOR-REVIEW-LOG phase entry (verbatim operator prompt) | `CURSOR-REVIEW-LOG.md` if exists |
| AGENTS.md extension log one-liner | `AGENTS.md` |
| RELEASE-NOTES.md delta | `RELEASE-NOTES.md` |
| E2E-CHECKLIST: add Wave 1–4 verification rows | `E2E-CHECKLIST.md` |

---

### Wave 6 — Operator handoff (blocked items)

**Run on home Linux tonight — not agent EOD code:**

```bash
./test/run-all.sh
./test/neo-diagnostic.sh
./tools/doc-truth-check.sh
./neo.sh <box> <ip>   # full loop through post with [t]
# E2E-CHECKLIST.md — 3 boxes when VPN available
# Then: bump VERSION to 1.0.0-rc
```

| Item | Stays until Linux |
|------|-------------------|
| 2.5.7 / 3.13 P18 E2E | Not started → operator |
| 3.12 VERSION bump | Operator after tests green |
| Toolkit/doc-truth "lab validated" | Complete after run-all |

---

## File touch list (master checklist)

```
lib/neo-workbench.sh          # Wave 1
lib/neo-payload.sh            # Wave 1 verify, Wave 3 post bundle
neo.sh                        # Wave 2 hooks
recon/babysteps.sh            # Wave 2A optional tail hook
lib/neo-exploit-framework.sh  # Wave 3
lib/neo-mission-state.sh      # Wave 3 session stub
foothold/ListenAssist.sh      # Wave 3 MSF handler
tools/neo-vendor.sh           # Wave 4
vendor/manifest.json          # Wave 4
test/workbench-test.sh        # Wave 1
test/menu-routing-test.sh     # Wave 1
test/plan-enum-hook-test.sh   # Wave 2 NEW
test/privesc-rank-hook-test.sh # Wave 2 NEW
test/exploit-framework-test.sh # Wave 3
test/vendor-test.sh           # Wave 4 NEW
test/run-all.sh               # register new suites
NEO-1.0-DESIGN/*              # Wave 5
```

---

## Risk register

| Risk | Mitigation |
|------|------------|
| neo.sh already large — hooks get messy | Small functions `neo_offer_plan_enum`, `neo_offer_privesc_rank` in new `lib/neo-pipeline-hooks.sh` |
| Interactive tests fail in CI | Use `NEO_TEST_NONINTERACTIVE=1` skip paths like existing tests |
| Windows can't run bash | Write tests; operator verifies Linux |
| Scope creep into full MSF conductor | Wave 3 stops at Prototyped; no auto-exploit |

---

## EOD scorecard (fill when done)

| Tier | Before | After (target) |
|------|--------|----------------|
| 0 | Complete | Complete |
| 1 | Complete | Complete |
| 2 | Complete* | **Complete** (helpers wired) |
| 2.5 | Prototyped | **Complete** except 2.5.7 lab |
| 3 | Incomplete | **Prototyped** except 3.12–3.13 blocked |
| 4 | Not started | **prototyped, v0.6** (Tier A/B lib files; integration pending) |
| **A/B** | — | **prototyped, v0.6** — conductor, feedback, report `[f]`, borg library AI |
| 5 | Deferred | Deferred |

\* helpers existed but unwired

---

## Agent start command

When operator says **"go"** or **"start the attack plan"**:

1. Execute Wave 1 → 2 → 3 → 4 → 5 in order  
2. Do not stop for permission between waves unless a test fails or design conflict  
3. Log operator prompt in CURSOR-REVIEW-LOG  
4. End with EOD scorecard + Linux handoff commands  

**Ready to start on your signal.**
