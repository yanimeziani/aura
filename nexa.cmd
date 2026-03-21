@echo off
REM Nexa CLI — Windows launcher.
REM Usage: nexa.cmd <command> [options]
setlocal
set NEXA_ROOT=%~dp0
set NEXA_ROOT=%NEXA_ROOT:~0,-1%
set AURA_ROOT=%NEXA_ROOT%
if "%~1"=="" (py -3 "%~dp0nexa.py" help) else (py -3 "%~dp0nexa.py" %*)
exit /b %ERRORLEVEL%
