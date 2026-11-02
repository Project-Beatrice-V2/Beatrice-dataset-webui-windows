"""WebSocket progress broadcaster for job updates."""

import asyncio
import json
import logging
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

router = APIRouter()


class ConnectionManager:
    """Manages WebSocket connections per job."""

    def __init__(self):
        self.active_connections: dict[str, list[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, job_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            if job_id not in self.active_connections:
                self.active_connections[job_id] = []
            self.active_connections[job_id].append(websocket)
        logger.info("WebSocket connected for job %s", job_id)

    async def disconnect(self, job_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            if job_id in self.active_connections:
                self.active_connections[job_id] = [
                    ws for ws in self.active_connections[job_id] if ws != websocket
                ]
                if not self.active_connections[job_id]:
                    del self.active_connections[job_id]

    async def broadcast(self, job_id: str, event: dict[str, Any]) -> None:
        async with self._lock:
            connections = list(self.active_connections.get(job_id, []))

        dead: list[WebSocket] = []
        for ws in connections:
            try:
                await ws.send_json(event)
            except Exception:
                dead.append(ws)

        for ws in dead:
            await self.disconnect(job_id, ws)

    def broadcast_sync(self, job_id: str, event: dict[str, Any]) -> None:
        """Called from Celery workers (sync context)."""
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.create_task(self.broadcast(job_id, event))
            else:
                loop.run_until_complete(self.broadcast(job_id, event))
        except RuntimeError:
            asyncio.run(self.broadcast(job_id, event))


manager = ConnectionManager()


def publish_progress(
    job_id: str,
    event_type: str,
    stage: str | None = None,
    progress: int | None = None,
    message: str | None = None,
    **kwargs: Any,
) -> None:
    """Publish progress via Redis (delegates to workers.progress)."""
    from workers.progress import publish_progress as _redis_publish
    _redis_publish(job_id, event_type, stage=stage, progress=progress, message=message, **kwargs)


@router.websocket("/ws/jobs/{job_id}")
async def websocket_job_progress(websocket: WebSocket, job_id: str):
    await manager.connect(job_id, websocket)

    # Subscribe to Redis pub/sub for this job
    pubsub = None
    redis_task = None

    try:
        from workers.celery_app import redis_client

        pubsub = redis_client.pubsub()
        pubsub.subscribe(f"job:{job_id}")

        async def redis_listener():
            while True:
                # timeout=0: non-blocking poll. A blocking timeout here froze the whole
                # event loop for every connected client.
                message = pubsub.get_message(ignore_subscribe_messages=True, timeout=0)
                if message and message["type"] == "message":
                    data = json.loads(message["data"])
                    await websocket.send_json(data)
                    continue
                await asyncio.sleep(0.1)

        redis_task = asyncio.create_task(redis_listener())

        while True:
            try:
                data = await websocket.receive_text()
                # Handle client messages (e.g., speaker selection)
                msg = json.loads(data)
                if msg.get("event") == "speaker_selected":
                    from workers.celery_app import redis_client as rc

                    rc.set(f"job:{job_id}:speaker", msg.get("speaker_id", ""))
            except WebSocketDisconnect:
                break
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error("WebSocket error for job %s: %s", job_id, e)
    finally:
        if redis_task:
            redis_task.cancel()
        if pubsub:
            pubsub.unsubscribe(f"job:{job_id}")
            pubsub.close()
        await manager.disconnect(job_id, websocket)
