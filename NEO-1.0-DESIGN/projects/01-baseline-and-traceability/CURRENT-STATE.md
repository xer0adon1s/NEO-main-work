# Current State — Baseline (updated 2026-08-31)

Status: **review_ready** with production integration substantially complete for 1.0-rc
candidate. Remaining gate: **lab E2E** (P18) on home Linux.

## Repository profile

- Current version file: `0.5` (target `1.0.0-rc` after operator sign-off)
- Production shell libs: 20+ under `lib/` (workbench, pipeline-hooks, exploit-framework, eli5, …)
- Test suites: 20+ in `test/run-all.sh`
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

## Integration waves complete (code)

- Tier 0–2: CORE, safety, workflows
- Tier 2.5: Operator workbench `[t]`/`[o]` including **post** phase
- Tier 3–4 (prototyped): pipeline hooks, MSF foundation, neo-vendor, ELI5, session adapter
- **Blocks 1.0.0-rc:** P18 E2E only (operator lab)

## Recommended verification

See `NEO-1.0-DESIGN/E2E-CHECKLIST.md` and `SCOPE-STATUS.md`.
