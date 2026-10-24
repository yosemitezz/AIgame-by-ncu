@echo off
setlocal
set "TEMP=%~dp0.local\tmp"
set "TMP=%TEMP%"
set "APPDATA=%~dp0.local\appdata"
set "LOCALAPPDATA=%APPDATA%"
set "XDG_CACHE_HOME=%~dp0.local\cache"
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%XDG_CACHE_HOME%" mkdir "%XDG_CACHE_HOME%"
for /d %%G in (D:\Godot*) do (
  for %%E in ("%%G\*console.exe") do (
    if exist "%%~E" (
      "%%~E" --path "%~dp0." --log-file "%~dp0.local\game.log"
      exit /b
    )
  )
)
echo Godot 4.7 not found. Open project.godot with Godot or use run.ps1 -Godot path.
pause
