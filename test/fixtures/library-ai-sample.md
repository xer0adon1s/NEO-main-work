## Educational library entry

Redis without authentication allows write primitives that can lead to code execution when
combined with cron or SSH key paths. Confirm with a benign PING before invasive tests.

## Professional reference (full intel)

Common on misconfigured HTB-style Linux boxes; pairs with web SSRF to hit 127.0.0.1:6379.
Tools: redis-cli, gopherus for SSRF chains.

## CVEs

- none identified

## Techniques

- T1190
- redis-unauth-write

## Suggested sources

- hacktricks
- nvd

## Suggested library slug

redis-unauth-rce
