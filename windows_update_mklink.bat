@echo off
cd %~dp0
copy "%~dp0\windows_update.bat" "%HOMEDRIVE%%HOMEPATH%\AppData\Local\windows_update.bat" /Y
copy "%~dp0\windows_update.ps1" "%HOMEDRIVE%%HOMEPATH%\AppData\Local\windows_update.ps1" /Y
copy "%~dp0\windows_update_mklink.bat" "%HOMEDRIVE%%HOMEPATH%\AppData\Local\windows_update_mklink.bat" /Y
echo Set oWS = WScript.CreateObject("WScript.Shell") > CreateShortcut.vbs
echo sLinkFile = "%HOMEDRIVE%%HOMEPATH%\Desktop\Aktualizovat Windows.lnk" >> CreateShortcut.vbs
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> CreateShortcut.vbs
echo oLink.TargetPath = "%HOMEDRIVE%%HOMEPATH%\AppData\Local\windows_update.bat" >> CreateShortcut.vbs
echo oLink.Save >> CreateShortcut.vbs
cscript CreateShortcut.vbs
del CreateShortcut.vbs
start "" "%HOMEDRIVE%%HOMEPATH%\Desktop\Aktualizovat Windows.lnk"