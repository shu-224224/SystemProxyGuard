@echo off
setlocal EnableExtensions

rem Keep date formatting stable and ASCII-only for the log line below.
chcp 936 >nul 2>&1

rem ==========================================================================
rem  Disable-SystemProxy.bat
rem  Force the Windows system proxy switch OFF (WinINET / Internet Options):
rem      HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings
rem      ProxyEnable (REG_DWORD) = 0
rem
rem  Intended to run silently at every logon, so a proxy address left behind
rem  by the previous shutdown cannot break network access after boot.
rem  No administrator rights required (per-user HKCU setting).
rem
rem  A one-line entry is appended to disable-proxy.log on every run.
rem ==========================================================================

set "REGKEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
set "LOG=%~dp0disable-proxy.log"
set "BEFORE=unknown"
set "AFTER=unknown"

rem --- Read the current value (for the log) --------------------------------
reg query "%REGKEY%" /v ProxyEnable >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=3" %%A in ('reg query "%REGKEY%" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do set "BEFORE=%%A"
)

rem --- Force the system proxy switch OFF -----------------------------------
reg add "%REGKEY%" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>&1
if errorlevel 1 (
    >>"%LOG%" echo [%date% %time%] ERROR: failed to write ProxyEnable=0
    exit /b 1
)

rem --- Read back the new value ---------------------------------------------
reg query "%REGKEY%" /v ProxyEnable >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=3" %%A in ('reg query "%REGKEY%" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do set "AFTER=%%A"
)

rem --- Tell WinINET the settings changed (best effort) ---------------------
if exist "%~dp0Refresh-ProxySettings.ps1" (
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Refresh-ProxySettings.ps1" >nul 2>&1
)

>>"%LOG%" echo [%date:~0,10% %time%] system proxy disabled: ProxyEnable %BEFORE% -^> %AFTER%
exit /b 0
