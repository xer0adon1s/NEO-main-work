# P18 — CLI 1.0 Validation and Release Gates

**Status:** review_ready · **Priority:** P1 · **Depends:** P02–P13, P14–P17

## Definition of done

A new operator can, on an authorized disposable lab box:

1. Install NEO 1.0
2. Create project — **educational or professional scope intake**
3. Connect VPN (with consent)
4. Run speed recon + optional deep
5. Add operator recon notes
6. Run optional Borg assimilation
7. Plan foothold via ListenAssist
8. **Workbench loop:** `[p]` suggest → `[t]` try → analyze until shell
9. Confirm shell → post-foothold enum
10. Work ranked privesc plan (workbench `[t]` on validation steps)
11. Complete without hidden automation or false success

## Capability checklist (18a)

| # | Capability | Projects | Evidence |
|---|------------|----------|----------|
| 1 | Secret broker | P05 | core-secrets-test |
| 2 | Production integrity gate | P09 | gate fails v0.5, passes 1.0 |
| 3 | Mission state machine | P16 | mission-state-test |
| 4 | Evidence JSONL | P14 | workflow test |
| 5 | Typed actions | P06 | action-enumerator-test |
| 6 | Provider abstraction | P08 | provider test |
| 7 | VPN consent | P10 | manual script test |
| 8 | ListenAssist | P02 | workflow test |
| 9 | FindPrivs transport | P03 | workflow test |
| 10 | Borg v2 dossier | P04 | schema validation |
| 11 | Service enum plans | P15 | action-enumerator-test |
| 12 | Scope intake E/P | P13 | scope-intake wizard |
| 13 | Privesc ranker | P17 | fixture test |
| 14 | Doc truth | P12 | doc-truth-check |
| 15 | Vendor manifest | P11 | verify test |
| 16 | Operator workbench | P20 | workbench-test + E2E checklist |

## Scenario matrix (18b)

| Scenario | Expected |
|----------|----------|
| Fresh install | All gates green |
| Resume mid-recon | Checkpoint restores state |
| Interrupted VPN | Consent re-prompt |
| No scope on new project | Prompt scope intake; block recon until complete |
| Educational OOS target | Warn + scope-override phrase |
| Professional OOS target | Block + offer expansion wizard |
| Expired professional dates | Warn at resume; require re-attestation |
| No AI / manual mode | Workflow continues |
| Provider failure | Clear message, manual path |
| Missing tool | Advisory, not crash |
| Workbench without tmux | Clear error; suggest NEO_TMUX_WRAP=1 |
| Paste in conductor pane | Menu consumes input — use [t] or operator pane |

## E2E lab targets (18c)

Minimum 3 easy HTB-style boxes (disposable VPN):
- Linux web foothold
- Linux service enum box
- Sudo/SUID privesc box

Record: project name, date, operator, pass/fail per checklist item.

## Release artifact (18f)

```
neo-1.0.0-manifest.json
neo-1.0.0.sha256sums
RELEASE-NOTES.md
KNOWN-LIMITATIONS.md
UPGRADE-FROM-0.5.md
```

## P0/P1 disposition (18d)

- Zero open P0 at release
- All P1 either fixed or documented with workaround

## Secret audit (18e)

Automated scan: repo, sample project dir, ps snapshot during run, tmux list-panes -F
for canary string.

## Validation host

Cannot run on current Windows work PC. Full E2E deferred to home Linux lab.

## Status

Design complete. Execution blocked on integration branch (NEO-at-work).
