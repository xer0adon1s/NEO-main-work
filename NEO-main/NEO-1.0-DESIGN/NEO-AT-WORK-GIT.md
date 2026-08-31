# NEO-at-work Git Setup Guide

Use this when pushing the **entire** desktop `NEO-main` folder to a separate
**neo-at-work** repository (not your live personal NEO git).

## What gets pushed

- Full v0.5 reference tree (`neo.sh`, `lib/`, `test/`, …)
- Complete `NEO-1.0-DESIGN/` design workspace
- `CLAUDE-COLLAB.md`, `CURSOR-REVIEW-LOG.md` (if present)
- Push scripts: `push-to-neo-at-work.sh`, `push-to-neo-at-work.ps1`

**Excluded** (via `.gitignore`): `projects/`, `vpn/`, `.env`, `vendor/`, etc.

## Quick push (when git is available)

### Linux / Git Bash (home lab)

```bash
cd ~/path/to/NEO-main
bash push-to-neo-at-work.sh
```

Creates private `neo-at-work` repo via `gh` if remote missing, then pushes.

### Windows (Git for Windows + PowerShell)

```powershell
cd C:\Users\DCI-SALES-4\Desktop\NEO-main
.\push-to-neo-at-work.ps1
```

### Manual remote

```bash
git init -b main
git add -A
git commit -m "NEO-at-work: v0.5 + full 1.0 design workspace"
git remote add neo-at-work https://github.com/YOU/neo-at-work.git
git push -u neo-at-work main
```

## Work PC limitation (2026-08-31)

Git was **not in PATH** on the operator work machine — push must run at home or
after installing [Git for Windows](https://git-scm.com/download/win).

## After push — tell Claude/Cursor

Point agents at:

```
NEO-1.0-DESIGN/AGENT-START-HERE.md
```

That file is the home-lab roadmap: what was built, test commands, integration
waves, and what differs between v0.5 and the prototype.

## Recommended repo layout

```
neo-at-work/                         # private GitHub repo
├── neo.sh, lib/, …                  # v0.5 reference (read-only until integration branch)
├── NEO-1.0-DESIGN/                  # all design + prototype
│   ├── AGENT-START-HERE.md          # ← agents read this first
│   ├── INTEGRATION-PLAN.md
│   ├── templates/scope-policy-template.md
│   └── prototype/neo-next/
├── CLAUDE-COLLAB.md
├── CURSOR-REVIEW-LOG.md
└── push-to-neo-at-work.sh
```

## Integration branch (later, at home)

```bash
git checkout -b neo-1.0-integration
# follow NEO-1.0-DESIGN/INTEGRATION-PLAN.md waves
# do NOT merge to personal NEO until P18 E2E passes
```

## Scope policy template (professional)

`NEO-1.0-DESIGN/templates/scope-policy-template.md` — fill out client RoE,
save outside repo, import with `scope-import.sh` at project create.
