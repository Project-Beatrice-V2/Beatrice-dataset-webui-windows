# Beatrice Dataset Studio - starts the job worker, the FastAPI backend and the web UI,
# each in its own window. Close those windows to stop the services.
#   powershell -ExecutionPolicy Bypass -File .\start.ps1

$ErrorActionPreference = 'Continue'

$Root = $PSScriptRoot
$Backend = Join-Path $Root 'voiceforge-backend'
$Frontend = Join-Path $Root 'frontend'
$VPy = Join-Path $Backend 'venv\Scripts\python.exe'
$Port = if ($env:VOICEFORGE_PORT) { $env:VOICEFORGE_PORT } else { '8001' }
# The API has no authentication, so it only listens on this computer by default.
$HostAddr = if ($env:VOICEFORGE_HOST) { $env:VOICEFORGE_HOST } else { '127.0.0.1' }

if (-not (Test-Path $VPy)) {
    Write-Host '[ERROR] The Python environment is missing. Run setup.ps1 first.' -ForegroundColor Red
    exit 1
}
if (-not (Test-Path (Join-Path $Frontend 'node_modules'))) {
    Write-Host '[ERROR] The web UI dependencies are missing. Run setup.ps1 first.' -ForegroundColor Red
    exit 1
}

# The web UI proxies /api and /ws to the backend on this port (inherited by the child windows).
$env:VOICEFORGE_PORT = $Port
$env:PYTHONPATH = $Backend
Set-Content -Path (Join-Path $Frontend '.env') -Value "VOICEFORGE_PORT=$Port" -Encoding ASCII

# Redis (any Redis-compatible server, e.g. the Memurai service)
& $VPy -c 'import redis; redis.Redis(socket_connect_timeout=1).ping()' *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host '[OK] Redis is running.' -ForegroundColor Green
} elseif (Get-Command redis-server -ErrorAction SilentlyContinue) {
    Write-Host '[*] Starting redis-server...' -ForegroundColor Yellow
    Start-Process -FilePath 'redis-server' -WindowStyle Minimized
    Start-Sleep -Seconds 2
} else {
    Write-Warning 'No Redis server is running, so dataset jobs will not start. Start the Memurai service or run: winget install Memurai.MemuraiDeveloper'
}

Write-Host '===================================================' -ForegroundColor Cyan
Write-Host '  Beatrice Dataset Studio - Windows' -ForegroundColor Cyan
Write-Host '===================================================' -ForegroundColor Cyan

# The venv's python.exe is started directly: no Activate.ps1, so no execution-policy prompt
# in the child windows.
Write-Host '[*] Starting the job worker (Celery, solo pool)...' -ForegroundColor Yellow
Start-Process -FilePath $VPy -WorkingDirectory $Backend -ArgumentList @('-m', 'celery', '-A', 'workers.celery_app', 'worker', '-P', 'solo', '--loglevel=info')

Write-Host "[*] Starting the API on ${HostAddr}:$Port..." -ForegroundColor Yellow
Start-Process -FilePath $VPy -WorkingDirectory $Backend -ArgumentList @('-m', 'uvicorn', 'main:app', '--host', $HostAddr, '--port', $Port)

Write-Host '[*] Starting the web UI...' -ForegroundColor Yellow
Start-Process -FilePath 'cmd.exe' -WorkingDirectory $Frontend -ArgumentList @('/k', 'npm run dev')

Write-Host ''
Write-Host '  Web UI:    http://localhost:5173' -ForegroundColor Green
Write-Host "  API:       http://localhost:$Port" -ForegroundColor Green
Write-Host "  API docs:  http://localhost:$Port/docs" -ForegroundColor Green
Write-Host 'Close the three service windows to stop everything.'
Start-Sleep -Seconds 5
Start-Process 'http://localhost:5173'
