# NEO 1.0 Release Notes (pre-release draft)

**Version:** 1.0.0-rc (integration branch) · **Baseline:** v0.5

## Core product change — Operator Workbench (P20)

NEO's primary loop is now **suggest → try (with permission) → capture → analyze → repeat**:

- **`[o]perator shell`** — dedicated tmux pane for commands (conductor pane stays on pause menus)
- **`[t]ry command`** — permission-gated execution in operator pane or safe local argv
- **`[z] analyze failures`** — widened after any workbench attempt
- Mission state: `foothold_planning` → `foothold_attempt` → `session_established`

See `NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md`.

## Tier 0 — Core dependencies

- Secret broker, evidence JSONL, mission state machine, scope policy, typed actions, provider adapter

## Tier 1 — Safety

- No eval/bash -c in Borg/payload; tmux does not forward API keys

## Tier 2 — Workflows

- Scope intake (educational + professional), full ListenAssist, FindPrivs transport, Borg v2, VPN consent

## Tier 3 — Release polish

- `tools/doc-truth-check.sh`, `tools/neo-vendor.sh` (install/rollback), `recon/review-plan.sh`
- `lib/neo-pipeline-hooks.sh` — plan-enum, operator-recon, privesc rank at phase boundaries
- MSF handler in ListenAssist + `neo_mission_record_handler_plan`
- E2E checklist, known limitations doc

## Upgrade

See `NEO-1.0-DESIGN/UPGRADE-FROM-0.5.md`.

## Not included in 1.0

- GUI (P19)
- Auto-SSH operator pane (future)
- Live Borg web research (capability flag off)
