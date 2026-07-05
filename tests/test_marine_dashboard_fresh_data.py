"""Dashboard forecast + tide activation tests."""

from __future__ import annotations

import unittest
from typing import Any, Dict, List

from marine_intelligence.marine_conditions import build_marine_conditions_payload
from marine_intelligence.models import HourlyForecastPointModel, MarineBlockModel
from marine_intelligence.providers.open_meteo_provider import (
    enrich_daily_forecast_days,
    parse_open_meteo_daily_series,
)
from marine_intelligence.tide_provider import TideProviderResult


def _sample_daily_payload() -> Dict[str, Any]:
    return {
        "daily": {
            "time": [f"2026-07-{d:02d}" for d in range(4, 11)],
            "temperature_2m_max": [28.0, 27.0, 26.0, 25.0, 24.0, 23.0, 22.0],
            "temperature_2m_min": [18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0],
            "precipitation_probability_max": [10, 20, 30, 40, 50, 60, 70],
            "weather_code": [0, 1, 2, 3, 61, 80, 95],
            "wind_speed_10m_max": [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0],
            "wind_gusts_10m_max": [20.0, 22.0, 24.0, 26.0, 28.0, 30.0, 32.0],
            "wind_direction_10m_dominant": [90, 100, 110, 120, 130, 140, 150],
        }
    }


class OpenMeteoDailyTests(unittest.TestCase):
    def test_parse_open_meteo_daily_series(self) -> None:
        series = parse_open_meteo_daily_series(_sample_daily_payload())
        self.assertEqual(len(series), 7)
        self.assertEqual(series[0]["date"], "2026-07-04")
        self.assertEqual(series[0]["temp_max_c"], 28.0)
        self.assertEqual(series[0]["wind_max_kmh"], 12.0)
        self.assertEqual(series[0]["wind_direction_deg"], 90.0)

    def test_parse_daily_empty_when_missing(self) -> None:
        self.assertEqual(parse_open_meteo_daily_series({}), [])

    def test_enrich_daily_forecast_days(self) -> None:
        days = parse_open_meteo_daily_series(_sample_daily_payload())
        enriched = enrich_daily_forecast_days(days)
        self.assertEqual(len(enriched), 7)
        self.assertIn("day_label", enriched[0])
        self.assertIn("weather_label_tr", enriched[0])


class MarineConditionsTests(unittest.TestCase):
    def test_build_marine_conditions_sea_movement(self) -> None:
        marine = MarineBlockModel(
            wave_height_m=_consensus(0.8),
            ocean_current_velocity_mps=_consensus(0.25),
        )
        hourly = [
            HourlyForecastPointModel(time="06:00", wave_height_m=0.6),
            HourlyForecastPointModel(time="12:00", wave_height_m=0.9),
        ]
        payload = build_marine_conditions_payload(marine=marine, hourly_series=hourly)
        self.assertFalse(payload["tide_provider_available"])
        self.assertEqual(payload["display_mode"], "sea_movement")
        self.assertEqual(len(payload["hourly_wave_points"]), 2)
        self.assertEqual(payload["chart_label_tr"], "Dalga (m)")

    def test_build_marine_conditions_with_tide_points(self) -> None:
        marine = MarineBlockModel(wave_height_m=_consensus(0.5))
        tide_result = TideProviderResult(
            provider_available=True,
            provider_name="world_tides",
            points=[
                {"time": "06:00", "height_m": 0.4},
                {"time": "12:00", "height_m": 1.2},
            ],
        )
        payload = build_marine_conditions_payload(
            marine=marine,
            tide_result=tide_result,
        )
        self.assertTrue(payload["tide_provider_available"])
        self.assertEqual(payload["display_mode"], "tide")
        self.assertEqual(len(payload["points"]), 2)

    def test_tide_null_safe(self) -> None:
        marine = MarineBlockModel()
        payload = build_marine_conditions_payload(marine=marine, hourly_series=None)
        self.assertFalse(payload["tide_provider_available"])
        self.assertEqual(payload["display_mode"], "empty")


def _consensus(value: float):
    from marine_intelligence.models import ConsensusValueModel

    return ConsensusValueModel(
        final_value=value,
        unit="m",
        confidence=0.8,
        source_count=1,
        disagreement_level="low",
    )


if __name__ == "__main__":
    unittest.main()
