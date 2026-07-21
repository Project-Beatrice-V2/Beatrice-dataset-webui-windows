# VoiceForge Dataset Studio Setup (PowerShell - Windows)

$ErrorActionPreference = "Stop"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  VoiceForge Dataset Studio Setup (Windows PS)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

$ROOT = $PSScriptRoot
$BACKEND = Join-Path $ROOT "voiceforge-backend"
$FRONTEND = Join-Path $ROOT "frontend"

Set-Location $BACKEND

# 1. Python Check
Write-Host "[*] Checking Python environment..." -ForegroundColor Yellow
$PythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $PythonCmd) {
    Write-Error "Python not found in PATH. Please install Python 3.11 or 3.12 from https://www.python.org/"
}

$PyVer = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
Write-Host "Using Python $PyVer" -ForegroundColor Green

# 2. Virtual Environment
$VenvDir = Join-Path $BACKEND "venv"
if (-not (Test-Path $VenvDir)) {
    Write-Host "[*] Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

$VenvActivate = Join-Path $VenvDir "Scripts\Activate.ps1"
if (Test-Path $VenvActivate) {
    & $VenvActivate
} else {
    $env:PATH = "$(Join-Path $VenvDir 'Scripts');$env:PATH"
}

# 3. Dependencies
Write-Host "[*] Upgrading pip, setuptools, wheel..." -ForegroundColor Yellow
python -m pip install --upgrade pip setuptools wheel

Write-Host "[*] Installing Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt

# CUDA GPU Detection
$NvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($NvidiaSmi) {
    Write-Host "[*] NVIDIA GPU detected via nvidia-smi." -ForegroundColor Cyan
    $CudaAvailable = & python -c "import torch; print(torch.cuda.is_available())" 2>$null
    if ($CudaAvailable -ne "True") {
        Write-Host "[*] Installing PyTorch with CUDA 12.1 acceleration..." -ForegroundColor Yellow
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    } else {
        Write-Host "[OK] PyTorch CUDA support is enabled." -ForegroundColor Green
    }
} else {
    Write-Host "[INFO] No NVIDIA GPU detected. PyTorch will run in CPU mode." -ForegroundColor DarkGray
}

# 4. Playwright Browser
Write-Host "[*] Installing Playwright Chromium browser..." -ForegroundColor Yellow
playwright install chromium 2>$null

# 5. Pre-download Demucs
Write-Host "[*] Pre-downloading Demucs model (htdemucs_ft)..." -ForegroundColor Yellow
python -c "try:`n    from demucs.pretrained import get_model`n    get_model('htdemucs_ft')`n    print('Demucs model downloaded')`nexcept Exception as e:`n    print(e)" 2>$null

# 6. Database Init
Write-Host "[*] Initializing SQLite database..." -ForegroundColor Yellow
python -c "from database import init_db; init_db(); print('Database initialized')"

New-Item -ItemType Directory -Force -Path (Join-Path $BACKEND "static\outputs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BACKEND "tmp") | Out-Null

$DotEnv = Join-Path $BACKEND ".env"
$DotEnvExample = Join-Path $BACKEND ".env.example"
if ((-not (Test-Path $DotEnv)) -and (Test-Path $DotEnvExample)) {
    Copy-Item $DotEnvExample $DotEnv
    Write-Host "[OK] Created .env from .env.example" -ForegroundColor Green
}

# 7. Frontend Setup
Write-Host "[*] Setting up React Frontend..." -ForegroundColor Yellow
Set-Location $FRONTEND
$NpmCmd = Get-Command npm -ErrorAction SilentlyContinue
if ($NpmCmd) {
    npm install
} else {
    Write-Warning "npm not found! Please install Node.js 18+ from https://nodejs.org/"
}

# 8. Dependency Check Summary
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Environment Checks & Recommendations" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Warning "FFmpeg not found in PATH. Install via Winget: winget install Gyan.FFmpeg"
} else {
    Write-Host "[OK] FFmpeg found in PATH." -ForegroundColor Green
}

if (-not (Get-Command redis-server -ErrorAction SilentlyContinue)) {
    Write-Warning "Redis server not found. Install Memurai (https://www.memurai.com/) or Redis for Windows."
} else {
    Write-Host "[OK] Redis found in PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "Setup Complete! Run .\start.ps1 to start VoiceForge Dataset Studio" -ForegroundColor Green
