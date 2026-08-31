# NEO Secrets Runbook (P05)

Operator reference for API keys and discovered credentials. Design artifact — apply at integration.

## Storage

| Item | Location | Permissions |
|------|----------|-------------|
| Anthropic API key | `~/.config/neo/secrets/ANTHROPIC_API_KEY` | 600 |
| Workspace ID | `~/.config/neo/secrets/ANTHROPIC_WORKSPACE_ID` | 600 |
| Lab creds (optional) | `~/.config/neo/secrets/LAB_<NAME>` | 600 |

**Never:** repo `.env`, `projects/*/`, Investigation-Notes.md plaintext, tmux command strings.

## Setup (post-integration)

```bash
mkdir -p ~/.config/neo/secrets && chmod 700 ~/.config/neo/secrets
neo-secret store ANTHROPIC_API_KEY    # interactive wrapper
neo-secret audit ~/Neo                # fail if .env in tree
```

## Rotation — suspected exposure

1. **Revoke** key at [Anthropic Console](https://console.anthropic.com/)
2. **Remove** local file: `neo_secret_remove ANTHROPIC_API_KEY`
3. **Search** for canary/leaked substring:
   ```bash
   grep -r 'sk-ant-' ~/Neo/projects/ ~/.local/state/neo/ 2>/dev/null || true
   ```
4. **Review** tmux sessions: `tmux list-panes -a -F '#{pane_current_command}'`
5. **Store** new key via broker
6. **Log** in Investigation-Notes LESSONS section (manual)

## Discovered target credentials

- Store in CREDS section (human-owned) or encrypted broker entry — never LOG raw
- `neo_secret_redact_text` runs before evidence/AI bundles
- Support export uses redacted bundle only

## CI / test canaries

Tests use `NEO_TEST_CANARY_KEY=canary-neo-test-do-not-use` — must never appear in:
- git commits
- test output files
- evidence artifacts after redaction

## Incident severity

| Exposure | Action |
|----------|--------|
| Key in git commit | Revoke + git filter-repo / new key |
| Key in tmux ps | Kill session, rotate, patch neo-tmux |
| Key in HTB notes | Redact notes, rotate if external |
