"""YouTube search + yt-dlp wrapper."""

import asyncio
import logging
from typing import Any

import yt_dlp

from config import get_settings

logger = logging.getLogger(__name__)

QUERY_TEMPLATES = {
    "anime_jp": [
        "{character} {anime} 声 日本語",
        "{character} {anime} japanese voice clips",
        "{voice_actor} voice acting compilation",
        "{anime} 日本語 {character} シーン集",
    ],
    "anime_en": [
        "{character} {anime} english dub compilation",
        "{character} {anime} voice lines",
        "{en_voice_actor} voice reel",
        "{anime} english dub all {character} scenes",
    ],
    "celebrity": [
        "{name} speech compilation",
        "{name} interview full",
        "{name} press conference",
        "{name} podcast audio",
    ],
    "voice_actor": [
        "{name} voice acting reel",
        "{name} characters voice compilation",
        "{name} behind the mic",
    ],
    "game_character": [
        "{character} {game} all voice lines",
        "{character} {game} full dialogue",
        "{va_name} {game} {character} voice",
    ],
}

YDL_OPTS_AUDIO = {
    "format": "bestaudio/best",
    "outtmpl": "%(id)s.%(ext)s",
    "postprocessors": [{
        "key": "FFmpegExtractAudio",
        "preferredcodec": "wav",
        "preferredquality": "0",
    }],
    "quiet": True,
    "no_warnings": True,
    "extract_flat": False,
    "concurrent_fragment_downloads": 4,
    "retries": 3,
    "http_chunk_size": 10485760,
}


async def search_youtube(
    query: str,
    query_type: str,
    character_info: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Search YouTube for relevant videos.

    yt-dlp is blocking (several searches, each can take seconds), so it runs in a worker
    thread instead of freezing the FastAPI event loop during a search preview.
    """
    return await asyncio.to_thread(_search_youtube_sync, query, query_type, character_info)


def _search_youtube_sync(
    query: str,
    query_type: str,
    character_info: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    settings = get_settings()
    search_queries = _build_queries(query, query_type, character_info)
    results = []
    seen_ids = set()

    for sq in search_queries[:6]:
        try:
            ydl_opts = {
                "quiet": True,
                "no_warnings": True,
                "extract_flat": True,
                "default_search": f"ytsearch{settings.YOUTUBE_MAX_RESULTS}",
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                search_result = ydl.extract_info(f"ytsearch{settings.YOUTUBE_MAX_RESULTS}:{sq}", download=False)

            if not search_result or "entries" not in search_result:
                continue

            for entry in search_result["entries"]:
                if not entry or entry.get("id") in seen_ids:
                    continue
                seen_ids.add(entry["id"])

                duration = entry.get("duration", 0) or 0
                if duration < 60 or duration > 7200:
                    continue

                results.append({
                    "id": entry["id"],
                    "title": entry.get("title", ""),
                    "url": f"https://www.youtube.com/watch?v={entry['id']}",
                    "duration": duration,
                    "view_count": entry.get("view_count", 0),
                    "relevance_score": _score_video(entry, query, character_info),
                })
        except Exception as e:
            logger.warning("YouTube search failed for '%s': %s", sq, e)

    results.sort(key=lambda x: (x["relevance_score"], x.get("view_count", 0)), reverse=True)
    return results[:settings.YOUTUBE_MAX_RESULTS]


def _build_queries(query: str, query_type: str, character_info: dict | None) -> list[str]:
    info = character_info or {}
    templates = []

    if query_type in ("anime", "fictional"):
        lang = info.get("language", "auto")
        if lang in ("jp", "auto", "both"):
            templates.extend(QUERY_TEMPLATES["anime_jp"])
        if lang in ("en", "auto", "both"):
            templates.extend(QUERY_TEMPLATES["anime_en"])
    elif query_type == "game_character":
        templates = QUERY_TEMPLATES["game_character"]
    elif query_type in ("celebrity", "musician", "youtuber"):
        templates = QUERY_TEMPLATES["celebrity"]
    elif query_type == "voice_actor":
        templates = QUERY_TEMPLATES["voice_actor"]
    else:
        templates = [f"{query} voice compilation", f"{query} speech"]

    formatted = []
    for t in templates:
        try:
            formatted.append(t.format(
                character=query,
                anime=info.get("series", query),
                voice_actor=info.get("voice_actor_jp", query),
                en_voice_actor=info.get("voice_actor_en", query),
                name=query,
                game=info.get("series", query),
                va_name=info.get("voice_actor_jp", info.get("voice_actor_en", query)),
            ))
        except KeyError:
            formatted.append(t.replace("{character}", query).replace("{name}", query))

    return formatted


def _score_video(entry: dict, query: str, character_info: dict | None) -> float:
    score = 0.0
    title = (entry.get("title") or "").lower()
    query_lower = query.lower()

    if query_lower in title:
        score += 30
    if character_info:
        for key in ("series", "voice_actor_jp", "voice_actor_en"):
            val = character_info.get(key, "")
            if val and val.lower() in title:
                score += 15

    duration = entry.get("duration", 0) or 0
    if 300 <= duration <= 3600:
        score += 20
    elif 60 <= duration < 300:
        score += 10

    views = entry.get("view_count", 0) or 0
    if views > 100000:
        score += 15
    elif views > 10000:
        score += 10

    return score


def download_youtube_audio(url: str, output_dir: str) -> str | None:
    """Download audio from a YouTube URL."""
    import os
    from pathlib import Path

    opts = {**YDL_OPTS_AUDIO, "outtmpl": os.path.join(output_dir, "%(id)s.%(ext)s")}
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=True)
            video_id = info["id"]
            wav_path = Path(output_dir) / f"{video_id}.wav"
            if wav_path.exists():
                return str(wav_path)
            # Check for other extensions
            for f in Path(output_dir).glob(f"{video_id}.*"):
                return str(f)
    except Exception as e:
        logger.error("YouTube download failed for %s: %s", url, e)
    return None
