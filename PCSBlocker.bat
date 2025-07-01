@echo off
setlocal EnableDelayedExpansion

:: ############################################
:: PCSBlocker v0.2.1 - Ultimate DNS AdBlock Utility
:: Corrections: conditional setup, whitelist file creation,
:: update fixes, improved menu header
:: ############################################

:: Config
set "APP_NAME=PCSBlocker"
set "VERSION=0.2.1"
set "INSTALL_DIR=%ProgramFiles%\PCSBlocker_v%VERSION%"
set "SCRIPT_NAME=PCSBlocker.bat"
set "SCRIPT_PATH=%INSTALL_DIR%\%SCRIPT_NAME%"
set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"
set "HOSTS_BACKUP=%HOSTS%.bak"
set "BLOCKLIST_FILE=%INSTALL_DIR%\blocklist.txt"
set "WHITELIST_FILE=%INSTALL_DIR%\whitelist.txt"
set "URL_FILE=%INSTALL_DIR%\blocklists_urls.txt"
set "CACHE_DIR=%INSTALL_DIR%\cache"
set "LOG_DIR=%INSTALL_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\PCSBlocker.log"
set "VERSION_URL=https://raw.githubusercontent.com/pcs666-de/PCSBlocker/main/version.txt"
set "SCRIPT_URL=https://raw.githubusercontent.com/pcs666-de/PCSBlocker/main/PCSBlocker.bat"
set "TASK_NAME=PCSBlocker_Update_Task"

:: Check if core files exist, otherwise run setup
if not exist "%SCRIPT_PATH%" goto setup
if not exist "%URL_FILE%" goto setup
if not exist "%WHITELIST_FILE%" goto setup

:main
cls

echo +------------------------------------------+
echo ^|          %APP_NAME% v%VERSION%            ^|
echo +------------------------------------------+
echo 1) Activate AdBlocker
 echo 2) Deactivate AdBlocker
 echo 3) Edit Blocklist / Whitelist
 echo 4) Check & Install Updates
 echo 5) View Logs
 echo 6) Show Storage Path
 echo 7) Whitelist Mode Toggle
 echo 8) Flush DNS Cache
 echo 9) Uninstall
 echo 0) Exit

echo.
set /p choice="Select [0-9]: "
for %%I in (0 1 2 3 4 5 6 7 8 9) do if "!choice!"=="%%I" goto option%%I
echo Invalid selection! & timeout /t 1 >nul & goto main

:option1
 call :backupHosts
 call :downloadBlocklists
 call :mergeLists
 call :applyBlockList
 call :log "Activated"
 echo Activated! & call :flushDNS & timeout /t 1 >nul & goto main

:option2
 call :restoreHosts
 call :log "Deactivated"
 echo Deactivated! & call :flushDNS & timeout /t 1 >nul & goto main

:option3
 cls
 echo 1) Edit Blocklist
 echo 2) Edit Whitelist
 echo 3) Switch Whitelist Mode
 set /p sub="Choose [1-3]: "
 if "%sub%"=="1" (notepad "%BLOCKLIST_FILE%" & call :log "Blocklist Edited")
 if "%sub%"=="2" (notepad "%WHITELIST_FILE%" & call :log "Whitelist Edited")
 if "%sub%"=="3" call :toggleWhitelistMode
 goto main

:option4
 call :checkUpdate
 echo Updating lists...
 call :downloadBlocklists
 call :mergeLists
 call :log "Lists Refreshed"
 echo Complete & timeout /t 1 >nul & goto main

:option5
 cls
 echo ==== Logs ====
 type "%LOG_FILE%" 2>nul || echo No logs.
 echo ============
 pause>nul & goto main

:option6
 cls
 echo Storage: %INSTALL_DIR%
 echo Cache  : %CACHE_DIR%
 echo Logs   : %LOG_DIR%
 echo Hosts  : %HOSTS%
 echo White  : %WHITELIST_FILE%
 pause>nul & goto main

:option7
 call :toggleWhitelistMode
 goto main

:option8
 call :flushDNS
 echo Done! & timeout /t 1 >nul & goto main

:option9
 call :restoreHosts
 schtasks /delete /tn "%TASK_NAME%" /f >nul
 rd /s /q "%INSTALL_DIR%"
 call :log "Uninstalled"
 echo Uninstalled.& exit /b

:option0
 exit /b

:setup
 md "%INSTALL_DIR%" 2>nul
 md "%CACHE_DIR%" 2>nul
 md "%LOG_DIR%" 2>nul

 :: create URL file
 > "%URL_FILE%" (
  echo https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
  echo https://raw.githubusercontent.com/AdAway/adaway.github.io/master/hosts.txt
  echo https://hosts-file.net/ad_servers.txt
 )

 :: create empty whitelist
 if not exist "%WHITELIST_FILE%" echo # whitelist > "%WHITELIST_FILE%"

 call :showProgress "Setting up" 30
 call :downloadBlocklists
 call :mergeLists
 call :backupHosts
 schtasks /create /tn "%TASK_NAME%" /tr "\"%SCRIPT_PATH%\" --setup" /sc daily /st 03:00 /f >nul
 call :log "Setup Completed"
 echo Setup Done! & pause>nul & goto main

:: Functions
:showProgress
 <nul set /p="%~1: ["
 for /L %%i in (1,1,%~2) do (<nul set /p=# & ping -n 1 127.0.0.1>nul)
 echo ]
 goto :eof

:backupHosts
 if not exist "%HOSTS_BACKUP%" (
  takeown /f "%HOSTS%">nul
  icacls "%HOSTS%" /grant Administrators:F>nul
  attrib -r "%HOSTS%"
  copy "%HOSTS%" "%HOSTS_BACKUP%">nul
 )
 goto :eof

:restoreHosts
 if exist "%HOSTS_BACKUP%" (
  takeown /f "%HOSTS%">nul
  icacls "%HOSTS%" /grant Administrators:F>nul
  attrib -r "%HOSTS%"
  copy /Y "%HOSTS_BACKUP%" "%HOSTS%">nul
 )
 goto :eof

:downloadBlocklists
 del "%CACHE_DIR%\*.tmp" >nul 2>&1
 for /F "usebackq delims=" %%U in ("%URL_FILE%") do (
  powershell -noprofile -command "try{(New-Object Net.WebClient).DownloadString('%%U')}catch{exit 0}" > "%CACHE_DIR%\%%~nU.tmp"
 )
 goto :eof

:mergeLists
 (
  for %%F in ("%CACHE_DIR%\*.tmp") do type "%%F"|findstr /B "0.0.0.0"
  for /f "usebackq delims=" %%W in ("%WHITELIST_FILE%") do echo 127.0.0.1 %%W
 )> "%BLOCKLIST_FILE%"
 goto :eof

:toggleWhitelistMode
 set /p mode="Whitelist only? [Y/N]: "
 if /I "%mode%"=="Y" (set "MERGE_CMD=for %%F in (\"%CACHE_DIR%\\*.tmp\") do type \"%%F\"^|findstr /B \"0.0.0.0\"^&for /f \"usebackq delims=\" %%W in (\"%WHITELIST_FILE%\") do echo 127.0.0.1 %%W")
 if /I "%mode%"=="N" (set "MERGE_CMD=for %%F in (\"%CACHE_DIR%\\*.tmp\") do type \"%%F\"^|findstr /B \"0.0.0.0\"")
 echo Whitelist mode set.& call :log "Whitelist set to %mode%"
 goto :eof

:applyBlockList
 takeown /f "%HOSTS%">nul
 icacls "%HOSTS%" /grant Administrators:F>nul
 attrib -r "%HOSTS%"
 (echo # %APP_NAME% Hosts v%VERSION%)> "%HOSTS%"
 cmd /c "%MERGE_CMD% >> "%BLOCKLIST_FILE%""
 type "%BLOCKLIST_FILE%" >> "%HOSTS%"
 goto :eof

:flushDNS
 ipconfig /flushdns>nul
 goto :eof

:checkUpdate
 set "remoteVer="
 for /f %%A in ('powershell -noprofile -command "(New-Object Net.WebClient).DownloadString('%VERSION_URL%')).Trim()"') do set "remoteVer=%%A"
 if not defined remoteVer (echo Check failed & goto :eof)
 echo Local: %VERSION% Remote: !remoteVer!
 if not "!remoteVer!"=="%VERSION%" (set /p up="Update? [Y/N]: " & if /I "%up%"=="Y" (powershell -noprofile -command "(New-Object Net.WebClient).DownloadFile('%SCRIPT_URL%','%SCRIPT_PATH%')" & echo Updated!&timeout /t 1>nul & start "" "%SCRIPT_PATH%" & exit /b))
 goto :eof

:log
 echo [%DATE% %TIME%] %~1>> "%LOG_FILE%"
 exit /b
