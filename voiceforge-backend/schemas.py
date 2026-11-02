"""Pydantic schemas for API request/response models."""

from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


class JobOptions(BaseModel):
    target_duration_minutes: int = 30
    min_clip_duration_sec: float = 1.5
    max_clip_duration_sec: float = 25.0
    target_sample_rate: int = 22050
    bit_depth: int = 16
    channels: Literal["mono", "stereo"] = "mono"
    output_format: Literal["ljspeech", "vctk", "raw", "rvc", "custom"] = "ljspeech"
    denoise_strength: Literal["off", "light", "medium", "aggressive"] = "medium"
    use_vad: bool = True
    transcribe: bool = True
    min_snr_db: float = 15.0
    quality_threshold: int = 60
    search_strategy: Literal["auto", "hub_only", "scrape_only", "hybrid"] = "auto"
    anime_episode_range: Optional[list[int]] = None
    include_secondary_speakers: bool = False
    manual_speaker_selection: bool = False
    use_demucs: bool = True
    # Read by workers/stage_speaker_verify.py; it used to be dropped here, so the
    # "Speaker similarity" slider in the UI had no effect.
    speaker_similarity_threshold: float = Field(0.75, ge=0.0, le=1.0)
    video_sources: list[str] = Field(
        default_factory=lambda: ["youtube", "bilibili", "nicovideo", "archive_org"]
    )


class CreateJobRequest(BaseModel):
    query: str
    query_type: Literal[
        "anime", "celebrity", "voice_actor", "musician", "youtuber", "fictional", "game_character"
    ]
    language: str = "auto"
    options: JobOptions = Field(default_factory=JobOptions)


class CreateJobResponse(BaseModel):
    job_id: str
    status: str
    estimated_time_minutes: int


class ClipResponse(BaseModel):
    id: int
    filename: Optional[str]
    duration_s: Optional[float]
    sample_rate: Optional[int]
    snr_db: Optional[float]
    rms_db: Optional[float]
    transcript: Optional[str]
    confidence: Optional[float]
    speaker_id: Optional[str]
    source_url: Optional[str]
    start_ts: Optional[float]
    end_ts: Optional[float]
    quality_score: Optional[float]
    kept: bool

    model_config = {"from_attributes": True}


class JobStageResponse(BaseModel):
    id: int
    stage: Optional[str]
    progress: int
    message: Optional[str]
    ts: datetime

    model_config = {"from_attributes": True}


class JobResponse(BaseModel):
    id: str
    query: str
    query_type: str
    language: str
    status: str
    strategy: Optional[str]
    source_urls: list[str] = []
    total_clips: int
    total_seconds: float
    output_path: Optional[str]
    metadata: dict[str, Any] = {}
    options: dict[str, Any] = {}
    error_msg: Optional[str]
    created_at: datetime
    updated_at: datetime
    stages: list[JobStageResponse] = []

    model_config = {"from_attributes": True}


class PaginatedClipsResponse(BaseModel):
    clips: list[ClipResponse]
    total: int
    page: int
    page_size: int


class SearchPreviewRequest(BaseModel):
    query: str
    query_type: str
    language: str = "auto"


class SourceFound(BaseModel):
    type: str
    dataset: Optional[str] = None
    size_gb: Optional[float] = None
    clips: Optional[int] = None
    videos: Optional[int] = None
    estimated_duration_minutes: Optional[float] = None


class SearchPreviewResponse(BaseModel):
    sources_found: list[SourceFound]
    recommended_strategy: str
    estimated_output_clips: int
    estimated_duration_minutes: float
    character_info: Optional[dict[str, Any]] = None


class ConvertRequest(BaseModel):
    target_format: str = "wav"
    sample_rate: int = 22050
    bit_depth: int = 16
    channels: str = "mono"
    normalize: bool = True
    trim_silence: bool = False


class ConvertResponse(BaseModel):
    job_id: str
    status: str
    files_converted: int
    download_url: Optional[str] = None


class ExportRequest(BaseModel):
    output_format: Optional[str] = None
    quality_threshold: Optional[int] = None


class HistoryItem(BaseModel):
    id: str
    query: str
    query_type: str
    language: str
    status: str
    total_clips: int
    total_seconds: float
    created_at: datetime
    download_url: Optional[str] = None

    model_config = {"from_attributes": True}


class WSEvent(BaseModel):
    event: str
    stage: Optional[str] = None
    progress: Optional[int] = None
    message: Optional[str] = None
    clip: Optional[dict[str, Any]] = None
    clips: Optional[int] = None
    duration_min: Optional[float] = None
    download_url: Optional[str] = None
    recoverable: Optional[bool] = None
