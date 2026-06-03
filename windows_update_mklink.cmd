@echo off
setlocal EnableDelayedExpansion

title Windows Update MKLink

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

call :LOG "cmd: Skript spusten. Uzivatel: %USERNAME%, Argumenty: %*"

:: Spusteni hlavniho toku
if "%~1"=="SKIP_SELF_UPDATE" goto :RUN_MAIN
:: V debug rezimu nebo s parametrem -noupdate preskocime self-update
if "%DEBUG_MODE%"=="1" (
    call :LOG "cmd: Debug rezim aktivni. Preskakuji self-update."
    goto :RUN_MAIN
)
if "%NO_UPDATE%"=="1" (
    call :LOG "cmd: Parametr -noupdate aktivni. Preskakuji self-update."
    goto :RUN_MAIN
)

:: Kontrola aktualizace obou skriptu
call :SELF_UPDATE windows_update        https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update.cmd
set "UPDATED_UPDATE=%errorlevel%"

call :SELF_UPDATE windows_update_mklink https://raw.githubusercontent.com/cesnekmichal/windows_update/master/windows_update_mklink.cmd
set "UPDATED_MKLINK=%errorlevel%"

:: Pokud se aktualizoval tento skript samotny, restartujeme ho (bezpecne bez zavorek)
if not "%UPDATED_MKLINK%"=="1" goto :RUN_MAIN
call :LOG "cmd: Skript windows_update_mklink.cmd se zaktualizoval, restartuji..."
%comspec% /c "%ScriptPath%" SKIP_SELF_UPDATE %*
set "FINAL_EXIT_CODE=%errorlevel%"
goto :EXIT_SCRIPT

:RUN_MAIN
call :MAIN
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
:: Hlavni funkce (vytvoreni slozky, zkopirovani skriptu a vytvoreni zástupce)
::==============================================================================
:MAIN
cd /d "%ScriptDir%"

:: Vytvoreni lokalni slozky pro skript v AppData (pokud neexistuje)
if not exist "%USERPROFILE%\AppData\Local\windows_update" (
    call :LOG "cmd: Vytvarim slozku AppData\Local\windows_update..."
    mkdir "%USERPROFILE%\AppData\Local\windows_update"
)

:: Zkopirovani aktualnich skriptu do AppData
call :LOG "cmd: Kopiruji skripty do AppData..."
copy /y "windows_update.cmd"        "%LocalAppData%\windows_update\windows_update.cmd" >nul
copy /y "windows_update_mklink.cmd" "%LocalAppData%\windows_update\windows_update_mklink.cmd" >nul

call :LOG "cmd: Skripty byly zkopirovany do slozky AppData\Local\windows_update."

:: Vytvoreni zastupce na plose pomoci PowerShellu bezpecne (odolne vuci OneDrive a apostrofum) a jeho spusteni
call :LOG "cmd: Vytvarim a spoustim zástupce na plose..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$fileLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Aktualizovat Windows.lnk';" ^
    "$fileCmd = Join-Path ($env:LocalAppData) 'windows_update\windows_update.cmd';" ^
    "$WshShell = New-Object -ComObject WScript.Shell;" ^
    "$Shortcut = $WshShell.CreateShortcut($fileLnk);" ^
    "$Shortcut.TargetPath = $fileCmd;" ^
    "$lnkArgs = @();" ^
    "if ($env:NO_UPDATE -eq '1') { $lnkArgs += '-noupdate' };" ^
    "if ($lnkArgs.Count -gt 0) { $Shortcut.Arguments = $lnkArgs -join ' ' };" ^
    "$Shortcut.Save();" ^
    "Start-Process $fileLnk;"

call :LOG "cmd: Zástupce vytvoren a spusten."
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

:: Nastaveni promennych prostredi pro prenos do PowerShellu
set "SELF_URL=%URL%"
set "SELF_LOCAL=%ScriptDir%%nameCmd%"
set "SELF_TMP=%ScriptDir%%nameTmp%"

:: Spusteni PowerShellu: stahne text, znormalizuje, porovna a zapise novy soubor s CRLF bez BOM jen pri zmene.
:: Vraci exit code:
:: 0 = soubory jsou shodne, neni treba aktualizovat
:: 1 = soubory se lisi, novy soubor byl zapsan do %nameTmp% s CRLF a bez BOM
:: 2 = chyba stahovani/siti
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
    "$wc = New-Object System.Net.WebClient;" ^
    "$wc.Encoding = [System.Text.Encoding]::UTF8;" ^
    "try { $raw = $wc.DownloadString($env:SELF_URL) } catch { exit 2 };" ^
    "$crlf = [char]13 + [char]10;" ^
    "$rawN = ($raw -replace '\r?\n', $crlf).TrimEnd();" ^
    "if (-not (Test-Path $env:SELF_LOCAL)) {" ^
    "  $utf8 = New-Object System.Text.UTF8Encoding($false);" ^
    "  [System.IO.File]::WriteAllText($env:SELF_TMP, $rawN + $crlf, $utf8);" ^
    "  exit 1;" ^
    "}" ^
    "$local = [System.IO.File]::ReadAllText($env:SELF_LOCAL, [System.Text.Encoding]::UTF8);" ^
    "$localN = ($local -replace '\r?\n', $crlf).TrimEnd();" ^
    "if ($rawN -ne $localN) {" ^
    "  $utf8 = New-Object System.Text.UTF8Encoding($false);" ^
    "  [System.IO.File]::WriteAllText($env:SELF_TMP, $rawN + $crlf, $utf8);" ^
    "  exit 1;" ^
    "} else {" ^
    "  exit 0;" ^
    "}"

set "SELF_STATUS=%errorlevel%"

if "%SELF_STATUS%"=="2" goto :DOWNLOAD_ERROR
if "%SELF_STATUS%"=="0" (
    call :LOG "cmd: %nameCmd% je aktualni."
    if exist "%nameTmp%" del "%nameTmp%"
    exit /b 0
)

:: Zde SELF_STATUS == 1 (lisi se, do %nameTmp% byl zapsan CRLF novy soubor)
if not exist "%nameCmd%" (
    rename "%nameTmp%" "%nameCmd%"
    call :LOG "cmd: %nameCmd% stazen jako novy."
    exit /b 0
)

if /i "%nameCmd%"=="%ScriptName%" (
    call :LOG "cmd: %nameCmd% aktualizovan, restartuji..."
    start "" cmd.exe /c "ping -n 2 127.0.0.1 >nul & copy /y "%ScriptDir%%nameTmp%" "%ScriptDir%%nameCmd%" >nul & del "%ScriptDir%%nameTmp%" & "%ScriptPath%" SKIP_SELF_UPDATE %*"
    exit /b 1
)

copy /y "%nameTmp%" "%nameCmd%" >nul
call :LOG "cmd: %nameCmd% aktualizovan."
del "%nameTmp%"
exit /b 1

:DOWNLOAD_ERROR
if exist "%nameTmp%" del "%nameTmp%"
call :LOG "cmd: Chyba pri stahovani %nameCmd% z %URL%"
exit /b 0

:EXIT_SCRIPT
call :LOG "cmd: Skript dokoncen s navratovym kodem: %FINAL_EXIT_CODE%"
exit /b %FINAL_EXIT_CODE%
