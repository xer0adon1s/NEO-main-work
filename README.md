# NEO-main-work

End-to-end authorized engagement conductor — enum through post-exploitation.

**Vision:** [`NEO-1.0-DESIGN/MISSION-STATEMENT.md`](NEO-1.0-DESIGN/MISSION-STATEMENT.md)  
**Operator loop:** [`NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md`](NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md)  
**Changelog:** [`MASTER-CHANGELOG.md`](MASTER-CHANGELOG.md) · **Doc index:** [`docs/INDEX.md`](docs/INDEX.md)  
**Run:** `./neo.sh <project> [target]` (Linux attack box + tmux)

NEO orchestrates the **whole box** (recon → foothold → privesc → post). Metasploit is one
tool among many — used when that step needs it. Same suggest → verify → `[t]` try → analyze
loop at every phase.

**Windows work PC:** `powershell -File tools/windows-static-check.ps1` (52 checks, no bash).  
**Linux offline gate:** `bash tools/linux-phase1-verify.sh` — see `tools/LINUX-PHASE1-INSTRUCTIONS.txt`.  
**Live lab sign-off:** `NEO-1.0-DESIGN/projects/22-live-simulation-block-h/DESIGN.md` (SIM-H / Block H).
