# ==========================================================================
#  verify-silent.ps1 -- end-to-end test for SystemProxyGuard.
#
#  1. Simulates a "leftover proxy" state: sets ProxyEnable = 1.
#  2. Launches the Startup-folder .vbs exactly as Windows does at logon.
#  3. Samples visible top-level windows during the whole run; any new
#     visible window belonging to cmd/wscript/powershell/conhost means the
#     promise "no visible window" is violated.
#  4. Confirms ProxyEnable was forced back to 0.
#
#  Run with: powershell -NoProfile -ExecutionPolicy Bypass -File verify-silent.ps1
# ==========================================================================

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class WinScan
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc cb, IntPtr p);
    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll")]
    private static extern int GetWindowThreadProcessId(IntPtr hWnd, out int pid);

    public static List<string> Snapshot()
    {
        var list = new List<string>();
        EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
        {
            if (IsWindowVisible(hWnd))
            {
                int pid;
                GetWindowThreadProcessId(hWnd, out pid);
                var sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                list.Add(pid.ToString() + "|" + sb.ToString());
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
'@

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$vbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'Disable-SystemProxy.vbs'
$log = Join-Path $env:LOCALAPPDATA 'SystemProxyGuard\disable-proxy.log'
$watched = @('cmd', 'powershell', 'wscript', 'conhost')

if (-not (Test-Path -LiteralPath $vbs)) { throw "Startup launcher not found: $vbs" }
$logLinesBefore = (Get-Content -LiteralPath $log | Measure-Object -Line).Lines

# --- 1. Simulate leftover proxy state ------------------------------------
Set-ItemProperty -Path $key -Name ProxyEnable -Value 1 -Type DWord
Write-Host "STEP 1  simulate leftover proxy : ProxyEnable = 1"

# --- 2. Baseline visible windows ------------------------------------------
$baseline = @{}
foreach ($w in [WinScan]::Snapshot()) { $baseline[$w] = $true }
Write-Host "STEP 2  baseline visible windows: $($baseline.Count)"

# --- 3. Launch exactly like the Startup folder does ------------------------
Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$vbs`""
Write-Host 'STEP 3  launched Startup launcher via wscript.exe'

$procNames = @{}
$hits = New-Object System.Collections.Generic.List[string]
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($sw.ElapsedMilliseconds -lt 4000) {
    Start-Sleep -Milliseconds 80
    foreach ($item in [WinScan]::Snapshot()) {
        if (-not $baseline.ContainsKey($item)) {
            $pidText = $item.Split('|')[0]
            $procId = [int]$pidText
            if (-not $procNames.ContainsKey($procId)) {
                $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
                $procNames[$procId] = if ($p) { $p.ProcessName } else { 'gone' }
            }
            $pname = $procNames[$procId]
            if ($watched -contains $pname) {
                $hits.Add("$pname | $item")
            }
        }
    }
}

# --- 4. Results -----------------------------------------------------------
$final = (Get-ItemProperty -Path $key).ProxyEnable
$logLinesAfter = (Get-Content -LiteralPath $log | Measure-Object -Line).Lines

Write-Host ''
Write-Host "STEP 4  final ProxyEnable          = $final  (expected 0)"
Write-Host "        new visible windows (startup chain) = $($hits.Count)  (expected 0)"
foreach ($h in $hits) { Write-Host "        VISIBLE: $h" }
Write-Host "        run-log lines added         = $($logLinesAfter - $logLinesBefore)  (expected 1)"
Write-Host ''
Write-Host ($(if ($final -eq 0 -and $hits.Count -eq 0) { 'RESULT  PASS' } else { 'RESULT  FAIL' }))
