# NEO Review — Tiers 1-3: Operator Workbench, LOCK & LOAD, Pipeline Hooks, MSF/Recon/Privesc

Reviewer: paid authorized code review (read-only). Repo: `/home/alexander/Work/NEO-main-work-review`
Verified against `./test/run-all.sh` ground truth + targeted offline reproduction. No network/target commands run.

## Severity summary

| Sev | Count | Findings |
|-----|-------|----------|
| P0  | 0 active | (one **latent** P0 gate-bypass, currently unreachable — F8) |
| P1  | 8 | F1 workbench extract dup, F2 toolkit awk, F3 offer-skip return, F4 mission-state MSF, F5 MSF builders gated, F6 api-key store mismatch/real-key clobber, F7 menu fragment invisible, F8 assisted no-confirm (latent) |
| P2  | 6 | F9–F14 (colors, run-lin* validation, global leak, id type, confirm inversion, classify over-broad) |

**Single most important finding: F6** — `test/recon-bundle-test.sh` overwrites the operator's *real* Anthropic API key at `~/.config/neo/secrets/ANTHROPIC_API_KEY` with the bogus test value `sk-ant-test-key-12345` every time it runs (confirmed: the file exists with that value on this box). Root cause is a genuine product bug: `neo_ai_save_api_key` and `neo_ai_load_api_key` disagree on where the key lives.

---

## P1 findings

### F1 — Workbench "extract last command" returns the command TWICE (awk `exit` re-runs END)
**File:** `lib/neo-workbench.sh:64-85` (`neo_workbench_extract_last_command`)
**Test:** `test/workbench-test.sh` FAIL "extract last command".

The awk program's `flush_exact()` does `print exact_buf; exit`. In awk, an `exit` in a main rule **still runs the `END` block**, and `END { flush_exact(); flush_last() }` calls `flush_exact()` again with `exact_buf` still non-empty — so the buffer is printed a second time.

Reproduced: input with a single `curl -s http://10.10.10.1/` yields output `curl -s http://10.10.10.1/\ncurl -s http://10.10.10.1/`.

**Blast radius (worse than the test):** the doubled string now contains a newline. `neo_workbench_classify_transport` (line 93) treats any embedded `\n` as `operator_pane`, and `neo_workbench_try_loop_step`/`neo_workbench_try_at_pause` will then `tmux send-keys` **both lines** into the operator pane — the intended command executes twice against whatever is in pane B. So a single suggested command silently runs twice.

**Fix:** make the flush idempotent, e.g. clear the buffer after printing (`print exact_buf; exact_buf=""; exit`) and likewise guard `flush_last`, or set a global `emitted` flag checked at the top of both flush functions and in `END`.

### F2 — Toolkit wordlist/path extraction awk fails to compile → path preflight is a silent no-op
**File:** `lib/neo-toolkit.sh:104` (`neo_toolkit_extract_paths_from_command`)
**Test:** `test/toolkit-test.sh` FAIL "detects wordlist path" (awk syntax error printed to stderr).

Line 104: `if ($i ~ ^(/|~|\$HOME/)) print $i` — the right-hand side of `~` is a bare, unquoted `^(...)` which is not a valid awk regex/expression: `awk: syntax error ... if ($i ~ ^(/|~|\$HOME/))`. Because it's a **compile** error, the *entire* awk program aborts and emits nothing — so not just the leading-path rule but also the `-w/--wordlist` rule (lines 97-99) and the SecLists rule (line 105) never run. The LOCK & LOAD "verify wordlists exist before you run" feature therefore checks **no paths at all**, silently, on every invocation.

**Fix:** use a proper regex literal with escaped slashes and `$`: `if ($i ~ /^(\/|~|\$HOME\/)/) print $i`.

### F3 — `offer_plan_enum` / `offer_privesc_rank` return success when the prompt is skipped
**Files:** `lib/neo-pipeline-hooks.sh:109-136` and `:161-208`
**Tests:** `plan-enum-hook-test.sh` FAIL "offer should skip"; `privesc-rank-hook-test.sh` FAIL "should skip interactive".

Both tests assert that in non-interactive mode the offer returns non-zero (`! neo_pipeline_offer_... && ok`). Reproduced: `neo_pipeline_offer_plan_enum vtest 10.10.10.5 </dev/null` returns rc=0.

Root cause: when `neo_pipeline_prompt_yn` returns 1 (non-interactive / declined), the trailing `if neo_pipeline_prompt_yn ...; then ... fi` (plan-enum) leaves the function's exit status = the `if` compound = 0. `offer_privesc_rank` similarly does `if ! prompt_yn; then return 0; fi` → returns 0 on skip. The header comment promises hooks are "skipped when non-interactive," but callers can't distinguish "ran the plan" (0) from "skipped" (also 0).

**Fix:** return non-zero on the skip/decline branch, e.g. `neo_pipeline_prompt_yn '...' y || return 1` at the decision point (keep the early `[[ offered == 1 ]] && return 0` semantics as-is or reconcile them, but a skipped prompt must be non-zero to match the contract the tests encode).

### F4 — MSF session state tracking is broken: two invalid transitions
**File:** `lib/neo-mission-state.sh:33-45` (transition table) and `:170-193` (`neo_mission_record_msf_session`)
**Test:** `session-adapter-test.sh` — 4 of the 6 failures ("to foothold planning", "record msf session", "msf session id", "state after msf session") trace here.

Two distinct defects, both reproduced by hand:

1. **`preflight -> foothold_planning` is not an allowed edge.** The only edge out of `preflight` is `preflight:recon` (line 36). The test's setup transition therefore dies (`neo: invalid mission transition: preflight -> foothold_planning`), and because state stays `preflight`, `neo_mission_record_msf_session` then rejects it (`MSF session may not be recorded in state: preflight`), cascading into the id/state assertions.

2. **Even from a correctly-reached `foothold_planning`, the session is never marked established.** `record_msf_session` (line 177-178) tries `neo_mission_try_transition session_established` when state is `foothold_planning`, but the table has **no** `foothold_planning:session_established` edge — only `foothold_attempt:session_established`. `try_transition` fails silently, the session JSON is written, but `.state` stays `foothold_planning`. Reproduced: after walking `recon→…→foothold_planning` then `record_msf_session 3`, state is still `foothold_planning`, so the "auto transition to session_established" contract is unmet.

**Fix:** decide the intended path and make table + code agree. Minimal: in `record_msf_session`, when state is `foothold_planning`, hop `foothold_planning→foothold_attempt→session_established` (both edges exist); OR add a direct `foothold_planning:session_established` edge. Separately, the session-adapter test's one-shot `preflight→foothold_planning` setup needs either a valid walk or a real edge — flag to owner which is intended (the `neo_mission_sync_pipeline_phase` design walks the long chain, suggesting the test's shortcut is the anomaly, but the product code's own auto-transition is still wrong regardless).

### F5 — MSF command *string builders* refuse to emit unless msfconsole is installed locally
**File:** `lib/neo-exploit-framework.sh:185` (`neo_msf_search_command`), `:205` (`neo_msf_post_module_command`); same pattern `:126` (`neo_msf_handler_command`)
**Test:** `session-adapter-test.sh` FAIL "msf search command", "post module command".

Both builders do `neo_msf_binary_available msfconsole || return 1` before constructing what is purely an **advisory text string** meant to be shown to the operator / typed into a separate pane. On any box without msfconsole (this review box; CI), they return 1 and produce empty output. Proven: with a stub `msfconsole` on `PATH`, both produce exactly the expected strings (`msfconsole -q -x "search cve:2021; exit"` and `msfconsole -q -x "sessions -i 2; getuid; exit"`); without it, rc=1/empty.

This contradicts the module's own design note ("Operator executes via NEO workbench [t] in the operator tmux pane") — the attack box generating the advice need not be the box running MSF, and MSF may be installed later. The offline test suite can therefore never pass on a box lacking MSF.

**Fix:** drop the local-availability guard from the pure string builders (keep availability checks only where NEO would actually *invoke* msfconsole, e.g. menu/handler-start paths). Availability can still gate a hint, but not construction of the advisory string.

### F6 — API key save/load location mismatch; test clobbers the operator's REAL key
**Files:** `lib/neo-ai.sh:54-80` (`neo_ai_load_api_key` / `neo_ai_save_api_key`), `lib/neo-secrets.sh:49-66`
**Test:** `recon-bundle-test.sh` FAIL "save api key".

`neo_ai_save_api_key` calls `neo_secret_store ANTHROPIC_API_KEY`, which writes to `${NEO_SECRET_DIR}` (default `~/.config/neo/secrets/`). But `neo_ai_keyfile_path`/the fallback branch of `neo_ai_load_api_key` (lines 64-71) read `NEO_AI_KEYFILE` (default `~/.config/neo/anthropic.key`). Save never writes `NEO_AI_KEYFILE`, so the test's `test -f "${NEO_AI_KEYFILE}"` fails — save and load use different storage.

**Real-world harm (the important part):** the test sets `NEO_AI_KEYFILE` for isolation but does **not** set `NEO_SECRET_DIR`/`XDG_CONFIG_HOME`, and save ignores `NEO_AI_KEYFILE`. So `neo_ai_save_api_key "sk-ant-test-key-12345"` writes the bogus key into the operator's **actual** secret store. Confirmed on this box: `~/.config/neo/secrets/ANTHROPIC_API_KEY` (mode 600) exists and contains the test value — i.e. running the unit suite silently overwrites the user's live Anthropic key and breaks their AI setup.

**Fix (product):** make save/load agree on one location — either have `neo_ai_save_api_key` also honor/write `NEO_AI_KEYFILE`, or drop the vestigial keyfile fallback and standardize on the secret broker. **Fix (test hygiene):** the test must export `NEO_SECRET_DIR` (and `XDG_CONFIG_HOME`) into its temp dir so it can never touch the real store.

### F7 — Workbench `[t]`/`[o]` menu items are dispatchable but never displayed
**File:** `lib/neo-menu.sh:127` calling `lib/neo-workbench.sh:47` (`neo_workbench_menu_fragment`)

`neo_workbench_menu_fragment` takes `phase` as `$1`, but `neo-menu.sh:127` calls it with **no arguments**: `run="${run}$(neo_workbench_menu_fragment)"`. Inside, `phase=""` → `neo_workbench_visible_phase ""` returns 1 → `|| return 0` → empty fragment. Reproduced: with args it returns ` / [t]ry it / [o]perator pane`; with no args it returns empty.

Net effect: the outer guard sets `NEO_PAUSE_HAS_WORKBENCH=true` and `neo.sh` *does* dispatch `t`/`o` (neo.sh:818-826 → `neo_workbench_handle_choice`), but the operator is **never shown** the `[t]ry it / [o]perator pane` options — the core operator-loop UI is invisible unless the user blind-types the keys. (Contrast: `neo_borg_menu_fragment "${project}"` on line 109 is passed its arg.)

**Fix:** `run="${run}$(neo_workbench_menu_fragment "${phase}" "${project}")"`.

### F8 — LATENT gate bypass: assisted try-loop sends to pane B with NO confirmation
**File:** `lib/neo-workbench.sh:176-284` (`neo_workbench_try_loop_step`, `assisted=true` path)

In non-assisted mode the function gates with `neo_workbench_confirm_yes 'Send to operator pane and run?'` (line 196). In `assisted=true` mode that entire y/N block is skipped (lines 195-210) and, with no confirmation, it either runs `neo_windup_execute_safe` (local_safe) or `neo_operator_pane_send_command "${cmd}"` (operator_pane, line 234) — i.e. it can type an AI-suggested command straight into pane B, which may hold a live SSH/meterpreter session on the target. The `local_safe` branch is still constrained to argv (windup rejects shell metachars), but the `operator_pane` branch has no content restriction and no human approval.

**Currently unreachable:** `neo_workbench_try_loop_step` has **no callers** in the repo (grep-confirmed) — it is the entry point the missing Tier A/B conductor was meant to drive. So today this is latent, not an active P0. **If** the conductor lands and calls it with `assisted=true`, it becomes a P0 safety-guarantee breach (unattended command to a live target).

**Fix:** require an explicit gate even in assisted mode before any `operator_pane` send (or restrict assisted auto-run to `local_safe` argv only and force confirm for `operator_pane`). Also note the live, *reachable* [t] path (`neo_workbench_try_at_pause`) **is** correctly gated — see Safety notes.

---

## P2 findings

### F9 — neo-interact.sh color codes are literal, not escapes
`lib/neo-interact.sh:16-21`: `C_RESET="${C_RESET:-\033[0m}"` stores the literal 4 chars `\033[0m` (no `$'...'`), so `printf '%s'` prints them verbatim instead of coloring. Cosmetic only. Fix: use `$'\033[0m'` as other modules do.

### F10 — run-linenum.sh / run-linpeas.sh: unvalidated SSH target, inconsistent NEO_HOME
`privesc/run-linenum.sh:6,32` and `privesc/run-linpeas.sh:6,32`: `TARGET` is taken positionally and passed to `ssh "${TARGET}"` with no `user@host` regex validation and no `--` guard (contrast `run-findprivs.sh:93` which validates `^[A-Za-z0-9._-]+@...$`). A target beginning with `-` could be read as an ssh option. Also `NEO_HOME:-${HOME}/Neo` default differs from every other script's repo-root default. Low risk (operator-supplied), but tighten to match run-findprivs.

### F11 — `offer_privesc_rank` leaks loop vars to global scope
`lib/neo-pipeline-hooks.sh:162` declares locals but omits `offered` (assigned line 166) and `tmp` (assigned line 180) — both become globals. Add them to the `local` list.

### F12 — msf_session_id stored as number vs string across paths
`neo_mission_record_msf_session` writes `msf_session_id` via `--argjson` (JSON number); `neo_mission_record_session` writes it via `--arg` (JSON string). Downstream readers use `// empty` so both work today, but the schema is inconsistent — pick one type.

### F13 — Confirmation asymmetry: operator_pane (live target) gets fewer confirms than local_safe
`lib/neo-workbench.sh:467-476` and `:213-215`: `local_safe` (runs on the *attack* box via argv) gets a second confirm; `operator_pane` (types into pane B, potentially a shell *on the target*) gets only one. The higher-risk transport has the weaker gate. Consider a second confirm (or an explicit target-pane warning) for `operator_pane`.

### F14 — `neo_windup_command_rejected` over-broad on `&`, `?`-less URLs fine but query strings routed to pane
`lib/neo-windup-actions.sh:15`: rejects on `[\;\|\&\`\$\(\)\<\>]`. A legitimate one-liner such as `curl 'http://h/?a=1&b=2'` contains `&` and is therefore classified `operator_pane` rather than executed as safe argv. Safe-side (never mis-runs), but pushes many benign commands to the manual/pane path. Acceptable; noted for awareness.

---

## Wiring / safety verification (as requested)

- **`[t]`/`[o]` dispatch:** `neo.sh:818-826` (and the second menu loop at 971-982) classify via `neo_menu_classify` (`lib/neo-menu.sh:40-41` → try-command/open-operator) and call `neo_workbench_handle_choice` → `neo_workbench_try_at_pause` / `neo_workbench_open_at_pause`. Dispatch is correct. **But** the options are never advertised — see **F7**.
- **Wind-up y/N gate (live path):** The reachable [t] path `neo_workbench_try_at_pause` **is** gated: `neo_workbench_confirm_yes 'Execute with your permission'` (line 467) fires before any `neo_operator_pane_send_command` / `neo_windup_execute_safe`, and empty/malformed input fails the `^[yY]` test (default deny). `neo_windup_execute_safe` additionally re-checks `neo_windup_command_rejected` and only ever runs argv via `neo_action_execute` (no eval/`bash -c`). No bypass found on the live path. The **only** gate gap is the unreachable assisted loop — **F8**.
- **Quoting / injection:** Target-derived strings flow into commands as argv (e.g. `babysteps.sh:205` `curl ... "http://${TARGET}:${port}/"`, ListenAssist argv arrays), not via shell strings; `plan-enum.sh`/`ListenAssist.sh`/`normalize-findprivs.sh` build JSON with `jq --arg`/`--argjson` and NUL-delimited `jq -Rs`, avoiding `awk -v` interpolation. No `awk -v <target>` injection surface found. `FindPrivs.sh:110-120` `sh -c` strings are GTFOBins *reference data* (printed, never executed).
- **`set -euo pipefail`:** Standalone scripts have it (`babysteps.sh:19`, recon/privesc entrypoints); `FindPrivs.sh:32` intentionally uses `set -uo pipefail` (no `-e`) since enumeration expects non-zero exits. Library files correctly omit `set -e` (they are sourced). Consistent.
- **Empty-array / no-match handling:** `review-plan.sh` and `neo_workbench_has_attempts` use `nullglob`/`compgen`; `normalize-findprivs.sh` uses `"${arr[@]:-}"` + `select(length>0)`. Handled well.

## MSF integration correctness (priority area)
Two independent defects break session tracking (**F4**: missing/incorrect state edges) and one breaks advisory command generation on MSF-less boxes (**F5**: over-eager availability guard). Together these account for all 6 session-adapter failures: 4 from F4 (the transition cascade), 2 from F5 (string builders). The post-module catalog, AI-context block, resource-script writer, and handler-command construction are otherwise correct (exploit-framework-test passes 10/10).

## Test-vs-code attribution note
Several failures sit at the test/spec boundary and the owner should confirm intent:
- F3, F5 read as **product** bugs the tests correctly catch (contract mismatch / non-portable guard).
- F4 defect #1 (`preflight→foothold_planning`) *could* be a stale test shortcut, **but** F4 defect #2 (bad auto-transition) is unambiguously a product bug.
- F6 is a product inconsistency **and** a dangerous test-isolation gap (clobbers real creds) — both should be fixed.
