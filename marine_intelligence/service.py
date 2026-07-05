from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from marine_intelligence.cache import MarineIntelligenceCache
from marine_intelligence.config import MarineIntelligenceConfig
from marine_intelligence.consensus import build_consensus
from marine_intelligence.decision_engine import compute_decision, compute_decision_timeline
from marine_intelligence.explainability_engine import compute_explainability
from marine_intelligence.marine_conditions import build_marine_conditions_payload
from marine_intelligence.models import (
    AstronomyBlockModel,
    ConsensusSummaryModel,
    ConsensusValueModel,
    CoordinateModel,
    HourlyForecastPointModel,
    MarineBlockModel,
    MarineCoordinateResponseModel,
    ProviderStatusModel,
    WeatherBlockModel,
    WindBlockModel,
)
from marine_intelligence.provider_comparison import build_provider_comparison
from marine_intelligence.scenario_engine import compute_scenarios, most_sensitive_factor_from_scenarios
from marine_intelligence.marine_ai_comment import generate_marine_ai_comment
from marine_intelligence.providers.astronomy_local import AstronomyLocalProvider
from marine_intelligence.providers.base import MarineProviderProtocol, MarineProviderSnapshot
from marine_intelligence.providers.mgm_provider import MgmProvider, PoseidonProvider, WindyAppProvider, WindyProvider
from marine_intelligence.tide_engine import compute_tide
from marine_intelligence.providers.open_meteo_provider import (
    OpenMeteoProvider,
    enrich_daily_forecast_days,
    wind_direction_text_tr,
)
from marine_intelligence.providers.reliability import ProviderReliabilityRegistry
from marine_intelligence.scoring import compute_fishing_score

_GROUP_FIELDS: Dict[str, List[Tuple[str, str]]] = {
    "weather": [
        ("weather", "temperature_c"),
        ("weather", "precipitation_probability_pct"),
    ],
    "wind": [
        ("wind", "speed_kmh"),
        ("wind", "gust_kmh"),
    ],
    "marine": [
        ("marine", "wave_height_m"),
        ("marine", "swell_height_m"),
    ],
}


def _group_confidence(
    block: Any,
    fields: List[Tuple[str, str]],
) -> Tuple[float, int, List[str]]:
    confidences: List[float] = []
    disagreements: List[str] = []
    source_counts: List[int] = []
    group_name = fields[0][0] if fields else ""
    for section, field in fields:
        model: Optional[ConsensusValueModel] = getattr(block, field, None)
        if model is None or model.source_count == 0:
            continue
        confidences.append(model.confidence)
        source_counts.append(model.source_count)
        if model.disagreement_level in {"medium", "high"}:
            disagreements.append(section)
    if not confidences:
        return 0.0, 0, disagreements
    return round(sum(confidences) / len(confidences), 3), max(source_counts), disagreements


def _build_consensus_summary(
    weather: WeatherBlockModel,
    wind: WindBlockModel,
    marine: MarineBlockModel,
    *,
    provider_count: int,
    partial: bool,
    failed_providers: List[str],
) -> ConsensusSummaryModel:
    group_scores: Dict[str, float] = {}
    source_count_by_group: Dict[str, int] = {}
    disagreement_groups: List[str] = []

    blocks = {"weather": weather, "wind": wind, "marine": marine}
    for group, fields in _GROUP_FIELDS.items():
        conf, sources, disagreements = _group_confidence(blocks[group], fields)
        group_scores[group] = conf
        source_count_by_group[group] = sources
        if disagreements:
            disagreement_groups.append(group)

    overall_values = [v for v in group_scores.values() if v > 0]
    overall_confidence = round(sum(overall_values) / len(overall_values), 3) if overall_values else 0.0

    strongest = weakest = None
    if group_scores:
        ranked = sorted(group_scores.items(), key=lambda item: item[1], reverse=True)
        if ranked[0][1] > 0:
            strongest = ranked[0][0]
        if ranked[-1][1] > 0:
            weakest = ranked[-1][0]

    partial_reason = None
    if partial and failed_providers:
        partial_reason = f"Şu sağlayıcılardan veri alınamadı: {', '.join(failed_providers)}."

    return ConsensusSummaryModel(
        overall_confidence=overall_confidence,
        provider_count=provider_count,
        partial_providers=partial,
        source_count_by_group=source_count_by_group,
        strongest_group=strongest,
        weakest_group=weakest,
        disagreement_groups=sorted(set(disagreement_groups)),
        partial_data_reason=partial_reason,
    )


class MarineIntelligenceService:
    _RESPONSE_CACHE_VERSION = "20260704-daily-tide-v1"

    def __init__(
        self,
        config: MarineIntelligenceConfig,
        *,
        cache: Optional[MarineIntelligenceCache] = None,
        providers: Optional[List[MarineProviderProtocol]] = None,
        reliability_registry: Optional[ProviderReliabilityRegistry] = None,
    ) -> None:
        self._config = config
        self._cache = cache or MarineIntelligenceCache(ttl_seconds=config.cache_ttl_minutes * 60)
        self._reliability = reliability_registry or ProviderReliabilityRegistry(config)
        self._providers = providers if providers is not None else self._build_default_providers()

    def _build_default_providers(self) -> List[MarineProviderProtocol]:
        return [
            OpenMeteoProvider(
                enabled=self._config.open_meteo_enabled,
                timeout_seconds=self._config.request_timeout_seconds,
            ),
            AstronomyLocalProvider(enabled=self._config.astronomy_local_enabled),
            MgmProvider(enabled=self._config.mgm_enabled),
            WindyProvider(enabled=self._config.windy_enabled),
            WindyAppProvider(enabled=self._config.windy_app_enabled),
            PoseidonProvider(enabled=self._config.poseidon_enabled),
        ]

    def get_coordinate_intelligence(
        self,
        lat: float,
        lon: float,
        *,
        force_refresh: bool = False,
        include_ai_comment: bool = False,
        client_ip: str = "unknown",
        spot_id: Optional[str] = None,
    ) -> MarineCoordinateResponseModel:
        provider_set = ",".join(sorted(self._config.enabled_provider_names()))
        fingerprint = f"{self._reliability.fingerprint()}:{self._RESPONSE_CACHE_VERSION}"
        cache_key = MarineIntelligenceCache.build_key(lat, lon, provider_set, fingerprint)

        if not force_refresh:
            cached, hit = self._cache.get(cache_key)
            if hit and cached is not None:
                response = MarineCoordinateResponseModel.model_validate(cached)
                response = response.model_copy(update={"cache_hit": True})
                return self._maybe_attach_ai_comment(
                    response,
                    include_ai_comment=include_ai_comment,
                    client_ip=client_ip,
                    spot_id=spot_id,
                    force_refresh=force_refresh,
                )

        snapshots = [provider.fetch(lat, lon) for provider in self._providers if self._provider_enabled(provider)]
        response = self._build_response(lat, lon, snapshots)
        self._cache.set(cache_key, response.model_dump(mode="json"))
        return self._maybe_attach_ai_comment(
            response,
            include_ai_comment=include_ai_comment,
            client_ip=client_ip,
            spot_id=spot_id,
            force_refresh=force_refresh,
        )

    @staticmethod
    def _maybe_attach_ai_comment(
        response: MarineCoordinateResponseModel,
        *,
        include_ai_comment: bool,
        client_ip: str,
        spot_id: Optional[str] = None,
        force_refresh: bool = False,
    ) -> MarineCoordinateResponseModel:
        if not include_ai_comment:
            return response.model_copy(update={"ai_comment": None})
        ai_comment = generate_marine_ai_comment(
            response,
            client_ip=client_ip,
            spot_id=spot_id,
            force_refresh=force_refresh,
        )
        return response.model_copy(update={"ai_comment": ai_comment})

    def _provider_enabled(self, provider: MarineProviderProtocol) -> bool:
        return provider.provider_name in self._config.enabled_provider_names()

    def _build_response(
        self,
        lat: float,
        lon: float,
        snapshots: List[MarineProviderSnapshot],
    ) -> MarineCoordinateResponseModel:
        provider_status: Dict[str, str] = {}
        partial = False
        success_count = 0
        failed_providers: List[str] = []

        for snap in snapshots:
            if snap.success:
                self._reliability.record_success(snap.provider_name)
                provider_status[snap.provider_name] = "ok"
                success_count += 1
            else:
                if snap.error == "disabled":
                    provider_status[snap.provider_name] = "disabled"
                elif snap.error == "not_implemented":
                    provider_status[snap.provider_name] = "not_implemented"
                else:
                    self._reliability.record_failure(snap.provider_name)
                    provider_status[snap.provider_name] = "failed"
                    failed_providers.append(snap.provider_name)
                    partial = True

        reliabilities = {rel.provider_name: rel for rel in self._reliability.list_enabled()}

        weather = self._build_weather_block(snapshots, reliabilities)
        wind = self._build_wind_block(snapshots, reliabilities)
        marine = self._build_marine_block(snapshots, reliabilities)
        astronomy = self._build_astronomy_block(snapshots)

        consensus_summary = _build_consensus_summary(
            weather,
            wind,
            marine,
            provider_count=success_count,
            partial=partial,
            failed_providers=failed_providers,
        )

        fishing_score = compute_fishing_score(
            wind_speed_kmh=wind.speed_kmh.final_value if wind.speed_kmh else None,
            wind_gust_kmh=wind.gust_kmh.final_value if wind.gust_kmh else None,
            wave_height_m=marine.wave_height_m.final_value if marine.wave_height_m else None,
            swell_height_m=marine.swell_height_m.final_value if marine.swell_height_m else None,
            rain_probability_pct=(
                weather.precipitation_probability_pct.final_value
                if weather.precipitation_probability_pct
                else None
            ),
            moon_illumination_pct=astronomy.moon_illumination_pct,
            confidence=consensus_summary.overall_confidence,
        )

        provider_comparison = build_provider_comparison(snapshots, self._reliability, provider_status)

        decision = compute_decision(
            fishing_score=fishing_score,
            consensus_summary=consensus_summary,
            provider_comparison=provider_comparison,
            weather=weather,
            wind=wind,
            marine=marine,
            astronomy=astronomy,
            partial_data=partial,
        )
        scenario = compute_scenarios(
            base_decision=decision,
            fishing_score=fishing_score,
            wind=wind,
            marine=marine,
            weather=weather,
            astronomy=astronomy,
            confidence=consensus_summary.overall_confidence,
            partial_data=partial,
            reason_codes=decision.decision_reason_codes,
        )
        sensitive = most_sensitive_factor_from_scenarios(scenario)
        explainability = compute_explainability(
            weather=weather,
            wind=wind,
            marine=marine,
            consensus_summary=consensus_summary,
            partial_data=partial,
            decision_reason_codes=decision.decision_reason_codes,
            most_sensitive_factor_tr=sensitive,
        )
        hourly_series = self._collect_hourly_series(snapshots)
        decision_timeline = compute_decision_timeline(
            base_decision=decision,
            fishing_score=fishing_score,
            partial_data=partial,
            hourly_series=hourly_series or None,
            wind=wind,
            marine=marine,
            weather=weather,
            astronomy=astronomy,
            reason_codes=decision.decision_reason_codes,
        )
        historical = self._build_historical(snapshots)
        tide_result = compute_tide(lat, lon, config=self._config)
        tide = build_marine_conditions_payload(
            marine=marine,
            hourly_series=hourly_series or None,
            tide_result=tide_result,
        )

        return MarineCoordinateResponseModel(
            coordinate=CoordinateModel(lat=lat, lon=lon),
            weather=weather,
            wind=wind,
            marine=marine,
            astronomy=astronomy,
            fishing_score=fishing_score,
            consensus_summary=consensus_summary,
            provider_status=ProviderStatusModel(providers=provider_status),
            provider_comparison=provider_comparison,
            explainability=explainability,
            decision=decision,
            scenario=scenario,
            decision_timeline=decision_timeline,
            historical=historical,
            tide=tide,
            updated_at=datetime.now(timezone.utc).isoformat(),
            cache_hit=False,
            partial_data=partial,
        )

    def _collect_hourly_series(
        self,
        snapshots: List[MarineProviderSnapshot],
    ) -> List[HourlyForecastPointModel]:
        for snap in snapshots:
            if not snap.success or not snap.hourly_series:
                continue
            points: List[HourlyForecastPointModel] = []
            for raw in snap.hourly_series:
                try:
                    points.append(HourlyForecastPointModel.model_validate(raw))
                except Exception:
                    continue
            if points:
                return points
        return []

    def _build_historical(
        self,
        snapshots: List[MarineProviderSnapshot],
    ) -> Optional[Dict[str, Any]]:
        for snap in snapshots:
            if not snap.success or not snap.daily_series:
                continue
            days = enrich_daily_forecast_days(snap.daily_series[:7])
            if days:
                return {
                    "source": snap.provider_name,
                    "day_count": len(days),
                    "days": days,
                }
        return None

    def _collect_field(
        self,
        snapshots: List[MarineProviderSnapshot],
        section: str,
        field: str,
    ) -> Dict[str, Optional[float]]:
        out: Dict[str, Optional[float]] = {}
        for snap in snapshots:
            if not snap.success:
                continue
            bucket = getattr(snap, section, {}) or {}
            if field in bucket:
                val = bucket.get(field)
                out[snap.provider_name] = float(val) if val is not None else None
        return out

    def _build_weather_block(
        self,
        snapshots: List[MarineProviderSnapshot],
        reliabilities: Dict[str, Any],
    ) -> WeatherBlockModel:
        mapping = [
            ("temperature_c", "temperature_c", "°C"),
            ("apparent_temperature_c", "apparent_temperature_c", "°C"),
            ("precipitation_probability_pct", "precipitation_probability_pct", "%"),
            ("precipitation_mm", "precipitation_mm", "mm"),
            ("relative_humidity_pct", "relative_humidity_pct", "%"),
            ("surface_pressure_hpa", "surface_pressure_hpa", "hPa"),
        ]
        values: Dict[str, Any] = {}
        for attr, field, unit in mapping:
            values[attr] = build_consensus(
                field,
                self._collect_field(snapshots, "weather", field),
                reliabilities,
                unit=unit,
            )
        return WeatherBlockModel(**values)

    def _build_wind_block(
        self,
        snapshots: List[MarineProviderSnapshot],
        reliabilities: Dict[str, Any],
    ) -> WindBlockModel:
        speed = build_consensus(
            "speed_kmh",
            self._collect_field(snapshots, "wind", "speed_kmh"),
            reliabilities,
            unit="km/h",
        )
        direction = build_consensus(
            "direction_deg",
            self._collect_field(snapshots, "wind", "direction_deg"),
            reliabilities,
            unit="deg",
            is_angle=True,
        )
        gust = build_consensus(
            "gust_kmh",
            self._collect_field(snapshots, "wind", "gust_kmh"),
            reliabilities,
            unit="km/h",
        )
        dir_text = wind_direction_text_tr(direction.final_value)
        return WindBlockModel(
            speed_kmh=speed,
            direction_deg=direction,
            direction_text=dir_text,
            gust_kmh=gust,
            max_gust_kmh=gust,
        )

    def _build_marine_block(
        self,
        snapshots: List[MarineProviderSnapshot],
        reliabilities: Dict[str, Any],
    ) -> MarineBlockModel:
        mapping = [
            ("wave_height_m", "wave_height_m", "m", False),
            ("wave_direction_deg", "wave_direction_deg", "deg", True),
            ("wave_period_s", "wave_period_s", "s", False),
            ("swell_height_m", "swell_height_m", "m", False),
            ("swell_direction_deg", "swell_direction_deg", "deg", True),
            ("swell_period_s", "swell_period_s", "s", False),
            ("sea_surface_temperature_c", "sea_surface_temperature_c", "°C", False),
            ("ocean_current_velocity_mps", "ocean_current_velocity_mps", "m/s", False),
            ("ocean_current_direction_deg", "ocean_current_direction_deg", "deg", True),
        ]
        values: Dict[str, Any] = {}
        for attr, field, unit, is_angle in mapping:
            values[attr] = build_consensus(
                field,
                self._collect_field(snapshots, "marine", field),
                reliabilities,
                unit=unit,
                is_angle=is_angle,
            )
        return MarineBlockModel(**values)

    @staticmethod
    def _build_astronomy_block(snapshots: List[MarineProviderSnapshot]) -> AstronomyBlockModel:
        for snap in snapshots:
            if snap.success and snap.astronomy:
                data = snap.astronomy
                return AstronomyBlockModel(
                    sunrise=data.get("sunrise"),
                    sunset=data.get("sunset"),
                    moon_phase=data.get("moon_phase"),
                    moon_illumination_pct=data.get("moon_illumination_pct"),
                    moonrise=data.get("moonrise"),
                    moonset=data.get("moonset"),
                    moon_altitude_deg=data.get("moon_altitude_deg"),
                )
        return AstronomyBlockModel()
