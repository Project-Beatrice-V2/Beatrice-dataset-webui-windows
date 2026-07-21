@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo   VoiceForge Dataset Studio Setup (Windows)
echo ===================================================
echo.

set "ROOT=%~dp0"
set "BACKEND=%ROOT%voiceforge-backend"
set "FRONTEND=%ROOT%frontend"

cd /d "%BACKEND%"

:: 1. Check Python
echo [*] Checking Python environment...
set "PYTHON=python"

where python >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Python not found in PATH!
    echo Please install Python 3.11 or 3.12 from https://www.python.org/
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"') do set PY_VER=%%v
echo Using Python %PY_VER%

:: 2. Virtual Environment
if not exist "venv" (
    echo [*] Creating virtual environment...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to create venv.
        pause
        exit /b 1
    )
)

echo [*] Activating virtual environment...
call venv\Scripts\activate.bat

:: 3. Dependencies
echo [*] Upgrading pip, setuptools, wheel...
python -m pip install --upgrade pip setuptools wheel

echo [*] Installing Python requirements...
pip install -r requirements.txt

:: Check NVIDIA CUDA GPU availability
where nvidia-smi >nul 2>nul
if %errorlevel% equ 0 (
    echo [*] NVIDIA GPU detected via nvidia-smi.
    echo [*] Verifying PyTorch CUDA support...
    python -c "import torch; exit(0 if torch.cuda.is_available() else 1)" >nul 2>nul
    if %errorlevel% neq 0 (
        echo [*] Installing PyTorch with CUDA 12.1 acceleration...
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    ) else (
        echo [OK] PyTorch CUDA support is already enabled.
    )
) else (
    echo [INFO] No NVIDIA GPU detected. PyTorch will run in CPU mode.
)

:: 4. Playwright Browser
echo [*] Installing Playwright Chromium browser...
playwright install chromium 2>nul

:: 5. Demucs ML model
echo [*] Pre-downloading Demucs model (htdemucs_ft)...
python -c "try: from demucs.pretrained import get_model; get_model('htdemucs_ft'); print('Demucs model ready.'); except Exception as e: print('Demucs download note:', e)" 2>nul

:: 6. Database Initialization
echo [*] Initializing SQLite database...
python -c "from database import init_db; init_db(); print('Database initialized successfully.')"

if not exist "static\outputs" mkdir static\outputs
if not exist "tmp" mkdir tmp

if not exist ".env" (
    if exist ".env.example" (
        copy .env.example .env >nul
        echo [OK] Created .env from .env.example
    )
)

:: 7. Frontend Setup
echo [*] Setting up React Frontend...
cd /d "%FRONTEND%"
where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] Node.js / npm not found in PATH!
    echo Please install Node.js 18+ from https://nodejs.org/
) else (
    echo [*] Installing npm dependencies...
    call npm install
)

:: 8. Dependency Check Summary
echo.
echo ===================================================
echo   Environment Checks ^& Recommendations
echo ===================================================
where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] FFmpeg was not found in your PATH.
    echo           Audio conversion features require FFmpeg.
    echo           Install via Winget: winget install Gyan.FFmpeg
) else (
    echo [OK] FFmpeg found in PATH.
)

where redis-server >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] Redis server was not found.
    echo           Dataset processing queue requires Redis.
    echo           Install Memurai for Windows: https://www.memurai.com/
    echo           Or Redis for Windows: winget install Redis-Windows.Redis-Windows
) else (
    echo [OK] Redis found in PATH.
)

echo.
echo ===================================================
echo   Setup Complete!
echo   Run start.bat to launch VoiceForge Dataset Studio
echo ===================================================
echo.
pause
