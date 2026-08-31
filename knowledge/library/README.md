# Borg Method Library

Canonical store for **ingested** pentest methodology — distinct from:

| Path | Purpose |
|------|---------|
| `knowledge/vectors/<slug>/` | Per-vector dossiers from live Borg assimilations on missions |
| `knowledge/resources/borg_research_index.yaml` | *Where to look* on the public web (URLs, not box spoilers) |
| `knowledge/library/` | **Curated ingested text**: techniques, cert lab patterns, walkthrough extracts |

## Layout (planned)

```
library/
  INDEX.yaml              # machine index: CVE → entries, technique → entries
  methods/                # technique-first (SUID, Kerberoast, SQLi chains, …)
  walkthroughs/           # box-scoped extracts (metadata + paths, multiple per box OK)
  cert-tracks/
    oscp/
    oswe/
    osee/
    gxpn/
```

Each walkthrough entry keeps **provenance** (source URL, author, license, ingest date) and
**disclosure tags** (`educational_safe_summary` vs `professional_full_intel`).

## Disclosure

NEO never serves raw walkthrough text to the operator in **educational** mode during an active
lab mission. Borg uses technique/CVE slices only. See `lib/neo-borg-disclosure.sh` and
`tools/borg-disclosure-check.sh`.

Full design: `NEO-1.0-DESIGN/projects/04-borg-assimilation/BORG-RESEARCH-LIBRARY.md`.

## Tools

- `tools/borg-library-ingest.sh` — manual ingest + disclosure lint
- `tools/borg-library-harvest.sh` — **AI research** (`--research TOPIC`); optional NVD/URL as context only
- `lib/neo-borg-library-ai.sh` — Claude synthesis + `borg_research_index` bundle
