# NEO 1.0 Hard-Coding Backlog

Track implementation from design → production. Update status as tiers complete.

**Status key:** `[ ]` todo · `[~]` rough draft in repo · `[x]` integrated + tested

---

## TIER 0 — Core dependencies (do first)

| ID | Item | Status | Production path |
|----|------|--------|-----------------|
| C0 | neo-core.sh | [x] | `lib/neo-core.sh` |
| C1 | neo-secrets.sh | [x] | `lib/neo-secrets.sh` |
| C2 | .gitignore .env/*.pem | [x] | `.gitignore` |
| C3 | neo-ai.sh secret broker | [x] | `lib/neo-ai.sh` |
| C4 | neo-tmux no key forward | [x] | `lib/neo-tmux.sh` |
| C5 | neo-evidence.sh | [x] | `lib/neo-evidence.sh` |
| C6 | neo-actions + schemas | [x] | `lib/neo-actions.sh`, `schemas/` |
| C7 | neo-mission-state.sh | [x] | `lib/neo-mission-state.sh` |
| C8 | neo-scope.sh | [x] | `lib/neo-scope.sh` |
| C9 | neo-provider.sh | [x] | `lib/neo-provider.sh` |
| C10 | production-integrity-gate | [x] | `test/production-integrity-gate.sh` |
| C11 | test/run-all.sh | [x] | `test/run-all.sh` |
| C12 | neo-diagnostic gate hook | [x] | `test/neo-diagnostic.sh` |
| C13 | neo-1.0-bootstrap + neo.sh | [x] | `lib/neo-1.0-bootstrap.sh`, `neo.sh` |

---

## TIER 1 — P0 safety

| ID | Item | Status |
|----|------|--------|
| 1.1 | Secret canary tests | [x] |
| 1.2 | Injection payload tests | [x] |
| 1.3 | neo-borg.sh remove eval | [x] |
| 1.4 | neo-payload.sh action JSON only | [x] |
| 1.5 | neo-ai-cli → provider | [x] |
| 1.6 | neo-ai-analyze → provider | [x] |
| 1.7 | analyze-recon → provider | [x] |
| 1.8 | tools/neo-secret CLI | [x] |

---

## TIER 2 — P1 high (workflows)

| ID | Item | Status |
|----|------|--------|
| 2.1 | scope-intake.sh | [x] |
| 2.2 | scope-import.sh | [x] |
| 2.3 | neo.sh scope + mission bootstrap | [x] |
| 2.4 | ListenAssist full script | [x] |
| 2.5 | run-findprivs + notes ingest | [x] |
| 2.6 | borg-v2.sh + --v2 flag | [x] |
| 2.7 | neo-vpn-consent + vpn patch | [x] |
| 2.8 | operator-recon.sh | [x] |
| 2.9 | plan-enum.sh | [x] |
| 2.10 | normalize/rank privesc | [x] |
| 2.11 | workflow-scope-test | [x] |
| 2.12 | integrity gate passes stubs | [x] |

---

## TIER 2.5 — Operator workbench (core loop)

| ID | Item | Status |
|----|------|--------|
| 2.5.1 | P20 design + OPERATOR-WORKBENCH.md | [x] |
| 2.5.2 | neo-operator-pane.sh | [x] |
| 2.5.3 | neo-workbench.sh try/analyze loop | [x] |
| 2.5.4 | Pause menu [t]/[o] + widened [z] | [x] |
| 2.5.5 | WORKBENCH notes section + schemas | [x] |
| 2.5.6 | workbench-test.sh + menu routing | [x] |
| 2.5.7 | Lab E2E tmux try→analyze (P18 / Tier 3.13) | [ ] |
| 2.5.8 | Post phase workbench [t]/[o] | [x] |

## TIER 3 — P1 mid (release polish)

| ID | Item | Status |
|----|------|--------|
| 3.1 | tools/doc-truth-check.sh | [~] |
| 3.2 | tools/neo-vendor.sh + vendor/manifest.json | [~] |
| 3.3 | recon/review-plan.sh | [~] |
| 3.4 | RELEASE-NOTES.md (1.0-rc draft) | [~] |
| 3.5 | KNOWN-LIMITATIONS.md | [x] |
| 3.6 | E2E-CHECKLIST.md (P18) | [x] |
| 3.7 | Doc alignment pass (P20 core loop) | [x] |
| 3.8 | MASTER-MANIFEST + WORKFLOW-MAP P20 | [x] |
| 3.9 | integrity gate workbench/toolkit libs | [x] |
| 3.10 | run-all doc-truth + toolkit suites | [x] |
| 3.11 | registry.yaml Tier 3 tools | [x] |
| 3.14 | neo-toolkit.sh LOCK & LOAD preflight | [~] |
| 3.15 | P21 MSF foundation + mission alignment docs | [~] |
| 3.16 | neo-pipeline-hooks (plan-enum, operator-recon, privesc rank) | [x] |
| 3.17 | plan-enum-hook + privesc-rank + vendor tests | [x] |
| 3.12 | VERSION 1.0.0-rc prep | [ ] |
| 3.13 | P18 lab E2E (3 boxes) | [ ] |

---

## TIER 4 — P2 hardening

| ID | Item | Status |
|----|------|--------|
| 4.1 | Wire plan-enum after recon | [x] |
| 4.2 | Privesc ranker at pause | [x] |
| 4.3 | operator-recon before foothold | [x] |
| 4.4 | Post phase workbench | [x] |
| 4.5 | Session adapter | [~] — SSH/MSF handler → operator pane; msf session id |
| 4.6 | neo-vendor install/rollback | [~] — file backup rollback for vendor kind |
| 4.7 | Borg live web research | [ ] |
| 4.9 | AI conductor (Tier A bundle + sequencing + hooks) | [x] |
| 4.8 | P21 full MSF conductor | [~] |

---

## TIER 5 — Post-1.0

P19 GUI — docs only.

---

## Session order

1. ~~**Tier 0** — CORE (this session)~~ **DONE** — see `CORE-STATUS.md`
2. ~~**Tier 1** — safety patches~~ **DONE** — see `TIER1-STATUS.md`
3. ~~**Tier 2** — scope, stubs, Borg, privesc~~ **DONE** — see `TIER2-STATUS.md`
4. ~~**Tier 2.5** — operator workbench (core loop)~~ **DONE** — see `TIER2.5-STATUS.md`
5. ~~**Tier 3** — release polish (docs/tools)~~ **INCOMPLETE** — see `SCOPE-STATUS.md` / `TIER3-STATUS.md`
6. **Tier 3.13 / P18** — lab E2E on home Linux (blocks 1.0.0-rc)
7. ~~**Tier 4+** — not started / deferred~~ **Tier 4 prototyped** — see `SCOPE-STATUS.md`
