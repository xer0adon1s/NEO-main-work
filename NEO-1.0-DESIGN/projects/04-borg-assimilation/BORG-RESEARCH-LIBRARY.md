# Borg Research & Method Library — Design Document

**Status:** draft · **Phase:** 65+ · **Owner:** Borg / P04 assimilation  
**Related:** `knowledge/resources/borg_research_index.yaml`, `knowledge/library/`,  
`lib/neo-borg-disclosure.sh`, `lib/neo-borg-library.sh`, P13 engagement scope policy

---

## 1. Operator intent

You asked for a Borg research library that:

1. Captures **every** useful pentest methodology taught across HTB, TryHackMe, OSCP, OSWE, OSEE, GXPN, and red-team training — including **multiple walkthroughs per box** (alternate solve paths are features, not duplicates).
2. Powers Borg assimilation and payload suggest with deep technique context.
3. Enforces **two disclosure profiles**:
   - **Educational** — teach CVE/technique/attack-path logic; **never** spoil that the live target is a known lab box or hand over a pre-solved cheat sheet.
   - **Professional** — full intel: name similar boxes, link walkthrough cross-refs, surface all relevant library entries for the engagement.

This document is the **architecture** for that system. It does **not** claim the entire web has been scraped — bulk ingestion is a phased pipeline with licensing, dedup, and disclosure gates.

---

## 2. Mental model (unchanged)

| Component | Role |
|-----------|------|
| **NEO** | Engagement conductor — recon → foothold → privesc → post; operator approval always |
| **Borg `[b]`** | Research + assimilate **one vector at a time** into `knowledge/vectors/<slug>/` |
| **Payload `[p]`** | Next command for **this step**, grounded in mission notes + Borg dossiers |
| **Method library** | Long-lived **ingested** reference corpus (techniques + walkthrough extracts) |
| **Research index** | *Pointers* to public sources (NVD, HackTricks, IppSec index, …) — not box spoilers |

```
                    ┌─────────────────────┐
  Enum / triage ──▶ │  Mission vectors    │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
     knowledge/library   Borg assimilate   Payload suggest
     (ingested corpus)   vectors/<slug>/    (next command)
              │                │                │
              └────────────────┴────────────────┘
                               │
                    disclosure mode filter
                    (educational | professional)
```

---

## 3. What “capture ALL walkthroughs” actually means

### 3.1 Scope categories

| Category | Examples | Library path |
|----------|----------|--------------|
| **Lab platforms** | HTB, TryHackMe, PG, VulnHub | `library/walkthroughs/<platform>/` |
| **Cert practical labs** | OSCP, OSWE, OSEE, GXPN course boxes | `library/cert-tracks/<cert>/` |
| **Technique canon** | SUID, Kerberoast, SQLi, deserialisation | `library/methods/<technique-slug>/` |
| **CVE-centric** | CVE-2021-41773, Log4Shell, … | cross-linked from methods + walkthroughs |

### 3.2 Multiple walkthroughs per box (required)

Each **box identity** is a stable `box_id` (e.g. `htb:reactor`, `thm:ignite`). Under it:

```
library/walkthroughs/htb/reactor/
  meta.yaml                    # box_id, platform, difficulty, tags, CVEs
  paths/
    ippsec-2021-03-12/
      meta.yaml                # author, url, license, ingest_date, path_name
      steps.md                 # normalized steps (professional tier)
      educational.md           # technique-only summary (no box title in output)
    0xdf-2021-04-01/
      ...
    official-htb-community/
      ...
```

**Rules:**

- Every path is a **first-class entry** — Borg may cite “Path B used Redis Gopher + cron” without merging into Path A.
- Paths share `meta.yaml` CVE/tag index so professional mode can say “same CVE on HTB X and THM Y”.
- Educational mode serves `educational.md` slices or AI-generated technique abstracts — never `steps.md` verbatim with box name.

### 3.3 What we will NOT do

- Commit full copyrighted writeup text without license clearance.
- Auto-scrape during an operator’s live session (latency, ToS, noise).
- Replace operator thinking in educational mode with “this is box X, step 3 is…”.

---

## 4. Educational vs professional disclosure

### 4.1 Source of truth

Priority order for `neo_borg_disclosure_mode(project)`:

1. `project.meta` → `engagement_mode=educational|professional`
2. `projects/<p>/engagement-scope.json` → `.mode` (P13)
3. `NEO_ENGAGEMENT_MODE` / `NEO_SCOPE_MODE` env
4. **Default: `educational`** (safe for HTB/THM practice)

### 4.2 Behavioral matrix

| Behavior | Educational | Professional |
|----------|-------------|--------------|
| Name HTB/THM box title as “the answer” | **Forbidden** | Allowed |
| Cite CVE + technique + tool commands from evidence | Allowed | Allowed |
| Link `library/walkthroughs/...` paths in AI bundle | **Suppressed** | Included |
| “Same vuln on box A and box B” cross-ref | **Forbidden** (box names) | Encouraged |
| Borg wind-up `[RUN:…]` from dossier | Allowed (adapt to target IP) | Allowed |
| ELI5 / Payload / Borg AI rules block | `neo_borg_disclosure_ai_rules()` | same function, different text |

### 4.3 Check function (implemented)

| Tool | Purpose |
|------|---------|
| `lib/neo-borg-disclosure.sh` | `neo_borg_disclosure_mode`, `neo_borg_disclosure_ai_rules`, `neo_borg_disclosure_check`, `neo_borg_disclosure_filter_text` |
| `tools/borg-disclosure-check.sh` | CLI linter for library files before git commit |
| `test/borg-disclosure-test.sh` | Offline regression |

**`neo_borg_disclosure_check educational "<text>"`** flags patterns like:

- “this is the Reactor box”
- “HackTheBox machine …”
- “IppSec walkthrough for …”
- “cheat sheet for this box”

Professional mode **always passes** the linter (full intel allowed).

### 4.4 Runtime enforcement layers

1. **AI system rules** — appended to every Borg/Payload/ELI5 bundle (done Phase 65).
2. **Bundle content** — library walkthrough paths omitted in educational mode (`neo_borg_library_context_for_vector`).
3. **Post-generation lint** (planned) — optional `neo_borg_disclosure_check` on AI output before saving to notes in educational missions.
4. **Human review** — ingest pipeline rejects commits that fail `borg-disclosure-check.sh`.

---

## 5. Ingestion pipeline (phased — not “scrape the whole web tonight”)

### Phase A — Schema + tooling (current)

- [x] `knowledge/library/README.md` layout
- [x] `lib/neo-borg-library.sh` paths + CVE grep lookup
- [x] Disclosure module + CLI check
- [x] `schemas/library-walkthrough.schema.json`
- [x] `tools/borg-library-ingest.sh` (manual ingest + `--check-only`)
- [x] Seed entries: `redis-unauth-rce` method + `htb:apache-path-traversal-example` path
- [x] `lib/neo-borg-library-ai.sh` — **AI-first** library synthesis (Claude + research index)
- [x] `tools/borg-library-harvest.sh` — `--research TOPIC` (mechanical fetch = AI context only)
- [ ] Provider-native web search (`NEO_PROVIDER_WEB_RESEARCH=1`) when API supports it

### Phase B — Curated seed (human + AI assist)

Sources (from `borg_research_index.yaml` + operator additions):

| Source type | Ingest strategy |
|-------------|-----------------|
| IppSec transcripts | Technique extraction → `educational.md`; full path → `steps.md` + disclosure tags |
| 0xdf posts | Same split |
| HTB official writeups | Professional tier; educational abstract required |
| Course PDFs (OSCP/OSWE) | **Operator-local only** — not in public git; path in `.gitignore` |
| MITRE ATT&CK / HackTricks | `library/methods/` technique docs (already technique-first) |

### Phase C — AI-driven harvest (implemented prototype)

```
borg-library-harvest --research "TOPIC"
  ├── bundle: borg_research_index.yaml + disclosure rules + optional NVD/URL context
  ├── Claude synthesizes Educational + Professional library sections
  ├── disclosure-check (educational hard-fail)
  └── borg-library-ingest → knowledge/library/
```

**Mechanical fetch is NOT the product** — `curl`/NVD/`html-to-text` only feeds optional
context into the AI bundle when `NEO_BORG_HARVEST=1`. The librarian is Claude.

**Operator controls:**

- `--platform htb|thm|oscp|...`
- `--box-id htb:reactor` (append path, never overwrite without `--force`)
- `--dry-run` + review diff

### Phase D — Borg integration at assimilate time

When `[b]org` runs:

1. Build evidence bundle (ports, services, triage) — today.
2. **Query library** by CVEs/techniques in vector string — professional only.
3. Merge with `borg_research_index` “where to look” URLs — not full text.
4. AI writes dossier with disclosure rules attached.
5. Optional: post-assimilate **Borg-guided payload suggest** (implemented Phase 65).

---

## 6. Data model sketch

### `library/walkthroughs/<platform>/<box>/meta.yaml`

```yaml
box_id: htb:reactor
platform: hackthebox
display_name: Reactor          # professional bundles only
difficulty: medium
tags: [windows, web, deserialisation]
cves: []
techniques: [T1190, T1059]
paths_count: 3
```

### `library/walkthroughs/.../paths/<path-id>/meta.yaml`

```yaml
path_id: ippsec-2021-03-12
source_url: https://...
author: IppSec
license: fair-use-summary
ingested: 2026-08-31
foothold_summary: ASP.NET ViewState deserialisation
privesc_summary: null
disclosure:
  educational_safe: true
  professional_full: true
```

### `library/INDEX.yaml` (machine index)

```yaml
version: 1
by_cve:
  CVE-2021-41773:
    - library/walkthroughs/htb/...
by_technique:
  redis-unauth-write:
    - library/methods/redis-unauth-rce/
by_box:
  htb:reactor:
    paths: [ippsec-..., 0xdf-...]
```

---

## 7. Cert track mapping (OSCP / OSWE / OSEE / GXPN)

| Cert | Library focus | Educational note |
|------|---------------|------------------|
| **OSCP** | Broad foothold + privesc patterns, buffer overflow template, Active Directory basics | Teach “unquoted service path” without naming PG box |
| **OSWE** | Source review, white-box chains, auth bypass patterns | Cite OWASP classes + language quirks, not exam lab name |
| **OSEE** | Advanced Windows / kASLR / custom exploit dev | Technique-only during course labs |
| **GXPN** | EDR evasion, C2, opsec | Professional red-team engagements get full cross-refs |

Directory: `library/cert-tracks/{oscp,oswe,osee,gxpn}/<lab-id>/` with same `paths/` multi-walkthrough layout.

---

## 8. Integration with NEO features (Phase 64–67)

| Feature | Status |
|---------|--------|
| Borg multi-vector assimilate (`a`, `1,3`) | Done |
| `[b]` menu gated when all vectors assimilated | Done |
| Payload Borg-guided (option 0) | Done |
| Post-assimilate → payload suggest Y/n | Done |
| Multi-slug payload focus picker | Done |
| STATUS Borg progress blurb | Done |
| Red herring skip (`s` in vector pick) | Done |
| Disclosure AI rules in Borg/Payload/ELI5 | Done |
| Library CVE lookup (professional) | Stub |
| Full web harvest | **Not started** (this design) |
| Final human report (`[f]`, `--report`) | Done — see `FINAL-REPORT.md` |

---

## 9. Legal & ethics guardrails

1. **Authorized labs only** — same as NEO mission statement.
2. **No exam brain-dumps** — cert track content is technique abstraction + operator-local full notes.
3. **Provenance required** — every ingested path has `source_url`, `author`, `license`.
4. **Git policy** — `knowledge/library/walkthroughs/**/steps.md` may be gitignored for copyrighted sources; keep `educational.md` + `meta.yaml` in repo.
5. **Professional mode** still requires P13 RoE for real client targets.

---

## 10. Success criteria

| Metric | Target |
|--------|--------|
| Educational mission | Operator never sees box title from library in AI output (spot-check + `borg-disclosure-check`) |
| Professional mission | Borg cites ≥1 library path when CVE match exists |
| Multi-path | ≥2 paths per popular HTB box without dedup merge |
| Ingest | Operator can add one walkthrough path in &lt;5 min via `borg-library-ingest.sh` |
| Tests | `borg-disclosure-test.sh` + library index tests in CI |

---

## 11. Recommended build order (after this doc)

1. `schemas/library-walkthrough.schema.json` + ingest CLI skeleton  
2. Seed 3 boxes × 2 paths each (manual ingest, prove INDEX)  
3. Post-AI disclosure lint on educational missions  
4. Harvest worker behind `NEO_BORG_HARVEST=1` feature flag  
5. GUI 2.0 library browser (professional mode only) — P19 boundary  

---

## 12. Operator FAQ

**Q: Will NEO scrape every HTB writeup automatically?**  
A: Not in one shot. The library is designed for exhaustive coverage over time via ingest pipeline + your contributions. Bulk scrape runs are operator-triggered, rate-limited, and disclosure-checked.

**Q: I’m on HTB — will Borg tell me the box name?**  
A: Not in **educational** mode (default). You get CVE/technique teaching. Set `engagement_mode=professional` only when you explicitly want full cross-refs (e.g. comparing a client finding to known lab analogues).

**Q: Multiple IppSec videos for one box?**  
A: Each becomes a `paths/<path-id>/` entry. Payload suggest can prefer the dossier you assimilated on-mission; the library holds the rest for professional lookup.

---

*Document version: 2026-08-31 · Phase 65 · Operator prompt: educational/professional library + capture all walkthrough methods.*
