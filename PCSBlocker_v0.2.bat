@echo off
setlocal EnableDelayedExpansion
set "APP_NAME=PCSBlocker"
set "VERSION=0.2"
set "INSTALL_DIR=%ProgramFiles%\PCSBlocker_v0.2"
set "SCRIPT_NAME=PCSBlocker_v0.2.bat"
set "SCRIPT_PATH=%INSTALL_DIR%\%SCRIPT_NAME%"
set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"
set "HOSTS_BACKUP=%HOSTS%.bak"
set "LOG_FILE=%INSTALL_DIR%\PCSBlocker.log"
set "BLOCKLIST_URL=https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
set "VERSION_URL=https://raw.githubusercontent.com/pcs666-de/PCSBlocker/main/version.txt"
set "SCRIPT_URL=https://raw.githubusercontent.com/pcs666-de/PCSBlocker/main/PCSBlocker_v0.2.bat"
set "TASK_NAME=PCSBlocker_Update_Task"

if /I "%~f0" NEQ "%SCRIPT_PATH%" (
    if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
    copy /Y "%~f0" "%SCRIPT_PATH%" >nul
    start "" "%SCRIPT_PATH%"
    exit /b
)

:main
echo ==========================================
echo        %APP_NAME% v%VERSION% Hauptmenü
echo ==========================================
echo 1. Aktivieren
echo 2. Deaktivieren
echo 3. Backup wiederherstellen
echo 4. Blockliste aktualisieren
echo 5. Auf Update prüfen
echo 6. Update-Task einrichten
echo 7. Logs anzeigen
echo 8. Deinstallieren
echo 9. Beenden
set /p choice="Wahl [1-9]: "
for %%i in (1 2 3 4 5 6 7 8 9) do if "%choice%"=="%%i" goto option%%i
echo Ungueltige Auswahl.& goto main

:option1
call :backupHosts
call :updateBlocklist
call :applyBlockList
call :log "Aktiviert"
echo Aktiviert.& pause>nul & goto main

:option2
call :restoreHosts
call :log "Deaktiviert"
echo Deaktiviert.& pause>nul & goto main

:option3
call :restoreHosts
call :log "Backup wiederhergestellt"
echo Wiederhergestellt.& pause>nul & goto main

:option4
call :updateBlocklist
call :log "Blockliste aktualisiert"
echo Aktualisiert.& pause>nul & goto main

:option5
call :checkUpdate
pause>nul & goto main

:option6
schtasks /create /tn "%TASK_NAME%" /tr "\"%SCRIPT_PATH%\" 5" /sc daily /st 03:00 /f>nul
call :log "Task erstellt"
echo Task eingerichtet.& pause>nul & goto main

:option7
type "%LOG_FILE%" 2>nul || echo Keine Logs.& pause>nul & goto main

:option8
call :restoreHosts
schtasks /delete /tn "%TASK_NAME%" /f>nul
rmdir /s /q "%INSTALL_DIR%"
call :log "Deinstalliert"
echo Deinstalliert.& exit /b

:option9
exit /b

:backupHosts
if not exist "%HOSTS_BACKUP%" copy "%HOSTS%" "%HOSTS_BACKUP%">nul
goto :eof

:restoreHosts
if exist "%HOSTS_BACKUP%" copy /Y "%HOSTS_BACKUP%" "%HOSTS%">nul
goto :eof

:updateBlocklist
powershell -noprofile -command "try{(New-Object Net.WebClient).DownloadFile('%BLOCKLIST_URL%','%INSTALL_DIR%\hosts_full.txt')}catch{exit 1}"
if errorlevel 1 (
    echo Blocklist-Download fehlgeschlagen.& exit /b
)
findstr /R "^0\.0\.0\.0" "%INSTALL_DIR%\hosts_full.txt" > "%INSTALL_DIR%\blocklist.txt"
goto :eof

:applyBlockList
(echo # %APP_NAME% Hosts v%VERSION%) > "%HOSTS%"
for /f "tokens=1,2" %%A in ('findstr /B "0.0.0.0" "%INSTALL_DIR%\blocklist.txt"') do echo %%A %%B>>"%HOSTS%"
goto :eof

:checkUpdate
for /f %%v in ('powershell -noprofile -command "try{(New-Object Net.WebClient).DownloadString('%VERSION_URL%')}catch{exit 1}"') do set "remoteVer=%%v"
if not defined remoteVer (
    echo Versionsabfrage fehlgeschlagen.& exit /b
)
echo Lokale Version: %VERSION%
echo Verfuegbare Version: %remoteVer%
if "%remoteVer%" NEQ "%VERSION%" (
    echo Update verfuegbar! [J/N]?
    set /p up=
    if /I "%up%"=="J" (
        powershell -noprofile -command "(New-Object Net.WebClient).DownloadFile('%SCRIPT_URL%','%SCRIPT_PATH%')"
        echo Update installiert. Starte neu.& timeout /t 2>nul
        start "" "%SCRIPT_PATH%"
        exit /b
    )
) else echo Keine Updates gefunden.
goto :eof

:log
echo [%DATE% %TIME%] %~1>>"%LOG_FILE%"
exit /b
