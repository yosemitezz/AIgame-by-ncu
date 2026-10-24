param([string]$Godot = '', [switch]$Editor)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$godotPath = & (Join-Path $projectRoot 'tools/find_godot.ps1') -Godot $Godot
$localRoot = Join-Path $projectRoot '.local'
foreach ($sub in @('tmp','appdata','cache')) {
    New-Item -ItemType Directory -Path (Join-Path $localRoot $sub) -Force | Out-Null
}
$env:TEMP = Join-Path $localRoot 'tmp'
$env:TMP = $env:TEMP
$env:APPDATA = Join-Path $localRoot 'appdata'
$env:LOCALAPPDATA = $env:APPDATA
$env:XDG_CACHE_HOME = Join-Path $localRoot 'cache'

$arguments = @('--path', $projectRoot, '--log-file', (Join-Path $localRoot 'game.log'))
if ($Editor) {
    $arguments += '--editor'
} else {
    & $godotPath --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
& $godotPath @arguments
exit $LASTEXITCODE

