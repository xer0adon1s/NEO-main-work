# Tier 3 — Release Polish

**Status:** rough draft integrated · most items `[~]` until Linux lab validation

## Delivered

| ID | Item | Path |
|----|------|------|
| 3.1 | Doc truth checks | `tools/doc-truth-check.sh` (existence + FEATURE-STATUS alignment; not “feature works”) |
| 3.2 | Vendor manifest CLI | `tools/neo-vendor.sh`, `vendor/manifest.json` |
| 3.3 | Enum plan reviewer | `recon/review-plan.sh` |
| 3.4 | Release notes draft | `RELEASE-NOTES.md` |
| 3.5 | Known limitations | `KNOWN-LIMITATIONS.md` |
| 3.6 | E2E checklist | `NEO-1.0-DESIGN/E2E-CHECKLIST.md` |
| 3.7 | Design doc alignment (P20 core loop) | WORKFLOW-MAP, P02–P18, INTEGRATION-PLAN, etc. |
| 3.8 | Manifest updates | `MASTER-MANIFEST.yaml` (+ P20) |
| 3.9 | Integrity gate | workbench lib checks in `production-integrity-gate.sh` |
| 3.10 | Test aggregate | `doc-truth-check` in `test/run-all.sh` |
| 3.11 | Registry | `registry.yaml` entries for Tier 3 tools |
| 3.14 | Toolkit LOCK & LOAD | `lib/neo-toolkit.sh` — wired to suggest/triage/[t] |

## Remaining

| ID | Item | Owner |
|----|------|-------|
| 3.12 | Bump `VERSION` to `1.0.0-rc` after operator review | operator |
| 3.13 | P18 lab E2E — 3 HTB boxes with workbench loop | home Linux lab |

## Doc alignment summary (P20)

All major design docs now describe the **core loop**:

```
enum → leads → AI/Borg/[p] → [t] try (permission) → analyze → repeat → foothold → pipeline
```

Updated: `WORKFLOW-MAP.md`, P02/P04/P06/P17/P18, `INTEGRATION-PLAN.md`, `AGENT-START-HERE.md`,
`UPGRADE-FROM-0.5.md`, `PROGRESS.md`, `MASTER-MANIFEST.yaml`, `NEO-1.0-DESIGN/README.md`.

## Verify (Linux lab)

```bash
./tools/doc-truth-check.sh
./tools/neo-vendor.sh init    # if manifest missing
./test/run-all.sh
# Full E2E: NEO-1.0-DESIGN/E2E-CHECKLIST.md
```
