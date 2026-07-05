from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


TRUST_NOTE_TR = (
    "Sonuçlar tavsiye niteliğindedir. Resmi deniz bilgisi, hava ve güvenli seyir ile "
    "çeliştiğinde her zaman o kaynaklara ve yerel yönetmeliklere uyun."
)

AiAssistantScope = Literal[
    "session_summary",
    "hotspot_detail",
    "live_context",
    "marine_coordinate",
    "marine_compare",
]
AiResponseSource = Literal["ai", "fallback"]
AiConfidence = Literal["low", "medium", "high"]


class AnalysisBoatModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    smoothed_gps: Optional[Dict[str, float]] = None
    boat_anchor_confidence: Optional[float] = None


class AnalysisDiagnosticsModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    mapping_mode: Optional[str] = None
    enrichment_enabled: Optional[bool] = None
    transform_quality: Optional[float] = None
    georeference_error_m: Optional[float] = None


class SpeciesMatchInputModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    species: str = ""
    confidence: str = ""
    reason: str = ""


class SeaStateInputModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    wave_height_m: Optional[float] = None
    water_temperature_c: Optional[float] = None
    wind_speed_knots: Optional[float] = None
    source: Optional[str] = None


class HotspotInputModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: int
    classification: str = "C"
    score: float = 0.0
    feature_type: str = ""
    recommendation_rank: Optional[int] = None
    final_fishing_score: Optional[float] = None
    distance_m: Optional[float] = None
    bearing_deg: Optional[float] = None
    reasoning: List[str] = Field(default_factory=list)
    reasoning_text: Optional[str] = None
    fish_prediction: Optional[str] = None
    species_match: Optional[List[SpeciesMatchInputModel]] = None
    sea_state: Optional[SeaStateInputModel] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    supporting_metrics: Optional[Dict[str, Any]] = None


class AnalysisPayloadModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    coordinate_mode: Optional[str] = None
    calibration_quality: Optional[float] = None
    calibration_reliability: Optional[str] = None
    user_warning_tr: Optional[str] = None
    session_advice: Optional[str] = None
    top_recommendations: List[int] = Field(default_factory=list)
    image_size: Optional[Dict[str, int]] = None
    boat: Optional[AnalysisBoatModel] = None
    diagnostics: Optional[AnalysisDiagnosticsModel] = None
    hotspots: List[HotspotInputModel] = Field(default_factory=list)


class ClientIdentityModel(BaseModel):
    """İstemci/cihaz kimliği — premium kota için opsiyonel."""

    model_config = ConfigDict(extra="ignore")

    device_id: Optional[str] = None
    user_id: Optional[str] = None
    app_version: Optional[str] = None
    platform: Optional[str] = None
    is_premium: Optional[bool] = None


class LiveContextInputModel(BaseModel):
    """Canlı alan / GPS bağlamı — Flutter Faz 3 contract ile uyumlu."""

    model_config = ConfigDict(extra="ignore")

    current_lat: Optional[float] = None
    current_lon: Optional[float] = None
    gps_accuracy_m: Optional[float] = None
    live_score: Optional[int] = None
    rating: Optional[str] = None
    reasoning: Optional[str] = None
    nearest_hotspot: Optional[int] = None
    distance_to_nearest: Optional[float] = None
    bearing_to_nearest: Optional[float] = None
    coordinate_mode: Optional[str] = None


class MarineCoordinateContextInputModel(BaseModel):
    """Marine Intelligence coordinate raporu özeti — marine_coordinate scope."""

    model_config = ConfigDict(extra="ignore")

    lat: float
    lon: float
    decision: Optional[Dict[str, Any]] = None
    decision_timeline: List[Dict[str, Any]] = Field(default_factory=list)
    fishing_score: Optional[Dict[str, Any]] = None
    consensus_summary: Optional[Dict[str, Any]] = None
    provider_comparison_summary: Optional[Dict[str, Any]] = None
    explainability: Optional[Dict[str, Any]] = None
    scenario_top_items: List[Dict[str, Any]] = Field(default_factory=list)
    weather_summary: Optional[Dict[str, Any]] = None
    wind_summary: Optional[Dict[str, Any]] = None
    marine_summary: Optional[Dict[str, Any]] = None
    astronomy_summary: Optional[Dict[str, Any]] = None
    most_sensitive_factor_tr: Optional[str] = None
    catch_context: Optional[Dict[str, Any]] = None


class MarineCompareContextInputModel(BaseModel):
    """Marine Compare — iki nokta karşılaştırma bağlamı."""

    model_config = ConfigDict(extra="ignore")

    left_label: str
    right_label: str
    comparison: Dict[str, Any] = Field(default_factory=dict)
    left_summary: Dict[str, Any] = Field(default_factory=dict)
    right_summary: Dict[str, Any] = Field(default_factory=dict)
    left_catch_context: Optional[Dict[str, Any]] = None
    right_catch_context: Optional[Dict[str, Any]] = None


class AiFishingAssistantRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    scope: AiAssistantScope = "session_summary"
    locale: str = "tr"
    analysis: Optional[AnalysisPayloadModel] = None
    focus_hotspot_id: Optional[int] = None
    live_context: Optional[LiveContextInputModel] = None
    marine_context: Optional[MarineCoordinateContextInputModel] = None
    marine_compare_context: Optional[MarineCompareContextInputModel] = None
    user_question: Optional[str] = None
    client_request_id: Optional[str] = None
    client_identity: Optional[ClientIdentityModel] = None
    chart_image_base64: Optional[str] = None
    force_refresh: bool = False

    @field_validator("locale")
    @classmethod
    def _locale_tr_only(cls, value: str) -> str:
        normalized = (value or "tr").strip().lower()
        if normalized != "tr":
            raise ValueError("Only locale 'tr' is supported in this phase.")
        return normalized

    @field_validator("user_question")
    @classmethod
    def _trim_question(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            return None
        if len(trimmed) > 500:
            return trimmed[:500]
        return trimmed

    @model_validator(mode="after")
    def _validate_scope_payload(self) -> "AiFishingAssistantRequestModel":
        if self.scope in {"marine_coordinate", "marine_compare"}:
            return self
        if self.scope in ("session_summary", "hotspot_detail") and self.analysis is None:
            raise ValueError("analysis is required for this scope.")
        return self


class AiAssistantTelemetryModel(BaseModel):
    """İstemci için opsiyonel telemetri özeti — secret içermez."""

    model_config = ConfigDict(extra="ignore")

    event: str = "ai_assistant_request"
    scope: Optional[str] = None
    source: Optional[str] = None
    model: Optional[str] = None
    prompt_version: Optional[str] = None
    assistant_name: Optional[str] = None
    persona_version: Optional[str] = None
    latency_ms: Optional[float] = None
    cache_hit: Optional[bool] = None
    fallback_reason: Optional[str] = None
    token_usage: Optional[Dict[str, int]] = None
    estimated_cost: Optional[float] = None


class RecommendedActionModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    priority: int = Field(ge=1, le=10)
    title_tr: str
    detail_tr: str


class HotspotInsightModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    hotspot_id: int
    headline_tr: str
    detail_tr: str


class AiStructuredPayloadModel(BaseModel):
    """OpenAI structured output şeması — API yanıtının çekirdeği."""

    model_config = ConfigDict(extra="forbid")

    summary_tr: str
    confidence: AiConfidence
    recommended_actions: List[RecommendedActionModel] = Field(default_factory=list)
    hotspot_insights: List[HotspotInsightModel] = Field(default_factory=list)
    conditions_comment_tr: str
    species_comment_tr: str
    limitations_tr: List[str] = Field(default_factory=list)
    safety_reminders_tr: List[str] = Field(default_factory=list)


class AiFishingAssistantResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source: AiResponseSource
    model: Optional[str] = None
    cache_hit: bool = False
    locale: str = "tr"
    trust_note_tr: str = TRUST_NOTE_TR
    prompt_version: str
    summary_tr: str
    confidence: AiConfidence
    recommended_actions: List[RecommendedActionModel] = Field(default_factory=list)
    hotspot_insights: List[HotspotInsightModel] = Field(default_factory=list)
    conditions_comment_tr: str
    species_comment_tr: str
    limitations_tr: List[str] = Field(default_factory=list)
    safety_reminders_tr: List[str] = Field(default_factory=list)
    fallback_reason: Optional[str] = None
    processing_ms: int = 0
    mode: Optional[AiAssistantScope] = None
    focus_hotspot_id: Optional[int] = None
    telemetry: Optional[AiAssistantTelemetryModel] = None
    remaining_ai_requests: Optional[int] = None
    is_premium_feature: Optional[bool] = None
    assistant_name: Optional[str] = None
    persona_version: Optional[str] = None
    tone: Optional[str] = None


class AiUsageSummaryResponseModel(BaseModel):
    """GET /api/v1/ai_usage_summary yanıtı."""

    model_config = ConfigDict(extra="forbid")

    total_requests: int = 0
    ai_requests: int = 0
    fallback_requests: int = 0
    cache_hit_rate: float = 0.0
    estimated_total_cost: float = 0.0
    by_scope: Dict[str, int] = Field(default_factory=dict)
    by_model: Dict[str, int] = Field(default_factory=dict)
    quota_remaining: Optional[int] = None
    client_identity_safe_id: Optional[str] = None
