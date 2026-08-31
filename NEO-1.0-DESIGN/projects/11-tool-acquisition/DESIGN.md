# P11 — Latest-Tool Acquisition with Provenance

**Status:** review_ready · **Priority:** P2 · **Depends:** P01, P05, P09

## Problem

setup.sh fetches latest GitHub releases without recording what was installed (CS-008).
OD-010 accepts latest behavior but requires audit trail.

## Vendor manifest schema

`prototype/neo-next/schemas/vendor-manifest.schema.json`

```json
{
  "schema_version": 1,
  "entries": [{
    "name": "linpeas",
    "url": "https://github.com/...",
    "resolved_version": "4.0.0",
    "resolved_at": "2026-08-31T12:00:00Z",
    "sha256": "...",
    "destination": "vendor/linpeas.sh",
    "installer": "setup.sh"
  }]
}
```

## Commands (target)

| Command | Purpose |
|---------|---------|
| `neo-vendor install [name]` | Download + verify + update manifest |
| `neo-vendor verify` | Checksum all entries |
| `neo-vendor inventory` | Print manifest |
| `neo-vendor rollback NAME` | Restore previous entry if kept |

## Safety rules

- Prefer signed release assets when available
- Never install package names suggested by AI
- Checksum mismatch blocks use
- Offensive tools optional profile, not base install

## v0.5 migration

Replace setup.sh download block with manifest-aware installer; keep same 6 default tools.

## Prototype artifacts

- `projects/11-tool-acquisition/DESIGN.md` (this file)
- `tools/neo-vendor.sh` — **integrated (Tier 3)**

## Acceptance

- inventory answers what/where/when/hash
- Mismatch fails verify
- Reproducible from manifest + URLs

## Tests

Fixture manifest with wrong hash → verify fails
