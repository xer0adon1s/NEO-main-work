# NEO 1.0 Design Workspace

This directory is the isolated design and implementation-planning workspace for NEO.
The existing repository source is the read-only reference implementation. Nothing under
this directory is automatically sourced, executed, installed, or used by `neo.sh`.

## Purpose

Produce a complete, AI-readable implementation package that Cursor and Claude can review
and later use to repair, extend, or rewrite NEO without confusing proposed work with the
current application.

## Hard boundary

- Existing NEO files are not modified during this design effort.
- Proposed code, replacement files, schemas, migrations, and patches belong here.
- Every proposed change must identify its target source file and acceptance tests.
- No document in this directory should contain a real API key, VPN credential, target
  credential, private key, or live engagement data.
- Current-source facts, operator requirements, review findings, and proposed designs must
  remain visibly distinguishable.

## How to use this package

1. Read `OPERATOR-DECISIONS.md` for the authoritative product decisions.
2. Read `MASTER-MANIFEST.yaml` for project order, dependencies, and status.
3. Read `AI-HANDOFF.md` before asking an AI agent to implement anything.
4. Work through `projects/` in dependency order, one project at a time.
5. Do not integrate a project until its acceptance criteria and required tests are satisfied.

## Project set

The design is divided into 19 implementation projects:

1. Baseline and requirements traceability
2. ListenAssist workflow
3. Post-foothold enumeration
4. Borg assimilation pipeline
5. Secrets and credential safety
6. Safe AI action execution
7. Operator recon intake
8. AI provider abstraction
9. Test integrity and production guards
10. VPN lifecycle and consent
11. Tool acquisition and provenance
12. Documentation and release truth
13. Engagement scope policy (educational + professional intake)
14. Evidence and investigation-note model
15. Service-specific enumeration framework
16. Foothold and session state machine
17. Privilege-escalation workflow
18. CLI 1.0 validation and release gates
19. GUI 2.0 boundary and API readiness

## Snapshot integrity

At workspace creation, the 64 existing repository files had the aggregate manifest hash:

`16A2897DB8CA38F92A6B8B6437597DDF268DE56161BB056D3722350C8A481E46`

The hash is calculated from sorted relative paths and each file's SHA-256. Files in this
design directory are excluded. It is used only to confirm that design work did not mutate
the source snapshot.

## Status

**Design phase complete (2026-08-31).** All 19 projects are `review_ready`, including P13
engagement scope (educational HTB/THM labs + professional authorized assessments).

| Doc | Purpose |
|-----|---------|
| `PROGRESS.md` | Live status board |
| `INTEGRATION-PLAN.md` | v0.5 → 1.0 file migration map |
| `IMPLEMENTATION-ROADMAP.md` | Waves, checklists, time estimates |
| `SECRETS-RUNBOOK.md` | P05 operator reference |
| `UPGRADE-FROM-0.5.md` | Migration guide |
| `AGENT-START-HERE.md` | **Home lab agent roadmap — read this first at home** |

Prototype code lives in `prototype/neo-next/`. Run tests on a Linux host:

```bash
cd NEO-1.0-DESIGN && bash tests/run-all.sh
```

Production `neo.sh` is **not** modified until integration on a separate NEO-at-work branch.
