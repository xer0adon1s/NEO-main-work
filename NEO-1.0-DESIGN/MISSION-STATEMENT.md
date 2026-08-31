# NEO Mission Statement

**Authoritative product vision.** Read this before any design or code change.

---

## 1. What you mean (plain language)

**Metasploit is an analogy, not the product.**

- **Metasploit** = a *vehicle* for one slice of pentesting (modules, payloads, exploits).
  You pick a module, set options, run it — MSF is the shell around *that* work.
- **NEO** = a *vehicle* for the **entire engagement** — enum, recon, triage, Borg,
  foothold, post-enum, privesc, post-exploit, flags, notes, the lot.

NEO does **not** replace Metasploit. NEO **orchestrates everything** and pulls in
**whatever tool fits the step** — `nmap`, `gobuster`, `curl`, `msfconsole`, `FindPrivs`,
`linpeas`, etc. Metasploit is just **one tool in the toolbox**, used when exploit/handler
/post-module work is the right move.

Same *idea* as MSF (“here’s the next thing to run, with context”), but **scope is the
whole box**, not one phase.

---

## 2. Normalized mission (for agents)

**NEO is an end-to-end authorized engagement conductor.**

| Idea | Meaning |
|------|---------|
| **Full lifecycle** | Connect → recon → enum → triage → Borg → foothold → post-foothold → privesc → post → done. Same operator loop at **every** step. |
| **Orchestrator, not one tool** | NEO picks the *right* tool per step. Sometimes bash/curl, sometimes MSF, sometimes a listener — never “everything is Metasploit.” |
| **Hand-holder + pro speed** | Explains what and why (learning). Saves time via suggest → verify deps → try → analyze (pros). |
| **Operator in control** | NEO prepares and recommends; you approve. Nothing runs without permission. |

---

## 3. The universal loop (every phase)

```
Evidence / enum → leads
  → AI + Borg (optional)
  → [p] suggest next step (right tool for this phase)
  → LOCK & LOAD (do we have the tools/paths?)
  → [t] try with permission → capture output
  → AI analyze → next suggestion
  → repeat until this phase is done → [c] continue
```

Works the same in **recon**, **foothold**, **privesc**, and **post** — not a “foothold-only” feature.

---

## 4. Where Metasploit fits

| When | Example |
|------|---------|
| Recon / validation | MSF **auxiliary** scanner modules (optional) |
| Foothold / exploit | `msfconsole` exploit module, handler, or `msfvenom` stager |
| Privesc | MSF **local** modules only when evidence supports it |
| Post | MSF **post** modules (hashdump, etc.) when you already have a session |

When MSF **isn’t** the best fit, NEO suggests something else — raw `curl`, `gobuster`,
`ssh`, upload/execute, etc.

**NEO should know MSF well enough to suggest exact commands when MSF applies.**  
That is **not** the same as “NEO is a Metasploit wrapper.”

---

## 5. What NEO is NOT

- Not Metasploit++, not a fork, not “MSF with extra steps”
- Not a single-phase tool (foothold-only or privesc-only)
- Not autonomous — no auto-exploit

---

## 6. One-line pitch

**NEO is to a full pentest what Metasploit is to running exploit modules — the conductor
for everything, with AI and operator approval at each step.**

---

## 7. Docs that implement this

| Doc | Role |
|-----|------|
| `OPERATOR-DECISIONS.md` OD-016 | Requirement |
| `OPERATOR-WORKBENCH.md` | Pause-menu loop UX |
| `WORKFLOW-MAP.md` | Phase-by-phase flow |
| `projects/21-exploit-framework-conductor/` | MSF *when relevant* — not MSF-centric product |
