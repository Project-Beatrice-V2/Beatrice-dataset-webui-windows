"""Pyannote speaker diarization stage."""

import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


def diarize_all(
    wav_files: list[dict[str, str]],
    character_info: dict[str, Any],
    options: dict[str, Any],
) -> list[dict[str, Any]]:
    """Diarize all audio files and identify target speaker segments."""
    all_segments = []

    for af in wav_files:
        src = Path(af["path"])
        try:
            segments = _diarize_file(src, character_info, options)
            for seg in segments:
                all_segments.append({
                    **af,
                    "start": seg["start"],
                    "end": seg["end"],
                    "speaker_id": seg.get("speaker_id", "SPK_00"),
                })
        except Exception as e:
            logger.warning("Diarization failed for %s: %s", src, e)
            # Fallback: treat entire file as single speaker
            from processing.audio_utils import load_audio
            data, sr = load_audio(src)
            duration = len(data) / sr
            all_segments.append({
                **af,
                "start": 0.0,
                "end": duration,
                "speaker_id": "SPK_00",
            })

    return all_segments


def _diarize_file(
    audio_path: Path,
    character_info: dict[str, Any],
    options: dict[str, Any],
) -> list[dict[str, Any]]:
    """Run pyannote diarization on a single file."""
    try:
        from models.pyannote_loader import get_pyannote_pipeline

        pipeline = get_pyannote_pipeline()
        # Hand pyannote the decoded waveform: this avoids its own file decoding
        # (torchaudio backends in 3.x, torchcodec + shared FFmpeg in 4.x).
        import soundfile as sf
        import torch

        data, sr = sf.read(str(audio_path), dtype="float32", always_2d=True)
        waveform = torch.from_numpy(data.T.copy())
        diarization = pipeline({"waveform": waveform, "sample_rate": sr})
        # pyannote.audio 4.x returns an output object; 3.x returns the Annotation itself
        annotation = getattr(diarization, "speaker_diarization", diarization)

        segments = []
        speaker_times: dict[str, float] = {}

        for turn, _, speaker in annotation.itertracks(yield_label=True):
            segments.append({
                "start": turn.start,
                "end": turn.end,
                "speaker_id": speaker,
            })
            speaker_times[speaker] = speaker_times.get(speaker, 0) + (turn.end - turn.start)

        # Select target speaker (most speaking time by default)
        if speaker_times:
            target_speaker = max(speaker_times, key=speaker_times.get)
            segments = [s for s in segments if s["speaker_id"] == target_speaker]

        return segments
    except Exception as e:
        logger.warning("Pyannote diarization failed: %s", e)
        raise
