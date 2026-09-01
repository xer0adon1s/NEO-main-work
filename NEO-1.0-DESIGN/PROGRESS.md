# NEO 1.0 Design Progress

Last updated: 2026-08-31 (feature status alignment — see FEATURE-STATUS.md)

## Summary

| Metric | Count |
|--------|-------|
| Projects total | 21 (P01–P21) |
| review_ready | 19 (**design** review only — not production shipped) |
| in_progress | 2 (P20 workbench, P21 MSF foundation) |
| Lib files under `lib/` | 30+ (16 Tier A/B = **prototyped, v0.6**) |
| Unit test suites | 38+ in `test/run-all.sh` |
| Shipped version | `0.5` → **prototyped, v0.6** milestone → `1.0.0-rc` after lab E2E + sign-off |

## Project status

| ID | Title | Design status | Production status |
|----|-------|---------------|-------------------|
| P01 | Baseline | review_ready | Traceability YAML, WORKFLOW-MAP — **implemented** |
| P02 | ListenAssist | review_ready | Full script + MSF handler (P21) — **implemented** |
| P03 | FindPrivs transport | review_ready | Wrapper + ingest — **implemented** |
| P04 | Borg assimilation | review_ready | Core `[b]` **implemented**; v2/library-AI layers **prototyped, v0.6** |
| P05–P19 | (see MASTER-MANIFEST) | review_ready | Per FEATURE-STATUS.md |
| P20 | Operator workbench | **in_progress** | Core loop **implemented**; conductor-driven loop **prototyped, v0.6** |
| P21 | Exploit framework (MSF) | **in_progress** | Foundation **implemented**; handler pane C **prototyped, v0.6** |

## Landed since initial PROGRESS (2026-08-31)

- Attack Plan Waves 1–4: post workbench, pipeline hooks, MSF handler, neo-vendor — **implemented**
- Tier A/B lib files (2026-08-31 evening): **prototyped, v0.6** — see FEATURE-STATUS.md

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
