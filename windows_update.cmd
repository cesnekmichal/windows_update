@echo off
setlocal EnableDelayedExpansion

title Windows Update 3.2

:: Cesta k adresari skriptu
set "ScriptDir=%~dp0"
set "ScriptName=%~nx0"
set "ScriptPath=%ScriptDir%%ScriptName%"
set "FINAL_EXIT_CODE=0"

:: Line endings: CRLF

:: Kontrola, zda je prítomen parametr -debug nebo --debug (bezpecne bez zavorek)
set "DEBUG_MODE=0"
set "LOGFILE="
for %%a in (%*) do if /i "%%a"=="-debug" set "DEBUG_MODE=1"
for %%a in (%*) do if /i "%%a"=="--debug" set "DEBUG_MODE=1"
if "%DEBUG_MODE%"=="1" set "LOGFILE=%ScriptDir%windows_update_debug.log"

:: Kontrola, zda je prítomen parametr -noupdate nebo --noupdate (bezpecne bez zavorek)
set "NO_UPDATE=0"
for %%a in (%*) do if /i "%%a"=="-noupdate" set "NO_UPDATE=1"
for %%a in (%*) do if /i "%%a"=="--noupdate" set "NO_UPDATE=1"

:: Kontrola administrátorskych prav (bezpecne bez zavorek)
set "IS_ELEVATED=No"
net file 1>nul 2>nul
if %errorlevel% equ 0 set "IS_ELEVATED=Yes"

call :LOG "cmd: Skript spusten. Uzivatel: %USERNAME%, Pravomoci: %IS_ELEVATED%, Argumenty: %*"

if "%IS_ELEVATED%"=="Yes" goto :MAIN

:: Bezpecne spusteni s UAC privilegem pomoci PowerShellu a cekani na dokonceni
call :LOG "cmd: Pozadavek na zvyseni prav (UAC)..."
set "TMP_EXIT_FILE=%ScriptDir%%ScriptName%_exit.tmp"
if exist "%TMP_EXIT_FILE%" del "%TMP_EXIT_FILE%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath '%comspec%' -ArgumentList ('/c ' + [char]34 + [char]34 + '%ScriptPath%' + [char]34 + ' %*' + [char]34) -Wait"

:: Cteni navratoveho kodu z docasneho souboru (bezpecne bez zavorek)
set "FINAL_EXIT_CODE=0"
if not exist "%TMP_EXIT_FILE%" goto :EXIT_SCRIPT
set /p FINAL_EXIT_CODE=<"%TMP_EXIT_FILE%"
del "%TMP_EXIT_FILE%"
call :LOG "cmd: Elevovany proces dokoncen s navratovym kodem: !FINAL_EXIT_CODE!"
goto :EXIT_SCRIPT

:MAIN
:: Pokud byl skript spusten s parametrem, preskocíme self-update
if "%~1"=="WINDOWS_UPDATE" goto :RUN_UPDATE
:: V debug rezimu nebo s parametrem -noupdate preskocime self-update
if "%DEBUG_MODE%"=="1" (
    call :LOG "cmd: Debug rezim aktivni. Preskakuji self-update."
    goto :RUN_UPDATE
)
if "%NO_UPDATE%"=="1" (
    call :LOG "cmd: Parametr -noupdate aktivni. Preskakuji self-update."
    goto :RUN_UPDATE
)

:: Kontrola aktualizace mklink skriptu
call :SELF_UPDATE windows_update_mklink https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update_mklink.cmd
set "UPDATED_MKLINK=%errorlevel%"

:: Kontrola aktualizace hlavniho skriptu
call :SELF_UPDATE windows_update        https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update.cmd
set "UPDATED_UPDATE=%errorlevel%"

:: Pokud se aktualizoval sam spoustec, restartujeme ho pro nacteni noveho kodu (bezpecne bez zavorek)
if not "%UPDATED_UPDATE%"=="1" goto :RUN_UPDATE
call :LOG "cmd: Skript windows_update.cmd se zaktualizoval, restartuji ho..."
%comspec% /c "%ScriptPath%" WINDOWS_UPDATE %*
set "FINAL_EXIT_CODE=%errorlevel%"
goto :EXIT_SCRIPT

:RUN_UPDATE
call :WINDOWS_UPDATE
set "FINAL_EXIT_CODE=%errorlevel%"
goto :EXIT_SCRIPT

::==============================================================================
:: Funkce pro logovani (Zcela bezpecne bez zavorek kuli moznemu vyskytu spec. znaku v %~1)
::==============================================================================
:LOG
if not "%DEBUG_MODE%"=="1" goto :LOG_CONSOLE
if "%LOGFILE%"=="" goto :LOG_CONSOLE
echo [%date% %time%] [INFO] %~1 >> "%LOGFILE%"
:LOG_CONSOLE
echo %~1
exit /b 0

::==============================================================================
:: Funkce pro Self Update (Vrací 1 pri zmene, 0 pri neuspechu/shode)
::==============================================================================
:SELF_UPDATE
set "name=%~1"
set "nameCmd=%name%.cmd"
set "nameTmp=%name%.tmp"
set "URL=%~2"

cd /d "%ScriptDir%"

call :LOG "cmd: %nameCmd% Kontrola aktualizace..."

:: Stazeni pres PowerShell s vynucenim TLS 1.2
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('%URL%', '%nameTmp%')" 2>nul
if errorlevel 1 goto :DOWNLOAD_ERROR

if not exist "%nameTmp%" goto :DOWNLOAD_ERROR

if not exist "%nameCmd%" (
    rename "%nameTmp%" "%nameCmd%"
    call :LOG "cmd: %nameCmd% stazen jako novy."
    exit /b 0
)

:: Rychle binarni porovnani pomoci nativniho fc.exe
fc /b "%nameCmd%" "%nameTmp%" >nul
if errorlevel 1 (
    if /i "%nameCmd%"=="%ScriptName%" (
        call :LOG "cmd: %nameCmd% aktualizovan, restartuji..."
        start "" cmd.exe /c "ping -n 2 127.0.0.1 >nul & copy /y \"%nameTmp%\" \"%nameCmd%\" >nul & del \"%nameTmp%\" & \"%ScriptPath%\" WINDOWS_UPDATE %*"
        exit /b 1
    )
    copy /b /v /y "%nameTmp%" "%nameCmd%" >nul
    call :LOG "cmd: %nameCmd% aktualizovan."
    del "%nameTmp%"
    exit /b 1
) else (
    call :LOG "cmd: %nameCmd% je aktualni."
    del "%nameTmp%"
    exit /b 0
)

:DOWNLOAD_ERROR
if exist "%nameTmp%" del "%nameTmp%"
call :LOG "cmd: Chyba pri stahovani %nameCmd% z %URL%"
exit /b 0

::==============================================================================
:: Spusteni Windows Update pomoci jednoho PowerShell volani (Hybridni skript)
::==============================================================================
:WINDOWS_UPDATE
call :LOG "cmd: Spousteni PowerShell updateru..."
set "CMD_FULL_PATH=%~f0"
set PS_LOADER=$s=[IO.File]::ReadAllText($env:CMD_FULL_PATH) -split ('###_PS' + '_START_###') ^| Select-Object -Last 1; ^& ([scriptblock]::Create($s))
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "%PS_LOADER%"
exit /b %errorlevel%

:EXIT_SCRIPT
:: Ulozeni navratoveho kodu pro parent proces (bezpecne bez zavorek)
if not "%IS_ELEVATED%"=="Yes" goto :SKIP_EXIT_TMP
echo %FINAL_EXIT_CODE% > "%ScriptDir%%ScriptName%_exit.tmp"
:SKIP_EXIT_TMP
call :LOG "cmd: Skript dokoncen s navratovym kodem: %FINAL_EXIT_CODE%"
exit /b %FINAL_EXIT_CODE%

###_PS_START_###
# Nastaveni logovani do souboru na zaklade systemove promenne
$LogFile = $env:LOGFILE

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    if ($Level -eq "ERROR") {
        Write-Host $Message -ForegroundColor Red
    } elseif ($Level -eq "WARNING") {
        Write-Host $Message -ForegroundColor Yellow
    } else {
        Write-Host $Message
    }
    
    if ($LogFile) {
        [System.IO.File]::AppendAllText($LogFile, $logLine + [Environment]::NewLine)
    }
}

function Invoke-AndLog {
    param([scriptblock]$ScriptBlock, [string]$Message)
    Write-Log $Message
    try {
        # Spusteni bloku a sloučení všech kanálu do success streamu
        & $ScriptBlock *>&1 | ForEach-Object {
            Write-Log "ps1: $_"
        }
    } catch {
        Write-Log "ps1: Vyjimka: $_" -Level "ERROR"
    }
}

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Log "ps1: PowerShell relace zahajena. Uzivatel: $currentUser, Admin: $isElevated"

# Kontrola a instalace NuGet Package Providera
Invoke-AndLog {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null
    }
} "ps1: Kontrola NuGet Package Providera..."

# Kontrola a instalace modulu PSWindowsUpdate
Invoke-AndLog {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-Module PSWindowsUpdate -Force -Confirm:$false -Scope AllUsers | Out-Null
    }
} "ps1: Kontrola PSWindowsUpdate modulu..."

# Vyhledani a instalace Windows aktualizací
Invoke-AndLog {
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -AutoReboot -Download -Install
} "ps1: Spousteni vyhledani a instalace Windows Update..."

# Aktualizace aplikaci z Microsoft Store
Invoke-AndLog {
    try {
        Get-CimInstance -Namespace 'Root\cimv2\mdm\dmmap' -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01' -ErrorAction Stop | Invoke-CimMethod -MethodName UpdateScanMethod -ErrorAction Stop | Out-Null
    } catch {
        # Fallback to opening Microsoft Store updates page if CIM method is not supported (e.g. on Windows Home)
        Start-Process "ms-windows-store:updates"
    }
} "ps1: Spousteni aktualizace Microsoft Store..."

# Rucni aktualizace definic viru Windows Defenderu
Invoke-AndLog { Update-MpSignature } "ps1: Aktualizace definic Windows Defender..."

Write-Log "ps1: HOTOVO ;)"

# Zaverecne cekani pred zavrenim okna
$i = 1
do {
    Start-Sleep -Seconds 1
    Write-Host -NoNewline '.'
    $i++
} while ($i -le 5)
Write-Host ''
