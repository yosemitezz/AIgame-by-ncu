param([string]$Godot = '')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$godotPath = & (Join-Path $PSScriptRoot 'find_godot.ps1') -Godot $Godot
$localRoot = Join-Path $projectRoot '.local'
$artifactRoot = Join-Path $projectRoot 'artifacts'
foreach ($sub in @('.local/tmp','.local/appdata','.local/cache','artifacts')) {
    New-Item -ItemType Directory -Path (Join-Path $projectRoot $sub) -Force | Out-Null
}
$env:TEMP = Join-Path $localRoot 'tmp'
$env:TMP = $env:TEMP
$env:APPDATA = Join-Path $localRoot 'appdata'
$env:LOCALAPPDATA = $env:APPDATA
$env:XDG_CACHE_HOME = Join-Path $localRoot 'cache'

function Invoke-GodotCheck {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [int] $TimeoutSeconds = 180
    )
    $log = Join-Path $artifactRoot "$Name.log"
    $stdout = Join-Path $artifactRoot "$Name.stdout.log"
    $stderr = Join-Path $artifactRoot "$Name.stderr.log"
    $fullArguments = @('--headless','--path',$projectRoot,'--log-file',$log) + $Arguments
    $process = Start-Process -FilePath $godotPath -ArgumentList $fullArguments -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        throw "$Name exceeded $TimeoutSeconds seconds"
    }
    $output = (Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
    # This sandboxed Windows runtime cannot read the machine certificate store.
    # It is unrelated to the offline game and is the only engine error ignored.
    $bad = ($output -split "`r?`n") |
        Where-Object { $_ -match 'SCRIPT ERROR:|Parse Error|ERROR:|FAIL |leaked|still in use at exit' } |
        Where-Object { $_ -notmatch 'Failed to read the root certificate store' }
    if ($process.ExitCode -ne 0 -or $bad) {
        throw "$Name failed (exit $($process.ExitCode)): $($bad -join '; ')"
    }
    if ($Name -match 'test' -and $output -notmatch '0 failed') {
        throw "$Name did not report a completed assertion summary"
    }
    Write-Output "$Name PASS"
}

Invoke-GodotCheck -Name 'import' -Arguments @('--editor','--import','--quit')
Invoke-GodotCheck -Name 'chart-parser-test' -Arguments @('--script','res://tests/chart_parser_test.gd')
Invoke-GodotCheck -Name 'combat-contract-test' -Arguments @('--script','res://tests/combat_contract_test.gd')
Invoke-GodotCheck -Name 'boss-attack-contract-test' -Arguments @('--script','res://tests/boss_attack_contract_test.gd')
Invoke-GodotCheck -Name 'audio-contract-test' -Arguments @('--script','res://tests/audio_contract_test.gd')
Invoke-GodotCheck -Name 'scheduler-test' -Arguments @('--script','res://tests/scheduler_test.gd')
Invoke-GodotCheck -Name 'startup-smoke' -Arguments @('--quit-after','20')

Write-Output 'ALL CHECKS PASS'

