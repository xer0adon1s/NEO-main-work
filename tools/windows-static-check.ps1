# windows-static-check.ps1 - run on Windows when bash/WSL unavailable.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$pass = 0
$fail = 0

function Ok($msg)  { Write-Host "  [ok] $msg" -ForegroundColor Green; $script:pass++ }
function Bad($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:fail++ }

Write-Host ""
Write-Host "NEO windows-static-check - $Root"
Write-Host ""

$requiredFiles = @(
    'lib/neo-pipeline-hooks.sh',
    'lib/neo-workbench.sh',
    'lib/neo-exploit-framework.sh',
    'lib/neo-toolkit.sh',
    'lib/neo-operator-pane.sh',
    'foothold/ListenAssist.sh',
    'tools/neo-vendor.sh',
    'test/plan-enum-hook-test.sh',
    'test/privesc-rank-hook-test.sh',
    'test/vendor-test.sh',
    'test/session-adapter-test.sh',
    'test/eli5-test.sh',
    'lib/neo-eli5.sh',
    'test/run-all.sh'
)
foreach ($f in $requiredFiles) {
    if (Test-Path (Join-Path $Root $f)) { Ok "present: $f" } else { Bad "missing: $f" }
}

$workbench = Get-Content (Join-Path $Root 'lib/neo-workbench.sh') -Raw
if ($workbench -match 'recon\|foothold\|privesc\|post') { Ok 'workbench visible on post phase' } else { Bad 'workbench missing post phase' }

$payload = Get-Content (Join-Path $Root 'lib/neo-payload.sh') -Raw
if ($payload -match 'recon\|privesc\|post') { Ok 'payload suggest on post phase' } else { Bad 'payload post phase' }

$listen = Get-Content (Join-Path $Root 'foothold/ListenAssist.sh') -Raw
if ($listen -match 'neo_listenassist_build_msf' -and $listen -match 'msfconsole') { Ok 'ListenAssist MSF handler' } else { Bad 'ListenAssist MSF' }

$msf = Get-Content (Join-Path $Root 'lib/neo-exploit-framework.sh') -Raw
if ($msf -match 'neo_msf_handler_backend') { Ok 'MSF handler backend helper' } else { Bad 'MSF handler backend' }

$neo = Get-Content (Join-Path $Root 'neo.sh') -Raw
if ($neo -match 'neo_pipeline_offer_plan_enum') { Ok 'neo.sh plan-enum hook' } else { Bad 'neo.sh plan-enum hook' }
if ($neo -match 'neo_pipeline_offer_privesc_rank') { Ok 'neo.sh privesc rank hook' } else { Bad 'neo.sh privesc rank hook' }
if ($neo -match 'neo_pipeline_offer_operator_recon') { Ok 'neo.sh operator-recon hook' } else { Bad 'neo.sh operator-recon hook' }
if ($neo -match 'neo_pipeline_offer_msf_post') { Ok 'neo.sh MSF post hook' } else { Bad 'neo.sh MSF post hook' }
if ($neo -match 'neo_mission_sync_pipeline_phase') { Ok 'neo.sh mission phase sync' } else { Bad 'neo.sh mission sync' }

if ($payload -match 'neo_mission_context_block') { Ok 'payload bundle mission context' } else { Bad 'payload mission context' }
if ($msf -match 'neo_msf_post_context_block') { Ok 'MSF post context block' } else { Bad 'MSF post context' }

$gate = Get-Content (Join-Path $Root 'test/production-integrity-gate.sh') -Raw
if ($gate -match 'neo-pipeline-hooks') { Ok 'integrity gate lists pipeline-hooks' } else { Bad 'integrity gate pipeline-hooks' }

$gitignore = Get-Content (Join-Path $Root '.gitignore') -Raw
if ($gitignore -match 'neo-pipeline-hooks') { Ok 'gitignore whitelists pipeline-hooks' } else { Bad 'gitignore pipeline-hooks' }

$runAll = Get-Content (Join-Path $Root 'test/run-all.sh') -Raw
@('plan-enum-hook-test', 'privesc-rank-hook-test', 'vendor-test', 'session-adapter-test', 'eli5-test') | ForEach-Object {
    if ($runAll -match $_) { Ok "run-all includes $_" } else { Bad "run-all missing $_" }
}

foreach ($lib in @('lib/neo-borg.sh', 'lib/neo-payload.sh', 'lib/neo-windup-actions.sh')) {
    $c = Get-Content (Join-Path $Root $lib) -Raw
    if ($c -match '(^|[^A-Za-z])eval\s') { Bad "eval found in $lib" } else { Ok "no eval in $lib" }
}

$hooks = Get-Content (Join-Path $Root 'lib/neo-pipeline-hooks.sh') -Raw
if ($hooks -match 'plan_enum_offered') { Ok 'plan_enum_offered meta skip' } else { Bad 'plan_enum_offered meta' }
if ($hooks -match 'privesc_rank_offered') { Ok 'privesc_rank_offered meta skip' } else { Bad 'privesc_rank_offered meta' }

$opPane = Get-Content (Join-Path $Root 'lib/neo-operator-pane.sh') -Raw
if ($hooks -match 'neo_pipeline_offer_msf_post') { Ok 'MSF post pause hook' } else { Bad 'MSF post hook' }
if ($hooks -match 'msf_post_offered') { Ok 'msf_post_offered meta skip' } else { Bad 'msf_post meta' }
if ($hooks -match 'neo_pipeline_append_top_actions') { Ok 'enum plan auto-TODO append' } else { Bad 'enum auto-TODO' }
if ($hooks -match 'operator_recon_offered') { Ok 'operator_recon_offered meta skip' } else { Bad 'operator_recon meta' }

if ($opPane -match 'neo_operator_pane_offer_session_connect') { Ok 'session adapter offer connect' } else { Bad 'session adapter' }
if ($opPane -match 'session_connect_offered') { Ok 'session_connect_offered meta skip' } else { Bad 'session_connect meta' }

if ($msf -match 'neo_msf_search_command') { Ok 'MSF module search helper' } else { Bad 'MSF search helper' }
if ($msf -match 'neo_msf_post_module_catalog') { Ok 'MSF post module catalog' } else { Bad 'MSF post catalog' }
if ($msf -match 'neo_msf_offer_post_module_menu') { Ok 'MSF post module menu' } else { Bad 'MSF post menu' }

$mission = Get-Content (Join-Path $Root 'lib/neo-mission-state.sh') -Raw
if ($mission -match 'neo_mission_record_msf_session') { Ok 'MSF session id recording' } else { Bad 'MSF session record' }
if ($mission -match 'neo_mission_try_transition') { Ok 'mission try_transition sync' } else { Bad 'mission try_transition' }

$eli5 = Get-Content (Join-Path $Root 'lib/neo-eli5.sh') -Raw
if ($eli5 -match 'neo_eli5_system_prompt' -and $eli5 -match 'Command walkthrough') { Ok 'ELI5 tutor module' } else { Bad 'ELI5 module' }
if ($neo -match 'NEO_PAUSE_HAS_ELI5') { Ok 'neo.sh ELI5 pause extra' } else { Bad 'neo.sh ELI5' }

$menu = Get-Content (Join-Path $Root 'lib/neo-menu.sh') -Raw
if ($menu -match 'e\|E\) echo eli5') { Ok 'menu e -> eli5' } else { Bad 'menu eli5 routing' }

$tmux = Get-Content (Join-Path $Root 'lib/neo-tmux.sh') -Raw
if ($tmux -match 'ANTHROPIC_API_KEY') { Bad 'API key in neo-tmux.sh' } else { Ok 'no API key in tmux forward' }

Write-Host ""
Write-Host ($pass.ToString() + ' passed, ' + $fail.ToString() + ' failed')
Write-Host ""
if ($fail -gt 0) { exit 1 }
exit 0
