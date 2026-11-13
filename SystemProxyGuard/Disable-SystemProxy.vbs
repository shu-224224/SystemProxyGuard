' ==========================================================================
'  Disable-SystemProxy.vbs
'  Silent launcher for Disable-SystemProxy.bat.
'
'  Place a copy in the user's Startup folder (Install.ps1 does this) and the
'  system proxy switch will be forced OFF at every logon, with no visible
'  window: wscript.exe has no console, and the .bat it starts is launched
'  with a hidden window (Run flag 0).
'
'  The .bat is located next to this .vbs when run from the install folder;
'  when this .vbs is the copy inside the Startup folder, it falls back to
'  %LOCALAPPDATA%\SystemProxyGuard\Disable-SystemProxy.bat.
' ==========================================================================

Option Explicit

Dim fso, shell, selfDir, batPath, localAppData

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

selfDir = fso.GetParentFolderName(WScript.ScriptFullName)
batPath = fso.BuildPath(selfDir, "Disable-SystemProxy.bat")

If Not fso.FileExists(batPath) Then
    localAppData = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%")
    batPath = localAppData & "\SystemProxyGuard\Disable-SystemProxy.bat"
End If

If fso.FileExists(batPath) Then
    ' 0 = hidden window, False = do not wait
    shell.Run "cmd.exe /d /c """ & batPath & """", 0, False
End If
