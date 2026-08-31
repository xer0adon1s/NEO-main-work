# P18 E2E Validation Checklist

Use on home Linux lab with HTB/THM disposable boxes. Record pass/fail per row.

## Prerequisites

- [ ] `./test/run-all.sh` passes
- [ ] `./test/production-integrity-gate.sh` passes
- [ ] `./tools/doc-truth-check.sh` passes
- [ ] Secret canary audit clean

## Box 1 — Linux web foothold

| Step | Action | Pass |
|------|--------|------|
| 1 | Scope intake (educational) | |
| 2 | VPN consent + connect | |
| 3 | Speed recon + AI triage | |
| 4 | `[p]` payload suggest → exact command in notes | |
| 4b | LOCK & LOAD verify (Y) — tools + SecLists paths | |
| 5 | `[o]` operator shell pane visible | |
| 6 | `[t]` try → y/N → output captured in WORKBENCH | |
| 7 | Analyze output → next command in PAYLOAD | |
| 8 | Repeat 6–7 until foothold | |
| 9 | Confirm foothold → `session_established` | |
| 10 | `[c]` continue → post-foothold enum | |

## Box 2 — Service enum

| Step | Action | Pass |
|------|--------|------|
| 1 | Recon surfaces non-web service | |
| 2 | Borg assimilate optional | |
| 3 | Workbench `[t]` on service-specific command | |
| 4 | `[z]` analyze after failed attempt | |

## Box 3 — Privesc

| Step | Action | Pass |
|------|--------|------|
| 1 | run-findprivs ingest | |
| 2 | rank-privesc-plan | |
| 3 | Workbench `[t]` on privesc validation command | |
| 4 | Mission reaches `privileged` or documented stop | |

## Core loop verification (all boxes)

- [ ] Never pasted exploit commands into conductor pane successfully (by design — must use `[t]` or operator pane)
- [ ] `workbench/attempts/*.json` records each try
- [ ] Post phase shows `[p]`/`[t]`/`[o]` on pause menu
- [ ] Recon pause offers enum plan generation (Y/n)
- [ ] Privesc pause offers ranked plan (Y/n) when FindPrivs ingested
- [ ] ListenAssist prints MSF handler when `--handler msf` or auto-detect
- [ ] No API keys in tmux scrollback or Investigation-Notes LOG

## Release sign-off

| Field | Value |
|-------|-------|
| Operator | |
| Date | |
| Boxes completed | /3 |
| Merge to live NEO approved | Y/N |
