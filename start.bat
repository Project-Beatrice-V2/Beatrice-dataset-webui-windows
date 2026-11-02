@echo off
rem Beatrice Dataset Studio - starts the job worker, the FastAPI backend and the web UI,
rem each in its own window. Close those windows to stop the services.
rem Keep this file ASCII with CRLF line endings; no %errorlevel% inside ( ) blocks.
setlocal EnableExtensions
chcp 65001 >nul

set "ROOT=%~dp0"
set "BACKEND=%ROOT%voiceforge-backend"
set "FRONTEND=%ROOT%frontend"
set "VPY=%BACKEND%\venv\Scripts\python.exe"
if "%VOICEFORGE_PORT%"=="" set "VOICEFORGE_PORT=8001"
rem The API has no authentication, so it only listens on this computer by default.
if "%VOICEFORGE_HOST%"=="" set "VOICEFORGE_HOST=127.0.0.1"

echo ===================================================
echo   Beatrice Dataset Studio - Windows
echo ===================================================
echo.

if not exist "%VPY%" goto :no_venv
if not exist "%FRONTEND%\node_modules" goto :no_node_modules

rem The web UI proxies /api and /ws to the backend on this port.
> "%FRONTEND%\.env" echo VOICEFORGE_PORT=%VOICEFORGE_PORT%

rem --- Redis --------------------------------------------------------------------
"%VPY%" -c "import redis; redis.Redis(socket_connect_timeout=1).ping()" >nul 2>nul
if not errorlevel 1 goto :redis_ok
where redis-server >nul 2>nul
if errorlevel 1 goto :redis_missing
echo [*] Starting redis-server...
start "Redis" /min redis-server
timeout /t 2 /nobreak >nul
goto :redis_done
:redis_missing
echo [WARNING] No Redis server is running, so dataset jobs will not start.
echo           Start the Memurai service, or install it: winget install Memurai.MemuraiDeveloper
goto :redis_done
:redis_ok
echo [OK] Redis is running.
:redis_done

set "PYTHONPATH=%BACKEND%"

echo [*] Starting the job worker - Celery, solo pool...
start "Dataset Studio - worker" /D "%BACKEND%" cmd /k ""%VPY%" -m celery -A workers.celery_app worker -P solo --loglevel=info"

echo [*] Starting the API on %VOICEFORGE_HOST%:%VOICEFORGE_PORT%...
start "Dataset Studio - API" /D "%BACKEND%" cmd /k ""%VPY%" -m uvicorn main:app --host %VOICEFORGE_HOST% --port %VOICEFORGE_PORT%"

echo [*] Starting the web UI...
start "Dataset Studio - web UI" /D "%FRONTEND%" cmd /k "npm run dev"

echo.
echo ===================================================
echo   Web UI:    http://localhost:5173
echo   API:       http://localhost:%VOICEFORGE_PORT%
echo   API docs:  http://localhost:%VOICEFORGE_PORT%/docs
echo ===================================================
echo Close the three service windows to stop everything.
echo.
timeout /t 5 /nobreak >nul
start "" http://localhost:5173
exit /b 0

:no_venv
echo [ERROR] The Python environment is missing. Run setup.bat first.
pause
exit /b 1

:no_node_modules
echo [ERROR] The web UI dependencies are missing. Run setup.bat first.
pause
exit /b 1
