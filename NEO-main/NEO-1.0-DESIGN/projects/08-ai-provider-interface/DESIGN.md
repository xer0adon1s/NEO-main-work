# P08 — Provider-Neutral AI Interface

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P05, P06

## Problem

v0.5 hard-codes Claude CLI and Anthropic HTTP across neo-ai.sh, neo-ai-cli.sh,
neo-borg.sh, neo-payload.sh. OD-006 requires credentials via secret broker only.

## Provider interface

```bash
neo_provider_available          # exit 0 if configured
neo_provider_capability NAME    # structured_json | web_research | ...
neo_provider_request SYS USER OUTFILE
neo_provider_extract_json IN OUT
```

## Adapters

| Provider | Env | Secrets |
|----------|-----|---------|
| claude-cli | NEO_AI_PROVIDER=claude-cli | None (subscription); strips API env |
| anthropic-api | NEO_AI_PROVIDER=anthropic-api | ANTHROPIC_API_KEY via broker; workspace optional |

## Capability matrix

| Capability | claude-cli | anthropic-api |
|------------|------------|---------------|
| structured_json | yes | yes |
| web_research | flag only | flag only (future) |

Missing capability → clear stderr message, workflow degrades (manual mode).

## Prototype

`prototype/neo-next/lib/neo-provider.sh` — **complete**.

## v0.5 migration

Replace direct `claude -p` and curl calls in:
- lib/neo-ai-cli.sh
- lib/neo-ai-analyze.sh
- recon/analyze-recon.sh
- lib/neo-borg.sh
- lib/neo-payload.sh

## Metadata recording

Each AI call logs: provider, model, timestamp — never credentials.

## Acceptance

- No direct claude/curl in workflow scripts post-integration
- Missing key → fallback message, no fabricated JSON
- Output validated before dossier/action parsing

## Tests

Provider unit tests with mock files in Linux lab
