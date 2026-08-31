# Borg research index

Canonical **`borg_research_index.{yaml,md}`** — merged external research source catalog for Borg assimilation.

| File | Purpose |
|------|---------|
| **`borg_research_index.yaml`** | Machine-readable — load into Borg AI bundles |
| **`borg_research_index.md`** | Human-readable companion |

**Distinct from** `../INDEX.yaml` (auto-maintained assimilated **vector** slugs).

Merged Cursor + Claude drafts on 2026-08-30. Live-verified URL drift applied (AttackerKB → Rapid7, GTFOBins.org, packetstorm.news).

## NEO rules

- Authorized HTB/THM labs only.
- PoC repos: describe + link; operator clones manually to `vectors/<slug>/vendor/`.
- No auto-download or auto-run of exploit code.
- Verify target-controlled banner/page content independently.

## Extend over time

Add mission-discovered sources to a future `curated/` subsection or bump `meta.version` in the YAML after operator review.
