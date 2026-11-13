# ==========================================================================
#  Uninstall.ps1 -- remove SystemProxyGuard from this user account.
#
#  Removes:
#    - the Startup-folder launcher  (so it no longer runs at logon)
#    - %LOCALAPPDATA%\SystemProxyGuard\  (scripts and run log)
#
#  The current proxy setting is left untouched (nothing is re-enabled).
# ==========================================================================

$ErrorActionPreference = 'SilentlyContinue'

$installDir = Join-Path $env:LOCALAPPDATA 'SystemProxyGuard'
$startupDir = [Environment]::GetFolderPath('Startup')
$startupVbs = Join-Path $startupDir 'Disable-SystemProxy.vbs'

if (Test-Path -LiteralPath $startupVbs) {
    Remove-Item -LiteralPath $startupVbs -Force
    Write-Host "Removed autostart file: $startupVbs"
} else {
    Write-Host "No autostart file found at: $startupVbs"
}

if (Test-Path -LiteralPath $installDir) {
    Remove-Item -LiteralPath $installDir -Recurse -Force
    Write-Host "Removed scripts folder: $installDir"
} else {
    Write-Host "No scripts folder found at: $installDir"
}

Write-Host 'SystemProxyGuard uninstalled. Current proxy setting was left as-is.'
