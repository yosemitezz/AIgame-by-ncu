param([string]$Godot='',[string]$Git='D:\Git\cmd\git.exe',[string]$TemplateRoot='')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
if(-not $Godot){$Godot=(Get-ChildItem -Path 'D:\Godot*\*console.exe' -File | Select-Object -First 1).FullName}
if(-not $TemplateRoot){$TemplateRoot=Join-Path $projectRoot '.local/godot-templates-4.7.2'}
$releaseTemplate=Join-Path $TemplateRoot 'windows_release_x86_64.exe'
$debugTemplate=Join-Path $TemplateRoot 'windows_debug_x86_64.exe'
if(-not (Test-Path -LiteralPath $releaseTemplate)){throw 'Supply official Godot4.7.2 Win64 release template. See docs/single-exe.md.'}
if((Get-FileHash -LiteralPath $releaseTemplate -Algorithm SHA256).Hash.ToLower() -ne 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'){throw 'Release template hash differs from the verified official member'}
$revision=(& $Git -C $projectRoot rev-parse HEAD).Trim();if($LASTEXITCODE -ne 0){throw 'Cannot resolve source revision'}
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$outputRoot=Join-Path $projectRoot ('exports/single-exe-'+$stamp+'-'+$revision.Substring(0,8))
$sourceRoot=Join-Path $outputRoot '.build/source'
$delivery=Join-Path $outputRoot 'standalone'
$isolated=Join-Path 'D:\code\bellkeep-single-verify' ($stamp+'-'+$revision.Substring(0,8))
foreach($folder in @($outputRoot,$isolated)){if(Test-Path -LiteralPath $folder){throw 'Unique delivery directory already exists'}}
foreach($folder in @($sourceRoot,$delivery,$isolated)){New-Item -ItemType Directory -Path $folder -Force | Out-Null}
$env:TEMP=Join-Path $outputRoot '.local/tmp';$env:TMP=$env:TEMP
$env:APPDATA=Join-Path $outputRoot '.local/appdata';$env:LOCALAPPDATA=$env:APPDATA
$env:XDG_CACHE_HOME=Join-Path $outputRoot '.local/cache'
$env:BELLKEEP_USE_PLACEHOLDER='0';$env:BELLKEEP_DISABLE_STORY='0'
foreach($folder in @($env:TEMP,$env:APPDATA,$env:XDG_CACHE_HOME)){New-Item -ItemType Directory -Path $folder -Force | Out-Null}
$archive=Join-Path $outputRoot '.build/source.zip'
& $Git -C $projectRoot archive --format=zip --output=$archive HEAD
if($LASTEXITCODE -ne 0){throw 'Source archive failed'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try {foreach($entry in $zip.Entries){$target=[IO.Path]::GetFullPath((Join-Path $sourceRoot $entry.FullName));if(-not $target.StartsWith($sourceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Archive entry outside source'}}} finally {$zip.Dispose()}
Expand-Archive -LiteralPath $archive -DestinationPath $sourceRoot
# Flatten only the two configured versioned inputs into raw exportable payloads.
# .oggdata prevents importer conversion; the unchanged OGG bytes are decoded in memory.
$configPath=Join-Path $sourceRoot 'data/full_song_timeline.json'
$config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$payload=Join-Path $sourceRoot 'data/runtime_payload';New-Item -ItemType Directory -Path $payload -Force | Out-Null
foreach($mapping in @(@('audio_path','selected_recording.oggdata'),@('chart_path','selected_chart.json'))){
 $value=$config.($mapping[0]);if(-not $value.StartsWith('res://')){throw 'Only versioned project input paths are accepted'}
 $inputPath=[IO.Path]::GetFullPath((Join-Path $sourceRoot $value.Substring(6)))
 if(-not $inputPath.StartsWith($sourceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Payload outside source'}
 Copy-Item -LiteralPath $inputPath -Destination (Join-Path $payload $mapping[1])
 $config.($mapping[0])='res://data/runtime_payload/'+$mapping[1]
}
[IO.File]::WriteAllText($configPath,($config | ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
$preset=@'
[preset.0]
name="Windows Single EXE"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.oggdata,*.txt,*LICENSE*,THIRD_PARTY_NOTICES.md"
exclude_filter=".local/*,artifacts/*,exports/*,tests/*,tools/*,docs/*,.agents/*,.github/*,boss_attack/*"
export_path=""
script_export_mode=2
[preset.0.options]
custom_template/release="__RELEASE__"
custom_template/debug="__DEBUG__"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
debug/export_console_wrapper=0
application/modify_resources=false
application/export_angle=2
application/export_d3d12=2
'@
$preset=$preset.Replace('__RELEASE__',$releaseTemplate.Replace('\','/')).Replace('__DEBUG__',$debugTemplate.Replace('\','/'))
[IO.File]::WriteAllText((Join-Path $sourceRoot 'export_presets.cfg'),$preset,[Text.UTF8Encoding]::new($false))
function RunBounded([string]$Label,[string]$Executable,[string[]]$Arguments,[string]$Working=$outputRoot){
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$Executable;$info.WorkingDirectory=$Working
 $info.Arguments=(($Arguments | ForEach-Object {'"'+($_ -replace '"','\"')+'"'}) -join ' ')
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $proc=[Diagnostics.Process]::new();$proc.StartInfo=$info;[void]$proc.Start()
 $out=$proc.StandardOutput.ReadToEndAsync();$err=$proc.StandardError.ReadToEndAsync();$deadline=[DateTime]::UtcNow.AddMinutes(3)
 while(-not $proc.WaitForExit(1000)){if([DateTime]::UtcNow -gt $deadline){$proc.Kill();throw ($Label+' timed out')}}
 [IO.File]::WriteAllText((Join-Path $outputRoot ($Label+'-console.log')),$out.Result)
 [IO.File]::WriteAllText((Join-Path $outputRoot ($Label+'-error.log')),$err.Result)
 if($proc.ExitCode -ne 0 -or ($out.Result+$err.Result) -match 'SCRIPT ERROR:|ERROR:'){throw ($Label+' failed; inspect its logs')}
}
# Official release templates disallow external --script overrides. Embed a dormant
# verifier that runs only for our explicit user flag plus isolated-test environment.
Copy-Item -LiteralPath (Join-Path $sourceRoot 'tools/single_exe_smoke.gd') -Destination (Join-Path $sourceRoot 'flow/release_build_probe.gd')
Add-Content -LiteralPath (Join-Path $sourceRoot 'project.godot') -Value "`n[autoload]`nReleaseBuildProbe=`"*res://flow/release_build_probe.gd`"`n" -Encoding utf8
RunBounded 'import' $Godot @('--headless','--path',$sourceRoot,'--editor','--import','--quit')
$exe=Join-Path $delivery 'Bellkeep.exe'
RunBounded 'export' $Godot @('--headless','--path',$sourceRoot,'--export-release','Windows Single EXE',$exe)
$initialFiles=@(Get-ChildItem -LiteralPath $delivery -File)
if($initialFiles.Count -ne 1 -or $initialFiles[0].Name -ne 'Bellkeep.exe'){throw 'Export has additional runtime files; single-EXE contract not met'}
$isolatedExe=Join-Path $isolated 'Bellkeep.exe';Copy-Item -LiteralPath $exe -Destination $isolatedExe
$env:BELLKEEP_VERIFY_ISOLATED='1'
RunBounded 'isolated-content' $isolatedExe @('--headless','--audio-driver','Dummy','--','--verify-embedded-build') $isolated
$env:BELLKEEP_VERIFY_ISOLATED='0'
if((Get-FileHash -LiteralPath $exe).Hash -ne (Get-FileHash -LiteralPath $isolatedExe).Hash){throw 'Verification copy differs'}
$manifest=[ordered]@{commit=$revision;format='official Windows x64 release template with embedded PCK and selected raw score/audio';entry=$exe;bytes=(Get-Item -LiteralPath $exe).Length;sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash;isolated_verification=$isolated;external_runtime_files=@();template_sha256=(Get-FileHash -LiteralPath $releaseTemplate -Algorithm SHA256).Hash}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot 'single-exe-manifest.json') -Encoding utf8
Write-Output ('SINGLE_EXE='+$exe)
Write-Output ('SINGLE_EXE_COMMIT='+$revision)
Write-Output ('SINGLE_EXE_BYTES='+$manifest.bytes)
Write-Output ('SINGLE_EXE_SHA256='+$manifest.sha256)
