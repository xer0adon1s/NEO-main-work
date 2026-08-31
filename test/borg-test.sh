#!/usr/bin/env bash
# borg-test.sh — offline tests for BORG helpers (no AI calls).

set -euo pipefail

NEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NEO_HOME="${NEO_ROOT}"
export NEO_DIR="${NEO_ROOT}"
export NEO_BORG_HUD=0

# shellcheck source=../lib/neo-ai.sh
source "${NEO_DIR}/lib/neo-ai.sh"
# shellcheck source=../lib/neo-borg.sh
source "${NEO_DIR}/lib/neo-borg.sh"

pass=0
fail=0

ok()   { printf '  [ok] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

printf 'borg-test.sh\n\n'

slug="$(neo_borg_slugify 'Redis 6379 — unauth write RCE!')"
[[ "${slug}" == "redis-6379-unauth-write-rce" ]] \
    && ok "slugify: ${slug}" || bad "slugify got: ${slug}"

sample_triage=$'## AI triage run 2026-01-01\n\n## Attack paths\n- Redis unauth on 6379\n- Apache path traversal\n\n## Vulnerability leads\n1. CVE-2021-41773 Apache 2.4.49\n'

mapfile -t vecs < <(neo_borg_collect_vectors "${sample_triage}")
((${#vecs[@]} >= 3)) && ok "collect_vectors: ${#vecs[@]} items" \
    || bad "collect_vectors: expected >=3 got ${#vecs[@]}"

sample_response=$'## Vector summary\nRedis open.\n\n## Tool manifest\n```yaml\ntools:\n  - name: redis-cli\n    install: pacman\n    package: redis\n```\n\n## Proposed wind-up actions\n1. `[RUN:redis-cli -h 127.0.0.1 PING]` Safe probe\n2. `[MANUAL]` Review redis INFO output\n'

manifest="$(neo_borg_extract_yaml_manifest "${sample_response}")"
[[ "${manifest}" == *"redis-cli"* ]] && ok "extract_yaml_manifest" || bad "manifest parse"

mapfile -t windup < <(neo_borg_windup_extract_actions "${sample_response}")
((${#windup[@]} >= 2)) && ok "windup extract: ${#windup[@]} actions" || bad "windup extract"

parsed="$(neo_borg_windup_parse_tag '[RUN:redis-cli PING]')"
[[ "${parsed}" == RUN\|redis-cli\ PING ]] && ok "windup parse RUN tag" || bad "windup parse: ${parsed}"

parsed="$(neo_windup_parse_tag '[PAYLOAD:whoami]')"
[[ "${parsed}" == 'PAYLOAD|whoami' ]] && ok "windup parse PAYLOAD tag" || bad "windup parse PAYLOAD: ${parsed}"

bash -n "${NEO_DIR}/borg/borg.sh" && ok "borg.sh syntax" || bad "borg.sh syntax"
bash -n "${NEO_DIR}/lib/neo-borg.sh" && ok "neo-borg.sh syntax" || bad "neo-borg.sh syntax"
[[ -f "${NEO_DIR}/assets/borg-splash-wide.txt" ]] && ok "borg splash asset" || bad "missing splash"

tmp_root="$(mktemp -d)"
export NEO_HOME="${tmp_root}/Neo"
export NEO_DIR="${NEO_HOME}"
mkdir -p "${NEO_HOME}/projects/testbox"
neo_borg_knowledge_init
[[ -d "${NEO_HOME}/knowledge/vectors" ]] && ok "knowledge collective init" || bad "collective init"
neo_borg_write_file "${NEO_HOME}/knowledge/vectors/redis-unauth/SUMMARY.md" "## Vector summary\nRedis."
neo_borg_meta_write "redis-unauth" "Redis unauth" "testbox" "2026-01-01 00:00:00"
neo_borg_refresh_collective_index
grep -q 'redis-unauth' "${NEO_HOME}/knowledge/README.md" && ok "collective README index" || bad "README index"
ctx="$(neo_borg_collective_context "redis-unauth")"
[[ "${ctx}" == *"Existing collective entry"* ]] && ok "collective context for slug" || bad "collective context"
rm -rf "${tmp_root}"

hud_frame="$(awk '/^neo_borg_hud_frame\(\)/,/^neo_borg_hud_start\(\)/' "${NEO_DIR}/lib/neo-borg.sh")"
! grep -q 'resistance is futile' <<< "${hud_frame}" && ok 'HUD tagline not in tick loop' || bad 'HUD tagline in tick loop'

tmp_proj="$(mktemp -d)"
export NEO_HOME="${tmp_proj}/Neo"
export NEO_DIR="${NEO_HOME}"
mkdir -p "${NEO_HOME}/projects/multibox/assimilated/redis-unauth"
neo_borg_write_file "${NEO_HOME}/projects/multibox/Investigation-Notes.md" "$(cat <<'EOF'
<!-- SECTION:AI-TRIAGE -->
## Attack paths
- Redis unauth on 6379
- Apache path traversal
<!-- /SECTION:AI-TRIAGE -->
EOF
)"
neo_borg_write_file "${NEO_HOME}/projects/multibox/assimilated/redis-unauth/SUMMARY.md" "## Proposed wind-up actions\n1. \`[RUN:redis-cli PING]\`"
# shellcheck source=../lib/script-lib.sh
source "${NEO_DIR}/lib/script-lib.sh"
OUTDIR="${NEO_HOME}/projects/multibox"
NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
pending="$(neo_borg_pending_count multibox)"
(( pending == 1 )) && ok "pending_vectors: 1 after one assimilated" || bad "pending_vectors expected 1 got ${pending}"
neo_borg_menu_should_show multibox && ok "menu shows while pending vectors remain" || bad "menu should show"
neo_borg_menu_should_show multibox >/dev/null
frag="$(neo_borg_menu_fragment multibox)"
[[ "${frag}" == *"1 lead"* ]] && ok "menu fragment shows pending count" || bad "menu fragment: ${frag}"

neo_borg_mark_skipped multibox "Apache path traversal"
pending_after="$(neo_borg_pending_count multibox)"
(( pending_after == 0 )) && ok "red herring skip removes pending vector" || bad "skip pending got ${pending_after}"
blurb="$(neo_borg_status_blurb multibox)"
[[ "${blurb}" == *"skipped"* ]] && ok "status blurb mentions skipped" || bad "blurb: ${blurb}"
rm -rf "${tmp_proj}"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
(( fail == 0 ))
