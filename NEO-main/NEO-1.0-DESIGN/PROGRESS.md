# NEO 1.0 Design Progress

Last updated: 2026-08-31

## Summary

| Metric | Count |
|--------|-------|
| Projects total | 19 |
| review_ready | 19 |
| deferred | 0 |
| Prototype modules | 15 shell libs/scripts |
| Prototype tests | 6 suites |
| JSON schemas | 6 |

## Project status

| ID | Title | Status | Design | Prototype |
|----|-------|--------|--------|-----------|
| P01 | Baseline | review_ready | ✓ | n/a |
| P02 | ListenAssist | review_ready | ✓ | ✓ |
| P03 | FindPrivs transport | review_ready | ✓ | ✓ |
| P04 | Borg v2 | review_ready | ✓ | ✓ |
| P05 | Secrets | review_ready | ✓ | ✓ |
| P06 | Safe actions | review_ready | ✓ | ✓ |
| P07 | Operator recon | review_ready | ✓ | ✓ |
| P08 | AI provider | review_ready | ✓ | ✓ |
| P09 | Test integrity | review_ready | ✓ | ✓ |
| P10 | VPN consent | review_ready | ✓ | ✓ |
| P11 | Tool provenance | review_ready | ✓ | partial |
| P12 | Doc truth | review_ready | ✓ | stub |
| P13 | Scope policy | review_ready | ✓ | ✓ |
| P14 | Evidence | review_ready | ✓ | ✓ |
| P15 | Service enum | review_ready | ✓ | ✓ |
| P16 | Mission state | review_ready | ✓ | ✓ |
| P17 | Privesc workflow | review_ready | ✓ | partial |
| P18 | CLI validation | review_ready | ✓ | n/a |
| P19 | GUI boundary | review_ready | ✓ | n/a |

## Blockers

| Blocker | Owner | Resolution |
|---------|-------|------------|
| No Bash on work Windows PC | environment | Run tests on home Linux |
| Production integration | operator | NEO-at-work git, waves C1–C5 |
| E2E lab boxes | operator | P18 on HTB VPN |

## Next actions for operator

1. Push `NEO-1.0-DESIGN/` to **neo-at-work** git (separate from live NEO)
2. On Linux: `cd NEO-1.0-DESIGN/prototype/neo-next && bash test/run-all.sh`
3. Review INTEGRATION-PLAN wave 1 when ready to integrate
4. Say the word when home lab is available for integration session

## Files added this session

- P01: REQUIREMENTS-TRACEABILITY.yaml, DISCREPANCIES.yaml, WORKFLOW-MAP.md, HISTORY-INGESTION.md
- P02–P19: DESIGN.md each
- Root: INTEGRATION-PLAN.md, IMPLEMENTATION-ROADMAP.md, PROGRESS.md (this file)
- Root: SECRETS-RUNBOOK.md, UPGRADE-FROM-0.5.md
- Prototype: privesc normalizer/ranker, neo-vendor, doc-truth-check, schemas
