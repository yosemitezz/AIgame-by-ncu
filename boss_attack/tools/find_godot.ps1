param([string]$Godot = '')

$ErrorActionPreference = 'Stop'
if ($Godot -and (Test-Path -LiteralPath $Godot)) {
    return (Resolve-Path -LiteralPath $Godot).Path
}

$commands = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
if ($commands) {
    return $commands.Source
}

$patterns = @(
    'D:\Godot*\*console.exe',
    'D:\Godot*\Godot*.exe',
    (Join-Path $PSScriptRoot '..\.local/godot/*console.exe'),
    (Join-Path $PSScriptRoot '..\.local/godot/*.exe')
)
foreach ($pattern in $patterns) {
    $found = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        return $found.FullName
    }
}
throw 'Godot 4.7 not found. Pass -Godot <path-to-godot.exe>.'

