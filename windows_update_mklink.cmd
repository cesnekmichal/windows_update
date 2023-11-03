@echo off
SETLOCAL EnableDelayedExpansion

Title "Windows Update MKLink"

:: Path to script directory location
set "ScriptDir=%~dp0"
:: Escaping roofs with: double 'roof'
set "ScriptDir=%ScriptDir:^=^^%"
:: Escaping ampersands with: 'roof'
set "ScriptDir=%ScriptDir:&=^&%"
:: Escaping spaces with: 'roof'
set "ScriptDir=%ScriptDir: =^ %"
:: Escaping apostrofs with: double 'apostrof'
set "ScriptDir=%ScriptDir:'=''%"
:: Escaping left bracket with: 'roof'
set "ScriptDir=%ScriptDir:(=^(%"
:: Escaping right bracket with: 'roof'
set "ScriptDir=%ScriptDir:)=^)%"
:: Escaping left brace with: 'roof'
set "ScriptDir=%ScriptDir:{=^{%"
:: Escaping right brace with: 'roof'
set "ScriptDir=%ScriptDir:}=^}%"
:: Escaping left square bracket with: 'roof'
set "ScriptDir=%ScriptDir:[=^[%"
:: Escaping right square bracket with: 'roof'
set "ScriptDir=%ScriptDir:]=^]%"
:: Script name %~n0 with extension %~x0
set "ScriptName=%~n0%~x0"
:: Script path joining script dir and script name
set "ScriptPath=%ScriptDir%%ScriptName%"

if "%1"=="SKIP_SELF_UPDATE" (
   call :MAIN
   EXIT /B 0
) else (
   call :SELF_UPDATE windows_update        https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update.cmd
   call :SELF_UPDATE windows_update_mklink https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update_mklink.cmd
   if !errorlevel!==1 (
      :: Self Update Success
      %comspec% /C %ScriptPath% SKIP_SELF_UPDATE %*
      EXIT /B 0
   ) else (
      :: Update not Available
      call :MAIN
      EXIT /B 0
   )
)

::==============================================================================
:: MAIN running function
:MAIN

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
EXIT /B 0
::==============================================================================


::==============================================================================
:: Self Update 
:: Syntax: call :SELF_UPDATE <script_name_cmd> <url_path_to_script>
:SELF_UPDATE

set name=%~1
set nameCmd=%name%.cmd
set nameTmp=%name%.tmp
set nameDff=%name%.diff
set URL=%~2

CD /D "%~dp0"

echo # Self Updating %nameCmd% ...
:: Download from URL to temporary file
PowerShell -Command "$URL='%URL%';(New-Object System.Net.WebClient).DownloadString($URL)">%nameTmp%
if NOT %errorlevel%==0 (
   :: Delete tmp file
   del %nameTmp%
   echo # Downloading remote file error! - %URL%
   EXIT /B 0
)
if NOT exist %nameTmp% (
   echo # Downloading remote file error! - %URL%
   EXIT /B 0
)
:: Compare original and new file to diff file
PowerShell -Command "$FA='%nameCmd%';$FB='%nameTmp%';if(Compare-Object -ReferenceObject $(Get-Content $FA) -DifferenceObject $(Get-Content $FB)) { echo different } else { echo same }">%nameDff%
:: Reading output of comaring file to variable
set /p status=<%nameDff%
:: Deleding output tmp file
del "%nameDff%"
:: if comparsion status is "different", then we will update the file
if "%status%"=="different" (
   copy /B /V /Y "%nameTmp%" "%nameCmd%"
   echo # Self Updating success...
   :: Delete tmp file
   del "%nameTmp%"
   EXIT /B 1
) else (
   echo # None Self Update detected.
   :: Delete tmp file
   del "%nameTmp%"
   EXIT /B 0
)
EXIT /B 0
::==============================================================================
