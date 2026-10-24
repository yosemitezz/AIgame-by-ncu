param([string]$Godot='D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',[string]$From='',[string[]]$Only=@(),[switch]$LocalScore)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$projectRoot=Split-Path $PSScriptRoot -Parent
foreach($d in @('.local/tmp','.local/appdata','.local/cache','artifacts')){New-Item -ItemType Directory -Path (Join-Path $projectRoot $d) -Force | Out-Null}
$env:TEMP=Join-Path $projectRoot '.local/tmp'
$env:TMP=$env:TEMP
$env:APPDATA=Join-Path $projectRoot '.local/appdata'
$env:LOCALAPPDATA=$env:APPDATA
$env:XDG_CACHE_HOME=Join-Path $projectRoot '.local/cache'
$checks=@('main_dungeon_migration_test','main_player_migration_test','friend_controls_test','friend_input_map_test','ut_hud_test','main_scene_migration_test','integration_test','hit_reaction_test','impact_feedback_test','music_contract_test','music_203_config_test','heavy_judge_test','heavy_lane_test','full_song_transport_test','full_song_boss_test','full_song_coverage_test','main_full_song_test','parry_controller_test','boss_parry_test','parry_integration_test','hero_motion_test','main_visual_migration_test','main_authored_boss_test','main_boss_runtime_test','main_enemy_cast_test','main_enemy_visual_test','source-chart','font','startup')
if($From){$index=[Array]::IndexOf($checks,$From);if($index -lt 0){throw 'Unknown -From'};$checks=$checks[$index..($checks.Count-1)]}
if($Only.Count){foreach($item in $Only){if($item -notin $checks){throw ('Unknown check: '+$item)}};$checks=@($checks | Where-Object {$_ -in $Only})}
$previousPlaceholder=[Environment]::GetEnvironmentVariable('BELLKEEP_USE_PLACEHOLDER','Process')
if(-not $LocalScore){$env:BELLKEEP_USE_PLACEHOLDER='1'}
try {
foreach($name in $checks){
 $stdout=Join-Path $projectRoot ('artifacts/unified-'+$name+'-console.log')
 $stderr=Join-Path $projectRoot ('artifacts/unified-'+$name+'-error.log')
 $log=Join-Path $projectRoot ('artifacts/unified-'+$name+'.log')
 $args=@('--headless','--audio-driver','Dummy','--path',$projectRoot,'--log-file',$log)
 if($name -eq 'source-chart'){$args+=@('--script','res://tools/audit_friend_chart.gd')}
 elseif($name -eq 'font'){$args+=@('--script','res://tools/font_glyph_check.gd')}
 elseif($name -eq 'startup'){$args+=@('--quit-after','60')}
 else{$args+=@('--script',('res://tests/'+$name+'.gd'))}
 $proc=Start-Process -FilePath $Godot -ArgumentList $args -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
 if(-not $proc.WaitForExit(60000)){$proc.Kill();throw ($name+' timed out')}
 $out=(Get-Content -LiteralPath $stdout -Raw)+(Get-Content -LiteralPath $stderr -Raw)
 if($proc.ExitCode -ne 0 -or $out -match 'SCRIPT ERROR:|ERROR:|FAIL |leaked|still in use at exit' -or ($name -notin @('font','startup') -and $out -notmatch '0 failed')){Write-Output $out;throw ($name+' FAILED exit '+$proc.ExitCode)}
 Write-Output ($name+' PASS '+(($out -split "`n" | Where-Object {$_ -match 'passed, 0 failed|Font glyph'}) -join ' '))
}
} finally {
 [Environment]::SetEnvironmentVariable('BELLKEEP_USE_PLACEHOLDER',$previousPlaceholder,'Process')
}
