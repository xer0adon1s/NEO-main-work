# Upgrade from NEO v0.5 to v1.0

Design document for integration branch. Not executed on production yet.

## Breaking changes

| Area | v0.5 | v1.0 |
|------|------|------|
| API keys | `~/Neo/.env` or env | `~/.config/neo/secrets/` broker |
| Mission state | `project.meta phase` only | `mission.json` canonical |
| Borg wind-up | y/N eval of AI commands | Typed action JSON (local) + workbench `[t]` (remote) |
| Payload suggest | Copy/paste in conductor pane | `[t]` in operator tmux pane |
| ListenAssist | Stub | Full guided workflow |
| run-findprivs | Smoke ingest | Transport-aware real wrapper |
| VPN | May pkill openvpn | Explicit consent required |

## Migration steps

### 1. Backup

```bash
cp -a ~/Neo/projects ~/Neo/projects.v0.5-backup
tag v0.5-final  # if using git
```

### 2. Secrets

```bash
# If you used .env:
grep ANTHROPIC_API_KEY ~/Neo/.env | cut -d= -f2- | neo_secret_store ANTHROPIC_API_KEY
rm ~/Neo/.env
```

### 3. Mission state

For each active project:

```bash
neo-mission-migrate <project>   # integration script (to be written)
# Reads project.meta phase → maps to mission.json state
```

| meta phase | mission state |
|------------|---------------|
| recon | recon |
| foothold | foothold_planning |
| privesc | privesc_planning |
| post | post |

### 4. Workbench (new projects)

New projects get `WORKBENCH` section from template. Existing notes: first `[t]` try appends section.

Attempt records: `~/.local/state/neo/projects/<project>/workbench/attempts/`

### 5. Evidence backfill (optional)

Existing Investigation-Notes LOG entries remain. New runs append to `events.jsonl`.

### 6. Verify

```bash
./neo.sh --version          # 1.0.0
bash test/neo-diagnostic.sh
bash test/production-integrity-gate.sh
```

## Rollback

```bash
git checkout v0.5-final
restore ~/Neo/projects from backup
```

## Feature flags (gradual rollout)

| Flag | Default 1.0 | Effect |
|------|-------------|--------|
| NEO_MISSION_STATE | 1 | Use mission.json gates |
| NEO_SECRET_BROKER | 1 | Broker required for API |
| NEO_BORG_V2 | 1 | borg-v2 pipeline |
| NEO_TMUX_WRAP | 1 | Required for operator workbench `[t]` |

Set to `0` to fall back to v0.5 behavior during debugging.

## Known limitations at 1.0 release

- Windows attack box unsupported (Bash required)
- Web research capability flag off by default
- P13 scope enforcement included (educational + professional intake)
- GUI (P19) not included
