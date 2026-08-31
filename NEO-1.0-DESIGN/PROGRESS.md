# NEO 1.0 Design Progress

Last updated: 2026-08-31 (post attack-plan waves + ELI5 + doc sync)

## Summary

| Metric | Count |
|--------|-------|
| Projects total | 21 (P01–P21) |
| review_ready | 19 |
| in_progress | 2 (P20 workbench, P21 MSF foundation) |
| Prototype / production libs | 20+ under `lib/` |
| Unit test suites | 20+ in `test/run-all.sh` |
| Shipped version | `0.5` → target `1.0.0-rc` after lab E2E |

## Project status

| ID | Title | Status | Production |
|----|-------|--------|------------|
| P01 | Baseline | review_ready | Traceability YAML, WORKFLOW-MAP |
| P02 | ListenAssist | review_ready | Full script + MSF handler (P21) |
| P03 | FindPrivs transport | review_ready | Wrapper + ingest |
| P04 | Borg assimilation | review_ready | v1 pause + v2 `--v2` |
| P05–P19 | (see MASTER-MANIFEST) | review_ready | Integrated per tier |
| P20 | Operator workbench | **in_progress** | Core loop + post phase; lab E2E pending |
| P21 | Exploit framework (MSF) | **in_progress** | Foundation + session adapter prototyped |

## Landed since initial PROGRESS (2026-08-31)

- Attack Plan Waves 1–4: post workbench, pipeline hooks, MSF handler, neo-vendor
- Phase 61: session adapter, MSF post menu
- Phase 62: ELI5 `[e]` educational tutor
- Phase 63: Borg HUD spam fix, doc truth sweep, vendor rollback, diagnostic expansion

## Blockers

| Blocker | Owner | Resolution |
|---------|-------|------------|
| Bash tests on work PC | environment | Home Linux tonight |
| P18 E2E (3 HTB boxes) | operator | `E2E-CHECKLIST.md` |
| VERSION 1.0.0-rc | operator | After `run-all.sh` + diagnostic green |

## Next actions for operator (home Linux)

```bash
./test/run-all.sh
./test/neo-diagnostic.sh
./tools/doc-truth-check.sh
./neo.sh <box> <ip>   # full loop recon → post with [t]/[e]
# E2E-CHECKLIST.md — 3 boxes when VPN up
# Then: bump VERSION to 1.0.0-rc if green
```
