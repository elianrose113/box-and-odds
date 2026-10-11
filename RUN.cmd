@echo off
setlocal
set "BOXYARD_GODOT=%GODOT_EXE%"
if not defined BOXYARD_GODOT set "BOXYARD_GODOT=%~dp0..\tools\godot\Godot_v4.6-stable_win64.exe"
if not exist "%BOXYARD_GODOT%" (
    echo Godot 4.6 not found. Import project.godot in Godot, or set GODOT_EXE.
    pause
    exit /b 1
)
start "" "%BOXYARD_GODOT%" --path "%~dp0." %*
