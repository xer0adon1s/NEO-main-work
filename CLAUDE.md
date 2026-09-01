Before writing or modifying any script in this repo, read **`AGENTS.md`**
in this directory (same folder as this file).

For NEO vision, repo layout, AI modes, BORG collective, wordlists, VPN paths,
and Claude API setup, read **`README.md`**.

Optional local briefing (gitignored, not on GitHub):

- **`CLAUDE-COLLAB.md`** — co-lab agenda, operator prompt log (Prompts 1–38), Phases 1–58
- **`CURSOR-REVIEW-LOG.md`** — dev changelog; every phase includes verbatim operator prompt(s)

When you add features, log the operator's exact prompt in `CURSOR-REVIEW-LOG.md` (Phase 19 convention).

**Release:** NEO **v0.5** (`VERSION`; `neo.sh --version`).

**Pre-review (Linux attack box):**
```bash
bash tools/linux-phase1-verify.sh   # recommended gate (run-all + diagnostic + Phase 73–74)
# or: ./test/run-all.sh && ./test/neo-diagnostic.sh
```
Read each runner's summary line for current counts (suites/assertions grow with new tests).
**Last offline green (2026-09-01):** `linux-phase1-verify.sh` 6/6 · `neo-smoke-test.sh` 24/24.
