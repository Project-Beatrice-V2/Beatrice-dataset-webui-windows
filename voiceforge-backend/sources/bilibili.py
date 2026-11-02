"""Bilibili search + yt-dlp."""

import asyncio
import logging
from typing import Any

import yt_dlp

from config import get_settings

logger = logging.getLogger(__name__)


async def search_bilibili(query: str, character_info: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    """Runs the blocking yt-dlp search in a worker thread (keeps the API responsive)."""
    return await asyncio.to_thread(_search_bilibili_sync, query, character_info)


def _search_bilibili_sync(query: str, character_info: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    """Search Bilibili for anime voice content."""
    settings = get_settings()
    info = character_info or {}
    anime = info.get("series", "")
    search_queries = [
        f"{query} {anime} 声",
        f"{anime} {query} 台词",
        f"{query} 语音合集",
    ]

    results = []
    seen_ids = set()

    for sq in search_queries:
        try:
            ydl_opts = {
                "quiet": True,
                "no_warnings": True,
                "extract_flat": True,
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                search_result = ydl.extract_info(
                    f"bilisearch{settings.BILIBILI_MAX_RESULTS}:{sq}", download=False
                )

            if not search_result or "entries" not in search_result:
                continue

            for entry in search_result["entries"]:
                if not entry or entry.get("id") in seen_ids:
                    continue
                seen_ids.add(entry["id"])
                results.append({
                    "id": entry["id"],
                    "title": entry.get("title", ""),
                    "url": entry.get("url", entry.get("webpage_url", "")),
                    "duration": entry.get("duration", 0) or 0,
                })
        except Exception as e:
            logger.warning("Bilibili search failed: %s", e)

    return results[:settings.BILIBILI_MAX_RESULTS]


def download_bilibili_audio(url: str, output_dir: str) -> str | None:
    """Download audio from Bilibili."""
    from sources.youtube import YDL_OPTS_AUDIO
    import os
    from pathlib import Path

    opts = {**YDL_OPTS_AUDIO, "outtmpl": os.path.join(output_dir, "%(id)s.%(ext)s")}
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=True)
            video_id = info["id"]
            for f in Path(output_dir).glob(f"{video_id}.*"):
                return str(f)
    except Exception as e:
        logger.error("Bilibili download failed: %s", e)
    return None
