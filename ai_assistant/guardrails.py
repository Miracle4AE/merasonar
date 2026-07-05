from __future__ import annotations

import re
from typing import Iterable, List, Optional

from ai_assistant.models import AiStructuredPayloadModel

_FORBIDDEN_SUBSTR = (
    "kesin avlan",
    "mutlaka avlan",
    "balık burada kesin",
    "kesin olarak",
    "garanti ed",
    "garanti av",
    "mutlaka burada",
    "mutlaka git",
    "kesin balık",
    "risk yok",
    "tehlike yok",
    "guaranteed",
    "will catch",
    "fish are here",
)

_FORBIDDEN_WORDS = frozenset({"kesin", "garanti", "mutlaka"})


class AiAssistantGuardrails:
    """Yasak ifade filtresi ve güvenli metin sanitize."""

    def validate_payload(self, payload: AiStructuredPayloadModel) -> Optional[str]:
        texts = _collect_texts(payload)
        for text in texts:
            reason = self._violation_reason(text)
            if reason:
                return reason
        return None

    def sanitize_payload(self, payload: AiStructuredPayloadModel) -> AiStructuredPayloadModel:
        return AiStructuredPayloadModel(
            summary_tr=_sanitize_text(payload.summary_tr),
            confidence=payload.confidence,
            recommended_actions=[
                item.model_copy(
                    update={
                        "title_tr": _sanitize_text(item.title_tr),
                        "detail_tr": _sanitize_text(item.detail_tr),
                    }
                )
                for item in payload.recommended_actions
            ],
            hotspot_insights=[
                item.model_copy(
                    update={
                        "headline_tr": _sanitize_text(item.headline_tr),
                        "detail_tr": _sanitize_text(item.detail_tr),
                    }
                )
                for item in payload.hotspot_insights
            ],
            conditions_comment_tr=_sanitize_text(payload.conditions_comment_tr),
            species_comment_tr=_sanitize_text(payload.species_comment_tr),
            limitations_tr=[_sanitize_text(x) for x in payload.limitations_tr],
            safety_reminders_tr=[_sanitize_text(x) for x in payload.safety_reminders_tr],
        )

    def _violation_reason(self, text: str) -> Optional[str]:
        low = text.lower()
        for banned in _FORBIDDEN_SUBSTR:
            if banned in low:
                return f"forbidden_substring:{banned}"
        tokens = re.findall(r"[a-zA-ZçğıöşüÇĞİÖŞÜ]+", low)
        for token in tokens:
            if token in _FORBIDDEN_WORDS:
                return f"forbidden_word:{token}"
        return None


def _collect_texts(payload: AiStructuredPayloadModel) -> List[str]:
    texts: List[str] = [
        payload.summary_tr,
        payload.conditions_comment_tr,
        payload.species_comment_tr,
    ]
    texts.extend(payload.limitations_tr)
    texts.extend(payload.safety_reminders_tr)
    for action in payload.recommended_actions:
        texts.extend([action.title_tr, action.detail_tr])
    for insight in payload.hotspot_insights:
        texts.extend([insight.headline_tr, insight.detail_tr])
    return texts


def _sanitize_text(text: str) -> str:
    cleaned = text.strip()
    if not cleaned:
        return cleaned
    low = cleaned.lower()
    if any(b in low for b in _FORBIDDEN_SUBSTR):
        return (
            "Bu yorum olasılıksal bir planlama fikridir; resmi deniz bilgisi ve yerel "
            "koşullar her zaman birincil referansınızdır."
        )
    for word in _FORBIDDEN_WORDS:
        pattern = re.compile(rf"\b{re.escape(word)}\b", re.IGNORECASE)
        cleaned = pattern.sub("olası", cleaned)
    return cleaned
