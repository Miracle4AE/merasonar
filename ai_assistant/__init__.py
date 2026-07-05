"""
MeraSonar AI Assistant — sidecar katmanı.

Mevcut analiz pipeline'ından bağımsız; yalnızca istemci tarafından gönderilen
analiz özetini yorumlar.
"""

from ai_assistant.config import AiAssistantConfig
from ai_assistant.dependencies import build_ai_assistant_service, get_ai_assistant_config
from ai_assistant.models import (
    AiFishingAssistantRequestModel,
    AiFishingAssistantResponseModel,
)
from ai_assistant.service import AiAssistantService

__all__ = [
    "AiAssistantConfig",
    "AiAssistantService",
    "AiFishingAssistantRequestModel",
    "AiFishingAssistantResponseModel",
    "build_ai_assistant_service",
    "get_ai_assistant_config",
]
