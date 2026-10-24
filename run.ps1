param([string]$Godot = '', [switch]$Editor, [switch]$Smoke)
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
if (-not $Editor) {
    & $Godot --headless --path $projectRoot --editor --import --quit --log-file (Join-Path $localRoot 'import.log')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$arguments = @('--path', $projectRoot, '--log-file', (Join-Path $localRoot 'game.log'))
if ($Smoke) { $arguments += @('--headless', '--quit-after', '60') }
if ($Editor) { $arguments += '--editor' }
& $Godot @arguments
exit $LASTEXITCODE
