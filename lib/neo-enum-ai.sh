#!/usr/bin/env bash
# neo-enum-ai.sh — post enum-plan AI review (runs after plan-enum scripts).

NEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO_DIR="${NEO_DIR:-$(cd "${NEO_LIB_DIR}/.." && pwd)}"
# shellcheck source=neo-conductor.sh
source "${NEO_LIB_DIR}/neo-conductor.sh"
# shellcheck source=neo-pipeline-hooks.sh
source "${NEO_LIB_DIR}/neo-pipeline-hooks.sh" 2>/dev/null || true
# shellcheck source=neo-conductor-tuning.sh
source "${NEO_LIB_DIR}/neo-conductor-tuning.sh" 2>/dev/null || true

neo_enum_ai_system_prompt() {
    cat <<'EOF'
You review an automated service enumeration plan for an authorized lab target.

Output markdown with:

## Top priority enum actions
Numbered list (highest value first) drawn from the plan JSON — title + why it matters.

## Exact commands to run first
Up to 3 copy-paste commands from the plan (argv joined). One command per fenced block.

## Gaps / follow-ups
What the plan missed or what to verify after these actions.

Rules:
- Teach techniques and CVEs; reference attack vectors and privesc paths when evidence supports them.
- Do NOT name specific CTF box platforms (HackTheBox, TryHackMe, etc.) or spoil walkthrough solutions.
- Do NOT invent services or ports not present in the bundle.
EOF
}

neo_enum_ai_collect_actions() {
    local project="$1" limit="${2:-12}" plan_root actions_dir block count=0 f
    plan_root="$(neo_pipeline_plan_root "${project}")"
    actions_dir="${plan_root}/actions"
    [[ -d "${actions_dir}" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    block=""
    shopt -s nullglob
    for f in "${actions_dir}"/*.json; do
        [[ -f "${f}" ]] || continue
        block+="$(jq -r '"- **\(.title)** (\(.target // "n/a")) → `\(.execution.argv | join(" "))`"' "${f}" 2>/dev/null || true)"$'\n'
        count=$((count + 1))
        (( count >= limit )) && break
    done
    [[ -n "${block//[[:space:]]/}" ]] || return 1
    printf '%s' "${block}"
}

neo_enum_ai_build_bundle() {
    local project="$1" target="$2" core actions
    core="$(neo_conductor_build_bundle "${project}" recon triage)" || return 1
    actions="$(neo_enum_ai_collect_actions "${project}" 12 || true)"
    cat <<EOF
${core}

## Enum plan actions (from plan-enum scripts)
Target: ${target}
${actions:-_no action JSON files found — run plan-enum first_}
EOF
}

neo_enum_ai_save() {
    local project="$1" response="$2" ts plan_root sidecar
    OUTDIR="${NEO_HOME}/projects/${project}"
    NOTES_FILE="${OUTDIR}/Investigation-Notes.md"
    # shellcheck source=notes-lib.sh
    source "${NEO_LIB_DIR}/notes-lib.sh" 2>/dev/null || return 1
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    notes_append_section AI-TRIAGE "**Enum plan review (${ts})**

${response}" 2>/dev/null || true
    notes_log enum-ai "=== enum-ai ${ts} ===
${response}" 2>/dev/null || true
    plan_root="$(neo_pipeline_plan_root "${project}")"
    sidecar="${plan_root}/ranked-order.md"
    mkdir -p "${plan_root}" 2>/dev/null || true
    cat > "${sidecar}" <<EOF
# Enum AI ranked review (${ts})

${response}
EOF
    chmod 600 -- "${sidecar}" 2>/dev/null || true
    printf '[*] Enum AI review saved → AI-TRIAGE + %s\n' "${sidecar}"
}

neo_enum_ai_run() {
    local project="$1" target="$2" bundle response
    neo_conductor_ai_available || return 0
    bundle="$(neo_enum_ai_build_bundle "${project}" "${target}")" || {
        printf '[*] Enum AI: no enum plan to review.\n'
        return 1
    }
    # shellcheck source=neo-payload.sh
    source "${NEO_LIB_DIR}/neo-payload.sh" 2>/dev/null || return 1
    neo_payload_init_colors 2>/dev/null || true
    printf '\n[*] AI reviewing enum plan for %s…\n\n' "${target}"
    if ! response="$(neo_payload_call_ai "${bundle}" "$(neo_enum_ai_system_prompt)" "${project}")"; then
        return 1
    fi
    neo_enum_ai_save "${project}" "${response}"
    return 0
}

neo_enum_ai_offer_after_plan() {
    local project="$1" target="$2" policy
    neo_conductor_skip_interactive && return 0
    neo_conductor_ai_available || return 0
    policy="$(neo_conductor_enum_ai_policy "${project}")"
    case "${policy}" in
        off)
            return 0
            ;;
        auto)
            neo_enum_ai_run "${project}" "${target}" || true
            ;;
        prompt|*)
            if neo_conductor_enum_ai_prompt_default_y; then
                neo_conductor_prompt_yn 'AI-review enum plan and suggest top actions?' y || return 0
            else
                neo_conductor_prompt_yn 'AI-review enum plan and suggest top actions?' n || return 0
            fi
            neo_enum_ai_run "${project}" "${target}" || true
            ;;
    esac
    return 0
}
