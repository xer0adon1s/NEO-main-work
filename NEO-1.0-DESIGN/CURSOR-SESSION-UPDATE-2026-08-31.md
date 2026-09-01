# NEO — Cursor session update (2026-08-31 evening)

Pipe-friendly summary for Claude or another reviewer. Repo: `xer0adon1s/NEO-main-work` @ `650d84a` on `main`.

---

## Context

Cursor executed Claude's 2026-08-31 code review against `NEO-main-work-review`: fix P0/P1 bugs first, then add rough-draft prototypes for all 16 missing `lib/` files, update the review doc with conversation notes + tomorrow workload, commit and push.

Full review + tomorrow checklist: `NEO-1.0-DESIGN/NEO-CODE-REVIEW-2026-08-31.md`  
Sub-reports: `NEO-1.0-DESIGN/neo-review/01-tier0-core.md` … `04-tests-docs-drift.md`

---

## Conversation clarifications (operator ↔ Claude)

| What exists | What it is | Status after Cursor |
|---|---|---|
| `NEO-1.0-DESIGN/AI-CONDUCTOR.md` | Design spec | Unchanged — describes intent |
| `lib/neo-conductor.sh` | Implementation | Was missing → **prototype added** |
| `TIER-B-PLAN.md` "Waves 1–5 implemented" | Plan claim | Still overstated — stubs exist, not fully integrated |
| `TIER1–3 STATUS` docs | Tier 1–3 trackers | Underlying code mostly real; many bugs fixed |
| `borg/borg-v2.sh` | Standalone script | Existed before |
| `lib/neo-borg-v2.sh` | Integration layer | Was missing → **prototype added** |

Design docs ≠ delivered code. `NEO-AT-WORK-README.md` was the honest doc. `tools/doc-truth-check.sh` was broken (missing `}`) — **fixed**.

---

## Critical bugs fixed

### P0
- `test/production-integrity-gate.sh` — split `local` self-reference; gate runs 38 checks (was crashing on first call)
- `lib/neo-scope.sh:61` — same `local` bug; scope enforcement works under `set -u`
- `lib/neo-borg.sh:739` — `$'...'` closed with `'` not `"`; **`[b]` Borg loads again**
- `tools/doc-truth-check.sh:7` — missing `}` restored
- `neo.sh` — guarded `source lib/neo-report.sh`; `--report` and mission-complete degrade instead of crash
- `lib/neo-workbench.sh` — **operator_pane always requires confirm**, even in assisted mode (OD-008)

### P1
- Workbench duplicate command send — awk `flush_exact()` clears buffer before `exit`
- Toolkit wordlist preflight — fixed invalid awk regex `neo-toolkit.sh:104`
- Pipeline hooks — decline/skip returns non-zero (`offer_plan_enum`, `offer_privesc_rank`)
- MSF mission state — added transitions `preflight:foothold_planning`, `foothold_planning:session_established`; jq guards on mission.json mutators; numeric MSF session ID validation
- MSF advisory string builders — no longer require local `msfconsole` to build text one-liners
- API key — `neo_ai_save_api_key` writes secret broker **and** legacy keyfile; `recon-bundle-test.sh` isolates `NEO_SECRET_DIR`
- Pause menu — `[t]`/`[o]` visible again (`neo_workbench_menu_fragment "${phase}" "${project}"`)
- Diagnostic — distinguishes gate crash vs gate failure (not "expected Wave 3" forever)
- Tests — smoke test copies full `lib/*.sh`; borg-test slug path + NEO_DIR; recon-bundle sets NEO_HOME before sourcing libs

---

## 16 missing lib files → rough prototypes added

All under `lib/`, whitelisted in `.gitignore`, offline tests green, **not production-complete**:

1. `neo-conductor.sh` — bundle builder, mode resolution, phase hooks (stubs)
2. `neo-conductor-loop.sh` — `neo_conductor_on_event` dispatcher
3. `neo-conductor-privesc.sh` — privesc ingest hook
4. `neo-report.sh` — menu fragments, bundle, generate stub
5. `neo-feedback.sh` — ack telemetry
6. `neo-ai-guard.sh` — disclosure lint wrapper
7. `neo-enum-ai.sh` — post enum-plan AI offer
8. `neo-adaptive-scan.sh` — scan mode hints
9. `neo-operator-recon-ai.sh` — operator recon summary offer
10. `neo-handler-pane.sh` — tmux pane C stub
11. `neo-borg-disclosure.sh` — educational/professional lint
12. `neo-borg-library.sh` — INDEX lookup, CVE extract
13. `neo-borg-library-ai.sh` — parse AI library response
14. `neo-borg-harvest.sh` — fetch/slugify helpers (network off by default)
15. `neo-borg-v2.sh` — dossier validate + pause offer
16. `neo-borg-library-batch.sh` — batch queue builder

---

## Test status

`./test/run-all.sh` → **Aggregate suites failed: 0** in a clean shell (38 suites + `bash -n`).

Note: `./test/neo-diagnostic.sh` may still report 1 fail on `setup.sh --check` if vendor/wordlists aren't installed — environment-specific, not from this session's code changes.

---

## Urgent operator action

If `./test/run-all.sh` or `recon-bundle-test.sh` ran **before** this commit, the old test bug may have overwritten:

`~/.config/neo/secrets/ANTHROPIC_API_KEY`

with a bogus 22-byte test key. **Re-save your real key** before a live session. Tests now isolate secrets; save also writes `~/.config/neo/anthropic.key` for compatibility.

---

## Can neo.sh launch?

**Yes.** Cold start unchanged. **New:** `[b]` Borg works (syntax fixed). `--report` no longer hard-crashes. Conductor/library **stubs** exist; most proactive behavior is still no-op or printf until integration (tomorrow's work).

---

## Git

- Branch: `main`
- Commit: `650d84a` — "Fix P0/P1 review bugs and add Tier A/B lib prototypes."
- Remote: https://github.com/xer0adon1s/NEO-main-work

---

## Tomorrow workload (abbreviated — full detail in NEO-CODE-REVIEW doc)

**Block A** — Re-save API key; confirm `./test/run-all.sh` green  
**Block B** — Align DAILY-RECAP, TIER-B-PLAN, AGENTS.md, registry.yaml with prototype reality  
**Block C** — Conductor integration (phase entry, after-triage, on_event, assisted loop opt-in)  
**Block D** — Borg library + disclosure (guard on all AI saves, live harvest)  
**Block E** — Report `[f]` end-to-end  
**Block F** — Workbench/MSF/handler pane polish  
**Block G** — P2 hardening (scope CIDR, IPv6, tautological tests, doc counts)  
**Block H** — Lab smoke: pause menu, assimilate, mission-complete

---

## Ask for Claude

Please treat this as ground truth for what Cursor changed tonight. The original Claude review findings in `NEO-CODE-REVIEW-2026-08-31.md` remain valid for anything not listed as fixed above. Prototypes pass unit tests but need integration and doc alignment — prioritize Block B then C/D when continuing.
