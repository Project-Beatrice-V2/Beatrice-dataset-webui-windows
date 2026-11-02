# Beatrice Dataset Studio - one-time setup for Windows (PowerShell).
#
# Windows blocks unsigned scripts by default. Run it like this (only this process is affected):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
# or right-click setup.ps1 > "Run with PowerShell".

# Native tools (pip, npm, nvidia-smi) report failure through $LASTEXITCODE. 'Stop' would turn
# their harmless stderr output into terminating errors in Windows PowerShell 5.1.
$ErrorActionPreference = 'Continue'

$Root = $PSScriptRoot
$Backend = Join-Path $Root 'voiceforge-backend'
$Frontend = Join-Path $Root 'frontend'
$VPy = Join-Path $Backend 'venv\Scripts\python.exe'
$TorchCuda = if ($env:TORCH_CUDA) { $env:TORCH_CUDA } else { 'cu128' }

function Fail([string]$Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

Write-Host '===================================================' -ForegroundColor Cyan
Write-Host '  Beatrice Dataset Studio setup - Windows (PowerShell)' -ForegroundColor Cyan
Write-Host '===================================================' -ForegroundColor Cyan

# 1. Python 3.12 or 3.11 (the py launcher first; plain "python" may be the Store stub)
Write-Host '[*] Looking for Python 3.12 or 3.11...' -ForegroundColor Yellow
$PyCmd = $null
$probe = 'import sys; sys.exit(0 if sys.version_info[:2] in ((3, 11), (3, 12)) else 1)'
foreach ($spec in @('py -3.12', 'py -3.11', 'python')) {
    $candidate = @($spec -split ' ')
    $exe = $candidate[0]
    $pre = @($candidate | Select-Object -Skip 1)
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { continue }
    & $exe @pre -c $probe *> $null
    if ($LASTEXITCODE -eq 0) { $PyCmd = $candidate; break }
}
if (-not $PyCmd) {
    Fail 'Python 3.12 or 3.11 not found. Install it with: winget install Python.Python.3.12'
}
$PyExe = $PyCmd[0]
$PyPre = @($PyCmd | Select-Object -Skip 1)
Write-Host ("[OK] Using " + (& $PyExe @PyPre --version)) -ForegroundColor Green

# 2. Virtual environment
Set-Location $Backend
if (-not (Test-Path $VPy)) {
    Write-Host '[*] Creating virtual environment...' -ForegroundColor Yellow
    & $PyExe @PyPre -m venv venv
    if ($LASTEXITCODE -ne 0) { Fail "Could not create $Backend\venv" }
}

# 3. Python packages (no activation needed: the venv's python.exe is called directly)
Write-Host '[*] Upgrading pip, setuptools and wheel...' -ForegroundColor Yellow
& $VPy -m pip install --upgrade pip setuptools wheel
if ($LASTEXITCODE -ne 0) { Fail 'pip upgrade failed' }

$HasNvidia = [bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue)
if ($HasNvidia) {
    Write-Host "[*] NVIDIA GPU detected: installing the CUDA build of PyTorch ($TorchCuda)..." -ForegroundColor Cyan
    & $VPy -m pip install torch torchaudio --index-url "https://download.pytorch.org/whl/$TorchCuda"
    if ($LASTEXITCODE -ne 0) { Write-Warning 'CUDA PyTorch install failed; continuing with the default build.' }
} else {
    Write-Host '[INFO] No NVIDIA GPU found: PyTorch will run on the CPU.' -ForegroundColor DarkGray
}

Write-Host '[*] Installing Python requirements (several GB)...' -ForegroundColor Yellow
& $VPy -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { Fail 'Installing requirements failed (see the pip error above)' }
# resemblyzer pins the source-only webrtcvad; webrtcvad-wheels already provides it.
& $VPy -m pip install --no-deps 'resemblyzer>=0.1.4'
if ($LASTEXITCODE -ne 0) { Fail 'Installing resemblyzer failed' }

if ($HasNvidia) {
    $cudaCheck = 'import sys, torch; sys.exit(0 if torch.cuda.is_available() else 1)'
    & $VPy -c $cudaCheck *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[*] Restoring the CUDA build of PyTorch...' -ForegroundColor Yellow
        & $VPy -m pip install --force-reinstall --no-deps torch torchaudio --index-url "https://download.pytorch.org/whl/$TorchCuda"
        & $VPy -c $cudaCheck *> $null
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Host '[OK] PyTorch can use your NVIDIA GPU.' -ForegroundColor Green
    } else {
        Write-Warning 'PyTorch cannot see the GPU. Update the NVIDIA driver, or set $env:TORCH_CUDA = "cu126" for older cards and run setup again.'
    }
}

# 4. Optional downloads
Write-Host '[*] Installing the Playwright Chromium browser (optional)...' -ForegroundColor Yellow
& $VPy -m playwright install chromium *> $null
if ($LASTEXITCODE -ne 0) { Write-Host '[INFO] Playwright browser skipped (optional).' -ForegroundColor DarkGray }

Write-Host '[*] Pre-downloading the Demucs model htdemucs_ft (optional)...' -ForegroundColor Yellow
& $VPy -c "from demucs.pretrained import get_model; get_model('htdemucs_ft'); print('Demucs model ready.')"
if ($LASTEXITCODE -ne 0) { Write-Host '[INFO] The Demucs model will download on first use.' -ForegroundColor DarkGray }

# 5. Folders, settings, database
New-Item -ItemType Directory -Force -Path (Join-Path $Backend 'static\outputs') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Backend 'tmp') | Out-Null
$DotEnv = Join-Path $Backend '.env'
if (-not (Test-Path $DotEnv)) {
    Copy-Item (Join-Path $Backend '.env.example') $DotEnv
    Write-Host '[OK] Created voiceforge-backend\.env - add your HF_TOKEN there.' -ForegroundColor Green
}

Write-Host '[*] Initializing the database...' -ForegroundColor Yellow
& $VPy -c "from database import init_db; init_db(); print('Database initialized.')"
if ($LASTEXITCODE -ne 0) { Fail 'Database initialisation failed' }

# 6. Web UI
Write-Host '[*] Installing web UI dependencies...' -ForegroundColor Yellow
Set-Location $Frontend
if (Get-Command npm -ErrorAction SilentlyContinue) {
    & npm install
    if ($LASTEXITCODE -ne 0) { Fail 'npm install failed (Node.js 20.19+ or 22 LTS is required)' }
} else {
    Write-Warning 'Node.js not found. Install it with: winget install OpenJS.NodeJS.LTS, then run setup again.'
}

# 7. Environment checks
Write-Host ''
Write-Host '  Environment checks' -ForegroundColor Cyan
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    Write-Host '[OK] FFmpeg found.' -ForegroundColor Green
} else {
    Write-Warning 'FFmpeg not found. Install it with: winget install Gyan.FFmpeg (then open a new terminal).'
}
& $VPy -c 'import redis; redis.Redis(socket_connect_timeout=1).ping()' *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host '[OK] A Redis server is running.' -ForegroundColor Green
} else {
    Write-Warning 'No Redis server on localhost:6379. Install Memurai Developer: winget install Memurai.MemuraiDeveloper (or run redis-server in WSL).'
}

Set-Location $Root
Write-Host ''
Write-Host 'Setup complete. Put your Hugging Face token in voiceforge-backend\.env (HF_TOKEN=...), then run start.ps1:' -ForegroundColor Green
Write-Host '  powershell -ExecutionPolicy Bypass -File .\start.ps1' -ForegroundColor Green
