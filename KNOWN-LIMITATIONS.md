# NEO 1.0 Known Limitations

## Environment

- **Linux attack box required** — Bash, tmux, jq. Windows host cannot run the full pipeline.
- **Windows work PC** — run `powershell -File tools/windows-static-check.ps1` for file/safety checks without bash.
- **tmux auto-wrap** — Operator workbench needs `NEO_TMUX_WRAP=1` (default). Set `NEO_TMUX_WRAP=0` only for automation; `[t]ry` will not work without a session.

## Operator workbench (P20)

- **Two-pane workflow** — Commands must run in the operator pane (`[o]` then `[t]`), not in the NEO conductor pane.
- **Manual steps** — Browser interaction, multi-step listeners, and complex shell one-liners use `operator_pane` transport; NEO sends keys but does not wait for exit codes from remote targets.
- **Auto-SSH** — Not yet implemented; operator opens SSH manually in the work pane.
- **Lab E2E** — Full try→capture→analyze loop validated on operator's home Linux lab (P18); not run from design workspace.

## AI and Borg

- **Advisory + permissioned execution only** — No auto-exploit. Borg wind-up local steps use typed argv; remote steps use workbench `[t]`.
- **Web research** — Borg v2 dossier pipeline; live web research adapter deferred (capability flag default off).

## Scope and professional mode

- Professional scope import requires filled policy template; out-of-scope targets blocked unless educational override phrase used.

## Migration from v0.5

- Existing projects lack `WORKBENCH` section until first workbench run (template updated for new projects).
- `mission.json` created on bootstrap; legacy `project.meta phase` still used for pipeline walk.

## Deferred to post-1.0

- GUI 2.0 (P19)
- Session adapter (reverse shell → auto-target operator pane)
- Borg research index automatic consultation
