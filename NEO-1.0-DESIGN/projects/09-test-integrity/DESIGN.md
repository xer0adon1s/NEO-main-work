# P09 — Test Integrity and Production-Entry Guards

**Status:** review_ready · **Priority:** P0 · **Depends:** P01

## Problem

Green tests do not guarantee production scripts are real (CS-003). Stubs can ship.

## Gate layers

| Layer | Tool | Fails release when |
|-------|------|-------------------|
| Production integrity | production-integrity-gate.sh | Stub entrypoints, .env not gitignored, tmux key forward |
| Unit | core-secrets, mission-state, action-enumerator | Logic regression |
| Workflow | workflow-prototype-test.sh | End-to-end prototype paths break |
| Syntax | bash -n on all .sh | Parse errors |
| Schema | jq validate on JSON schemas | Invalid examples |
| Docs | doc-truth-check.sh (P12) | Version/test count drift |
| Secret canary | Tests with NEO_TEST_CANARY_KEY | Leak into output |

## Stub detection rules

For each production entrypoint in registry.yaml with `runs: local`:
- Minimum line count (per script)
- Required behavior regex (e.g. ncat for ListenAssist)
- Forbidden strings: `Smoke privesc`, `stub — real script`

## Skip policy

Required integration tests that `skip` → release FAIL (not pass).

## Machine-readable summary

`test-results.json` emitted by `tests/run-all.sh`:

```json
{"suite": "production-integrity-gate", "passed": 12, "failed": 3, "skipped": 0}
```

## Prototype test tree

```
prototype/neo-next/test/
  run-all.sh
  production-integrity-gate.sh  # MUST fail against v0.5
  core-secrets-test.sh
  mission-state-test.sh
  action-enumerator-test.sh
  workflow-prototype-test.sh
  test-helper.sh
```

## v0.5 expected gate result

**FAIL** until P02, P03, P05 integrated — this is correct behavior.

## CI constraints

- No real API keys
- No live target IPs
- Disposable project dirs under /tmp/neo-test-*

## Acceptance

- v0.5 snapshot fails gate (verified design intent)
- Tests invoke `bash script.sh` explicitly
- No credentials in test fixtures
