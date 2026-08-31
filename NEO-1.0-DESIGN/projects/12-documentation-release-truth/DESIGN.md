# P12 — Documentation and Release Truth

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P09

## Problem

README mixes v0.4/v0.5, stale test counts, and incorrect scan-mode claims (CS-009).

## Single source of truth

| Claim | Authority file | Consumers |
|-------|----------------|-----------|
| Version | VERSION | README, neo.sh --version, diagnostic banner |
| Test counts | test/neo-diagnostic.sh + unit run-all | README, AGENTS.md |
| Registry scripts | registry.yaml | README tables, AGENTS.md |
| Scan modes | recon/babysteps.sh --help | README, AI bundle text |
| Stub status | production-integrity-gate | README capability list |

## doc-truth-check.sh (design)

Automated checks:
1. `grep VERSION` consistency across README, AGENTS.md, CLAUDE.md
2. Run diagnostic --count-only; compare to documented totals
3. Parse babysteps for speed vs deep flags; compare README bullets
4. Flag registry entries whose files fail integrity gate

## Prototype marking

Until integration, README sections for ListenAssist/findprivs should say **PROTOTYPE**
when pointing at NEO-1.0-DESIGN artifacts.

## Migration notes template

For each schema/state change:
- What changed
- Auto-migrate script path
- Rollback steps

## Secrets documentation

Document in README:
- Secret broker path
- No .env in repo
- Rotation pointer to P05 runbook

## Acceptance

- No conflicting version strings after integration
- Speed mode nmap -p- documented accurately
- Stubs not advertised as complete

## Deliverables at integration

- `tools/doc-truth-check.sh` — **integrated (Tier 3)**
- Generated TEST-COUNTS.md from CI (deferred)
- CHANGELOG.md entries per release (see RELEASE-NOTES.md)
