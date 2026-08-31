# P10 — VPN Lifecycle Detection and Consent

**Status:** review_ready · **Priority:** P1 · **Depends:** P01, P09

## Problem

lib/neo-vpn.sh can `sudo pkill -x openvpn` without OD-011 consent, disconnecting
unrelated VPN sessions.

## Target flow

```
1. pgrep -x openvpn → list PIDs with ps details
2. If none → proceed to connect
3. If any → prompt:
     [k] Keep all — continue without profile change (return 2)
     [a] Terminate ALL — require "terminate-all-openvpn" (return 0)
     [q] Cancel profile change (return 3)
4. Kill only previously listed PIDs (not fresh pgrep wildcard)
5. Verify survivors; fail if any remain
6. Record consent decision in evidence (no credentials)
```

## Prototype

`prototype/neo-next/lib/neo-vpn-consent.sh` — **complete**.

## Integration with v0.5

| File | Change |
|------|--------|
| lib/neo-vpn.sh | Call neo_vpn_resolve_existing before pkill/connect |
| connect/ovpn-connect.sh | Respect return codes 2/3 |
| lib/neo-boot.sh | Boot ritual uses --no-attach path; consent first |

## Non-interactive behavior

If stdin not TTY and OpenVPN running → fail with message (no silent kill).

## Acceptance

- Enter alone → keep (k default)
- Invalid response → re-prompt, no kill
- Exact phrase required for terminate
- sudo failure → truthful non-connected state

## Tests

Mock pgrep in disposable environment; integration in P18
