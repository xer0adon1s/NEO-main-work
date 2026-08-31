# Redis unauthenticated write — technique summary

## Applicability

Open Redis (6379/tcp) without `requirepass`, reachable from the attacker position.

## Technique

1. Confirm with `redis-cli -h <target> PING` → `PONG`.
2. Use `CONFIG SET` or module load (version-dependent) to write a cron entry or SSH key
   when the service runs as a user with writable paths.
3. Alternative: gopher/redis protocol smuggling through an SSRF-capable HTTP parameter.

## Prerequisites

- Network path to Redis port
- Redis not bound to localhost-only (or SSRF to localhost)
- Writable location for chosen persistence mechanism

## Detection / hardening

- Enable `requirepass` and ACLs
- Bind to internal interfaces; firewall 6379 from untrusted networks
- Disable dangerous commands via `rename-command`

## Related CVEs

Often misconfiguration rather than a single CVE — pair with web SSRF chains (document CVE
per component when version-specific issues exist in mission evidence).
