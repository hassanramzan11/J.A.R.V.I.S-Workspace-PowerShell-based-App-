' J.A.R.V.I.S Workspace - silent launcher
' Runs the PowerShell GUI without showing a console window.
Set sh = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
ps1Path = scriptDir & "\Jarvis_Builder.ps1"
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & ps1Path & """", 0, False
