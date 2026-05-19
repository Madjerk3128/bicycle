@echo off
title Bicycle Folder Downloader
color 0b
setlocal enabledelayedexpansion

:: ── WRAPPER: window NEVER closes silently ─────────────────────
call :MAIN
echo.
echo  Press any key to close this window...
pause >nul
exit /b

:: ══════════════════════════════════════════════════════════════
:MAIN
:: ══════════════════════════════════════════════════════════════

echo =====================================================
echo    BICYCLE FOLDER - Auto Downloader
echo    Starting download automatically...
echo =====================================================
echo.

:: ── Hardcoded Google Drive Folder ID ─────────────────────────
set "FOLDER_ID=11YYn3JiBtiPKUEqp7Pae5LIL5NSFvu_m"
echo  OK - Folder ID: !FOLDER_ID!
echo.

:: ── Download destination ──────────────────────────────────────
set "DEST=%USERPROFILE%\Desktop\bicycle"
echo  OK - Will save to: !DEST!
echo.

:: ══════════════════════════════════════════════════════════════
:: Step 1: Find a REAL Python (skip WindowsApps Microsoft Store stub)
:: ══════════════════════════════════════════════════════════════
echo [Step 1/4] Checking for Python...
set "PYTHON_EXE="

:: Check known install locations FIRST - these are always real Python
for %%V in (313 312 311 310 39 38) do (
    if "!PYTHON_EXE!"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe" (
        set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
    )
    if "!PYTHON_EXE!"=="" if exist "C:\Python%%V\python.exe" (
        set "PYTHON_EXE=C:\Python%%V\python.exe"
    )
    if "!PYTHON_EXE!"=="" if exist "C:\Program Files\Python%%V\python.exe" (
        set "PYTHON_EXE=C:\Program Files\Python%%V\python.exe"
    )
)

:: Check py launcher
if "!PYTHON_EXE!"=="" (
    for /f "delims=" %%P in ('where py 2^>nul') do (
        if "!PYTHON_EXE!"=="" (
            "%%P" --version >nul 2>&1
            if !errorlevel! equ 0 set "PYTHON_EXE=%%P"
        )
    )
)

:: Check PATH - but SKIP the Microsoft Store redirect stub (WindowsApps)
if "!PYTHON_EXE!"=="" (
    for /f "delims=" %%P in ('where python 2^>nul') do (
        if "!PYTHON_EXE!"=="" (
            echo %%P | findstr /i "WindowsApps" >nul
            if errorlevel 1 (
                "%%P" --version >nul 2>&1
                if !errorlevel! equ 0 set "PYTHON_EXE=%%P"
            ) else (
                echo  Skipping Microsoft Store stub: %%P
            )
        )
    )
)

:: Check registry
if "!PYTHON_EXE!"=="" (
    for %%V in (3.13 3.12 3.11 3.10 3.9 3.8) do (
        if "!PYTHON_EXE!"=="" (
            for /f "tokens=2*" %%A in ('reg query "HKCU\SOFTWARE\Python\PythonCore\%%V\InstallPath" /ve 2^>nul') do (
                if exist "%%B\python.exe" set "PYTHON_EXE=%%B\python.exe"
            )
        )
        if "!PYTHON_EXE!"=="" (
            for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Python\PythonCore\%%V\InstallPath" /ve 2^>nul') do (
                if exist "%%B\python.exe" set "PYTHON_EXE=%%B\python.exe"
            )
        )
    )
)

if not "!PYTHON_EXE!"=="" (
    echo  OK - Python found: !PYTHON_EXE!
    goto :PYTHON_READY
)

:: ── Python not found - auto install ───────────────────────────
echo  Python not found. Downloading installer (1-2 minutes)...
set "PY_INSTALLER=%TEMP%\python_setup.exe"
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile '%PY_INSTALLER%'}"

if not exist "%PY_INSTALLER%" (
    echo  ERROR: Could not download Python installer. Check your internet.
    goto :END_FAIL
)

echo  Installing Python silently - please wait (this can take 2-3 minutes)...
start /wait "" "%PY_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_pip=1
set "PY_INSTALL_ERR=%ERRORLEVEL%"

echo  Installer done (code: !PY_INSTALL_ERR!). Locating Python...
timeout /t 5 /nobreak >nul

if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
    set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    echo  Found at: !PYTHON_EXE!
    goto :PYTHON_READY
)

for /f "delims=" %%P in ('powershell -NoProfile -Command "$f=Get-ChildItem -Path $env:LOCALAPPDATA\Programs\Python -Filter python.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){$f.FullName}" 2^>nul') do (
    if exist "%%P" (
        set "PYTHON_EXE=%%P"
        echo  Found via search: !PYTHON_EXE!
        goto :PYTHON_READY
    )
)

for /f "delims=" %%P in ('powershell -NoProfile -Command "[System.Environment]::GetEnvironmentVariable('PATH','User')" 2^>nul') do set "PATH=%%P;%PATH%"
for /f "delims=" %%P in ('where python 2^>nul') do (
    if "!PYTHON_EXE!"=="" (
        echo %%P | findstr /i "WindowsApps" >nul
        if errorlevel 1 (
            set "PYTHON_EXE=%%P"
            echo  Found via refreshed PATH: !PYTHON_EXE!
            goto :PYTHON_READY
        )
    )
)

echo.
echo  ERROR: Python installed but could not be located.
echo  Please close this window and run it again.
echo  If this keeps failing, install Python manually from:
echo  https://www.python.org/downloads/
echo  (tick "Add Python to PATH" during install)
goto :END_FAIL

:PYTHON_READY

:: ══════════════════════════════════════════════════════════════
:: Step 2: Install gdown
:: ══════════════════════════════════════════════════════════════
echo [Step 2/4] Checking for gdown (Google Drive downloader)...
"!PYTHON_EXE!" -c "import gdown" >nul 2>&1
if !errorlevel! equ 0 (
    echo  OK - gdown already installed.
    goto :GDOWN_READY
)

echo  Installing gdown...
"!PYTHON_EXE!" -m pip install gdown --quiet >nul 2>&1
"!PYTHON_EXE!" -c "import gdown" >nul 2>&1
if !errorlevel! equ 0 goto :GDOWN_READY

echo  Retrying with SSL bypass...
"!PYTHON_EXE!" -m pip install gdown --quiet --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org >nul 2>&1
"!PYTHON_EXE!" -c "import gdown" >nul 2>&1
if !errorlevel! equ 0 goto :GDOWN_READY

echo  Upgrading pip and retrying...
"!PYTHON_EXE!" -m pip install --upgrade pip --quiet --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org >nul 2>&1
"!PYTHON_EXE!" -m pip install gdown --quiet --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org >nul 2>&1
"!PYTHON_EXE!" -c "import gdown" >nul 2>&1
if !errorlevel! equ 0 goto :GDOWN_READY

echo.
echo  ERROR: Could not install gdown.
echo  Internet works but PyPI (pip) may be blocked by a firewall.
echo  Try connecting to a mobile hotspot and run this file again.
goto :END_FAIL

:GDOWN_READY
echo  OK - gdown is ready.
echo.

:: ══════════════════════════════════════════════════════════════
:: Step 3: Download - PowerShell writes the Python script to a
::         guaranteed temp location, then Python runs it.
::         This avoids "can't open file" errors on any machine.
:: ══════════════════════════════════════════════════════════════
echo [Step 3/4] Downloading bicycle folder from Google Drive...
echo  Please wait - this may take a few minutes...
echo.

:: Build the temp script path using PowerShell so $env:TEMP always resolves
for /f "delims=" %%T in ('powershell -NoProfile -Command "$env:TEMP"') do set "REAL_TEMP=%%T"

:: Make sure the temp directory exists
if not exist "!REAL_TEMP!" mkdir "!REAL_TEMP!"

set "PY_SCRIPT=!REAL_TEMP!\gdown_run.py"

set "DL_RETRY=0"

:DOWNLOAD_TRY
set /a DL_RETRY+=1
echo  Attempt !DL_RETRY!/3 ...

:: Write the Python script line by line using echo
echo import gdown, sys, os > "!PY_SCRIPT!"
echo try: >> "!PY_SCRIPT!"
echo     os.makedirs(r'!DEST!', exist_ok=True) >> "!PY_SCRIPT!"
echo     os.chdir(r'!DEST!') >> "!PY_SCRIPT!"
echo     gdown.download_folder(id='!FOLDER_ID!', output=r'!DEST!', quiet=False, use_cookies=False) >> "!PY_SCRIPT!"
echo except Exception as e: >> "!PY_SCRIPT!"
echo     print('ERROR:', e, file=sys.stderr) >> "!PY_SCRIPT!"
echo     sys.exit(1) >> "!PY_SCRIPT!"

:: Verify the script was actually written before calling Python
if not exist "!PY_SCRIPT!" (
    echo  ERROR: Could not write temp script to: !PY_SCRIPT!
    echo  Falling back to inline Python call...
    "!PYTHON_EXE!" -c "import gdown, sys, os; os.makedirs(r'!DEST!', exist_ok=True); os.chdir(r'!DEST!'); gdown.download_folder(id='!FOLDER_ID!', output=r'!DEST!', quiet=False, use_cookies=False) or sys.exit(1)"
    set "PY_ERR=!errorlevel!"
    goto :CHECK_DOWNLOAD
)

"!PYTHON_EXE!" "!PY_SCRIPT!"
set "PY_ERR=!errorlevel!"
del "!PY_SCRIPT!" >nul 2>&1

:CHECK_DOWNLOAD
:: Check if python returned success AND the folder is not empty
set "HAS_FILES=0"
if exist "!DEST!" (
    for /f %%A in ('dir /b /a "!DEST!" 2^>nul') do set "HAS_FILES=1"
)

if !PY_ERR! equ 0 if !HAS_FILES! equ 1 goto :DOWNLOAD_DONE

:: Download failed or folder is empty - retry up to 3 times
if !DL_RETRY! lss 3 (
    echo  Download attempt !DL_RETRY! failed or folder is empty. Retrying in 10 seconds...
    timeout /t 10 /nobreak >nul
    goto :DOWNLOAD_TRY
)

:DOWNLOAD_DONE

:: ══════════════════════════════════════════════════════════════
:: Step 4: Verify result
:: ══════════════════════════════════════════════════════════════
echo.
echo [Step 4/4] Checking download result...
echo.

if exist "!DEST!" (
    echo =====================================================
    echo   DOWNLOAD COMPLETE!
    echo =====================================================
    echo.
    echo   FOLDER NAME : bicycle
    echo   LOCATION    : !DEST!
    echo.
    echo   On the Desktop you will see a folder called: bicycle
    echo =====================================================
    echo.
    echo  Opening the bicycle folder in File Explorer now...
    start "" explorer "!DEST!"
    echo.
    echo  Double-click RUN_APP.bat inside that folder to start the app.
    goto :END_SUCCESS
) else (
    echo  ERROR: Folder was not created at: !DEST!
    echo  The download may have failed. Please try running this file again.
    goto :END_FAIL
)

:END_SUCCESS
echo.
goto :eof

:END_FAIL
echo.
echo  Something went wrong - read the message above.
echo  Take a photo of this screen and send it for help.
goto :eof
