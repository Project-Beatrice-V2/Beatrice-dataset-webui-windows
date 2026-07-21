@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo   VoiceForge Dataset Studio Launcher (Windows)
echo ===================================================
echo.

set "ROOT=%~dp0"
set "BACKEND=%ROOT%voiceforge-backend"
set "FRONTEND=%ROOT%frontend"

if "%VOICEFORGE_PORT%"=="" (
    set "PORT=8001"
) else (
    set "PORT=%VOICEFORGE_PORT%"
)

:: Ensure backend venv exists
if not exist "%BACKEND%\venv\Scripts\activate.bat" (
    echo [ERROR] Virtual environment not found at %BACKEND%\venv
    echo Please run setup.bat first!
    pause
    exit /b 1
)

:: Sync frontend env
echo VITE_API_URL=http://localhost:%PORT% > "%FRONTEND%\.env"
echo VITE_WS_URL=ws://localhost:%PORT% >> "%FRONTEND%\.env"

:: Start Redis if available locally
where redis-server >nul 2>nul
if %errorlevel% equ 0 (
    echo [*] Checking Redis server status...
    where redis-cli >nul 2>nul
    if %errorlevel% equ 0 (
        redis-cli ping >nul 2>nul
        if %errorlevel% neq 0 (
            echo [*] Starting local Redis server...
            start "Redis Server" /min redis-server
            timeout /t 2 /nobreak >nul
        ) else (
            echo [OK] Redis server is already running.
        )
    )
) else (
    echo [NOTE] redis-server not in PATH. Ensure Redis / Memurai service is running for job processing.
)

:: Set PYTHONPATH for backend modules
set "PYTHONPATH=%BACKEND%;%PYTHONPATH%"

echo.
echo [*] Launching Celery ML worker (solo pool)...
start "VoiceForge - Celery Worker" cmd /k "cd /d "%BACKEND%" && call venv\Scripts\activate.bat && celery -A workers.celery_app worker -P solo --loglevel=info"

echo [*] Launching FastAPI backend server on port %PORT%...
start "VoiceForge - FastAPI Server" cmd /k "cd /d "%BACKEND%" && call venv\Scripts\activate.bat && uvicorn main:app --host 0.0.0.0 --port %PORT% --reload --reload-exclude static/* --reload-exclude tmp/* --reload-exclude *.db"

echo [*] Launching React Vite frontend...
start "VoiceForge - React Frontend" cmd /k "cd /d "%FRONTEND%" && npm run dev"

echo.
echo ===================================================
echo   VoiceForge Dataset Studio Started!
echo.
echo   Frontend Web UI: http://localhost:5173
echo   Backend API:     http://localhost:%PORT%
echo   API Docs:        http://localhost:%PORT%/docs
echo ===================================================
echo.
echo Close the process windows to stop the services.
echo.
pause
