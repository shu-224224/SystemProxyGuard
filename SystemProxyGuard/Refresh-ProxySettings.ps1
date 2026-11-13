# Refresh-ProxySettings.ps1
# Notify WinINET that the proxy settings changed, so already-running
# processes re-read them from the registry. Best effort: any failure is
# ignored and the script still exits 0. Runs hidden, produces no output.

$ErrorActionPreference = 'SilentlyContinue'

$typeDefinition = @'
using System;
using System.Runtime.InteropServices;

public static class WinInetProxyRefresh
{
    [DllImport("wininet.dll", SetLastError = true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
}
'@

try {
    Add-Type -TypeDefinition $typeDefinition -ErrorAction Stop
    # INTERNET_OPTION_SETTINGS_CHANGED (39), then INTERNET_OPTION_REFRESH (37)
    [void][WinInetProxyRefresh]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
    [void][WinInetProxyRefresh]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
} catch { }

exit 0
