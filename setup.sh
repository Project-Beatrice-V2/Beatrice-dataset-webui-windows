#!/bin/bash
# Beatrice Dataset Studio — one-time setup from Git Bash on Windows (also works on Linux).
# setup.bat / setup.ps1 are the native Windows equivalents.
set -e

echo "=== Beatrice Dataset Studio setup (Git Bash) ==="

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$ROOT/voiceforge-backend"
cd "$BACKEND"

have() { command -v "$1" &>/dev/null; }

# Python 3.11 or 3.12: the ML stack (torch, pyannote, demucs) is unreliable elsewhere.
PYTHON=""
FALLBACK=""
# On Windows the "py" launcher is the reliable way in; "python3" is often the Microsoft Store stub.
for candidate in "py -3.12" "py -3.11" python3.12 python3.11 python python3; do
    if have "${candidate%% *}"; then
        ver=$($candidate -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
        major=${ver%%.*}
        minor=${ver#*.}
        if [ "$major" -eq 3 ] && [ "$minor" -ge 11 ] && [ "$minor" -le 12 ]; then
            PYTHON="$candidate"
            break
        fi
        if [ -z "$FALLBACK" ] && [ "$major" -eq 3 ] && [ "$minor" -ge 13 ]; then
            FALLBACK="$candidate"
        fi
    fi
done
if [ -z "$PYTHON" ] && [ -n "$FALLBACK" ]; then
    PYTHON="$FALLBACK"
fi
if [ -z "$PYTHON" ]; then
    echo "ERROR: Python 3.11 or 3.12 not found."
    echo "       Install it with: winget install Python.Python.3.12"
    exit 1
fi

PY_VER=$($PYTHON -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Using Python $PY_VER ($PYTHON)"
if [ "${PY_VER#*.}" -gt 12 ]; then
    echo "WARNING: Python $PY_VER detected. The ML packages work best on 3.11 or 3.12."
    echo "         Install 3.12 with: winget install Python.Python.3.12"
fi

# FFmpeg (audio decoding) and Node.js (web UI) are required.
if ! have ffmpeg; then
    echo "WARNING: FFmpeg not found. Install it with: winget install Gyan.FFmpeg (then open a new terminal)"
fi
if ! have npm; then
    echo "ERROR: Node.js not found. Install it with: winget install OpenJS.NodeJS.LTS"
    exit 1
fi

# The venv layout differs: venv/Scripts on Windows, venv/bin elsewhere
venv_python() {
    if [ -x venv/Scripts/python.exe ]; then echo venv/Scripts/python.exe; else echo venv/bin/python; fi
}

# Recreate the venv if it was built with a different Python version
if [ -d "venv" ]; then
    if [ -f "venv/.python-version" ]; then
        OLD_VER=$(cat venv/.python-version)
    else
        OLD_VER=$("$(venv_python)" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
    fi
    if [ "$OLD_VER" != "$PY_VER" ]; then
        echo "Removing old venv (was Python $OLD_VER, need $PY_VER)..."
        rm -rf venv
    fi
fi

if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    $PYTHON -m venv venv
    echo "$PY_VER" > venv/.python-version
fi
if [ -f venv/Scripts/activate ]; then source venv/Scripts/activate; else source venv/bin/activate; fi

echo "Installing Python dependencies (this downloads PyTorch and several GB of packages)..."
python -m pip install --upgrade pip setuptools wheel
# NVIDIA GPU: install the CUDA build of PyTorch first so the requirements keep it.
# cu121 stops at torch 2.5.1, too old for pyannote.audio 4; override with TORCH_CUDA=cu126.
TORCH_CUDA="${TORCH_CUDA:-cu128}"
if have nvidia-smi; then
    echo "NVIDIA GPU detected: installing the CUDA build of PyTorch ($TORCH_CUDA)..."
    python -m pip install torch torchaudio --index-url "https://download.pytorch.org/whl/$TORCH_CUDA" \
        || echo "WARNING: CUDA PyTorch install failed; continuing with the default build."
fi
python -m pip install -r requirements.txt
# resemblyzer pins the source-only `webrtcvad`; its dependencies are already installed
# (webrtcvad-wheels provides the same module), so install it without them.
python -m pip install --no-deps "resemblyzer>=0.1.4"
if have nvidia-smi && ! python -c "import sys, torch; sys.exit(0 if torch.cuda.is_available() else 1)" &>/dev/null; then
    echo "Restoring the CUDA build of PyTorch..."
    python -m pip install --force-reinstall --no-deps torch torchaudio --index-url "https://download.pytorch.org/whl/$TORCH_CUDA" || true
fi

# Playwright for the BTVA resolver (optional)
echo "Installing Playwright Chromium (optional)..."
python -m playwright install chromium 2>/dev/null || echo "Playwright install skipped (optional)"

# Pre-download the Demucs model (optional, ~300 MB; otherwise it downloads on first use)
echo "Pre-downloading the Demucs model (htdemucs_ft)..."
python -c "
try:
    from demucs.pretrained import get_model
    get_model('htdemucs_ft')
    print('Demucs model downloaded')
except Exception as e:
    print(f'Demucs download skipped: {e}')
" 2>/dev/null || true

mkdir -p static/outputs tmp

if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created voiceforge-backend/.env from .env.example: add your HF_TOKEN for speaker diarization"
fi

echo "Initializing database..."
python -c "from database import init_db; init_db(); print('Database initialized')"

# Web UI
echo "Installing web UI dependencies..."
cd "$ROOT/frontend"
npm install

# Redis (required for the Celery job queue): any Redis-compatible server, e.g. Memurai
cd "$BACKEND"
if python -c "import redis; redis.Redis(socket_connect_timeout=1).ping()" &>/dev/null; then
    echo "Redis is running"
else
    echo "WARNING: No Redis server on localhost:6379. Install Memurai: winget install Memurai.MemuraiDeveloper"
fi

echo ""
echo "=== Setup complete ==="
echo "Next: put your Hugging Face token in voiceforge-backend/.env (HF_TOKEN=...), then run ./start.sh"
