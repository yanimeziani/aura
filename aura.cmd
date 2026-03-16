@echo off
REM Web4 CLI — Windows launcher. Plug-and-play.
REM Legacy alias: aura.cmd
REM Usage: aura.cmd <command> [options]
setlocal
set AURA_ROOT=%~dp0
set AURA_ROOT=%AURA_ROOT:~0,-1%
if "%~1"=="" (py -3 "%~dp0aura.py" help) else (py -3 "%~dp0aura.py" %*)
exit /b %ERRORLEVEL%
