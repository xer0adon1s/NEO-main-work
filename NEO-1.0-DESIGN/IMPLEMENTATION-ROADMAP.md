# NEO 1.0 Implementation Roadmap

**Target:** functional CLI for authorized CTF/HTB-style boxes (OD-014).  
**Constraint:** design/prep on work PC; integration + E2E on home Linux lab.

## Phase A — Design complete (this session)

| Project | Status | Deliverables |
|---------|--------|--------------|
| P01 | review_ready | CURRENT-STATE, TRACEABILITY, DISCREPANCIES, WORKFLOW-MAP, HISTORY |
| P02–P12 | review_ready | DESIGN.md each |
| P13 | review_ready | DESIGN.md + scope intake prototype |
| P14–P17 | review_ready | DESIGN.md + prototype libs |
| P18–P19 | review_ready | DESIGN.md + release/GUI boundary |
| Prototype | review_ready | neo-next/* tests, schemas, workflows |
| Cross | review_ready | INTEGRATION-PLAN, this file, PROGRESS |

## Phase B — NEO-at-work git (next, operator)

1. Init `neo-at-work` remote repo
2. Commit entire `NEO-1.0-DESIGN/` + root planning docs (optional)
3. Do **not** modify production neo.sh on live machine

## Phase C — Integration waves (home Linux)

Execute INTEGRATION-PLAN waves 1→5 in order. After each wave:

```bash
bash test/run-all.sh
bash test/neo-diagnostic.sh
```

### Wave 1 checklist (P05, P09, P14)

- [ ] Copy neo-secrets, neo-evidence, neo-core
- [ ] Patch neo-tmux, neo-ai .env
- [ ] Add production-integrity-gate to diagnostic
- [ ] Gate fails on stubs until Wave 3

### Wave 2 checklist (P06, P08, P13, P14, P16)

- [ ] Copy neo-actions, neo-provider, neo-mission-state, **neo-scope**
- [ ] Wire neo.sh mission init + **scope-intake before first recon**
- [ ] Provider replaces direct claude calls in analyze-recon
- [ ] P06 actions call neo_scope_check_network

### Wave 3 checklist (P02, P03, P07, P10, P15)

- [ ] Replace ListenAssist, run-findprivs stubs
- [ ] Add operator-recon, plan-enum
- [ ] VPN consent in neo-vpn

### Wave 4 checklist (P04, P17)

- [ ] borg-v2 integration
- [ ] privesc normalizer + ranker

### Wave 5 checklist (P11, P12, P18, P20)

- [x] neo-vendor manifest CLI
- [x] doc-truth-check
- [x] OPERATOR-WORKBENCH design + libs (P20)
- [x] RELEASE-NOTES, KNOWN-LIMITATIONS, E2E-CHECKLIST
- [ ] VERSION 1.0.0-rc bump (operator)
- [ ] P18 E2E on 3 lab boxes

## Phase D — E2E validation (P18)

3 easy HTB boxes, full checklist, secret canary audit.

## Phase E — GUI prep (P19, post-1.0)

Document JSON API shapes; no GUI code in 1.0.

## Time estimates (operator planning)

| Phase | Effort |
|-------|--------|
| B — git setup | 30 min |
| C Wave 1–2 | 4–6 hours |
| C Wave 3–4 | 6–8 hours |
| C Wave 5 + D | 4–6 hours |
| **Total to 1.0** | ~2–3 focused days on Linux |

## Risk register

| Risk | Mitigation |
|------|------------|
| Windows can't run tests | All bash verification on home lab |
| Breaking v0.5 missions | Integration branch + feature flags |
| AI provider drift | Provider adapter + schema validation |
| Secret leak regression | Canary tests in every CI run |

## Success criteria

P18 definition of done — operator completes easy box without false success or hidden automation.
