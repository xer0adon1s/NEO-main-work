# NEO 1.0 Tier 1 — P0 Safety Status

**Updated:** 2026-08-31

Tier 1 rough drafts are **complete**. Borg wind-up and AI calls no longer use `eval` / `bash -c` on AI prose.

---

## Changes

| ID | Deliverable |
|----|-------------|
| 1.1 | `test/secret-canary-test.sh` — canary must not leak to evidence JSONL/artifacts |
| 1.2 | `test/injection-payload-test.sh` — `; rm -rf /` rejected; no eval in borg libs |
| 1.3 | `lib/neo-borg.sh` — wind-up delegates to `neo-windup-actions.sh` (argv only) |
| 1.4 | `lib/neo-payload.sh` — advisory suggest + provider calls (no execute loop) |
| 1.5 | `lib/neo-ai-cli.sh` — `neo_provider_request` (claude-cli) |
| 1.6 | `lib/neo-ai-analyze.sh` — unchanged HUD; callers route through provider |
| 1.7 | `lib/neo-ai.sh` `neo_ai_call_claude` → `neo_provider_request` (anthropic-api) |
| 1.8 | `tools/neo-secret.sh` — store / remove / audit / redact |

**New lib:** `lib/neo-windup-actions.sh` — tokenize safe commands → action JSON → `neo_action_execute`.

---

## Operator notes

- Borg `[RUN:]` / `[PAYLOAD:]` steps now require **typed argv** (no `;`, `|`, `$()`, etc.). Refused commands must be run manually.
- `[NEO:]` only runs whitelisted repo paths (`neo.sh`, `recon/`, `borg/`, …).
- Store API keys: `./tools/neo-secret.sh store ANTHROPIC_API_KEY`
- Audit repo: `./tools/neo-secret.sh audit .`

---

## Home lab verify

```bash
bash test/secret-canary-test.sh
bash test/injection-payload-test.sh
bash test/production-integrity-gate.sh   # still fails on ListenAssist/privesc stubs (Wave 3)
bash test/run-all.sh
```

**Next:** Tier 2 — scope intake, stub replacement, Borg v2 workflow.
