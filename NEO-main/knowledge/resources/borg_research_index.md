# Borg research resource index

**Canonical** merged index (Cursor + Claude, live-verified 2026-08-30).  
**Machine-readable:** [`borg_research_index.yaml`](borg_research_index.yaml)

This is a **directory of directories** — where Borg looks before searching the web cold.
It does **not** store CVE data, exploit code, or payloads.

**Not the same as** [`../INDEX.yaml`](../INDEX.yaml) — that file auto-tracks **assimilated
vectors** from missions. This file tracks **external research sources**.

---

## How Borg should use this

1. Check **`~/Neo/knowledge/vectors/`** and mission `assimilated/` symlinks first.
2. Match your research question to a category (below) — don't search everything every run.
3. Write dossiers lean: technique in SUMMARY/EXPLOIT; executable steps only in tagged wind-up.
4. PoC repos: **link + [MANUAL] clone** — never auto-clone or auto-run.

### Research flow (pick one path)

| Question | Start here |
|----------|------------|
| CVE ID → facts (CVSS, versions, description) | NVD, CVE.org, CISA KEV, EPSS |
| CVE/product → exploit or PoC | Exploit-DB, PoC-in-GitHub, trickest/cve, Metasploit, Sploitus |
| Technique, not a specific CVE | HackTricks, GTFOBins, LOLBAS, WADComs, PATs, SecLists |
| Scanner already covers this CVE? | nuclei-templates |
| HTB/CTF box | 0xdf, ippsec.rocks, HTB official, CTFtime |
| Actively exploited now? ATT&CK frame? | GreyNoise, Shodan, MITRE ATT&CK |

If one source is empty, widen to the adjacent category before a blind web search.

### Live-verification notes (2026-08-30)

- **AttackerKB** was sunset **2026-08-18** — redirects to **Rapid7 Vulnerability & Exploit Database**. Do not list AttackerKB separately.
- **GTFOBins** canonical URL is **`https://gtfobins.org/`** (`gtfobins.github.io` → 301 redirect).
- **Packet Storm** canonical URL is **`https://packetstorm.news/`** (`packetstormsecurity.com` redirects).
- Some sites 403 default fetch agents (Vulners, VulDB, CVE Details, CISA) — fine in browser.

---

## 1. Authoritative CVE & package databases

### NVD
- **URL:** https://nvd.nist.gov/vuln/detail/`<CVE-ID>`
- **API:** `https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=<CVE-ID>`
- CVSS, CPE ranges, CWE, references. Optional API key for bulk rate limits.

### CVE.org (MITRE)
- **URL:** https://www.cve.org/CVERecord?id=`<CVE-ID>`
- **API:** `https://cveawg.mitre.org/api/cve/<CVE-ID>`
- Often published before NVD enrichment lands.

### cvelistV5 (bulk)
- **GitHub:** https://github.com/CVEProject/cvelistV5 — offline clone / air-gapped research.

### GitHub Security Advisories (GHSA)
- **URL:** https://github.com/advisories?query=`<terms>`
- OSS packages only (npm, PyPI, Maven, Go, …). Filter: `query=CVE-…`, `ecosystem:npm`, `severity:critical`.

### OSV.dev
- **URL:** https://osv.dev/vulnerability/`<ID>` · **API:** POST https://api.osv.dev/v1/query
- Best when you have `package@version`, not just a CVE ID.

### Vulners · VulDB · CVE Details · Snyk
- **Vulners:** https://vulners.com/cve/`<CVE-ID>` — Lucene API cross-source aggregator.
- **VulDB:** https://vuldb.com/kb/cve — secondary pointer; paywalled detail.
- **CVE Details:** https://www.cvedetails.com/cve/`<CVE-ID>`/ — browse by vendor/product.
- **Snyk:** https://security.snyk.io/package/`<ecosystem>`/`<package>` — package vulns.

### Rapid7 Vulnerability & Exploit Database
- **URL:** https://www.rapid7.com/db/vulnerabilities/cve-`<year>-<number>` (lowercase)
- Metasploit module cross-ref + exploitability writeups. **Replaces AttackerKB** (Aug 2026).

---

## 2. Prioritization signals

| Source | URL | Use |
|--------|-----|-----|
| **CISA KEV** | https://www.cisa.gov/known-exploited-vulnerabilities-catalog | Confirmed in-the-wild — urgent |
| **KEV JSON** | https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json | Machine-readable |
| **EPSS** | https://api.first.org/data/v1/epss?cve=`<CVE-ID>` | 30-day exploitation probability |
| **NIST LEV** | https://csrc.nist.gov/pubs/cswp/41/likely-exploited-vulnerabilities/final | Likely already exploited |
| **VulnCheck KEV** | https://vulncheck.com/kev | Broader KEV + nuclei `kev,vkev` tags |

**Rule:** KEV listed → treat as live threat. EPSS ranks backlog; does not replace KEV.

---

## 3. Exploit & PoC aggregators

### Exploit-DB
- **URL:** https://www.exploit-db.com/search?cve=`<year>-<number>`
- **CLI:** `searchsploit --cve <CVE-ID>` · `searchsploit -m <EDB-ID>`

### PoC-in-GitHub
- **Repo:** https://github.com/nomi-sec/PoC-in-GitHub · **API:** https://poc-in-github.motikan2010.net/api/v1/?cve_id=`<CVE-ID>`
- Unvetted — review every hit; never auto-run.

### trickest/cve
- **Repo:** https://github.com/trickest/cve — files at `<year>/<CVE-ID>.md`, plus `hot_cves.csv`.

### Metasploit
- **Repo:** https://github.com/rapid7/metasploit-framework
- Use `msfconsole → search cve:<CVE-ID>` — tree is by platform, not CVE.

### Packet Storm
- **Canonical:** https://packetstorm.news/search/?q=`<query>`

### Sploitus
- **URL:** https://sploitus.com/`<CVE-ID>` — meta-search across EDB, GitHub, Packet Storm, Metasploit.

### Multi-source CLIs (optional, not shipped)
- **sploitscan** — https://github.com/GuiMatosInfra/explorer2sectool
- **PoC_Hunter** — https://github.com/jturini/PoC_Hunter
- **cve2poc** — https://github.com/0xP1ckl3d/cve2poc

---

## 4. Scanner templates (verification only)

### nuclei-templates
- **Repo:** https://github.com/projectdiscovery/nuclei-templates
- CVE path: `http/cves/<year>/CVE-<year>-<number>.yaml`
- Search: https://templatesearch.io/ · CLI: `nuclei -tags cve -id CVE-…`

### Nmap NSE
- **Docs:** https://nmap.org/nsedoc/

---

## 5. Technique references

| Resource | URL | For |
|----------|-----|-----|
| **HackTricks** | https://book.hacktricks.wiki/ | Default methodology |
| **HackTricks Cloud** | https://cloud.hacktricks.wiki/ | AWS/GCP/Azure/K8s |
| **InternalAllTheThings** | https://swisskyrepo.github.io/InternalAllTheThings/ | AD / internal |
| **PayloadsAllTheThings** | https://github.com/swisskyrepo/PayloadsAllTheThings | Vuln-class payloads |
| **GTFOBins** | https://gtfobins.org/gtfobins/`<binary>`/ | Linux LOL |
| **LOLBAS** | https://lolbas-project.github.io/ | Windows LOL |
| **LOLDrivers** | https://www.loldrivers.io/ | Vulnerable drivers |
| **WADComs** | https://wadcoms.github.io/ | AD command templates |
| **SecLists** | https://github.com/danielmiessler/SecLists | Wordlists |
| **revshells.com** | https://revshells.com/ | Shell syntax reference |
| **PortSwigger Academy** | https://portswigger.net/web-security | Web vuln learning |
| **OWASP WSTG** | https://owasp.org/www-project-web-security-testing-guide/ | Web test methodology |

**Service chapters:** https://book.hacktricks.wiki/network-services-pentesting/ — map NEO **PORTS** to SMB, LDAP, Redis, MSSQL, etc.

---

## 6. Vendor advisories

Microsoft MSRC · Red Hat · Ubuntu USN · Debian tracker · Cisco PSIRT · Fortinet · VMware — see YAML for URLs.

---

## 7. HTB / CTF indices

| Resource | URL |
|----------|-----|
| **0xdf** | https://0xdf.gitlab.io/ |
| **ippsec.rocks** | https://ippsec.rocks/?binP=`<term>` |
| **HTB official** | https://www.hackthebox.com/machines/`<name>` (retired, VIP) |
| **CTFtime** | https://ctftime.org/writeups |

---

## 8. Threat context

- **GreyNoise** — https://viz.greynoise.io/ (mass-scan tags per CVE)
- **Shodan** — https://www.shodan.io/ · CVEDB: https://cvedb.shodan.io/
- **MITRE ATT&CK** — https://attack.mitre.org/techniques/`<T-id>`/

---

## 9. NEO collective (grows over time)

| Path | Purpose |
|------|---------|
| `~/Neo/knowledge/vectors/<slug>/` | Canonical Borg dossiers |
| `~/Neo/knowledge/INDEX.yaml` | Assimilated vector slug index |
| `~/Neo/projects/<box>/assimilated/<slug>/` | Mission symlinks |

Successful assimilations supersede this static index for repeat vectors.

---

## Quick API examples

```bash
curl -s 'https://poc-in-github.motikan2010.net/api/v1/?cve_id=CVE-2021-44228' | jq .
curl -s 'https://api.first.org/data/v1/epss?cve=CVE-2021-44228' | jq .
curl -s -d '{"package":{"name":"log4j","ecosystem":"Maven"},"version":"2.14.1"}' \
  https://api.osv.dev/v1/query | jq .
searchsploit --cve 2021-44228
```

All execution: **operator y/N** per NEO wind-up model.
