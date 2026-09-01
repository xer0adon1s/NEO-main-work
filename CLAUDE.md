Before writing or modifying any script in this repo, read **`AGENTS.md`**
in this directory (same folder as this file).

For NEO vision, repo layout, AI modes, BORG collective, wordlists, VPN paths,
and Claude API setup, read **`README.md`**.

**Changelog (all agents):** [`MASTER-CHANGELOG.md`](MASTER-CHANGELOG.md) — major milestones.  
**Full phase log:** [`docs/collab/CURSOR-REVIEW-LOG.md`](docs/collab/CURSOR-REVIEW-LOG.md) — verbatim operator prompts (Phase 19).  
**Co-lab brief:** [`docs/collab/CLAUDE-COLLAB.md`](docs/collab/CLAUDE-COLLAB.md) (optional local).  
**Doc catalog:** [`docs/INDEX.md`](docs/INDEX.md).

**Release:** NEO **v0.5** (`VERSION`; `neo.sh --version`).

**Pre-review (Linux attack box):**
```bash
bash tools/linux-phase1-verify.sh   # recommended gate (run-all + diagnostic + Phase 73–74)
# or: ./test/run-all.sh && ./test/neo-diagnostic.sh
```
Read each runner's summary line for current counts (suites/assertions grow with new tests).
**Last offline green (2026-09-01):** `linux-phase1-verify.sh` 6/6 · `neo-smoke-test.sh` 24/24.
