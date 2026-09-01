# NEO Dry-Run Simulation — 2026-08-31 evening

**⚠️ SIMULATION STOPPED EARLY — PARTIAL RESULTS.** Halted mid-ELI5 AI call to conserve
remaining usage budget. Everything below is real, actually-observed behavior (not
inferred) up to the stop point; nothing after it was exercised.

**Method:** Live execution, not code reading. Ran `./neo.sh dryrun-sim-01 192.0.2.1`
for real in a tmux session (`neo-dryrun-sim-01`, driven via `send-keys`/`capture-pane`)
against `192.0.2.1` — an IANA TEST-NET-1 address (RFC 5737), permanently reserved,
never a real host — inside the isolated repo clone
`/home/alexander/Work/NEO-main-work-review`, run against its current (uncommitted)
working-tree state. No files edited, no commits, no real network fetches, no real VPN
connection attempted.

**Cursor note (2026-08-31):** This is the **tmux send-keys / capture-pane** method —
not piped stdin. Piped input disables tmux self-wrap by design and cannot adapt to
prompts; see `DAILY-WORK-2026-09-01.md` § Dry-run methods compared.

---

## What was actually covered

1. **Boot sequence** — splash/HUD intro rendered correctly.
2. **AI provider prompt** — chose `[A] Claude Pro/Max (claude -p)`. Confirmed banner
   rendered correctly.
3. **First-boot VPN gate — found a real gap (see Bugs).** Declining VPN on a fresh
   project hard-exits the whole mission (`neo: VPN / target setup failed.`), even
   though a target IP was already given on the CLI. No bypass flag exists.
4. **Worked around it via NEO's own resume path** (not a hack): re-ran the same
   project without `--fresh`. Since AI mode + target were already cached in
   `project.meta` from the first attempt, `neo_boot_should_run` correctly skipped the
   boot sequence on the second run, so the VPN gate became non-fatal
   ("`[!] VPN not detected — connect manually when needed`") and the mission proceeded.
   This is legitimate, documented NEO behavior, not an exploit of a bug.
5. **Engagement scope setup** — `[E]` Educational → Platform `3) Home lab` → purpose
   line → networks `192.0.2.0/24` → `authorized-lab` confirmation. All rendered and
   saved correctly to `~/.local/state/neo/projects/dryrun-sim-01/engagement-scope.json`
   (note: this state path lives **outside** the repo/project directory, under a
   user-global `~/.local/state/neo/` tree — worth knowing, not necessarily a bug).
6. **Recon phase — real execution.** rustscan ran (capped ~45s), then nmap ran
   (`Host seems down`, 0 hosts up — correct and expected against a reserved,
   unreachable IP). `BabySteps-findings.txt` was created. No crash, no hang beyond
   the tool's own normal timeout.
7. **Real AI triage call — worked correctly end-to-end.** NEO built a mission bundle
   (794 bytes) from the empty recon findings and piped it through `claude -p` for
   real (this is a genuine subprocess call to the Claude Code CLI, not a mock). The
   response was accurate and well-reasoned: it correctly identified `192.0.2.1` as a
   reserved documentation address, correctly inferred this was "almost certainly a
   simulation/dry-run rather than live engagement data" from the target+project name,
   correctly noted the empty PORTS table, and gave sound generic next-step advice.
   Result was written to `Investigation-Notes.md → AI Triage` as claimed.
8. **LOCK & LOAD toolkit preflight — confirmed the awk fix works.** Answered `Y` to
   "Verify tools & wordlists for this suggestion?" — got `[ok] nmap` / "All checked
   dependencies look ready," no compile error dumped. This directly confirms tonight's
   `neo-toolkit.sh:104` awk-regex fix is good in live execution, not just `bash -n`.
9. **ELI5 — started but not completed.** Answered `y` to "Explain this at ELI5 level
   now?", pressed Enter to use the latest suggestion, saw "`[*] ELI5 — building
   teaching bundle…`" and the AI call begin (~81s countdown observed). **Simulation
   was stopped here, mid-call, before this AI response returned.** Whether ELI5
   renders/saves correctly is therefore unverified.

## What was NOT covered (stop happened before these)

- ELI5 response completing and being saved.
- `[b]` Borg/assimilate (the syntax-fix verification never got exercised).
- `[t]` try-it / `[o]` operator-pane (the menu-visibility fix never got exercised).
- `[p]` payload-suggest, `[a]` ask-claude at a later pause.
- Foothold, privesc, and post phases entirely.
- `[f]` final-report and the mission-complete report-offer guard fix.
- Mission-state (`mission.json`) transitions were never snapshotted, since the run
  never got past the recon pause.
- Conductor/Tier-A-B prototype stub behavior (never reached).

## Bugs / findings

### NEW finding — first-boot VPN gate has no bypass for a pre-supplied target
**`neo.sh:1170-1175`**, `lib/neo-boot.sh` `neo_boot_vpn_flow()`

On a **fresh** project (first boot), declining the VPN prompt (`[y/N]` → `N`) always
hard-exits the entire mission setup (`neo: VPN / target setup failed.`, exit 1) —
even when a target IP/hostname was already supplied on the command line and no VPN
is actually needed to reach it (e.g. a local lab host, or in this case a synthetic
test address). There is no `--no-vpn`/`--offline` flag or equivalent. The **only**
way to proceed is either (a) actually establish a real VPN connection, or (b) exploit
the fact that a second, non-`--fresh` invocation of the same project skips the boot
sequence entirely once AI-mode + target are cached in `project.meta` — which is
real, intended "resume" behavior, but not a documented or obvious way to get past a
declined VPN on true first boot. Worth deciding whether this is intentional
(NEO explicitly targets HTB/THM, which do require VPN) or whether a first-run
`--no-vpn` escape hatch should exist for local/offline lab targets. Severity: P2/P3 —
not a crash-the-tool bug, but a real UX/workflow gap that would confuse anyone trying
to point NEO at a non-VPN target for the first time.

### Confirmed FIXED (not new, but positively verified live, not just via `bash -n`/unit tests)
- `lib/neo-toolkit.sh:104` LOCK & LOAD awk regex — confirmed working live (item 8 above).
- `lib/neo-ai-cli.sh` `neo_ai_cli_call()` → `claude -p` pipeline — confirmed working
  live end-to-end: bundle build → subprocess call → real response → render → save to
  Investigation-Notes.md (item 7 above). This was previously only known to exist as
  code; this run is the first real evidence it actually works.

### Nothing else new
No crashes, no raw error dumps, no hangs beyond normal tool timeouts, and no
mission-state corruption observed in the portion actually exercised (recon phase
through the start of ELI5). This is a genuinely positive, if incomplete, signal for
tonight's fixes — the parts that got covered held up under real execution, not just
static analysis.

---

## Verdict (based on partial coverage only)

**Not a full go/no-go — too little of the mission was actually exercised** (recon +
the very start of a pause menu only; foothold/privesc/post, `[b]`/`[t]`/`[o]`/`[f]`,
and mission-complete were never reached). What **was** covered held up cleanly:
real AI integration works, the toolkit fix works, recon orchestration is solid. The
one new, real finding (first-boot VPN gate has no offline/pre-supplied-target bypass)
is a workflow gap worth a decision, not a blocker for tonight's HTB run specifically
(since a real HTB session *will* have a real VPN connection, so this gate won't
actually get in the way live) — but it does mean this dry run itself couldn't be
completed cheaply, and a second pass with more usage budget is needed to actually
cover `[b]`/`[t]`/`[o]`/`[f]` and the later phases before treating the full mission
loop as verified end-to-end.

**Artifacts:** `projects/dryrun-sim-01/` (notes, meta), `~/.local/state/neo/projects/dryrun-sim-01/mission.json`
