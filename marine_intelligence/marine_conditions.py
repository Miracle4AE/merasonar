"""Deniz koşulları özeti — gerçek dalga/akıntı/gelgit; sahte veri üretmez."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from marine_intelligence.models import HourlyForecastPointModel, MarineBlockModel
from marine_intelligence.tide_provider import TideProviderResult


def build_marine_conditions_payload(
    *,
    marine: MarineBlockModel,
    hourly_series: Optional[List[HourlyForecastPointModel]] = None,
    tide_result: Optional[TideProviderResult] = None,
) -> Dict[str, Any]:
    """Gelgit sağlayıcısı varsa tide points; yoksa dalga/akıntı modu."""
    wave = marine.wave_height_m.final_value if marine.wave_height_m else None
    current = (
        marine.ocean_current_velocity_mps.final_value
        if marine.ocean_current_velocity_mps
        else None
    )
    current_dir = (
        marine.ocean_current_direction_deg.final_value
        if marine.ocean_current_direction_deg
        else None
    )

    hourly_wave_points: List[Dict[str, Any]] = []
    hourly_current_points: List[Dict[str, Any]] = []
    if hourly_series:
        for pt in hourly_series[:24]:
            if pt.wave_height_m is not None:
                hourly_wave_points.append(
                    {
                        "time": pt.time,
                        "wave_height_m": pt.wave_height_m,
                    }
                )
            current_mps = getattr(pt, "ocean_current_velocity_mps", None)
            if current_mps is not None:
                hourly_current_points.append(
                    {
                        "time": pt.time,
                        "current_speed_mps": current_mps,
                    }
                )

    tide_points: List[Dict[str, Any]] = []
    provider_available = False
    provider_name: Optional[str] = None
    note_tr: Optional[str] = None

    if tide_result is not None:
        provider_available = tide_result.provider_available
        provider_name = tide_result.provider_name
        note_tr = tide_result.note_tr
        if tide_result.provider_available and tide_result.points:
            tide_points = list(tide_result.points)

    if tide_points:
        display_mode = "tide"
        chart_label_tr = "Gelgit (m)"
        context_tr = None
    elif hourly_wave_points or hourly_current_points or wave is not None or current is not None:
        display_mode = "sea_movement"
        chart_label_tr = "Dalga (m)"
        context_tr = (
            "Gelgit sağlayıcısı bağlı değil. "
            "Bu kart dalga ve akıntı verileriyle deniz hareketini gösteriyor."
        )
    else:
        display_mode = "empty"
        chart_label_tr = None
        context_tr = "Bu koordinatta gelgit/akıntı sağlayıcı verisi yok."

    summary_tr: Optional[str] = None
    if wave is not None:
        summary_tr = f"Dalga {wave:.1f} m"
        if current is not None:
            summary_tr += f" · Akıntı {current:.2f} m/s"

    return {
        "tide_provider_available": provider_available,
        "provider_name": provider_name,
        "display_mode": display_mode,
        "chart_label_tr": chart_label_tr,
        "summary_tr": summary_tr,
        "context_tr": context_tr,
        "note_tr": note_tr,
        "ocean_current_velocity_mps": current,
        "ocean_current_direction_deg": current_dir,
        "wave_height_m": wave,
        "points": tide_points,
        "hourly_wave_points": hourly_wave_points,
        "hourly_current_points": hourly_current_points,
    }
