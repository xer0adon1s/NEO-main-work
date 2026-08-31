# NEO 1.0 CORE — Rough Draft Status

**Updated:** 2026-08-31  
**Branch/repo:** `NEO-main-work` (design + CORE drafts; not merged to live `NEO`)

Tier 0 CORE rough drafts are **complete**. These are foundation libraries and gates — not yet wired into every workflow path (Tier 1+).

---

## Landed in production tree

| ID | Component | Path |
|----|-----------|------|
| C0 | Shared primitives | `lib/neo-core.sh` |
| C1 | Secret broker | `lib/neo-secrets.sh` |
| C2 | Secret gitignore | `.gitignore` (`.env`, `.env.*`, `*.pem`, `*.key`) |
| C3 | AI key via broker | `lib/neo-ai.sh` (no repo `.env` sourcing) |
| C4 | Tmux no key forward | `lib/neo-tmux.sh` |
| C5 | Evidence JSONL | `lib/neo-evidence.sh` |
| C6 | Typed actions | `lib/neo-actions.sh` + `schemas/*.json` (7 files) |
| C7 | Mission state machine | `lib/neo-mission-state.sh` |
| C8 | Scope policy | `lib/neo-scope.sh` (python3 CIDR when available) |
| C9 | AI provider layer | `lib/neo-provider.sh` |
| C10 | Integrity gate | `test/production-integrity-gate.sh` |
| C11 | Test aggregate | `test/run-all.sh` |
| C12 | Diagnostic hook | `test/neo-diagnostic.sh` |
| C13 | Bootstrap + entry | `lib/neo-1.0-bootstrap.sh`, `neo.sh` early source |

### Unit tests (CORE)

- `test/test-helper.sh`
- `test/core-secrets-test.sh`
- `test/mission-state-test.sh`

---

## Expected gate behavior (v0.5 baseline)

`test/production-integrity-gate.sh` should **fail** until Wave 3 replaces:

- `foothold/ListenAssist.sh` stub (CS-001)
- `privesc/run-findprivs.sh` stub (CS-002)

It should **pass** for CORE safety items already patched:

- `.gitignore` excludes `.env`
- No API keys in `NEO_TMUX_ENV_FORWARD`
- All eight CORE lib files present
- `schemas/action-policy.json` present

---

## Home lab verification

```bash
git clone https://github.com/xer0adon1s/NEO-main-work.git
cd NEO-main-work
bash test/core-secrets-test.sh
bash test/mission-state-test.sh
bash test/production-integrity-gate.sh   # expect stub failures
bash test/run-all.sh
bash test/neo-diagnostic.sh
```

Design prototype suites remain under `NEO-1.0-DESIGN/prototype/neo-next/test/`.

---

## Next: Tier 1 (P0 safety)

See `NEO-1.0-DESIGN/HARD-CODE-BACKLOG.md` — Borg eval removal, payload action JSON, AI libs → provider, secret canary tests.
