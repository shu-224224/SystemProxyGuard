# ==========================================================================
#  Install.ps1 -- deploy SystemProxyGuard and make it run at every logon.
#
#  What it does:
#    1. Copies the three runtime files to %LOCALAPPDATA%\SystemProxyGuard\
#    2. Puts Disable-SystemProxy.vbs into the user's Startup folder, so it
#       runs automatically at every logon (no admin rights needed).
#    3. Runs the .bat once right now, so a leftover proxy is disabled
#       immediately instead of only after the next reboot.
#    4. Prints the resulting ProxyEnable value.
#
#  Run with:  powershell -NoProfile -ExecutionPolicy Bypass -File Install.ps1
# ==========================================================================

$ErrorActionPreference = 'Stop'

$srcDir     = $PSScriptRoot
$installDir = Join-Path $env:LOCALAPPDATA 'SystemProxyGuard'
$startupDir = [Environment]::GetFolderPath('Startup')

$runtimeFiles = @(
    'Disable-SystemProxy.bat',
    'Refresh-ProxySettings.ps1',
    'Disable-SystemProxy.vbs'
)

foreach ($name in $runtimeFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $srcDir $name))) {
        throw "Missing source file: $name"
    }
}

Write-Host 'Installing SystemProxyGuard ...'
Write-Host "  Source    : $srcDir"
Write-Host "  Scripts   : $installDir"
Write-Host "  Autostart : $startupDir\Disable-SystemProxy.vbs"

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
foreach ($name in $runtimeFiles) {
    Copy-Item -LiteralPath (Join-Path $srcDir $name) -Destination (Join-Path $installDir $name) -Force
}

$startupVbs = Join-Path $startupDir 'Disable-SystemProxy.vbs'
Copy-Item -LiteralPath (Join-Path $installDir 'Disable-SystemProxy.vbs') -Destination $startupVbs -Force

# Run once immediately: disable any proxy left over from the last session.
Start-Process -FilePath (Join-Path $installDir 'Disable-SystemProxy.bat') -WindowStyle Hidden -Wait

# Verify and report.
$key   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$value = (Get-ItemProperty -Path $key -Name ProxyEnable -ErrorAction Stop).ProxyEnable

Write-Host ''
Write-Host "Done. Current ProxyEnable = $value  (0 = system proxy OFF)."
Write-Host "It will be forced to 0 automatically at every logon."
Write-Host ''
Write-Host 'To uninstall, run Uninstall.ps1.'
Write-Host 'Run log: ' -NoNewline
Write-Host (Join-Path $installDir 'disable-proxy.log')
