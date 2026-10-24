param([string]$Godot = '', [switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$localRoot = Join-Path $projectRoot '.local'
foreach ($sub in @('tmp','appdata','cache')) { New-Item -ItemType Directory -Path (Join-Path $localRoot $sub) -Force | Out-Null }
$env:TEMP = Join-Path $localRoot 'tmp'
$env:TMP = $env:TEMP
$env:APPDATA = Join-Path $localRoot 'appdata'
$env:LOCALAPPDATA = $env:APPDATA
$env:XDG_CACHE_HOME = Join-Path $localRoot 'cache'
if (-not $Godot) {
    $found = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $Godot = $found.Source }
    else {
        $portable = Get-ChildItem -Path 'D:\Godot*\*console.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($portable) { $Godot = $portable.FullName }
    }
}
if (-not $Godot) { throw 'Godot 4.7 not found. Run .\run.ps1 -Godot <path-to-godot.exe>' }
$arguments = @('--path', $projectRoot, '--log-file', (Join-Path $localRoot 'game.log'))
if ($Editor) { $arguments += '--editor' }
& $Godot @arguments
exit $LASTEXITCODE
