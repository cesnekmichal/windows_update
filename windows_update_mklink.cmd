@echo off
chcp 1252
Title "Windows Update MKLink"

:: Go to current script direcotry
cd /D "%~dp0"

:: Copying cmd files to local windows_update location
mkdir "%HOMEDRIVE%%HOMEPATH%\AppData\Local\windows_update"
copy "%~dp0\windows_update.cmd"        "%HOMEDRIVE%%HOMEPATH%\AppData\Local\windows_update\windows_update.cmd" /Y
copy "%~dp0\windows_update_mklink.cmd" "%HOMEDRIVE%%HOMEPATH%\AppData\Local\windows_update\windows_update_mklink.cmd" /Y

:: Creating Shortcut
set "fileLnk=%HOMEDRIVE%%HOMEPATH%\Desktop\Aktualizovat Windows.lnk"
set "fileCmd=%HOMEDRIVE%%HOMEPATH%\AppData\Local\windows_update\windows_update.cmd"
PowerShell.exe -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%fileLnk%'); $Shortcut.TargetPath = '%fileCmd%'; $Shortcut.Save();"

:: Executing Shortcut
start "" "%fileLnk%"