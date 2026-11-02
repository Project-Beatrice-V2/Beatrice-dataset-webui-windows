"""Lazy-loaded ML model instances."""

import logging

logger = logging.getLogger(__name__)

_silero_model = None
_silero_utils = None
_whisper_model = None
_demucs_model = None
_pyannote_pipeline = None
_resemblyzer_encoder = None


def get_silero_model():
    global _silero_model, _silero_utils
    if _silero_model is None:
        import torch
        model, utils = torch.hub.load("snakers4/silero-vad", "silero_vad", trust_repo=True)
        _silero_model = model
        _silero_utils = utils
    return _silero_model, _silero_utils


def get_whisper_model(model_size: str = "large-v3"):
    global _whisper_model
    if _whisper_model is None:
        from processing.audio_utils import get_device
        device = get_device()
        
        # faster-whisper (ctranslate2) does not support mps.
        # If device is mps, we prefer openai-whisper on mps for GPU acceleration.
        if device == "mps":
            try:
                import whisper
                _whisper_model = whisper.load_model(model_size, device="mps")
                logger.info("Loaded openai-whisper %s on mps", model_size)
                return _whisper_model
            except Exception as e:
                logger.warning("Failed to load openai-whisper on mps, trying cpu: %s", e)
                device = "cpu"
        
        try:
            from faster_whisper import WhisperModel
            compute_type = "float16" if device == "cuda" else "int8"
            _whisper_model = WhisperModel(model_size, device=device, compute_type=compute_type)
            logger.info("Loaded faster-whisper %s on %s", model_size, device)
        except Exception as e:
            logger.warning("Failed to load faster-whisper, falling back to openai-whisper: %s", e)
            import whisper
            _whisper_model = whisper.load_model(model_size, device=device)
            logger.info("Loaded openai-whisper %s on %s", model_size, device)
    return _whisper_model


def get_pyannote_pipeline():
    global _pyannote_pipeline
    if _pyannote_pipeline is None:
        from pyannote.audio import Pipeline
        from config import get_settings

        settings = get_settings()
        token = settings.HF_TOKEN or True  # True = use the token saved by `hf auth login`
        try:
            # pyannote.audio 4.x renamed `use_auth_token` to `token`
            pipeline = Pipeline.from_pretrained(settings.PYANNOTE_MODEL, token=token)
        except TypeError:
            pipeline = Pipeline.from_pretrained(settings.PYANNOTE_MODEL, use_auth_token=token)
        if pipeline is None:
            raise RuntimeError(
                f"Could not load {settings.PYANNOTE_MODEL}. Accept its terms (and those of "
                "pyannote/segmentation-3.0) on huggingface.co and set HF_TOKEN in voiceforge-backend/.env"
            )
        _pyannote_pipeline = pipeline
        from processing.audio_utils import get_device
        device = get_device()
        if device != "cpu":
            import torch
            _pyannote_pipeline.to(torch.device(device))
        logger.info("Loaded pyannote pipeline on %s", device)
    return _pyannote_pipeline


def get_resemblyzer_encoder():
    global _resemblyzer_encoder
    if _resemblyzer_encoder is None:
        from resemblyzer import VoiceEncoder
        _resemblyzer_encoder = VoiceEncoder()
        logger.info("Loaded Resemblyzer voice encoder")
    return _resemblyzer_encoder
