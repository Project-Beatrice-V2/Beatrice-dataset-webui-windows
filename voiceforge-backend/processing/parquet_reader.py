"""Parquet audio extraction for HuggingFace datasets."""

import io
import logging
from pathlib import Path

import numpy as np
import pyarrow.parquet as pq
import soundfile as sf

from processing.audio_utils import resample, to_mono
from processing.normalizer import normalize_audio

logger = logging.getLogger(__name__)

AUDIO_COLUMN_NAMES = ["audio", "wav", "speech", "voice", "audio_bytes", "sound"]


def detect_audio_column(table) -> str | None:
    for col in AUDIO_COLUMN_NAMES:
        if col in table.column_names:
            return col
    for col in table.column_names:
        if "audio" in col.lower() or "wav" in col.lower():
            return col
    return None


def extract_audio_from_parquet(
    parquet_path: Path,
    output_dir: Path,
    sample_rate: int = 22050,
    bit_depth: int = 16,
    channels: str = "mono",
    normalize: bool = True,
) -> list[Path]:
    """Extract audio from parquet file, handling HF audio feature schemas."""
    table = pq.read_table(str(parquet_path))
    audio_col_name = detect_audio_column(table)
    if not audio_col_name:
        raise ValueError(f"No audio column found in {parquet_path}. Columns: {table.column_names}")

    audio_col = table.column(audio_col_name)
    results = []

    for i in range(len(audio_col)):
        row = audio_col[i].as_py()
        data, sr = _decode_audio_row(row, table, i)

        if data is None:
            continue

        if channels == "mono":
            data = to_mono(data) if data.ndim > 1 else data
        if sr != sample_rate:
            data = resample(data, sr, sample_rate)
            sr = sample_rate
        if normalize:
            data = normalize_audio(data)

        # Prefix with the shard name so several Parquet files don't overwrite each other.
        out_path = output_dir / f"{parquet_path.stem}_{i:05d}.wav"
        subtype = {16: "PCM_16", 24: "PCM_24", 32: "FLOAT"}.get(bit_depth, "PCM_16")
        sf.write(str(out_path), data, sr, subtype=subtype)
        results.append(out_path)

    return results


def _decode_audio_row(row, table, index: int) -> tuple[np.ndarray | None, int]:
    """Decode a single audio row from various parquet schemas."""
    default_sr = 22050

    # Pattern A: HuggingFace Audio feature dict
    if isinstance(row, dict):
        if "bytes" in row and row["bytes"]:
            data, sr = sf.read(io.BytesIO(row["bytes"]))
            sr = row.get("sampling_rate", sr)
            return data.astype(np.float32), sr
        if "path" in row and row["path"]:
            path = Path(row["path"])
            if path.exists():
                data, sr = sf.read(str(path))
                return data.astype(np.float32), row.get("sampling_rate", sr)
        if "array" in row:
            arr = np.array(row["array"], dtype=np.float32)
            sr = row.get("sampling_rate", default_sr)
            return arr, sr

    # Pattern B: raw bytes
    if isinstance(row, (bytes, bytearray)):
        data, sr = sf.read(io.BytesIO(row))
        return data.astype(np.float32), sr

    # Pattern C: numpy array directly
    if isinstance(row, (list, np.ndarray)):
        return np.array(row, dtype=np.float32), default_sr

    # Pattern D: separate bytes column
    for col_name in ["audio_bytes", "wav_bytes", "bytes"]:
        if col_name in table.column_names:
            bytes_val = table.column(col_name)[index].as_py()
            if bytes_val:
                data, sr = sf.read(io.BytesIO(bytes_val))
                return data.astype(np.float32), default_sr

    logger.warning("Could not decode audio row %d: type=%s", index, type(row))
    return None, default_sr
