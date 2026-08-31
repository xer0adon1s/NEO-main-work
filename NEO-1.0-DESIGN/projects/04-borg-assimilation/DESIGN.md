# P04 — Borg Pre-Foothold Assimilation Pipeline

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P06, P07, P08, P11, P14

## Problem

v0.5 Borg works but executes AI prose via eval (CS-006). OD-007 requires dossier-first
pipeline: evidence → initial dossier → operator consent → vector research → knowledge
without auto-install or auto-run.

## Target pipeline

```
babysteps artifacts ──┐
operator recon (P07) ─┼──▶ evidence bundle (hashed)
AI triage (optional) ─┘
         │
         ▼
   initial dossier (JSON schema)
         │
    operator: stop | research selected vectors
         │
         ▼
   Borg research (if provider.web_research)
         │
         ▼
   knowledge/vectors/<slug>/ dossier files
         │
         ▼
   typed action proposals (P06) — advisory only
```

## Dossier schema

`prototype/neo-next/schemas/dossier.schema.json`

```json
{
  "schema_version": 1,
  "target": "10.10.11.1",
  "facts": [{"claim": "...", "source_artifact": "artifacts/...", "confidence": "observed"}],
  "hypotheses": [{"claim": "...", "rationale": "...", "vectors": ["slug"]}],
  "unknowns": ["..."],
  "citations": [{"title": "...", "url": "...", "linked_claims": [0]}],
  "tools_needed": [{"name": "...", "installed": false, "purpose": "..."}],
  "recommended_checks": [{"description": "...", "action_id": null}]
}
```

## Prototype

- `borg/borg-v2.sh` — dossier build, consent gates, no eval
- Integrates P07 operator recon, P08 provider, P14 evidence

## v0.5 migration

| Component | Action |
|-----------|--------|
| `borg/borg.sh` | Thin wrapper calling borg-v2 after P18 |
| `lib/neo-borg.sh` | Remove eval loop; delegate to neo-actions |
| `knowledge/vectors/` | Keep symlink model; dossier JSON + markdown |

## Untrusted data handling

- All target-derived text wrapped in `--- OPERATOR DATA BOUNDARY ---`
- Model output validated as JSON before storage
- No `[RUN:]` or `[PAYLOAD:]` execution paths

## Acceptance

- Can stop after initial dossier
- web_research gated on provider capability
- Citations linked to claim indices
- Final output has zero executable action objects (only action_id refs)

## Deferred to integration

- Live web research adapter (capability flag default 0)
- borg_research_index.yaml automatic consultation
