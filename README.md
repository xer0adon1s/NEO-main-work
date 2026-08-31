# NEO-main-work

End-to-end authorized engagement conductor — enum through post-exploitation.

**Vision:** [`NEO-1.0-DESIGN/MISSION-STATEMENT.md`](NEO-1.0-DESIGN/MISSION-STATEMENT.md)  
**Operator loop:** [`NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md`](NEO-1.0-DESIGN/OPERATOR-WORKBENCH.md)  
**Run:** `./neo.sh <project> [target]` (Linux attack box + tmux)

NEO orchestrates the **whole box** (recon → foothold → privesc → post). Metasploit is one
tool among many — used when that step needs it. Same suggest → verify → `[t]` try → analyze
loop at every phase.

**Windows work PC:** `powershell -File tools/windows-static-check.ps1` (29 checks, no bash).
