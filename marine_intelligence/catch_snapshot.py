from __future__ import annotations

from typing import Any, Dict, Optional


def snapshots_from_last_report(last_report: Optional[Dict[str, Any]]) -> Dict[str, Optional[Dict[str, Any]]]:
    """Spot last_report içinden catch kaydı snapshot alanlarını üretir."""
    if not last_report:
        return {
            "weather_snapshot": None,
            "marine_snapshot": None,
            "decision_snapshot": None,
            "scenario_snapshot": None,
            "moon_snapshot": None,
        }
    return {
        "weather_snapshot": last_report.get("weather"),
        "marine_snapshot": last_report.get("marine"),
        "decision_snapshot": last_report.get("decision"),
        "scenario_snapshot": last_report.get("scenario"),
        "moon_snapshot": last_report.get("astronomy"),
    }
