#!/bin/bash

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$ROOT/voiceforge-backend"
FRONTEND="$ROOT/frontend"
PORT="${VOICEFORGE_PORT:-8001}"

cleanup() {
    echo "Shutting down..."
    kill $CELERY_PID $API_PID $FRONTEND_PID 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

port_in_use() {
    lsof -i ":$1" -sTCP:LISTEN &>/dev/null
}

# Pick port — default 8001 to avoid conflict with other apps on 8000
if port_in_use "$PORT"; then
    echo "WARNING: Port $PORT already in use."
    for try_port in 8002 8003 8004 8005; do
        if ! port_in_use "$try_port"; then
            PORT=$try_port
            break
        fi
    done
    if port_in_use "$PORT"; then
        echo "ERROR: No free port found. Stop other services or set VOICEFORGE_PORT."
        exit 1
    fi
fi

if port_in_use 8000 && [ "$PORT" != "8000" ]; then
    echo "Note: Port 8000 is used by another app — VoiceForge using port $PORT"
fi

# Redis — required for Celery job queue
start_redis() {
    if redis-cli ping &>/dev/null; then
        echo "Redis already running"
        return 0
    fi

    if command -v redis-server &>/dev/null; then
        redis-server --daemonize yes 2>/dev/null
        sleep 1
        if redis-cli ping &>/dev/null; then
            echo "Redis started"
            return 0
        fi
    fi

    if command -v brew &>/dev/null && brew list redis &>/dev/null; then
        brew services start redis 2>/dev/null
        sleep 2
        if redis-cli ping &>/dev/null; then
            echo "Redis started via brew services"
            return 0
        fi
    fi

    echo ""
    echo "WARNING: Redis not running — dataset jobs won't process."
    echo "  brew install redis && brew services start redis"
    echo ""
    return 1
}

start_redis

# Ensure Python can import backend modules from Celery worker subprocesses
export PYTHONPATH="$BACKEND:$PYTHONPATH"

# Prevent macOS fork crashes when using Objective-C runtimes (like PyTorch/MPS) with Celery prefork pool
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# Sync frontend env with chosen port
cat > "$FRONTEND/.env" <<EOF
VITE_API_URL=http://localhost:$PORT
VITE_WS_URL=ws://localhost:$PORT
EOF

# Backend
cd "$BACKEND"
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
elif [ -f "venv/Scripts/activate" ]; then
    source venv/Scripts/activate
fi

echo "Starting Celery worker..."
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    # Use solo execution pool on macOS and Windows to prevent multi-process fork crashes
    celery -A workers.celery_app worker -P solo --loglevel=info &
else
    celery -A workers.celery_app worker --concurrency=2 --loglevel=info &
fi
CELERY_PID=$!

echo "Starting FastAPI server on port $PORT..."
uvicorn main:app --host 0.0.0.0 --port "$PORT" --reload --reload-exclude "static/*" --reload-exclude "tmp/*" --reload-exclude "*.db" &
API_PID=$!

# Frontend
cd "$FRONTEND"
echo "Starting frontend dev server..."
npm run dev &
FRONTEND_PID=$!

echo ""
echo "=== VoiceForge Dataset Studio ==="
echo "  Frontend:  http://localhost:5173"
echo "  API:       http://localhost:$PORT"
echo "  API Docs:  http://localhost:$PORT/docs"
echo ""
echo "Press Ctrl+C to stop all services"

wait
