# P05 — Zero-Exposure Secrets and Credential Handling

**Status:** review_ready · **Priority:** P0 · **Depends:** P01

## Problem

CS-004: `.env` in repo sourced as shell. CS-005: API keys in tmux command strings.
Discovered creds can leak into notes, prompts, and artifacts.

## Secret broker design

**Location:** `~/.config/neo/secrets/<NAME>` — mode 600, single line, no symlinks.

**API:**

| Function | Behavior |
|----------|----------|
| `neo_secret_load NAME` | Sets NEO_SECRET_VALUE; prints nothing |
| `neo_secret_store NAME VALUE` | Atomic write via temp + mv |
| `neo_secret_prompt NAME` | Interactive -s read; optional store |
| `neo_secret_redact_text TEXT NAMES...` | In-process substitution |
| `neo_secret_audit_repository REPO` | Fail on .env, *.pem, *.key |

## Rules (OD-006)

1. Never `source` repository `.env`
2. Never pass secrets as subprocess argv (use curl --config file)
3. Never include in `NEO_TMUX_ENV_FORWARD`
4. Redact before: LOG, evidence, AI prompts, support bundles
5. `.gitignore` must exclude `.env` and `*.pem` (integration patch)
6. Rotation doc in `SECRETS-RUNBOOK.md`

## Prototype

`prototype/neo-next/lib/neo-secrets.sh` — **complete**.

## Production replacements

| v0.5 | Change |
|------|--------|
| `lib/neo-ai.sh` | Remove .env source; call neo_secret_load |
| `lib/neo-tmux.sh` | Remove API keys from forward list |
| `lib/neo-ai-analyze.sh` | Redact bundle before provider |
| `.gitignore` | Add .env patterns |

## Incident response (5g)

1. Revoke key at provider console
2. `neo_secret_remove NAME`
3. Grep repo + projects/ for canary substring
4. Rotate workspace ID if applicable
5. Log incident in LESSONS (manual)

## Acceptance

- secret load silent on stdout
- ps/tmux show no key material
- Canary `NEO_TEST_CANARY_KEY` redacted in evidence tests
- production-integrity-gate fails tmux key forward

## Tests

`prototype/neo-next/test/core-secrets-test.sh`
