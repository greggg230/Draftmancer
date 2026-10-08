' Launches deploy\windows\supervise.mjs with a hidden console window.
' Run by the "Draftmancer" scheduled task (see install-task.ps1).
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)))
Set shell = CreateObject("WScript.Shell")
shell.CurrentDirectory = root
shell.Run """C:\Program Files\nodejs\node.exe"" """ & root & "\deploy\windows\supervise.mjs""", 0, False
