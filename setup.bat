@echo off
rem Beatrice Dataset Studio - one-time setup for Windows 10/11 (Command Prompt).
rem Creates the Python venv, installs PyTorch (CUDA build when an NVIDIA GPU is present),
rem the ML stack and the web UI. Re-running it is safe.
rem Notes for editors: keep this file ASCII with CRLF line endings, avoid parentheses inside
rem echo text and never read %errorlevel% inside ( ) blocks - use "if errorlevel" and goto.
setlocal EnableExtensions
chcp 65001 >nul

set "ROOT=%~dp0"
set "BACKEND=%ROOT%voiceforge-backend"
set "FRONTEND=%ROOT%frontend"
set "VPY=%BACKEND%\venv\Scripts\python.exe"
if "%TORCH_CUDA%"=="" set "TORCH_CUDA=cu128"

echo ===================================================
echo   Beatrice Dataset Studio setup - Windows
echo ===================================================
echo.

rem --- 1. Python 3.12 or 3.11 ----------------------------------------------
echo [*] Looking for Python 3.12 or 3.11...
set "PY="
call :try_python py -3.12
if not defined PY call :try_python py -3.11
if not defined PY call :try_python python
if not defined PY goto :no_python
echo [OK] Using:
%PY% --version

rem --- 2. Virtual environment -----------------------------------------------
cd /d "%BACKEND%"
if exist "%VPY%" goto :venv_ready
echo [*] Creating virtual environment...
%PY% -m venv venv
if errorlevel 1 goto :venv_failed
:venv_ready

rem --- 3. Python packages ---------------------------------------------------
echo [*] Upgrading pip, setuptools and wheel...
"%VPY%" -m pip install --upgrade pip setuptools wheel
if errorlevel 1 goto :pip_failed

where nvidia-smi >nul 2>nul
if errorlevel 1 goto :cpu_torch
echo [*] NVIDIA GPU detected: installing the CUDA build of PyTorch - index %TORCH_CUDA%...
"%VPY%" -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/%TORCH_CUDA%
if errorlevel 1 echo [WARNING] The CUDA build of PyTorch could not be installed, continuing with the default build.
goto :requirements
:cpu_torch
echo [INFO] No NVIDIA GPU found: PyTorch will run on the CPU.
:requirements

echo [*] Installing Python requirements - this downloads several GB...
"%VPY%" -m pip install -r requirements.txt
if errorlevel 1 goto :pip_failed
rem resemblyzer pins the source-only webrtcvad; webrtcvad-wheels already provides it.
"%VPY%" -m pip install --no-deps "resemblyzer>=0.1.4"
if errorlevel 1 goto :pip_failed

where nvidia-smi >nul 2>nul
if errorlevel 1 goto :cuda_checked
"%VPY%" -c "import sys, torch; sys.exit(0 if torch.cuda.is_available() else 1)" >nul 2>nul
if not errorlevel 1 goto :cuda_ok
echo [*] Restoring the CUDA build of PyTorch...
"%VPY%" -m pip install --force-reinstall --no-deps torch torchaudio --index-url https://download.pytorch.org/whl/%TORCH_CUDA%
"%VPY%" -c "import sys, torch; sys.exit(0 if torch.cuda.is_available() else 1)" >nul 2>nul
if errorlevel 1 echo [WARNING] PyTorch still cannot see the GPU. Update the NVIDIA driver, or set TORCH_CUDA=cu126 for older cards and run setup.bat again.
goto :cuda_checked
:cuda_ok
echo [OK] PyTorch can use your NVIDIA GPU.
:cuda_checked

rem --- 4. Optional downloads ------------------------------------------------
echo [*] Installing the Playwright Chromium browser - optional...
"%VPY%" -m playwright install chromium >nul 2>nul
if errorlevel 1 echo [INFO] Playwright browser skipped - it is optional.

echo [*] Pre-downloading the Demucs model htdemucs_ft - optional...
"%VPY%" -c "from demucs.pretrained import get_model; get_model('htdemucs_ft'); print('Demucs model ready.')"
if errorlevel 1 echo [INFO] The Demucs model will download on first use instead.

rem --- 5. Folders, settings, database --------------------------------------
if not exist "static\outputs" mkdir "static\outputs"
if not exist "tmp" mkdir "tmp"
if exist ".env" goto :env_ready
copy ".env.example" ".env" >nul
echo [OK] Created voiceforge-backend\.env - add your HF_TOKEN there.
:env_ready

echo [*] Initializing the database...
"%VPY%" -c "from database import init_db; init_db(); print('Database initialized.')"
if errorlevel 1 goto :db_failed

rem --- 6. Web UI ------------------------------------------------------------
echo [*] Installing web UI dependencies...
cd /d "%FRONTEND%"
where npm >nul 2>nul
if errorlevel 1 goto :no_node
call npm install
if errorlevel 1 goto :npm_failed
goto :checks
:no_node
echo [WARNING] Node.js was not found. Install Node.js 22 LTS: winget install OpenJS.NodeJS.LTS
echo           then run setup.bat again.

rem --- 7. Environment checks ------------------------------------------------
:checks
echo.
echo ===================================================
echo   Environment checks
echo ===================================================
where ffmpeg >nul 2>nul
if errorlevel 1 goto :no_ffmpeg
echo [OK] FFmpeg found.
goto :check_redis
:no_ffmpeg
echo [WARNING] FFmpeg not found. Install it with: winget install Gyan.FFmpeg
echo           then open a new terminal so PATH is updated.

:check_redis
"%VPY%" -c "import redis; redis.Redis(socket_connect_timeout=1).ping()" >nul 2>nul
if errorlevel 1 goto :no_redis
echo [OK] A Redis server is running.
goto :done
:no_redis
echo [WARNING] No Redis server is running on localhost:6379. The job queue needs one.
echo           Install Memurai Developer, a Redis-compatible Windows service:
echo           winget install Memurai.MemuraiDeveloper
echo           or run Redis inside WSL: sudo apt install redis-server

:done
echo.
echo ===================================================
echo   Setup complete.
echo   1. Put your Hugging Face token in voiceforge-backend\.env  - HF_TOKEN=...
echo   2. Run start.bat
echo ===================================================
echo.
pause
exit /b 0

rem --- helpers and errors -----------------------------------------------------
:try_python
%* -c "import sys; sys.exit(0 if sys.version_info[:2] in ((3, 11), (3, 12)) else 1)" >nul 2>nul
if not errorlevel 1 set "PY=%*"
exit /b 0

:no_python
echo [ERROR] Python 3.12 or 3.11 was not found.
echo         Install it with: winget install Python.Python.3.12
echo         or from https://www.python.org/downloads/ - tick "Add python.exe to PATH".
pause
exit /b 1

:venv_failed
echo [ERROR] Could not create the virtual environment in %BACKEND%\venv
pause
exit /b 1

:pip_failed
echo [ERROR] Installing Python packages failed. Scroll up for the pip error.
pause
exit /b 1

:db_failed
echo [ERROR] Database initialisation failed. Scroll up for the error.
pause
exit /b 1

:npm_failed
echo [ERROR] npm install failed. Check that Node.js is 20.19 or newer: node --version
pause
exit /b 1
