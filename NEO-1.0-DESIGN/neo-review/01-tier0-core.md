# NEO Tier 0 CORE — Line-by-Line Logic & Correctness Review

**Scope:** the *real* foundation files (Tier 0 CORE + safety/secrets/scope/AI infra). The
missing "AI Conductor"/Borg-v2 files are out of scope (catalogued separately).
**Method:** every listed file read in full; both known crashes reproduced and root-caused;
data-corruption and scope hypotheses verified by executing the real functions offline.
No files were modified.

---

## Headline

**The single most important finding:** `test/production-integrity-gate.sh` — described as
*THE* production safety/integrity gate — **crashes on line 11 before it runs a single
assertion**, and that crash is silently reclassified as an *expected* soft-failure by
`test/neo-diagnostic.sh`. So the gate that is supposed to verify "no API key forwarded
through tmux", "no `eval`/`bash -c` in the exec libs", "`.gitignore` excludes `.env`", and
"core libs present" **enforces none of them, and never will**, regardless of Wave-3 work.
Verified: the gate emits **0** `[ok]`/`[FAIL]` lines — zero checks execute.

Both this crash and the `neo-scope.sh` crash share **one root cause** (a bash `local`
gotcha), and it also silently corrupts scope evaluation and mission state elsewhere.

---

## Root cause shared by the two known crashes

Bash expands **all** RHS values on a single `local`/`declare` statement *before* it performs
any of the assignments. So a later variable that references an **earlier variable declared on
the same line** sees it as **unset** — which under `set -u` is a **fatal** error (exits the
shell, and is *not* catchable by `|| ...`), and even without `set -u` yields a **silently
empty** value.

Reproduced (bash 5.3):

```bash
g() { local a="$1" b="$a"; echo "a=[$a] b=[$b]"; }
g hello          # set -u  -> "a: unbound variable" (exit 1)
                 # no -u   -> a=[hello] b=[]   <-- b silently empty
```

A full scan of `lib/` and `test/` found **exactly two** same-line self-references — and they
are precisely the two reported crash sites. Fix for both: split the `local` onto separate
lines (declare the referenced var first).

---

## P0 findings

### P0-1 — Production integrity/safety gate is inert; failure masked as "expected"
**File:** `test/production-integrity-gate.sh:11` (crash) → masked at `test/neo-diagnostic.sh:75-80`

```sh
require_substantive_script() {
    local rel="$1" min_lines="$2" required_pattern="$3" file="${NEO_SOURCE_ROOT}/${rel}" count
    #                                                          ^^^^^ references same-line `rel`
```
The script sets `set -uo pipefail` (line 3). The **first** call
(`require_substantive_script foothold/... 40 ...`, line 21) evaluates the `local`, hits
`${rel}` unbound, and the shell **exits immediately** — before any of the ~40 assertions run.

**Failure scenario:** `bash test/production-integrity-gate.sh` prints only
`line 11: rel: unbound variable`, exit 1, **zero checks executed** (confirmed: 0
`[ok]`/`[FAIL]` lines). `neo-diagnostic.sh:79` then prints
`production-integrity-gate not yet green (expected until Wave 3 stub replacement)` — so the
crash is written off as normal. Because the crash is unconditional, the gate can **never** go
green even after stubs are replaced, so its perpetual redness is permanently ignored. Every
guarantee the gate claims to protect (the tmux-no-API-key check, the no-`eval`/no-`bash -c`
checks, the `.gitignore` `.env` check, core-lib presence) is **unverified in CI**.

**Fix:** split the declaration —
```sh
local rel="$1" min_lines="$2" required_pattern="$3" count
local file="${NEO_SOURCE_ROOT}/${rel}"
```
Separately, `neo-diagnostic.sh` should distinguish a *gate crash* (exit before any check)
from an *expected assertion failure*, so a broken gate can't hide behind the Wave-3 note.

### P0-2 — Scope enforcement crashes the whole tool under production `set -u`
**File:** `lib/neo-scope.sh:61`; reached from `lib/neo-actions.sh:75`

```sh
neo_scope_target_allowed() {
    local target="$1" host="${target%%:*}"     # host references same-line target
```
`neo.sh:9` runs `set -euo pipefail`, and `neo.sh` sources `neo-scope.sh`. In
`neo_action_execute` (`lib/neo-actions.sh:71-86`), any action document that carries a
`target` triggers `neo_scope_check_network "${target_host}"` → `neo_scope_target_allowed`
→ **unbound `target`** → **fatal exit of the entire `neo.sh` process**. Verified that the
`set -u` error is fatal even inside a `cmd || scope_rc=$?` guard (the `||` does not catch it).

**Downstream blast radius:**
- The scope check is the gate that keeps NEO from acting on an **out-of-scope** host during
  an authorized engagement. Under production settings it either kills the session outright
  (with `set -u`) or, if `set -u` were ever off, computes `host=""` for **every** target →
  `neo_scope_target_allowed` returns "not allowed" for everything → `neo_scope_check_network`
  returns 1 (educational warn) / 2 (professional block) for *all* targets. **Good news:** the
  empty-host degradation **fails closed** (blocks/prompts, never a silent scope-bypass). **Bad
  news:** the correct-path scope logic has therefore **never actually executed** — the only
  test that exercises it (`workflow-scope-test.sh:30`) dies on the same line.
- Every caller of `neo_scope_check_network` is affected. Today that is `neo-actions.sh`;
  any future caller inherits the crash.

**Fix:** split the `local`:
```sh
local target="$1"
local host="${target%%:*}"
```
After the fix, add a `workflow-scope-test.sh` case that drives `neo_scope_check_network`
end-to-end (not just `neo_scope_target_allowed`) so the enforcement path is regression-locked.

---

## P1 findings

### P1-1 — Mission-state writes clobber `mission.json` to 0 bytes on any `jq` failure (and return success)
**File:** `lib/neo-mission-state.sh` — pattern at lines 57-61, 73-77, 154-166, **187-192**,
**201-206**, **252-256** (also 29, 239-243)

Every mutator uses the unguarded pattern:
```sh
jq ... "${NEO_MISSION_FILE}" > "${tmp}"      # no exit-status check
mv -f -- "${tmp}" "${NEO_MISSION_FILE}"      # runs even if jq wrote nothing
```
When `jq` fails, `${tmp}` is empty and `mv` overwrites the good state file with an **empty
file**. The most exploitable triggers are the `--argjson` calls, which parse **operator-typed**
values as JSON:
- `neo_mission_record_msf_session` (`:187`, `--argjson msf_id "${session_id}"`) — a non-numeric
  Metasploit session id.
- `neo_mission_record_handler_plan` (`:201`, `--argjson lport "${lport}"`) — a port like
  `4444/tcp` or empty.
- `neo_mission_conductor_patch_int` (`:252`, `--argjson v "${value}"`).

**Verified failure scenario (executed against the real function):**
```
neo_mission_record_msf_session 'abc' ...
  -> jq: invalid JSON text passed to --argjson
  -> mission.json truncated from 373 bytes to 0 bytes
  -> function returns rc=0  (silent "success")
```
After this, `jq -r '.state' mission.json` yields empty and the state machine is permanently
broken for that project. Because the function returns **0**, no caller can detect the wipe.
These id/port values arrive from live operator input during the P21 foothold flow
(`# Record ... after operator confirms meterpreter/shell`), so a fat-fingered entry destroys
mission state mid-engagement. The passing `mission-state-test.sh` only ever feeds **valid**
numerics (`record_msf_session 7`, `lport 4444`), so this is untested.

**Fix:** guard the write — `jq ... > "${tmp}" || return 1` (or `&& mv ... || { rm -f tmp;
return 1; }`), and validate numeric inputs (`neo_core_valid_port`, `[[ id =~ ^[0-9]+$ ]]`)
before the `jq --argjson`. Apply to all mutators; `neo-scope.sh:99` and `neo-secrets.sh:63`
already do the right thing (validate-first / `printf`, not raw `jq`), so this is isolated to
mission-state.

---

## P2 findings (robustness / correctness gaps)

### P2-1 — CIDR fallback (no python3) is a naive string-prefix match
**File:** `lib/neo-scope.sh:55-57`
```sh
local net="${cidr%%/*}"
[[ "${ip}" == "${net}"* ]] && return 0
```
This drops the mask entirely and does a literal-prefix compare. For `10.10.10.0/24`,
net=`10.10.10.0`, so `10.10.10.5` does **not** match (false negative — most in-scope hosts
rejected), while contrived cases can over-match (e.g. net `10.1.1.1` matches `10.1.1.11`).
Only reached when `python3` is absent (present on the review host, so severity is limited),
but it is not a correct CIDR test. **Fix:** implement a real 32-bit mask compare in bash, or
require `python3`/`ipcalc` and fail closed when neither is available.

### P2-2 — Scope globals reused across projects (stale-scope confusion)
**File:** `lib/neo-scope.sh:76-82` (`NEO_SCOPE_FILE`/`NEO_SCOPE_MODE` are process globals)
`neo_scope_check_network` reuses an already-set `NEO_SCOPE_FILE` without confirming it belongs
to the target's current engagement. In a multi-project in-process session, scope loaded for
project A can be silently applied to an action for project B. Narrow trigger, but a real
correctness/safety smell for an authorization boundary. **Fix:** key the loaded scope to the
project and reload when it differs, or pass the scope file explicitly.

### P2-3 — IPv6 target parsing mangled
**File:** `lib/neo-scope.sh:61` `host="${target%%:*}"` turns `[::1]:80` into `[` . Host/CIDR
checks then never match IPv6. **Fix:** detect/strip the `[...]` bracket form before the port
split.

### P2-4 — `injection-payload-test.sh` is narrower than its name implies
**File:** `test/injection-payload-test.sh`
It only tests `neo-windup-actions.sh` command rejection + argv tokenization. It does **not**
drive `neo-actions.sh` execution or any evidence-redaction/`awk -v` path. That is *acceptable*
in practice because (a) `neo-evidence.sh` and `neo-actions.sh` use `jq --arg`/argv arrays with
**no** `awk -v`-with-user-data and **no** shell eval, and (b) `secret-canary-test.sh` does
prove redaction through the real evidence JSONL + artifact path. But the suite name implies
broader coverage than it delivers — false confidence. **Fix:** add a case that pushes shell
metacharacters through `neo_evidence_record`/`neo_action_execute` and asserts they are stored
literally / rejected.

### P2-5 — Unconditional `set -e` after `set +e` assumes global errexit
**Files:** `lib/neo-ai-cli.sh:40-43`, `lib/neo-ai-analyze.sh:72-80`
Both do `set +e; <call>; set -e`. If ever invoked from a context where errexit was **off**,
line `set -e` silently turns it on for the remainder of the caller. Harmless under `neo.sh`
(errexit always on), but fragile. **Fix:** save/restore with
`local -; set +e` or capture `$-` and restore.

### P2-6 — `.ovpn` filename interpolated into a tmux shell string
**File:** `lib/neo-vpn.sh:124`
```sh
tmux new-session -d -s "${session}" "sudo openvpn --config '${dest}'"
```
`${dest}` is placed inside a single-quoted string that tmux runs via `$SHELL -c`; a profile
filename containing a `'` breaks out and injects shell. Operator-local file, low risk, but
avoidable. **Fix:** pass argv tokens to tmux instead of building a shell string, or `printf
%q` the path.

### P2-7 — `rc` used without `local`
**File:** `lib/neo-vpn.sh:112` (`rc=$?` inside `neo_vpn_connect_profile`) leaks a global.
Benign; declare it `local`.

### P2-8 — GEMINI key not in evidence redaction set
**File:** `lib/neo-evidence.sh:33,51` redacts `ANTHROPIC_API_KEY OPENAI_API_KEY
ANTHROPIC_WORKSPACE_ID` only. `production-integrity-gate.sh` greps for `GEMINI_API_KEY` too,
implying it is in the threat model, but evidence never redacts it. Tool only uses Anthropic
today, so latent. **Fix:** add GEMINI/other provider keys to the redaction list (or drive it
from a single shared list).

---

## Things that are actually correct (verified, worth stating)

- **C4 — no API keys in tmux forward:** `NEO_TMUX_ENV_FORWARD` (`lib/neo-tmux.sh:92-97`) is an
  **allowlist** of exact variable names; no `*_API_KEY`/secret vars are present, and values
  are `printf %q`-quoted. Confirmed clean. This is the right design (allowlist, not denylist)
  and it holds. A brand-new tmux session also doesn't inherit the parent's exported env, so
  even the parent's exported `ANTHROPIC_API_KEY` isn't carried into the wrapped session.
- **Secret broker (C1/C9):** `neo_secret_load` is silent on stdout (verified in
  core-secrets-test and secret-canary-test), enforces mode `600`/`400` and rejects symlinks
  (`neo-secrets.sh:36-43`), and `neo_secret_store` writes via a 600 temp + atomic `mv` with
  `printf` (can't fail-clobber). The Anthropic API key never appears in `argv`: `claude-cli`
  path strips it with `env -u` (`neo-provider.sh:39`), and the HTTP path passes it via a
  600-perm `curl --config` file (`neo-provider.sh:74-83`), after validating it matches
  `^[A-Za-z0-9_-]+$` (so it can't break the config quoting).
- **Redaction actually works end-to-end:** `secret-canary-test.sh` plants a canary secret and
  proves it is stripped from both the evidence JSONL and a saved artifact — this exercises the
  real `neo_secret_redact_text` → `neo_evidence_record`/`neo_evidence_save_artifact` path, not
  a stub.
- **The 3 "passing" suites genuinely exercise real paths** (verified by reading them):
  core-secrets (store/load/redact/audit), secret-canary (redaction through evidence),
  mission-state (transitions + record). Their green is trustworthy *for the inputs they use* —
  the gap is only the untested bad-input path in P1-1.
- **No `eval`/shell-string execution in the exec path:** `neo_action_execute` runs argv arrays
  via `timeout -- "${argv[@]}"` (no shell); `neo_windup_command_rejected` +
  `read -ra` tokenization is sound belt-and-suspenders.
- **Import graph:** `neo-1.0-bootstrap.sh` sources core→secrets→evidence→actions→
  mission-state→scope→provider in dependency order, and each lib re-sources its own
  transitive deps, so the (odd-looking) ordering of `neo.sh`'s `NEO_LIB_SCRIPTS` array does
  not produce a use-before-source bug for the Tier-0 set. No circular-source problem observed.

---

## Severity tally

| Severity | Count | Items |
|----------|-------|-------|
| **P0** | 2 | Integrity gate inert & masked (`production-integrity-gate.sh:11`); scope check crashes tool under `set -u` (`neo-scope.sh:61`) |
| **P1** | 1 | Mission-state `jq`→`mv` clobbers `mission.json` to empty & returns success (`neo-mission-state.sh`, `--argjson` mutators) |
| **P2** | 8 | CIDR prefix-match fallback; cross-project scope globals; IPv6 parse; narrow injection test; `set -e` restore; tmux filename injection; unscoped `rc`; GEMINI not redacted |

**Common thread:** P0-1, P0-2 (and the silent-empty variant behind P0-2) are the *same* bash
`local` self-reference bug, and P1-1 is the same class of "unchecked step then destructive
`mv`". Fixing the `local`-split (2 sites) and adding an exit-status guard before the
mission-state `mv` (plus numeric validation of `--argjson` inputs) resolves the two crashes and
the data-corruption path. The most consequential single fix is **P0-1**: until the gate runs,
none of NEO's advertised safety invariants are actually being checked.
