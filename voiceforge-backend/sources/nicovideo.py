"""Nicovideo search + yt-dlp."""

import asyncio
import logging
from typing import Any

import yt_dlp

logger = logging.getLogger(__name__)


async def search_nicovideo(query: str, character_info: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    """Runs the blocking yt-dlp search in a worker thread (keeps the API responsive)."""
    return await asyncio.to_thread(_search_nicovideo_sync, query, character_info)


def _search_nicovideo_sync(query: str, character_info: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    """Search Nicovideo for JP anime content."""
    info = character_info or {}
    search_q = f"{query} {info.get('series', '')} 声"
    results = []

    try:
        ydl_opts = {"quiet": True, "no_warnings": True, "extract_flat": True}
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            search_result = ydl.extract_info(f"nicosearch10:{search_q}", download=False)

        if search_result and "entries" in search_result:
            for entry in search_result["entries"]:
                if entry:
                    results.append({
                        "id": entry.get("id", ""),
                        "title": entry.get("title", ""),
                        "url": entry.get("url", ""),
                        "duration": entry.get("duration", 0) or 0,
                    })
    except Exception as e:
        logger.warning("Nicovideo search failed: %s", e)

    return results
