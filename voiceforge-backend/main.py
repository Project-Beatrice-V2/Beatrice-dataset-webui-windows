"""FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from config import get_settings
from database import init_db
from api.routes_jobs import router as jobs_router
from api.routes_convert import router as convert_router
from api.routes_search import router as search_router
from api.routes_history import router as history_router
from api.websocket import router as ws_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    settings.ensure_dirs()
    logger.info("VoiceForge Dataset Studio started")
    yield
    logger.info("VoiceForge shutting down")


app = FastAPI(
    title="VoiceForge Dataset Studio",
    description="AI Voice Dataset Creator — search, extract, and package voice datasets",
    version="1.0.0",
    lifespan=lifespan,
)

# The API is unauthenticated, so browsers may only call it from local origins. A wildcard
# here would let any website you visit drive (and delete) your jobs through the browser.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1|\[::1\])(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(jobs_router)
app.include_router(convert_router)
app.include_router(search_router)
app.include_router(history_router)
app.include_router(ws_router)

# Serve packaged outputs from wherever OUTPUT_DIR points (it may live outside the repo).
settings.ensure_dirs()
app.mount("/static/outputs", StaticFiles(directory=str(settings.OUTPUT_DIR)), name="outputs")


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "voiceforge", "version": "1.0.0"}


@app.get("/api/health")
def api_health():
    return {"status": "ok", "redis": _check_redis()}


def _check_redis() -> str:
    try:
        from workers.celery_app import redis_client

        redis_client.ping()
        return "connected"
    except Exception:
        return "disconnected"


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT)
