@echo off
SETLOCAL EnableDelayedExpansion

Title Windows Update 3.0

::::::::::::::::::::::::::::::::::::::::
:: User Account Control - UAC ELEVATE ::
:: 
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
:: Test to UAC Privileges
NET FILE 1>NUL 2>NUL
:: if %errorlevel% is ZERO then UAC Privileges are already available, otherwise not
if %errorlevel% EQU 0 (
   goto :MAIN
) else (
   :: Running this script via PowerShell with UAC Privileges Prompt and all input parameters
   PowerShell.exe -Command "Start-Process -Verb RunAs -FilePath '%comspec%' -ArgumentList '/C %ScriptPath% %*'"
)
:: Retun code in %errorlevel% always throught PowerShell will be only 0=success or 1=failed
if %errorlevel% NEQ 0 (
   :: Exit with Return Code 8
   EXIT /B 8
)
:: Exit with Return Code 0
EXIT /B 0
::::::::::::::::::::::::::::::::::::::::


::==============================================================================
:: MAIN Function
:MAIN
if "%1"=="WINDOWS_UPDATE" (
   call :WINDOWS_UPDATE
) else (
   call :SELF_UPDATE windows_update_mklink https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update_mklink.cmd
   call :SELF_UPDATE windows_update        https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update.cmd
   if %errorlevel%==1 (
      %comspec% /C %ScriptPath% WINDOWS_UPDATE %*
   ) else (
      call :WINDOWS_UPDATE
   )
)
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

echo # %nameCmd% Self Updating...
:: Download from URL to temporary file
PowerShell -Command "$URL='%URL%';(New-Object System.Net.WebClient).DownloadString($URL)">%nameTmp%
if NOT %errorlevel%==0 (
   :: Delete tmp file
   DEL %nameTmp%
   echo # %nameCmd% Downloading remote file error! - %URL%
   EXIT /B 0
)
if NOT exist %nameTmp% (
   echo # %nameCmd% Downloading remote file error! - %URL%
   EXIT /B 0
)
if NOT exist %nameCmd% (
   RENAME %nameTmp% %nameCmd%
   EXIT /B 0
)
:: Compare original and new file to diff file
PowerShell -Command "$FA='%nameCmd%';$FB='%nameTmp%';if(Compare-Object -ReferenceObject $(Get-Content $FA) -DifferenceObject $(Get-Content $FB)) { echo different } else { echo same }">%nameDff%
:: Reading output of comaring file to variable
set /p status=<%nameDff%
:: Deleding output tmp file
DEL "%nameDff%"
:: if comparsion status is "different", then we will update the file
if "%status%"=="different" (
   COPY /B /V /Y "%nameTmp%" "%nameCmd%"
   echo # %nameCmd% Self Updating success.
   :: Delete tmp file
   DEL "%nameTmp%"
   EXIT /B 1
) else (
   echo # %nameCmd% None Self Update detected.
   :: Delete tmp file
   DEL "%nameTmp%"
   EXIT /B 0
)
EXIT /B 0
::==============================================================================


::==============================================================================
:WINDOWS_UPDATE

:: #Install module nuget - #NuGet provider for the OneGet meta-package manager.
PowerShell.exe -Command "if (Get-Module -ListAvailable -Name 'nuget') { Write-Host '# NuGet Installed.'; } else { Write-Host '# NuGet Installing...'; Find-PackageProvider -Name 'nuget' -ForceBootstrap -IncludeDependencies; Install-Package 'nuget' -Force -Confirm:$False; Write-Host '# NuGet Installed.'; }"

:: #Install module  PSWindowsUpdate
PowerShell.exe -Command "if (Get-Module -ListAvailable -Name PSWindowsUpdate) { Write-Host '# PSWindowsUpdate Installed.'; } else { Write-Host '# PSWindowsUpdate Installing...'; Install-Module PSWindowsUpdate -Confirm:$False -Force; Write-Host '# PSWindowsUpdate Installed.'; }"

:: #Install the available windows updates and reboot if necessary
PowerShell.exe -ExecutionPolicy Bypass -Command "Write-Host '# Windows Update Installing...'; Import-Module PSWindowsUpdate; Get-WindowsUpdate -AcceptAll -AutoReboot -Download -Install;"

:: #Hide problematic KB5034441,KB5001716 (if available and visible)
PowerShell.exe -ExecutionPolicy Bypass -Command "if (Get-WUlist -KBArticleID KB5034441) { Write-Host '# Hide problematic KB5034441 update...'; Import-Module PSWindowsUpdate; Hide-WindowsUpdate -KBArticleID KB5034441 -AcceptAll; }"
PowerShell.exe -ExecutionPolicy Bypass -Command "if (Get-WUlist -KBArticleID KB5001716) { Write-Host '# Hide problematic KB5001716 update...'; Import-Module PSWindowsUpdate; Hide-WindowsUpdate -KBArticleID KB5001716 -AcceptAll; }"

:: #Microsoft Store Updates Scan...
PowerShell.exe -Command "Write-Host '# Microsoft Store Updates Scan...'; Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod;"

:: #Update Windows Defender
PowerShell.exe -Command "Write-Host '# Windows Defender Updating...'; Update-MpSignature;"

:: #DONE
PowerShell.exe -Command "Write-Host '# DONE ;-)'"

:: #FINAL SLEEP
PowerShell.exe -Command "$i = 1; do{ Start-Sleep -s 1; Write-Host -NoNewline '.'; $i++;} while ($i -le 5)"
EXIT /B 0
::==============================================================================

