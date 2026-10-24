param([string]$Godot = '', [string]$From = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $Godot) { $Godot = (Get-ChildItem -Path 'D:\Godot*\*console.exe' -File | Select-Object -First 1).FullName }
if (-not $Godot) { throw 'Supply -Godot <Godot 4.7 executable>' }
foreach ($sub in @('.local/tmp','.local/appdata','.local/cache','artifacts')) { New-Item -ItemType Directory -Path (Join-Path $projectRoot $sub) -Force | Out-Null }
$env:TEMP = Join-Path $projectRoot '.local/tmp'
$env:TMP = $env:TEMP
$env:APPDATA = Join-Path $projectRoot '.local/appdata'
$env:LOCALAPPDATA = $env:APPDATA
$env:XDG_CACHE_HOME = Join-Path $projectRoot '.local/cache'
$checks = @(@('import','--editor','--import','--quit'),@('integration','--script','res://tests/integration_test.gd'),@('music-contract','--script','res://tests/music_contract_test.gd'),@('combat-feel','--script','res://tests/combat_feel_test.gd'),@('impact-feedback','--script','res://tests/impact_feedback_test.gd'),@('parry-controller','--script','res://tests/parry_controller_test.gd'),@('boss-parry','--script','res://tests/boss_parry_test.gd'),@('parry-integration','--script','res://tests/parry_integration_test.gd'),@('font-glyph','--script','res://tools/font_glyph_check.gd'),@('source-fx','--script','res://tests/fx_layer_test.gd'),@('fused-fx','--script','res://tests/fused_fx_test.gd'),@('fused-cadence','--script','res://tests/fused_cadence_test.gd'),@('level-layout','--script','res://tests/level_layout_test.gd'),@('dungeon-layout','--script','res://tests/dungeon_layout_test.gd'),@('traversal','--script','res://tests/traversal_test.gd'),@('mob-barrage','--script','res://tests/mob_barrage_test.gd'),@('dungeon-integration','--script','res://tests/dungeon_integration_test.gd'),@('attack-profile','--script','res://tests/attack_profile_test.gd'),@('friend-boss','--script','res://tests/friend_boss_test.gd'),@('speed-feedback','--script','res://tests/speed_feedback_test.gd'),@('katana-visual','--script','res://tests/katana_visual_test.gd'),@('wide-melee','--script','res://tests/wide_melee_integration_test.gd'),@('startup','--quit-after','60'))
if ($From) {
    $labels = @($checks | ForEach-Object { $_[0] })
    $index = [Array]::IndexOf($labels, $From)
    if ($index -lt 0) { throw ('Unknown check: '+$From) }
    $checks = @($checks[$index..($checks.Count-1)])
}
foreach ($check in $checks) {
    $name = $check[0]
    $log = Join-Path $projectRoot ('artifacts/'+$name+'.log')
    $stdout = Join-Path $projectRoot ('artifacts/'+$name+'-console.log')
    $stderr = Join-Path $projectRoot ('artifacts/'+$name+'-error.log')
    $arguments = @('--headless','--path',$projectRoot,'--log-file',$log) + $check[1..($check.Count-1)]
    $checkProcess = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    if (-not $checkProcess.WaitForExit(60000)) { $checkProcess.Kill(); throw ($name+' exceeded 60 second limit') }
    $code = $checkProcess.ExitCode
    $output = (Get-Content -LiteralPath $stdout -Raw) + (Get-Content -LiteralPath $stderr -Raw)
    $bad = $output | Select-String -Pattern 'SCRIPT ERROR:|ERROR:|Parse Error|FAIL |leaked|still in use at exit'
    if ($code -ne 0 -or $bad) { throw ($name+' failed (exit '+$code+'): '+($bad -join '; ')) }
    if ($name -in @('integration','music-contract','combat-feel','impact-feedback','parry-controller','boss-parry','parry-integration','source-fx','fused-fx','fused-cadence','level-layout','dungeon-layout','traversal','mob-barrage','dungeon-integration','attack-profile','friend-boss','speed-feedback','katana-visual','wide-melee') -and $output -notmatch '0 failed') { throw ($name+' did not finish its assertions') }
    Write-Output ($name+' PASS (exit 0, no engine/script errors)')
}
exit 0
