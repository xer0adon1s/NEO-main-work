# P14 — Evidence Provenance and Investigation Notes

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P05

## Problem

Investigation-Notes.md mixes human curation, raw LOG, and AI prose without cryptographic
provenance or concurrent-write safety.

## Dual-layer model

| Layer | Format | Purpose |
|-------|--------|---------|
| Evidence store | JSONL + hashed artifacts | Machine truth, AI input |
| Investigation notes | Markdown sections | Human-readable report |

## Evidence API (prototype complete)

```bash
neo_evidence_init PROJECT
neo_evidence_record TYPE SOURCE SUMMARY [ARTIFACT] [CONFIDENCE]
neo_evidence_save_artifact LABEL   # stdin → artifacts/<label>-<hash>.txt
neo_evidence_record_artifact ...
```

## Event schema

```json
{
  "schema_version": 1,
  "timestamp": "ISO8601",
  "project": "boxname",
  "type": "recon|operator_observation|action_result|...",
  "source": "babysteps|operator|ai:claude",
  "summary": "redacted text",
  "artifact": "artifacts/abc123.txt",
  "confidence": "observed|inferred|operator_confirmed"
}
```

## Concurrency

- Append JSONL with single write per line (atomic on POSIX for small writes)
- Artifact writes: temp + mv
- Future: flock on events.jsonl for tmux multi-pane (14f)

## Support bundle export

`neo_evidence_export_bundle` — redacted tarball of events + artifacts; secrets stripped.

## v0.5 bridge

- Keep notes-lib section markers (AGENTS.md ownership table)
- Scripts write evidence first, then update curated sections from evidence IDs
- LOG section remains append-only preview + artifact pointers

## Acceptance

- Same-second writes do not overwrite (unique artifact hashes)
- Dossier JSON includes input_artifact_hashes array
- Canary secrets redacted

## Tests

`core-secrets-test.sh`, `workflow-prototype-test.sh`
