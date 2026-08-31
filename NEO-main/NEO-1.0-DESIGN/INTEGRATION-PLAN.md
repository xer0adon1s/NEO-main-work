# NEO 1.0 Integration Plan

Maps **prototype/neo-next/** and design projects to **v0.5 production files**.
Do not apply until operator approves integration on NEO-at-work branch.

## Integration waves

| Wave | Projects | Risk | Est. files |
|------|----------|------|------------|
| 1 — Safety foundation | P05, P09, P14 | P0 | 8 |
| 2 — Core libs | P06, P08, P13, P14, P16 | P0/P1 | 14 |
| 3 — Workflows | P02, P03, P07, P10, P15 | P1 | 10 |
| 4 — Borg + privesc | P04, P17 | P1 | 6 |
| 5 — Meta | P11, P12, P18 | P1 | 5 |
| 6 — Future | P19 | P3 | GUI boundary only |

## File-by-file migration

### New files (copy from prototype)

| Prototype | Production target | Project |
|-----------|-------------------|---------|
| lib/neo-core.sh | lib/neo-core.sh | foundation |
| lib/neo-secrets.sh | lib/neo-secrets.sh | P05 |
| lib/neo-evidence.sh | lib/neo-evidence.sh | P14 |
| lib/neo-actions.sh | lib/neo-actions.sh | P06 |
| lib/neo-provider.sh | lib/neo-provider.sh | P08 |
| lib/neo-mission-state.sh | lib/neo-mission-state.sh | P16 |
| lib/neo-vpn-consent.sh | lib/neo-vpn-consent.sh | P10 |
| schemas/*.json | schemas/*.json | P06, P04, P15 |
| recon/operator-recon.sh | recon/operator-recon.sh | P07 |
| enumerators/plan-enum.sh | recon/plan-enum.sh | P15 |
| enumerators/review-plan.sh | recon/review-plan.sh | P15 |
| tools/neo-vendor.sh | tools/neo-vendor.sh | P11 |
| tools/doc-truth-check.sh | tools/doc-truth-check.sh | P12 |
| lib/neo-scope.sh | lib/neo-scope.sh | P13 |
| tools/scope-intake.sh | tools/scope-intake.sh | P13 |
| privesc/rank-privesc-plan.sh | privesc/rank-privesc-plan.sh | P17 |
| test/production-integrity-gate.sh | test/production-integrity-gate.sh | P09 |

### Replace stubs

| Production (v0.5) | Replacement source | Project |
|-------------------|-------------------|---------|
| foothold/ListenAssist.sh | prototype/foothold/ListenAssist.sh + notes bridge | P02 |
| privesc/run-findprivs.sh | prototype/privesc/run-findprivs.sh + notes_ingest | P03 |

### Modify in place

| File | Changes | Project |
|------|---------|---------|
| lib/neo-ai.sh | Remove .env source; use neo_secret_load | P05 |
| lib/neo-tmux.sh | Remove API keys from NEO_TMUX_ENV_FORWARD | P05 |
| lib/neo-ai-cli.sh | Delegate to neo_provider_request | P08 |
| lib/neo-ai-analyze.sh | Provider + redact | P08 |
| lib/neo-borg.sh | Remove eval; link to borg-v2 pattern | P04, P06 |
| lib/neo-vpn.sh | Call neo_vpn_resolve_existing before pkill | P10 |
| lib/neo-boot.sh | VPN consent before connect | P10 |
| lib/neo-payload.sh | Emit action JSON only | P06 |
| neo.sh | Mission state gates; operator-recon hook; **scope intake before recon** | P16, P07, P13 |
| borg/borg.sh | Thin wrapper to borg-v2 or merge | P04 |
| recon/analyze-recon.sh | Provider abstraction | P08 |
| setup.sh | Manifest-aware vendor install | P11 |
| .gitignore | .env, *.pem exclusions | P05 |
| registry.yaml | New entries + stub status removed | P12 |
| templates/investigation-notes.md | Optional EVIDENCE-INDEX section | P14 |
| test/neo-diagnostic.sh | Call production-integrity-gate | P09 |
| test/run-all.sh (new) | Aggregate unit + gate | P09 |
| README.md, AGENTS.md | Generated truth from P12 | P12 |
| VERSION | Bump to 1.0.0 at release | P18 |

### Preserve unchanged

| File | Reason |
|------|--------|
| privesc/FindPrivs.sh | On-target; works |
| recon/babysteps.sh | Implemented; P15 adds optional planner hook |
| lib/notes-lib.sh | Section model; extend don't replace |
| lib/script-lib.sh | cybersec_finish pattern |
| lib/neo-menu.sh | Pause routing (Phase 49) |
| lib/neo-interact.sh | Pre-foothold; complements P07 |
| phases.yaml | Data-driven walk; add state checks in neo.sh |
| knowledge/vectors/ | Borg collective unchanged |

## neo.sh integration sequence

```bash
# Pseudocode for integration — not applied yet
1. source lib/neo-core.sh neo-secrets.sh neo-mission-state.sh
2. neo_mission_init on project create
3. Before each phase script:
     - neo_mission_current_state must allow phase
4. After each script:
     - neo_evidence_record + cybersec_finish (existing)
     - neo_mission_transition on success events
5. VPN boot: neo_vpn_resolve_existing before connect
6. Borg menu [b]: borg-v2.sh instead of eval wind-up
```

## State directory layout (1.0)

```
~/.local/state/neo/projects/<project>/
  mission.json
  evidence/
    events.jsonl
    artifacts/
  borg/
    initial-dossier-*.json
    assimilated-dossier-*.json

~/Neo/projects/<project>/          # unchanged gitignored
  Investigation-Notes.md
  project.meta                     # phase derived from mission.json
  artifacts/                       # legacy + evidence symlink option
```

## Rollback strategy

- Integration on `neo-1.0-integration` branch only
- Tag v0.5 before merge
- Feature flags: NEO_MISSION_STATE=0, NEO_SECRET_BROKER=0 for gradual rollout
- UPGRADE-FROM-0.5.md documents meta migration

## Test gate before merge

```bash
cd NEO-1.0-DESIGN/prototype/neo-next && bash test/run-all.sh
cd <integration-branch> && bash test/neo-diagnostic.sh
bash test/production-integrity-gate.sh  # must PASS on 1.0 branch
```

## NEO-at-work git layout (recommended)

```
neo-at-work/
├── NEO-1.0-DESIGN/     # this entire design workspace (committed)
├── integration/        # future: patched v0.5 → 1.0 branch
└── README.md           # "design only, not production"
```

Do **not** push to operator's live NEO git until P18 E2E passes on Linux lab.
