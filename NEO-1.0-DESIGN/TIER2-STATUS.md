# NEO 1.0 Tier 2 — Workflow Status

**Updated:** 2026-08-31

Tier 2 rough drafts are **complete**. Production integrity gate should now **pass** stub checks (ListenAssist, run-findprivs).

---

## Scope (P13)

| File | Purpose |
|------|---------|
| `tools/scope-intake.sh` | Interactive [E]ducational / [P]rofessional wizard |
| `tools/scope-import.sh` | Import filled `templates/scope-policy-template.md` |
| `neo.sh` | `neo_scope_ensure` before phase walk; `neo_mission_bootstrap` |

Scope files: `~/.local/state/neo/projects/<project>/engagement-scope.json`

---

## Stubs replaced (P02, P03)

| File | Lines | Behavior |
|------|-------|----------|
| `foothold/ListenAssist.sh` | ~170 | ncat/nc/socat listener plan + evidence + cybersec_finish |
| `privesc/run-findprivs.sh` | ~130 | SSH / ingest / existing-shell + FindPrivs notes ingest |

---

## Borg v2 (P04)

| File | Entry |
|------|-------|
| `borg/borg-v2.sh` | JSON dossiers only — no execution |
| `borg/borg.sh --v2` | Delegates to borg-v2 |

Legacy vector Borg (`neo_borg_run`) unchanged for `[b]` pause menu.

---

## VPN consent (P10)

| File | Change |
|------|--------|
| `lib/neo-vpn-consent.sh` | Operator k/a/q before killing OpenVPN |
| `lib/neo-vpn.sh` | Uses consent instead of blind `pkill` |

---

## Recon / enum / privesc helpers

- `recon/operator-recon.sh` — operator evidence capture (P07)
- `recon/plan-enum.sh` — service → advisory action JSON (P15)
- `privesc/normalize-findprivs.sh` — FindPrivs → privesc-facts.json (P17)
- `privesc/rank-privesc-plan.sh` — rank hypotheses (P17)

---

## Tests

```bash
bash test/workflow-scope-test.sh
bash test/production-integrity-gate.sh   # should PASS stub checks now
bash test/run-all.sh
```

---

## Operator quick start

```bash
./tools/scope-intake.sh --project MyBox --target 10.10.10.5
./neo.sh MyBox 10.10.10.5
./borg/borg.sh MyBox --v2
./recon/operator-recon.sh --project MyBox
./privesc/run-findprivs.sh --project MyBox --ssh user@10.10.10.5
```

**Next:** Tier 3 — release polish, doc truth checks, E2E validation (P18).
