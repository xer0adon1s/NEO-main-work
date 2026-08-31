Before writing or modifying any script in this repo, read **`AGENTS.md`**
in this directory (same folder as this file).

For NEO vision, repo layout, AI modes, BORG collective, wordlists, VPN paths,
and Claude API setup, read **`README.md`**.

Optional local briefing (gitignored, not on GitHub):

- **`CLAUDE-COLLAB.md`** — co-lab agenda, operator prompt log (Prompts 1–38), Phases 1–58
- **`CURSOR-REVIEW-LOG.md`** — dev changelog; every phase includes verbatim operator prompt(s)

When you add features, log the operator's exact prompt in `CURSOR-REVIEW-LOG.md` (Phase 19 convention).

**Release:** NEO **v0.5** (`VERSION`; `neo.sh --version`).

**Pre-review:** `./test/neo-diagnostic.sh` (61 checks) + unit suites under `test/` (162 tests total).
