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

call :LOG "cmd: Skript spusten. Uzivatel: %USERNAME%, Argumenty: %*"

:: Spusteni hlavniho toku
if "%~1"=="SKIP_SELF_UPDATE" goto :RUN_MAIN
:: V debug rezimu preskocime self-update, abychom neprepysali testovany kod remote verzi
if "%DEBUG_MODE%"=="1" (
    call :LOG "cmd: Debug rezim aktivni. Preskakuji self-update."
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
echo # %~1
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
    "if ($env:DEBUG_MODE -eq '1') { $Shortcut.Arguments = '-debug' };" ^
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

:EXIT_SCRIPT
call :LOG "cmd: Skript dokoncen s navratovym kodem: %FINAL_EXIT_CODE%"
exit /b %FINAL_EXIT_CODE%
