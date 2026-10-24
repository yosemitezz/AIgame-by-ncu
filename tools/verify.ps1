param([string]$Godot = '')
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
$checks = @(@('import','--editor','--import','--quit'),@('integration','--script','res://tests/integration_test.gd'),@('music-contract','--script','res://tests/music_contract_test.gd'),@('startup','--quit-after','60'))
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
    if ($name -in @('integration','music-contract') -and $output -notmatch '0 failed') { throw ($name+' did not finish its assertions') }
    Write-Output ($name+' PASS (exit 0, no engine/script errors)')
}
exit 0
