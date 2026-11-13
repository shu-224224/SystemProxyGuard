@echo off
setlocal EnableExtensions
title SystemProxyGuard Installer

rem ==========================================================================
rem  Install.cmd -- double-click installer for SystemProxyGuard.
rem
rem  Copies the runtime scripts to %LOCALAPPDATA%\SystemProxyGuard\ and puts
rem  the silent launcher (Disable-SystemProxy.vbs) into the user's Startup
rem  folder, so the system proxy is forced OFF at every logon.
rem
rem  Pure batch on purpose: no PowerShell execution-policy problems.
rem  No administrator rights needed.
rem
rem  Usage:  double-click, or  Install.cmd /quiet  (no pause at the end).
rem ==========================================================================

set "DST=%LOCALAPPDATA%\SystemProxyGuard"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

if not exist "%~dp0Disable-SystemProxy.bat" (
    echo [ERROR] Disable-SystemProxy.bat was not found next to this installer.
    echo         Keep all files of the system-proxy-guard folder together.
    goto :fail
)
if not exist "%~dp0Refresh-ProxySettings.ps1" goto :fail
if not exist "%~dp0Disable-SystemProxy.vbs" goto :fail

echo Installing SystemProxyGuard for user %USERNAME% ...
mkdir "%DST%" 2>nul
copy /y "%~dp0Disable-SystemProxy.bat"   "%DST%" >nul
copy /y "%~dp0Refresh-ProxySettings.ps1" "%DST%" >nul
copy /y "%~dp0Disable-SystemProxy.vbs"   "%DST%" >nul
copy /y "%~dp0Disable-SystemProxy.vbs"   "%STARTUP%" >nul

echo Running once now to disable any leftover proxy ...
call "%DST%\Disable-SystemProxy.bat"

set "PV=unknown"
for /f "tokens=3" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do set "PV=%%A"

echo.
if /i "%PV%"=="0x0" (
    echo Done. System proxy is OFF ^(ProxyEnable=0^).
    echo It will be forced OFF silently at every logon.
) else (
    echo Done. Current ProxyEnable = %PV% ^(see log below^).
)
echo Run log: %DST%\disable-proxy.log

if /i not "%~1"=="/quiet" (
    echo.
    echo Press any key to close...
    pause >nul
)
exit /b 0

:fail
echo [ERROR] Required files are missing. Copy the whole system-proxy-guard folder.
if /i not "%~1"=="/quiet" pause >nul
exit /b 1
