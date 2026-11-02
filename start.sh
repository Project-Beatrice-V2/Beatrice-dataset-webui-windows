#!/bin/bash
# Beatrice Dataset Studio — starts the Celery worker, the FastAPI backend and the web UI
# from Git Bash on Windows (also works on Linux). Press Ctrl+C to stop everything.
# start.bat / start.ps1 are the native Windows equivalents.

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$ROOT/voiceforge-backend"
FRONTEND="$ROOT/frontend"
PORT="${VOICEFORGE_PORT:-8001}"
# The API has no authentication: keep it on this computer unless you know you need otherwise.
HOST="${VOICEFORGE_HOST:-127.0.0.1}"

if [ ! -x "$BACKEND/venv/Scripts/python.exe" ] && [ ! -x "$BACKEND/venv/bin/python" ]; then
    echo "ERROR: The Python environment is missing. Run ./setup.sh first."
    exit 1
fi
if [ ! -d "$FRONTEND/node_modules" ]; then
    echo "ERROR: The web UI dependencies are missing. Run ./setup.sh first."
    exit 1
fi

CELERY_PID=""
API_PID=""
FRONTEND_PID=""
cleanup() {
    trap - SIGINT SIGTERM EXIT
    echo ""
    echo "Shutting down..."
    kill $CELERY_PID $API_PID $FRONTEND_PID 2>/dev/null
    wait 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

port_in_use() {
    if command -v lsof &>/dev/null; then
        lsof -i ":$1" -sTCP:LISTEN &>/dev/null
    elif command -v netstat &>/dev/null; then
        netstat -an 2>/dev/null | grep -E "[:.]$1 .*LISTEN" &>/dev/null
    else
        return 1
    fi
}

# Pick the API port: 8001 by default (8000 is often taken by other apps)
if port_in_use "$PORT"; then
    echo "WARNING: Port $PORT is already in use."
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
    echo "Using port $PORT for the API"
fi

# Redis — required for the Celery job queue
start_redis() {
    if "$PY" -c "import redis; redis.Redis(socket_connect_timeout=1).ping()" &>/dev/null; then
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
    echo ""
    echo "WARNING: Redis is not running, so dataset jobs won't process."
    echo "  Start the Memurai service, or install it: winget install Memurai.MemuraiDeveloper"
    echo ""
    return 1
}
if [ -x "$BACKEND/venv/Scripts/python.exe" ]; then PY="$BACKEND/venv/Scripts/python.exe"; else PY="$BACKEND/venv/bin/python"; fi
start_redis

# Let Celery worker subprocesses import the backend modules
export PYTHONPATH="$BACKEND:$PYTHONPATH"

# The web UI proxies /api and /ws to the backend; tell it which port to use.
export VOICEFORGE_PORT="$PORT"
cat > "$FRONTEND/.env" <<EOF
# Written by start.sh: the Vite dev server proxies /api and /ws to the backend on this port.
VOICEFORGE_PORT=$PORT
EOF

cd "$BACKEND"
echo "Starting Celery worker..."
# Solo pool: Windows cannot fork, and it keeps PyTorch/CUDA in one process
"$PY" -m celery -A workers.celery_app worker -P solo --loglevel=info &
CELERY_PID=$!

echo "Starting FastAPI server on $HOST:$PORT..."
"$PY" -m uvicorn main:app --host "$HOST" --port "$PORT" &
API_PID=$!

cd "$FRONTEND"
echo "Starting the web UI..."
npm run dev &
FRONTEND_PID=$!

echo ""
echo "=== Beatrice Dataset Studio ==="
echo "  Web UI:    http://localhost:5173"
echo "  API:       http://localhost:$PORT"
echo "  API docs:  http://localhost:$PORT/docs"
echo ""
echo "Press Ctrl+C to stop all services"

wait
