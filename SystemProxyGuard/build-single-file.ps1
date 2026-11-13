# ==========================================================================
#  build-single-file.ps1 -- assemble the self-contained installer
#  "SystemProxyGuard-Setup.cmd" from the runtime files in this folder.
#
#  The generated .cmd embeds the three runtime files as base64 payloads and
#  extracts them on the target machine, so a single file can be copied to
#  any Windows 10/11 PC and run by double-click. No admin rights needed.
#
#  Run with:  powershell -NoProfile -ExecutionPolicy Bypass -File build-single-file.ps1
# ==========================================================================

$ErrorActionPreference = 'Stop'
$srcDir  = $PSScriptRoot
$outPath = Join-Path $srcDir 'SystemProxyGuard-Setup.cmd'

function Read-B64([string]$Path) {
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
}

function Wrap-B64([string]$B64, [int]$Width = 100) {
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $B64.Length; $i += $Width) {
        [void]$sb.AppendLine($B64.Substring($i, [Math]::Min($Width, $B64.Length - $i)))
    }
    return $sb.ToString().TrimEnd()
}

foreach ($name in 'Disable-SystemProxy.bat', 'Refresh-ProxySettings.ps1', 'Disable-SystemProxy.vbs') {
    if (-not (Test-Path -LiteralPath (Join-Path $srcDir $name))) { throw "Missing source file: $name" }
}

$batB64 = Wrap-B64 (Read-B64 (Join-Path $srcDir 'Disable-SystemProxy.bat'))
$ps1B64 = Wrap-B64 (Read-B64 (Join-Path $srcDir 'Refresh-ProxySettings.ps1'))
$vbsB64 = Wrap-B64 (Read-B64 (Join-Path $srcDir 'Disable-SystemProxy.vbs'))

# --- PowerShell extraction stage (appended after the batch header) ---------
$psLines = @(
    "# SystemProxyGuard -- embedded setup stage (runs after the batch header).",
    '$ErrorActionPreference = ''Stop''',
    '$installDir = Join-Path $env:LOCALAPPDATA ''SystemProxyGuard''',
    '$startupDir = [Environment]::GetFolderPath(''Startup'')',
    'New-Item -ItemType Directory -Path $installDir -Force | Out-Null',
    '',
    'function Write-Payload([string]$Path, [string]$Base64) {',
    '    [IO.File]::WriteAllBytes($Path, [Convert]::FromBase64String($Base64))',
    '}',
    '',
    '$payloadBat = @''',
    $batB64,
    '''@',
    'Write-Payload (Join-Path $installDir ''Disable-SystemProxy.bat'') $payloadBat',
    '',
    '$payloadPs1 = @''',
    $ps1B64,
    '''@',
    'Write-Payload (Join-Path $installDir ''Refresh-ProxySettings.ps1'') $payloadPs1',
    '',
    '$payloadVbs = @''',
    $vbsB64,
    '''@',
    'Write-Payload (Join-Path $installDir ''Disable-SystemProxy.vbs'') $payloadVbs',
    '',
    'Copy-Item -LiteralPath (Join-Path $installDir ''Disable-SystemProxy.vbs'') -Destination (Join-Path $startupDir ''Disable-SystemProxy.vbs'') -Force',
    '',
    '# Disable any leftover proxy immediately (not only at the next logon).',
    'Start-Process -FilePath (Join-Path $installDir ''Disable-SystemProxy.bat'') -WindowStyle Hidden -Wait',
    '',
    '$key = ''HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings''',
    '$value = (Get-ItemProperty -Path $key -Name ProxyEnable -ErrorAction Stop).ProxyEnable',
    'Write-Host ''''',
    'Write-Host "SystemProxyGuard installed. Current ProxyEnable = $value (0 = system proxy OFF)."',
    'Write-Host ''It will be forced OFF silently at every logon.''',
    'Write-Host ''Scripts:   '' -NoNewline',
    'Write-Host $installDir',
    'Write-Host ''Run log:   '' -NoNewline',
    'Write-Host (Join-Path $installDir ''disable-proxy.log'')'
)

# --- Batch header (its line count defines the "more +N" skip) --------------
$header = @(
    '@echo off',
    'setlocal EnableExtensions',
    'title SystemProxyGuard Setup',
    'set "SETUP_PS1=%TEMP%\SystemProxyGuard-Setup.ps1"',
    'more +SKIP "%~f0" > "%SETUP_PS1%"',
    'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SETUP_PS1%"',
    'set "RC=%ERRORLEVEL%"',
    'del "%SETUP_PS1%" >nul 2>&1',
    'if not "%RC%"=="0" (',
    '    echo.',
    '    echo Setup failed with exit code %RC%.',
    '    echo If your PC blocks PowerShell, use the folder installer Install.cmd instead.',
    ')',
    'if /i not "%~1"=="/quiet" (',
    '    echo.',
    '    echo Press any key to close...',
    '    pause >nul',
    ')',
    'exit /b %RC%'
)

$skip = $header.Count   # PowerShell stage starts on line $skip + 1
$header[4] = $header[4].Replace('SKIP', [string]$skip)
$allLines = @($header) + @($psLines)
[IO.File]::WriteAllText($outPath, (($allLines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Built: $outPath"
Write-Host ("Lines: {0}  (batch header {1}, payload stage {2})" -f $allLines.Count, $header.Count, $psLines.Count)
