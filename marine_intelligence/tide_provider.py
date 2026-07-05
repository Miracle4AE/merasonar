"""Gelgit sağlayıcı abstraction — WorldTides (API key gerekir)."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

FetchJsonFn = Callable[[str, float], Dict[str, Any]]


@dataclass(frozen=True)
class TideProviderResult:
    provider_available: bool
    provider_name: Optional[str] = None
    points: List[Dict[str, Any]] = field(default_factory=list)
    note_tr: Optional[str] = None


class WorldTidesTideProvider:
    provider_name = "world_tides"

    def __init__(
        self,
        *,
        enabled: bool = False,
        api_key: str = "",
        base_url: str = "https://www.worldtides.info/api/v3",
        timeout_seconds: float = 10.0,
        fetch_json: Optional[FetchJsonFn] = None,
    ) -> None:
        self._enabled = enabled
        self._api_key = api_key.strip()
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout_seconds
        self._fetch_json = fetch_json or self._default_fetch_json

    def fetch(self, lat: float, lon: float) -> TideProviderResult:
        if not self._enabled or not self._api_key:
            return TideProviderResult(
                provider_available=False,
                note_tr="Gelgit sağlayıcısı bağlı değil.",
            )
        try:
            params = {
                "heights": "",
                "lat": lat,
                "lon": lon,
                "days": 1,
                "key": self._api_key,
            }
            url = f"{self._base_url}?{urlencode(params)}"
            payload = self._fetch_json(url, self._timeout)
            heights = payload.get("heights") or []
            points: List[Dict[str, Any]] = []
            for item in heights:
                if not isinstance(item, dict):
                    continue
                dt = item.get("dt")
                height = item.get("height")
                if dt is None or height is None:
                    continue
                from datetime import datetime, timezone

                ts = datetime.fromtimestamp(float(dt), tz=timezone.utc)
                points.append(
                    {
                        "time": ts.strftime("%H:%M"),
                        "height_m": round(float(height), 2),
                        "type": "normal",
                    }
                )
            if len(points) < 2:
                return TideProviderResult(
                    provider_available=False,
                    provider_name=self.provider_name,
                    note_tr="Gelgit sağlayıcısı yanıt verdi ancak yeterli nokta yok.",
                )
            return TideProviderResult(
                provider_available=True,
                provider_name=self.provider_name,
                points=points[:48],
            )
        except Exception as exc:  # noqa: BLE001
            return TideProviderResult(
                provider_available=False,
                provider_name=self.provider_name,
                note_tr=f"Gelgit sağlayıcısı hatası: {exc}",
            )

    @staticmethod
    def _default_fetch_json(url: str, timeout: float) -> Dict[str, Any]:
        req = Request(url, headers={"User-Agent": "MeraSonar-MarineIntelligence/1.0"})
        with urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
