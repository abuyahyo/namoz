Set objShell = CreateObject("WScript.Shell")
strScriptPath = WScript.ScriptFullName
strFolder = Left(strScriptPath, InStrRev(strScriptPath, "\"))
objShell.Run "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File """ & strFolder & "widget.ps1""", 0, False
