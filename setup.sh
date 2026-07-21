#!/bin/bash
set -e

echo "=== VoiceForge Dataset Studio Setup ==="

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$ROOT/voiceforge-backend"
cd "$BACKEND"

# Prefer Python 3.12 or 3.11 — ML stack (torch, pyarrow, pyannote) is unreliable on 3.13+
PYTHON=""
for candidate in python3.12 python3.11 python3; do
    if command -v "$candidate" &>/dev/null; then
        ver=$("$candidate" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        major=$(echo "$ver" | cut -d. -f1)
        minor=$(echo "$ver" | cut -d. -f2)
        if [ "$major" -eq 3 ] && [ "$minor" -ge 11 ] && [ "$minor" -le 12 ]; then
            PYTHON="$candidate"
            break
        fi
        if [ -z "$PYTHON" ]; then
            PYTHON="$candidate"
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python 3.11+ not found. Install Python 3.12: brew install python@3.12"
    exit 1
fi

PY_VER=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Using Python $PY_VER ($PYTHON)"

if [ "$(echo "$PY_VER" | cut -d. -f2)" -gt 12 ]; then
    echo "WARNING: Python $PY_VER detected. ML packages work best on 3.11–3.12."
    echo "         Install 3.12: brew install python@3.12"
fi

# Recreate venv if it was built with a different Python version
if [ -d "venv" ]; then
    if [ -f "venv/.python-version" ]; then
        OLD_VER=$(cat venv/.python-version)
        if [ "$OLD_VER" != "$PY_VER" ]; then
            echo "Removing old venv (was Python $OLD_VER, need $PY_VER)..."
            rm -rf venv
        fi
    else
        VENV_VER=$(venv/bin/python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
        if [ "$VENV_VER" != "$PY_VER" ]; then
            echo "Removing old venv (was Python $VENV_VER, need $PY_VER)..."
            rm -rf venv
        fi
    fi
fi

if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    "$PYTHON" -m venv venv
    echo "$PY_VER" > venv/.python-version
fi
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
elif [ -f "venv/Scripts/activate" ]; then
    source venv/Scripts/activate
fi

echo "Installing Python dependencies..."
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

# Detect CUDA GPU on Windows/Linux
if command -v nvidia-smi &>/dev/null; then
    if ! python -c "import torch; exit(0 if torch.cuda.is_available() else 1)" &>/dev/null; then
        echo "NVIDIA GPU detected. Installing CUDA PyTorch..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    fi
fi

# Playwright for BTVA scraper
echo "Installing Playwright..."
playwright install chromium 2>/dev/null || echo "Playwright install skipped (optional)"

# Pre-download ML models (optional, may take time)
echo "Pre-downloading ML models (this may take a while)..."
python -c "
try:
    from demucs.pretrained import get_model
    get_model('htdemucs_ft')
    print('Demucs model downloaded')
except Exception as e:
    print(f'Demucs download skipped: {e}')
" 2>/dev/null || true

# Initialize database
echo "Initializing database..."
python -c "from database import init_db; init_db(); print('Database initialized')"

# Create directories
mkdir -p static/outputs tmp

# Frontend
echo "Installing frontend dependencies..."
cd "$ROOT/frontend"
npm install

# Copy env file
cd "$BACKEND"
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example — edit HF_TOKEN before running"
fi

# Redis (required for Celery)
if ! redis-cli ping &>/dev/null 2>&1; then
    if command -v brew &>/dev/null; then
        if ! brew list redis &>/dev/null; then
            echo "Installing Redis..."
            brew install redis
        fi
        echo "Starting Redis..."
        brew services start redis
        sleep 2
    fi
    if ! redis-cli ping &>/dev/null 2>&1; then
        echo "WARNING: Redis not running. Install with: brew install redis && brew services start redis"
    else
        echo "Redis ready"
    fi
else
    echo "Redis already running"
fi

echo ""
echo "=== Setup complete! ==="
echo "Run: ./start.sh"
