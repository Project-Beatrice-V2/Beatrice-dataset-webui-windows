# VoiceForge Dataset Studio Launcher (PowerShell - Windows)

$ROOT = $PSScriptRoot
$BACKEND = Join-Path $ROOT "voiceforge-backend"
$FRONTEND = Join-Path $ROOT "frontend"

$PORT = if ($env:VOICEFORGE_PORT) { $env:VOICEFORGE_PORT } else { "8001" }

$VenvDir = Join-Path $BACKEND "venv"
if (-not (Test-Path $VenvDir)) {
    Write-Error "Virtual environment not found at $VenvDir. Please run .\setup.ps1 first!"
    exit 1
}

# Sync frontend environment file
Set-Content -Path (Join-Path $FRONTEND ".env") -Value "VITE_API_URL=http://localhost:$PORT`nVITE_WS_URL=ws://localhost:$PORT"

# Check Redis
$RedisCli = Get-Command redis-cli -ErrorAction SilentlyContinue
if ($RedisCli) {
    $Ping = redis-cli ping 2>$null
    if ($Ping -ne "PONG") {
        $RedisServer = Get-Command redis-server -ErrorAction SilentlyContinue
        if ($RedisServer) {
            Write-Host "[*] Starting local Redis server..." -ForegroundColor Yellow
            Start-Process -FilePath "redis-server" -WindowStyle Hidden
            Start-Sleep -Seconds 2
        }
    } else {
        Write-Host "[OK] Redis is running." -ForegroundColor Green
    }
}

$env:PYTHONPATH = "$BACKEND;$env:PYTHONPATH"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Launching VoiceForge Dataset Studio (Windows)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[*] Starting Celery ML Worker (solo pool)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$BACKEND'; .\venv\Scripts\Activate.ps1; celery -A workers.celery_app worker -P solo --loglevel=info"

Write-Host "[*] Starting FastAPI Server on port $PORT..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$BACKEND'; .\venv\Scripts\Activate.ps1; uvicorn main:app --host 0.0.0.0 --port $PORT --reload --reload-exclude 'static/*' --reload-exclude 'tmp/*' --reload-exclude '*.db'"

Write-Host "[*] Starting React Frontend..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$FRONTEND'; npm run dev"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host "  VoiceForge Dataset Studio Running!" -ForegroundColor Green
Write-Host "  Frontend: http://localhost:5173" -ForegroundColor Green
Write-Host "  API:      http://localhost:$PORT" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
