# P17 — Privilege-Escalation Workflow

**Status:** review_ready · **Priority:** P1 · **Depends:** P03, P06, P14, P16

## Problem

Post-FindPrivs, operators face raw SUDO/SUID/cron lists without ranked, evidence-linked
validation workflow. AI must not overclaim exploitability.

## Pipeline

```
FindPrivs ingest → privesc-facts.json (normalized)
                → ranker (deterministic rules + optional AI hypotheses)
                → privesc-plan.json (ranked items)
                → operator validates each via P06 actions
                → track attempts in evidence
```

## privesc-facts.json fields

- os, kernel, user, groups, sudo -l, suid[], caps[], cron[], writable_paths[]
- Each fact links to `source_artifact` hash from P03

## Ranking dimensions

| Factor | Weight |
|--------|--------|
| Evidence strength | High |
| Impact (root vs user) | High |
| Reversibility | Medium |
| Prerequisites | Medium |

Categories: **misconfiguration** (observed) vs **hypothesis** (needs validation).

## Validation rules

- No privilege change inferred from exit code alone
- GTFOBins references are citations, not auto recipes
- Intrusive actions require P06 invasive confirmation
- Linux first; Windows adapter interface reserved

## Prototype artifacts

- `prototype/neo-next/privesc/normalize-findprivs.sh` (design)
- `prototype/neo-next/privesc/rank-privesc-plan.sh` (design)
- `schemas/privesc-facts.schema.json` (design)

## v0.5 bridge

After run-findprivs ingest, call normalizer → update PRIVESC-PLAN section in notes.

## Acceptance

- Every recommendation cites evidence artifact
- AI prose cannot execute without action JSON
- Failed validation recorded, plan re-ranked

## Tests

Fixture FindPrivs output → deterministic rank order
