# Current State — Baseline (updated 2026-08-31)

Status: **review_ready** (design). Production: Tier 0 + Tiers 1–3 foundation **implemented**;
Tier A/B **prototyped, v0.6**. Remaining gate: **lab E2E** (P18) + human sign-off per `FEATURE-STATUS.md`.

## Repository profile

- Current version file: `0.5` (target `1.0.0-rc` after operator sign-off)
- Production shell libs: 20+ under `lib/` (workbench, pipeline-hooks, exploit-framework, eli5, …)
- Test suites: **39** in `test/run-all.sh` (+ repo-wide `bash -n`)
- Offline gate: `linux-phase1-verify.sh` **6/6** (2026-09-01)
- Live gate: **P22 SIM-H** (`projects/22-live-simulation-block-h/DESIGN.md`)
- Walked phases: recon, foothold, privesc, post (conductor-guided post)

## Resolved since initial baseline (CS-001 / CS-002)

### CS-001 — ListenAssist — **RESOLVED**

`foothold/ListenAssist.sh` is a full interactive listener script (~170+ lines): ncat/nc/socat,
optional MSF `exploit/multi/handler`, tmux guidance, notes logging. Integrated in pipeline.

### CS-002 — run-findprivs — **RESOLVED**

`privesc/run-findprivs.sh` is a substantive wrapper (~140+ lines): SSH transport, ingest,
existing-shell path. Production integrity gate checks line count.

## Still open (non-blocking for code; lab or post-1.0)

| ID | Item | Status |
|----|------|--------|
| CS-003 | Diagnostic semantic guards | Partial — babysteps + ListenAssist + run-findprivs line checks |
| CS-004 | `.env` secret risk | Mitigated — `.gitignore` excludes `.env`; secret broker preferred |
| CS-005 | tmux API key forward | **Resolved** — keys not forwarded in `neo-tmux.sh` |
| CS-006 | Borg eval | **Resolved** — wind-up uses typed argv |
| CS-007 | VPN pkill consent | **Resolved** — `neo-vpn-consent.sh` |
| CS-008 | Moving dependencies | Documented in KNOWN-LIMITATIONS |

## Integration status (see FEATURE-STATUS.md)

- Tier 0–2: CORE, safety, workflows — **implemented**
- Tier 2.5: Operator workbench `[t]`/`[o]` including **post** phase — **implemented**
- Tier 3: pipeline hooks, ELI5, neo-vendor, doc-truth — **implemented** (tools); lab E2E pending
- Tier A/B: conductor, feedback, report `[f]`, borg library AI, handler pane — **prototyped, v0.6**
- **Blocks 1.0.0-rc:** integration Blocks C–E + P18 E2E + human sign-off

## Recommended verification

See `NEO-1.0-DESIGN/E2E-CHECKLIST.md` and `SCOPE-STATUS.md`.
