from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Protocol


@dataclass
class MarineProviderSnapshot:
    provider_name: str
    success: bool
    error: Optional[str] = None
    weather: Dict[str, Optional[float]] = field(default_factory=dict)
    wind: Dict[str, Optional[float]] = field(default_factory=dict)
    marine: Dict[str, Optional[float]] = field(default_factory=dict)
    astronomy: Dict[str, Any] = field(default_factory=dict)
    hourly_series: List[Dict[str, Any]] = field(default_factory=list)
    daily_series: List[Dict[str, Any]] = field(default_factory=list)


class MarineProviderProtocol(Protocol):
    @property
    def provider_name(self) -> str:
        ...

    def fetch(self, lat: float, lon: float) -> MarineProviderSnapshot:
        ...
