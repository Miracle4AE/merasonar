from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

DisagreementLevel = Literal["unknown", "low", "medium", "high"]
FishingDecisionLevel = Literal["excellent", "good", "borderline", "poor", "unsafe"]

MAX_SPOT_NAME_LEN = 80
MAX_SPOT_NOTE_LEN = 500
MAX_PERSONAL_TAGS = 20
MAX_TAG_LEN = 30
MAX_CATCH_SPECIES_LEN = 80
MAX_CATCH_BAIT_LEN = 80
MAX_CATCH_METHOD_LEN = 80
MAX_CATCH_NOTES_LEN = 500
MAX_CATCH_LENGTH_CM = 500.0
MAX_CATCH_WEIGHT_KG = 500.0
MAX_BULK_LEARNING_SPOT_IDS = 100
MAX_COMPARE_LABEL_LEN = 80


def _validate_lat_value(v: float) -> float:
    if not -90.0 <= float(v) <= 90.0:
        raise ValueError("lat must be between -90 and 90")
    return float(v)


def _validate_lon_value(v: float) -> float:
    if not -180.0 <= float(v) <= 180.0:
        raise ValueError("lon must be between -180 and 180")
    return float(v)


def _validate_personal_tags(tags: Optional[List[str]]) -> List[str]:
    if tags is None:
        return []
    if len(tags) > MAX_PERSONAL_TAGS:
        raise ValueError(f"personal_tags must have at most {MAX_PERSONAL_TAGS} items")
    cleaned: List[str] = []
    for tag in tags:
        text = str(tag).strip()
        if not text:
            continue
        if len(text) > MAX_TAG_LEN:
            raise ValueError(f"each personal tag must be at most {MAX_TAG_LEN} characters")
        cleaned.append(text)
    return cleaned

class CoordinateModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    lat: float
    lon: float

    @field_validator("lat")
    @classmethod
    def _validate_lat(cls, v: float) -> float:
        return _validate_lat_value(v)

    @field_validator("lon")
    @classmethod
    def _validate_lon(cls, v: float) -> float:
        return _validate_lon_value(v)

class MarineCoordinateRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    lat: float
    lon: float
    include_ai_comment: bool = False
    force_refresh: bool = False

    @field_validator("lat")
    @classmethod
    def _validate_lat(cls, v: float) -> float:
        return _validate_lat_value(v)

    @field_validator("lon")
    @classmethod
    def _validate_lon(cls, v: float) -> float:
        return _validate_lon_value(v)

class ConsensusValueModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    final_value: Optional[float] = None
    unit: Optional[str] = None
    provider_values: Dict[str, Optional[float]] = Field(default_factory=dict)
    confidence: float = 0.0
    source_count: int = 0
    disagreement_level: DisagreementLevel = "unknown"
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    mean_value: Optional[float] = None


class WeatherBlockModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    temperature_c: Optional[ConsensusValueModel] = None
    apparent_temperature_c: Optional[ConsensusValueModel] = None
    precipitation_probability_pct: Optional[ConsensusValueModel] = None
    precipitation_mm: Optional[ConsensusValueModel] = None
    relative_humidity_pct: Optional[ConsensusValueModel] = None
    surface_pressure_hpa: Optional[ConsensusValueModel] = None


class WindBlockModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    speed_kmh: Optional[ConsensusValueModel] = None
    direction_deg: Optional[ConsensusValueModel] = None
    direction_text: Optional[str] = None
    gust_kmh: Optional[ConsensusValueModel] = None
    max_gust_kmh: Optional[ConsensusValueModel] = None


class MarineBlockModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    wave_height_m: Optional[ConsensusValueModel] = None
    wave_direction_deg: Optional[ConsensusValueModel] = None
    wave_period_s: Optional[ConsensusValueModel] = None
    swell_height_m: Optional[ConsensusValueModel] = None
    swell_direction_deg: Optional[ConsensusValueModel] = None
    swell_period_s: Optional[ConsensusValueModel] = None
    sea_surface_temperature_c: Optional[ConsensusValueModel] = None
    ocean_current_velocity_mps: Optional[ConsensusValueModel] = None
    ocean_current_direction_deg: Optional[ConsensusValueModel] = None


class AstronomyBlockModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    sunrise: Optional[str] = None
    sunset: Optional[str] = None
    moon_phase: Optional[str] = None
    moon_illumination_pct: Optional[float] = None
    moonrise: Optional[str] = None
    moonset: Optional[str] = None
    moon_altitude_deg: Optional[float] = None


class FishingScoreModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    suitability_score: int = Field(ge=0, le=100, default=0)
    risk_score: int = Field(ge=0, le=100, default=0)
    best_hours_tr: str = ""
    wind_comment_tr: str = ""
    wave_comment_tr: str = ""
    swell_comment_tr: str = ""
    moon_comment_tr: str = ""
    general_advice_tr: str = ""
    confidence: float = Field(ge=0.0, le=1.0, default=0.0)


class ConsensusSummaryModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    overall_confidence: float = 0.0
    provider_count: int = 0
    partial_providers: bool = False
    source_count_by_group: Dict[str, int] = Field(default_factory=dict)
    strongest_group: Optional[str] = None
    weakest_group: Optional[str] = None
    disagreement_groups: List[str] = Field(default_factory=list)
    partial_data_reason: Optional[str] = None


class ProviderComparisonEntryModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str
    enabled: bool = True
    status: str = "unknown"
    weight: float = 0.0
    confidence: float = 0.0
    last_success: Optional[str] = None
    last_failure: Optional[str] = None
    metrics_provided: List[str] = Field(default_factory=list)


class ProviderComparisonSummaryModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    provider_count: int = 0
    healthy_count: int = 0
    partial_count: int = 0
    failed_count: int = 0
    overall_provider_confidence: float = 0.0


class ProviderComparisonModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    providers: List[ProviderComparisonEntryModel] = Field(default_factory=list)
    summary: ProviderComparisonSummaryModel = Field(default_factory=ProviderComparisonSummaryModel)


class ProviderStatusModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    providers: Dict[str, str] = Field(default_factory=dict)


class DecisionModel(BaseModel):
    """Faz 7+ Decision Engine — Faz 7a null."""

    model_config = ConfigDict(extra="forbid")

    fishing_decision: Optional[FishingDecisionLevel] = None
    go_score: Optional[int] = None
    wait_score: Optional[int] = None
    best_action_tr: Optional[str] = None
    decision_reason_codes: List[str] = Field(default_factory=list)
    short_summary_tr: Optional[str] = None


class ExplainabilityModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    positive_factors: List[str] = Field(default_factory=list)
    negative_factors: List[str] = Field(default_factory=list)
    uncertainty_factors: List[str] = Field(default_factory=list)
    explanation_summary_tr: Optional[str] = None
    most_sensitive_factor_tr: Optional[str] = None


class ScenarioItemModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    scenario_id: str
    title_tr: str
    changed_inputs: Dict[str, Any] = Field(default_factory=dict)
    resulting_go_score: Optional[int] = None
    resulting_risk_score: Optional[int] = None
    decision: Optional[FishingDecisionLevel] = None
    delta_go_score: Optional[int] = None
    delta_risk_score: Optional[int] = None
    delta_summary_tr: Optional[str] = None


class ScenarioBundleModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    base_go_score: Optional[int] = None
    items: List[ScenarioItemModel] = Field(default_factory=list)


class HourlyForecastPointModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    time: str
    time_utc: Optional[str] = None
    wind_speed_kmh: Optional[float] = None
    gust_kmh: Optional[float] = None
    wave_height_m: Optional[float] = None
    precipitation_probability_pct: Optional[float] = None
    surface_pressure_hpa: Optional[float] = None


# Geriye dönük uyumluluk — tek senaryo modeli artık kullanılmıyor.
ScenarioModel = ScenarioBundleModel


class DecisionTimelineItemModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    time: str
    go_score: Optional[int] = None
    risk_score: Optional[int] = None
    decision: Optional[FishingDecisionLevel] = None
    reason_tr: Optional[str] = None
    is_best_slot: bool = False


class MarineAiCommentActionModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title_tr: str
    detail_tr: str = ""


class MarineAiCommentModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source: Literal["ai", "fallback"] = "fallback"
    summary_tr: str = ""
    recommended_actions: List[MarineAiCommentActionModel] = Field(default_factory=list)
    risk_note_tr: Optional[str] = None
    best_time_window_tr: Optional[str] = None
    cache_hit: bool = False
    fallback_reason: Optional[str] = None
    assistant_name: str = "Captain Atlas"
    persona_version: str = "captain_atlas_v1"
    tone: str = "calm_expert"


class MarineCoordinateResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    coordinate: CoordinateModel
    weather: WeatherBlockModel
    wind: WindBlockModel
    marine: MarineBlockModel
    astronomy: AstronomyBlockModel
    fishing_score: FishingScoreModel
    consensus_summary: ConsensusSummaryModel
    provider_status: ProviderStatusModel
    updated_at: str
    cache_hit: bool = False
    partial_data: bool = False

    provider_comparison: Optional[ProviderComparisonModel] = None
    tide: Optional[Any] = None
    fish_activity: Optional[Any] = None
    marine_risk: Optional[Any] = None
    marine_index: Optional[Any] = None
    weather_stability: Optional[Any] = None
    decision: Optional[DecisionModel] = None
    explainability: Optional[ExplainabilityModel] = None
    scenario: Optional[ScenarioBundleModel] = None
    decision_timeline: Optional[List[DecisionTimelineItemModel]] = None
    historical: Optional[Any] = None
    trends: Optional[Any] = None
    ai_comment: Optional[MarineAiCommentModel] = None


class SpotIntelligenceModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    name: str
    lat: float
    lon: float
    note: Optional[str] = None
    favorite: bool = False
    created_at: str
    updated_at: str
    last_report: Optional[Dict[str, Any]] = None
    last_report_at: Optional[str] = None
    visit_count: int = 0
    personal_tags: List[str] = Field(default_factory=list)

    ai_learning_score: Optional[float] = None
    last_success_date: Optional[str] = None
    last_success_species: Optional[str] = None
    last_success_weight: Optional[float] = None
    preferred_fishing_style: Optional[str] = None
    bottom_type: Optional[str] = None
    estimated_depth: Optional[float] = None
    spot_reputation: Optional[float] = None
    spot_reputation_updated_at: Optional[str] = None
    spot_reputation_factors: Optional[List[str]] = None


class CreateSpotRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=MAX_SPOT_NAME_LEN)
    lat: float
    lon: float
    note: Optional[str] = Field(default=None, max_length=MAX_SPOT_NOTE_LEN)
    favorite: bool = False
    personal_tags: List[str] = Field(default_factory=list)

    @field_validator("lat")
    @classmethod
    def _validate_lat(cls, v: float) -> float:
        return _validate_lat_value(v)

    @field_validator("lon")
    @classmethod
    def _validate_lon(cls, v: float) -> float:
        return _validate_lon_value(v)

    @field_validator("personal_tags")
    @classmethod
    def _validate_tags(cls, v: List[str]) -> List[str]:
        return _validate_personal_tags(v)


class PatchSpotRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Optional[str] = Field(default=None, min_length=1, max_length=MAX_SPOT_NAME_LEN)
    note: Optional[str] = Field(default=None, max_length=MAX_SPOT_NOTE_LEN)
    favorite: Optional[bool] = None
    personal_tags: Optional[List[str]] = None

    @field_validator("personal_tags")
    @classmethod
    def _validate_tags(cls, v: Optional[List[str]]) -> Optional[List[str]]:
        if v is None:
            return None
        return _validate_personal_tags(v)


class SpotListResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    spots: List[SpotIntelligenceModel] = Field(default_factory=list)
    count: int = 0


class SpotDeleteResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    deleted: bool
    id: str
    deleted_catches: int = 0


class SpotRefreshRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    force_refresh: bool = False
    include_ai_comment: bool = False


class SpotRefreshResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    spot: SpotIntelligenceModel
    report: MarineCoordinateResponseModel


class CatchRecordModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    spot_id: str
    species: str
    length_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    bait: Optional[str] = None
    method: Optional[str] = None
    caught_at: str
    photo_path: Optional[str] = None
    notes: Optional[str] = None
    weather_snapshot: Optional[Dict[str, Any]] = None
    marine_snapshot: Optional[Dict[str, Any]] = None
    decision_snapshot: Optional[Dict[str, Any]] = None
    scenario_snapshot: Optional[Dict[str, Any]] = None
    moon_snapshot: Optional[Dict[str, Any]] = None
    created_at: str
    updated_at: str


class CreateCatchRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    species: str = Field(min_length=1, max_length=MAX_CATCH_SPECIES_LEN)
    length_cm: Optional[float] = Field(default=None, ge=0, le=MAX_CATCH_LENGTH_CM)
    weight_kg: Optional[float] = Field(default=None, ge=0, le=MAX_CATCH_WEIGHT_KG)
    bait: Optional[str] = Field(default=None, max_length=MAX_CATCH_BAIT_LEN)
    method: Optional[str] = Field(default=None, max_length=MAX_CATCH_METHOD_LEN)
    caught_at: str
    notes: Optional[str] = Field(default=None, max_length=MAX_CATCH_NOTES_LEN)

    @field_validator("species", "bait", "method", "notes")
    @classmethod
    def _strip_optional_text(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        stripped = v.strip()
        return stripped or None

    @field_validator("species", mode="after")
    @classmethod
    def _validate_species_after_strip(cls, v: Optional[str]) -> str:
        if v is None or not v.strip():
            raise ValueError("species is required")
        return v


class CreateCatchResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    catch: CatchRecordModel
    spot: SpotIntelligenceModel
    learning_summary: "LearningSummaryModel"


class CatchListResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    catches: List[CatchRecordModel] = Field(default_factory=list)
    count: int = 0
    summary: "LearningSummaryModel"


class CatchDeleteResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    deleted: bool
    id: str
    spot_id: Optional[str] = None
    learning_summary: Optional["LearningSummaryModel"] = None


class PatchCatchRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    species: Optional[str] = Field(default=None, min_length=1, max_length=MAX_CATCH_SPECIES_LEN)
    length_cm: Optional[float] = Field(default=None, ge=0, le=MAX_CATCH_LENGTH_CM)
    weight_kg: Optional[float] = Field(default=None, ge=0, le=MAX_CATCH_WEIGHT_KG)
    bait: Optional[str] = Field(default=None, max_length=MAX_CATCH_BAIT_LEN)
    method: Optional[str] = Field(default=None, max_length=MAX_CATCH_METHOD_LEN)
    caught_at: Optional[str] = None
    notes: Optional[str] = Field(default=None, max_length=MAX_CATCH_NOTES_LEN)

    @field_validator("species", "bait", "method", "notes")
    @classmethod
    def _strip_optional_text(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        stripped = v.strip()
        return stripped or None

    @field_validator("species", mode="after")
    @classmethod
    def _validate_species_after_strip(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        if not v.strip():
            raise ValueError("species cannot be empty")
        return v


class UpdateCatchResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    catch: CatchRecordModel
    spot: SpotIntelligenceModel
    learning_summary: "LearningSummaryModel"


class BulkLearningSummariesRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    spot_ids: List[str] = Field(min_length=1, max_length=MAX_BULK_LEARNING_SPOT_IDS)


class BulkLearningSummariesResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    summaries: Dict[str, Optional["LearningSummaryModel"]] = Field(default_factory=dict)
    missing_spot_ids: List[str] = Field(default_factory=list)


class LearningSummaryModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    spot_id: str
    catch_count: int = 0
    top_species: Optional[str] = None
    last_success_date: Optional[str] = None
    average_weight_kg: Optional[float] = None
    spot_reputation: Optional[int] = None
    spot_level: Optional[str] = None
    message_tr: str = ""


CompareWinner = Literal["left", "right", "tie"]


class MarineCompareSideInputModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    lat: Optional[float] = None
    lon: Optional[float] = None
    spot_id: Optional[str] = None
    label: Optional[str] = Field(default=None, max_length=MAX_COMPARE_LABEL_LEN)

    @field_validator("lat")
    @classmethod
    def _validate_lat(cls, v: Optional[float]) -> Optional[float]:
        if v is None:
            return None
        return _validate_lat_value(v)

    @field_validator("lon")
    @classmethod
    def _validate_lon(cls, v: Optional[float]) -> Optional[float]:
        if v is None:
            return None
        return _validate_lon_value(v)

    @field_validator("label")
    @classmethod
    def _strip_label(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        stripped = v.strip()
        return stripped or None


class MarineCompareRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    left: MarineCompareSideInputModel
    right: MarineCompareSideInputModel
    include_ai_comment: bool = False
    force_refresh: bool = False


class MarineComparisonModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    winner: CompareWinner
    winner_label: Optional[str] = None
    score_delta: int = 0
    risk_delta: int = 0
    confidence_delta: int = 0
    decision_delta_tr: str = ""
    main_reasons: List[str] = Field(default_factory=list)
    risk_note_tr: Optional[str] = None
    summary_tr: str = ""


class MarineCompareResponseModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    left_report: MarineCoordinateResponseModel
    right_report: MarineCoordinateResponseModel
    comparison: MarineComparisonModel
    captain_comment: Optional[MarineAiCommentModel] = None
    updated_at: str
