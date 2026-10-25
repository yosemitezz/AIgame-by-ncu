param([string]$Godot='', [string]$Git='D:\Git\cmd\git.exe')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
if(-not $Godot){$Godot=(Get-ChildItem -Path 'D:\Godot*\*console.exe' -File | Select-Object -First 1).FullName}
if(-not $Godot -or -not (Test-Path -LiteralPath $Godot)){throw 'Supply the installed Godot executable.'}
$revision=(& $Git -C $projectRoot rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Cannot resolve build revision'}
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$outputRoot=Join-Path $projectRoot ('exports/bellkeep-'+$stamp+'-'+$revision.Substring(0,8))
if(Test-Path -LiteralPath $outputRoot){throw 'Build directory exists; previous deliveries are never replaced.'}
$sourceRoot=Join-Path $outputRoot '.build/source'
New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
$env:TEMP=Join-Path $outputRoot '.local/tmp';$env:TMP=$env:TEMP
$env:APPDATA=Join-Path $outputRoot '.local/appdata';$env:LOCALAPPDATA=$env:APPDATA
$env:XDG_CACHE_HOME=Join-Path $outputRoot '.local/cache'
foreach($folder in @($env:TEMP,$env:APPDATA,$env:XDG_CACHE_HOME)){New-Item -ItemType Directory -Path $folder -Force | Out-Null}
$archive=Join-Path $outputRoot '.build/source.zip'
& $Git -C $projectRoot archive --format=zip --output=$archive HEAD
if($LASTEXITCODE -ne 0){throw 'Git archive failed'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try {foreach($entry in $zip.Entries){$target=[IO.Path]::GetFullPath((Join-Path $sourceRoot $entry.FullName));if(-not $target.StartsWith($sourceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Archive entry outside build source'}}} finally {$zip.Dispose()}
Expand-Archive -LiteralPath $archive -DestinationPath $sourceRoot
$preset=@'
[preset.0]
name="Windows Portable Pack"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.mc,*.txt,*.csv"
exclude_filter=".local/*,artifacts/*,exports/*,tests/*,tools/*,docs/*,.agents/*,.github/*,boss_attack/scripts/*,boss_attack/scenes/*,boss_attack/tests/*"
export_path=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
'@
[IO.File]::WriteAllText((Join-Path $sourceRoot 'export_presets.cfg'),$preset,[Text.UTF8Encoding]::new($false))
function RunGodot([string]$Label,[string[]]$Arguments){
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$Godot
 $info.Arguments=(($Arguments | ForEach-Object {'"'+($_ -replace '"','\"')+'"'}) -join ' ')
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $proc=[Diagnostics.Process]::new();$proc.StartInfo=$info;[void]$proc.Start()
 $out=$proc.StandardOutput.ReadToEndAsync();$err=$proc.StandardError.ReadToEndAsync();$deadline=[DateTime]::UtcNow.AddMinutes(3)
 while(-not $proc.WaitForExit(1000)){if([DateTime]::UtcNow -gt $deadline){$proc.Kill();throw ($Label+' timed out')}}
 [IO.File]::WriteAllText((Join-Path $outputRoot ($Label+'-console.log')),$out.Result)
 [IO.File]::WriteAllText((Join-Path $outputRoot ($Label+'-error.log')),$err.Result)
 if($proc.ExitCode -ne 0 -or ($out.Result+$err.Result) -match 'SCRIPT ERROR:|ERROR:'){throw ($Label+' failed; see build logs')}
}
RunGodot 'import' @('--headless','--path',$sourceRoot,'--editor','--import','--quit')
$pack=Join-Path $outputRoot 'Bellkeep.pck'
RunGodot 'pack' @('--headless','--path',$sourceRoot,'--export-pack','Windows Portable Pack',$pack)
if(-not (Test-Path -LiteralPath $pack)){throw 'Pack was not produced'}
$runtime=Get-ChildItem -LiteralPath (Split-Path $Godot -Parent) -File -Filter '*.exe' | Where-Object Name -NotMatch 'console' | Select-Object -First 1
if(-not $runtime){throw 'Installed graphical Godot runtime not found'}
Copy-Item -LiteralPath $runtime.FullName -Destination (Join-Path $outputRoot 'Bellkeep.exe')
$launcher=@'
@echo off
setlocal
cd /d "%~dp0"
set "TEMP=%~dp0.local\tmp"
set "TMP=%TEMP%"
set "APPDATA=%~dp0.local\appdata"
set "LOCALAPPDATA=%APPDATA%"
set "XDG_CACHE_HOME=%~dp0.local\cache"
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%XDG_CACHE_HOME%" mkdir "%XDG_CACHE_HOME%"
"%~dp0Bellkeep.exe" --path "%~dp0." --main-pack "%~dp0Bellkeep.pck" --log-file "%~dp0.local\game.log" %*
'@
[IO.File]::WriteAllText((Join-Path $outputRoot 'play.cmd'),$launcher,[Text.UTF8Encoding]::new($false))
foreach($notice in @('LICENSE','THIRD_PARTY_NOTICES.md')){Copy-Item -LiteralPath (Join-Path $sourceRoot $notice) -Destination $outputRoot}
$notices=Join-Path $outputRoot 'notices'
New-Item -ItemType Directory -Path $notices -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'third_party') -Destination $notices -Recurse
$fontNotices=Join-Path $notices 'fonts';New-Item -ItemType Directory -Path $fontNotices -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'assets/fonts') -File | Where-Object Extension -NotIn @('.otf','.ttf','.import') | Copy-Item -Destination $fontNotices
[IO.File]::WriteAllText((Join-Path $notices 'GODOT_RUNTIME_NOTICE.txt'),"Unmodified Godot Engine runtime. Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. MIT license and third-party component notices: https://godotengine.org/license/ . This portable package uses the installed editor-capable runtime with an exported game PCK; it is not a custom engine or installer.")
RunGodot 'startup' @('--headless','--audio-driver','Dummy','--path',$outputRoot,'--main-pack',$pack,'--quit-after','60')
$manifest=[ordered]@{commit=$revision;godot=$Godot;format='portable Windows x64; installed Godot runtime plus exported PCK';entry='play.cmd';files=@()}
foreach($file in @('Bellkeep.exe','Bellkeep.pck')){$item=Get-Item -LiteralPath (Join-Path $outputRoot $file);$manifest.files+=@{name=$file;bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash}}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot 'build-manifest.json') -Encoding utf8
Write-Output ('BUILD_OUTPUT='+$outputRoot)
Write-Output ('BUILD_COMMIT='+$revision)
