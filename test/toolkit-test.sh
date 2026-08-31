#!/usr/bin/env bash
# toolkit-test.sh — neo-toolkit parsing and analysis (offline).
set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"

# shellcheck source=../lib/neo-toolkit.sh
source "${NEO_DIR}/lib/neo-toolkit.sh"

pass=0
fail=0
ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'toolkit-test.sh\n\n'

[[ "$(neo_toolkit_command_binary 'sudo gobuster dir -w /usr/share/seclists/foo.txt')" == gobuster ]] \
    && ok 'binary extraction skips sudo' || bad 'binary extraction'

text='## Exact next command
```bash
gobuster dir -u http://10.0.0.1 -w /usr/share/seclists/Discovery/Web-Content/common.txt
```'

mapfile -t lines < <(neo_toolkit_analyze_text "${text}")
((${#lines[@]} > 0)) && ok 'analyze_text produces lines' || bad 'analyze_text lines'

has_gobuster=false
has_path=false
for line in "${lines[@]}"; do
    [[ "${line}" == *gobuster* ]] && has_gobuster=true
    [[ "${line}" == *seclists* || "${line}" == *common.txt* ]] && has_path=true
done
${has_gobuster} && ok 'detects gobuster' || bad 'detects gobuster'
${has_path} && ok 'detects wordlist path' || bad 'detects wordlist path'

tool_text='Use [TOOL:ffuf] for fuzzing'
mapfile -t tlines < <(neo_toolkit_analyze_text "${tool_text}")
echo "${tlines[*]}" | grep -q ffuf && ok 'detects [TOOL:ffuf] tag' || bad '[TOOL:ffuf] tag'

bash -n "${NEO_DIR}/lib/neo-toolkit.sh" && ok 'syntax neo-toolkit.sh' || bad 'syntax'

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
test "${fail}" -eq 0
