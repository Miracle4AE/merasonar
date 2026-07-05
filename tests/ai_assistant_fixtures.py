"""Shared fixtures for AI assistant tests."""

from __future__ import annotations

import json
from typing import Optional

from ai_assistant.config import AiAssistantConfig
from ai_assistant.models import (
    AiFishingAssistantRequestModel,
    AiStructuredPayloadModel,
    AnalysisPayloadModel,
    HotspotInputModel,
    LiveContextInputModel,
)
from ai_assistant.identity import resolve_client_identity
from ai_assistant.openai_client import OpenAIGenerationResult


def make_ai_config(
    *,
    enabled: bool = True,
    api_key: str = "test-key",
    model: str = "test-model",
    vision: bool = False,
    streaming: bool = False,
) -> AiAssistantConfig:
    return AiAssistantConfig(
        openai_api_key=api_key,
        openai_model=model,
        ai_assistant_enabled=enabled,
        ai_timeout_seconds=5.0,
        ai_max_tokens=800,
        ai_temperature=0.0,
        prompt_version="v1-test",
        vision_enabled=vision,
        streaming_enabled=streaming,
        cache_ttl_seconds=60,
        cost_input_per_1m=1.0,
        cost_output_per_1m=2.0,
        ai_rate_limit_enabled=False,
        ai_rate_limit_per_minute=30,
        ai_max_estimated_cost_per_request_usd=0.0,
        ai_quota_enabled=False,
        ai_free_daily_limit=10,
        ai_premium_daily_limit=100,
        ai_telemetry_persist_enabled=False,
        ai_telemetry_jsonl_path="run_logs/ai_telemetry.jsonl",
        ai_usage_admin_key=None,
    )


def sample_structured_payload() -> AiStructuredPayloadModel:
    return AiStructuredPayloadModel(
        summary_tr="Olası plan: önce A sınıfı noktayı kısa deneyin.",
        confidence="medium",
        recommended_actions=[
            {
                "priority": 1,
                "title_tr": "Nokta #10",
                "detail_tr": "Yapısal skor yüksek görünüyor.",
            }
        ],
        hotspot_insights=[
            {
                "hotspot_id": 10,
                "headline_tr": "A sınıfı aday",
                "detail_tr": "Sırt yapısı baskın.",
            }
        ],
        conditions_comment_tr="Dalga düşük görünüyor; resmi kaynakları doğrulayın.",
        species_comment_tr="Levrek olasılığı orta düzeyde.",
        limitations_tr=["Kalibrasyon iyi."],
        safety_reminders_tr=["Resmi haritaya uyun."],
    )


def sample_structured_json() -> str:
    return sample_structured_payload().model_dump_json()


def sample_live_context(**overrides: object) -> LiveContextInputModel:
    base = {
        "current_lat": 37.35,
        "current_lon": 27.25,
        "gps_accuracy_m": 12.0,
        "live_score": 72,
        "rating": "good",
        "reasoning": "Yakın sırt hattı.",
        "nearest_hotspot": 10,
        "distance_to_nearest": 420.0,
        "bearing_to_nearest": 85.0,
        "coordinate_mode": "geo_referenced",
    }
    base.update(overrides)
    return LiveContextInputModel.model_validate(base)


def sample_request(
    *,
    scope: str = "session_summary",
    focus_id: Optional[int] = None,
    coordinate_mode: str = "geo_referenced",
    live_context: Optional[LiveContextInputModel] = None,
) -> AiFishingAssistantRequestModel:
    return AiFishingAssistantRequestModel(
        scope=scope,  # type: ignore[arg-type]
        analysis=AnalysisPayloadModel(
            coordinate_mode=coordinate_mode,
            session_advice="Önce Nokta #10'a yaklaşmayı düşünün.",
            top_recommendations=[10, 3],
            hotspots=[
                HotspotInputModel(
                    id=10,
                    classification="A",
                    score=0.82,
                    feature_type="drop_off",
                    recommendation_rank=1,
                    reasoning=["yüksek eğim"],
                    reasoning_text="Derinlik kırığına yakın olası aday.",
                    fish_prediction="Levrek",
                    species_match=[
                        {"species": "Dicentrarchus labrax", "confidence": "medium", "reason": "yapı"}
                    ],
                    latitude=37.35,
                    longitude=27.25,
                    supporting_metrics={"slope": 0.7, "dropoff_proximity": 0.6},
                ),
                HotspotInputModel(
                    id=3,
                    classification="B",
                    score=0.55,
                    feature_type="ridge_spur",
                    recommendation_rank=2,
                    reasoning=["orta yapı"],
                    reasoning_text="Sırt hattı.",
                    latitude=37.351,
                    longitude=27.251,
                    supporting_metrics={"ridge_likelihood": 0.5},
                ),
            ],
        ),
        focus_hotspot_id=focus_id,
        live_context=live_context,
        client_request_id="test-req-1",
    )


class MockOpenAIResponsesClient:
    def __init__(
        self,
        output_text: str,
        *,
        fail_times: int = 0,
    ) -> None:
        self.output_text = output_text
        self.fail_times = fail_times
        self.calls = 0

    def generate_structured(self, **kwargs) -> OpenAIGenerationResult:
        self.calls += 1
        if self.fail_times >= self.calls:
            return OpenAIGenerationResult(
                output_text="{not-json",
                input_tokens=100,
                output_tokens=10,
                total_tokens=110,
                latency_ms=12.0,
                model="test-model",
            )
        return OpenAIGenerationResult(
            output_text=self.output_text,
            input_tokens=120,
            output_tokens=80,
            total_tokens=200,
            latency_ms=15.5,
            model="test-model",
        )

    def generate_structured_stream(self, **kwargs):
        raise RuntimeError("streaming test stub")


def default_client_identity(*, client_ip: str = "127.0.0.1"):
    return resolve_client_identity(None, client_ip)
