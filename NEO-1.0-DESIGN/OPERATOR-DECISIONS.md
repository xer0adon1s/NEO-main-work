# Authoritative Operator Decisions

These decisions come directly from the project owner. Later AI agents should treat them as
requirements unless the owner explicitly revises them.

## OD-001 — Isolated design work

All review, architecture, proposed rewrites, implementation plans, schemas, and handoff
material must remain inside `NEO-1.0-DESIGN/`. Existing NEO code remains untouched during
this design phase.

## OD-002 — Implementation ownership

Codex is producing design and review work. Cursor and Claude will later review and implement
the accepted projects. Proposed replacement code is allowed, but it must remain isolated.

## OD-003 — ListenAssist is intentionally a placeholder

The current `foothold/ListenAssist.sh` is a placeholder. The real feature must ask the
operator questions, prepare the required listener workflow, explain what to run in the
operator's separate window or pane, observe/record results, and guide the next decision.

## OD-004 — Post-foothold enumeration intent

FindPrivs is an enumeration tool used after a foothold exists. Its purpose is to inspect the
compromised lab box for obvious privilege-escalation paths. The workflow should support an
already-open shell; SSH must not be the only transport assumption.

## OD-005 — Stub-related tests

Production-integrity tests must prevent placeholder or smoke-test scripts from shipping as
functional production entry points.

## OD-006 — API keys must never be exposed

NEO must be designed so API keys are not committed, printed, logged, included in notes,
embedded in tmux command strings, exposed through process arguments, or copied into artifacts.
This is a priority workstream.

## OD-007 — Borg's intended place in the mission

After babysteps and operator-supplied recon, the built-in AI reviews all available evidence
and creates an initial dossier. Before foothold, NEO asks whether the operator wants Borg to
assimilate the relevant vectors. Borg then researches the dossier, builds durable knowledge,
identifies attack vectors, and inventories available or required tools. This pipeline needs
a top-to-bottom redesign.

## OD-008 — Safe AI output handling

Replace unsafe free-form command execution with whatever structured and reviewable mechanism
best preserves the operator-in-control model.

## OD-009 — Engagement scope at project creation (educational + professional)

NEO must ask for **engagement mode and scope parameters when a new project is created**,
before recon or network activity begins. Two profiles share one schema:

- **Educational** — HTB, TryHackMe, course VMs, home labs. Lighter intake; lab target +
  declared networks; mis-aimed scans require a logged `scope-override` confirmation.
- **Professional** — Real authorized assessments. Requires client name, authorization
  reference (SOW/ticket), validity dates, in-scope hosts/networks, and
  `authorized-engagement` attestation. Out-of-scope network actions are **blocked** until
  an audited scope expansion is recorded.

Scope files live outside git (`~/.local/state/neo/projects/<project>/engagement-scope.json`).
Signed authorization documents are referenced by path only — never committed.

## OD-015 — Dual product vision

NEO 1.0 proves the CLI on educational lab boxes. The same core must **accommodate**
professional pentesting workflows without a separate codebase. P13 scope intake is a 1.0
deliverable, not a post-release add-on.

## OD-010 — Latest tools are acceptable

NEO may acquire the latest upstream tools. The design should not force permanent version
pinning. It should record the resolved source, version/commit when knowable, download time,
and checksum so later runs can explain exactly what was used and detect upstream changes.

## OD-011 — VPN termination requires consent

If NEO detects existing OpenVPN processes and changing profiles may require stopping them,
it must explain the effect and explicitly ask whether to terminate all detected OpenVPN
connections before proceeding. Declining must leave them untouched and return safe choices.

## OD-012 — Documentation must match behavior

The version, test totals, scan-mode descriptions, stage behavior, and AI context must be
derived from or checked against the implementation so stale documentation does not mislead
operators or AI agents.

## OD-013 — Missing local history

`CLAUDE-COLLAB.md` and `CURSOR-REVIEW-LOG.md` will be provided later. Work should proceed
without them, then Project 01 must ingest them and update traceability when available.

## OD-014 — Product milestones

NEO 1.0 is a functional CLI that works with AI agents and can guide an operator through easy,
authorized CTF/HTB-style boxes, with engagement scope captured at project creation for both
educational and professional use. NEO 2.0 adds a GUI after the 1.0 core has stable interfaces.
