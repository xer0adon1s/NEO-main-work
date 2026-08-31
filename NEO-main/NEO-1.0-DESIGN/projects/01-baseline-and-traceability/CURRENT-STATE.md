# Current State — Baseline Complete

Status: review_ready (2026-08-31). Static review complete; CLAUDE-COLLAB.md and
CURSOR-REVIEW-LOG.md ingested. Existing v0.5 source remains unchanged.

## Repository profile

- Current version file: `0.5`
- Production shell files: 29
- Production shell lines: approximately 7,035
- Test shell files: 11
- Test shell lines: approximately 1,351
- Registered entries: 14
- Walked phases: recon, foothold, privesc, post

## Strong foundations

- Mission phase ordering and checkpoint/resume behavior are explicit.
- Investigation notes use marked sections so scripts can update owned content safely.
- Large output can be stored as artifacts while notes retain a preview and pointer.
- Operator approval is already a visible product principle.
- AI triage, Borg, payload guidance, tmux capture, and pre-foothold interaction are modular.
- The test history shows serious attempts to reproduce real tmux and state bugs.

## Confirmed blockers and discrepancies

### CS-001 — ListenAssist production placeholder

`foothold/ListenAssist.sh` is seven lines and only sets phase metadata. It does not start a
listener, ask questions, guide a second window, capture results, or update foothold evidence.
This is intentional placeholder status per OD-003, but documentation presents it as working.

Routed to: P02, P09, P12, P16.

### CS-002 — run-findprivs production placeholder

`privesc/run-findprivs.sh` is seven lines and ingests a hard-coded smoke verdict instead of
running `FindPrivs.sh` through an existing shell or SSH transport.

Routed to: P03, P09, P12, P17.

### CS-003 — Production-integrity gap

`test/neo-diagnostic.sh` contains an anti-stub integrity check for `babysteps.sh`, but no
equivalent semantic guards for ListenAssist or run-findprivs. Existence and syntax are not
enough to establish production capability.

Routed to: P09.

### CS-004 — Repository `.env` secret risk

`lib/neo-ai.sh` can source `${NEO_HOME}/.env`, and README documents it as a credential source.
`.gitignore` does not exclude `.env`. Sourcing also treats it as shell code instead of strict
key-value data.

Routed to: P05, P09, P12.

### CS-005 — tmux command secret exposure

`lib/neo-tmux.sh` forwards `ANTHROPIC_API_KEY` by building a tmux shell command containing its
value. Shell quoting protects parsing but not confidentiality.

Routed to: P05, P08, P10.

### CS-006 — Free-form AI command execution

`lib/neo-borg.sh` parses commands from AI prose and executes them with `eval` or `bash -c`
after a y/N prompt. Prompt-injection warnings cannot make arbitrary shell text a safe API.

Routed to: P04, P06, P09.

### CS-007 — VPN process ownership

`lib/neo-vpn.sh` can use `sudo pkill -x openvpn`, affecting every matching process. OD-011
requires explicit informed consent before that action.

Routed to: P10.

### CS-008 — Unrecorded moving dependencies

`setup.sh` fetches latest/master artifacts without recording resolved version, commit,
download time, or checksum. OD-010 accepts latest behavior but requires provenance.

Routed to: P11.

### CS-009 — Documentation drift

README identifies NEO as both v0.5 and v0.4, publishes stale test totals, and the AI recon
bundle says the nmap full-range cross-check is deep-only even though speed mode runs it.

Routed to: P12, P09.

### CS-010 — Historical records absent from GitHub

**Resolved locally (2026-08-31):** both files now in workspace root. Ingested in
`HISTORY-INGESTION.md`. Phases 1–60 traceability in `REQUIREMENTS-TRACEABILITY.yaml`.

Routed to: P01 (closed).

## Validation limitation

The Windows review host has no WSL distribution, Bash, or ShellCheck. No Linux scripts or
tests have been executed. Runtime claims remain unverified until P18.
