from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional

from marine_intelligence.config import MarineIntelligenceConfig

_DEFAULT_WEIGHTS: Dict[str, float] = {
    "open_meteo": 1.0,
    "astronomy_local": 0.8,
    "mgm": 0.9,
    "windy": 0.85,
    "windy_app": 0.75,
    "poseidon": 0.7,
}

_ALL_PROVIDER_NAMES = tuple(_DEFAULT_WEIGHTS.keys())


@dataclass
class ProviderReliability:
    provider_name: str
    static_weight: float
    runtime_confidence: float = 0.75
    last_success: Optional[datetime] = None
    last_failure: Optional[datetime] = None
    success_count: int = 0
    failure_count: int = 0
    enabled: bool = True
    disabled_reason: Optional[str] = None

    @property
    def weight(self) -> float:
        return self.static_weight

    @property
    def confidence(self) -> float:
        return self.runtime_confidence

    @property
    def effective_weight(self) -> float:
        if not self.enabled:
            return 0.0
        return round(self.static_weight * self.runtime_confidence, 4)


@dataclass
class _ProviderRuntimeState:
    last_success: Optional[datetime] = None
    last_failure: Optional[datetime] = None
    success_count: int = 0
    failure_count: int = 0


class ProviderReliabilityRegistry:
    def __init__(self, config: MarineIntelligenceConfig) -> None:
        self._config = config
        self._state: Dict[str, _ProviderRuntimeState] = {
            name: _ProviderRuntimeState() for name in _ALL_PROVIDER_NAMES
        }

    def record_success(self, provider_name: str) -> None:
        state = self._state.setdefault(provider_name, _ProviderRuntimeState())
        state.last_success = datetime.now(timezone.utc)
        state.success_count += 1

    def record_failure(self, provider_name: str) -> None:
        state = self._state.setdefault(provider_name, _ProviderRuntimeState())
        state.last_failure = datetime.now(timezone.utc)
        state.failure_count += 1

    @staticmethod
    def compute_runtime_confidence(
        *,
        success_count: int,
        failure_count: int,
        enabled: bool,
    ) -> float:
        if not enabled:
            return 0.0
        total = success_count + failure_count
        if total == 0:
            return 0.75
        success_rate = success_count / total
        return round(min(0.95, max(0.3, 0.35 + 0.6 * success_rate)), 2)

    def _disabled_reason(self, provider_name: str, enabled: bool) -> Optional[str]:
        if enabled:
            return None
        if provider_name not in self._config.enabled_provider_names():
            return "disabled_by_config"
        return "disabled"

    def get(self, provider_name: str) -> ProviderReliability:
        enabled = provider_name in self._config.enabled_provider_names()
        state = self._state.setdefault(provider_name, _ProviderRuntimeState())
        runtime = self.compute_runtime_confidence(
            success_count=state.success_count,
            failure_count=state.failure_count,
            enabled=enabled,
        )
        return ProviderReliability(
            provider_name=provider_name,
            static_weight=_DEFAULT_WEIGHTS.get(provider_name, 0.5),
            runtime_confidence=runtime,
            last_success=state.last_success,
            last_failure=state.last_failure,
            success_count=state.success_count,
            failure_count=state.failure_count,
            enabled=enabled,
            disabled_reason=self._disabled_reason(provider_name, enabled),
        )

    def list_enabled(self) -> List[ProviderReliability]:
        return [self.get(name) for name in self._config.enabled_provider_names()]

    def list_all(self) -> List[ProviderReliability]:
        return [self.get(name) for name in _ALL_PROVIDER_NAMES]

    def fingerprint(self) -> str:
        """Cache key parçası — provider set + statik ağırlıklar."""
        parts: List[str] = []
        for name in sorted(self._config.enabled_provider_names()):
            rel = self.get(name)
            parts.append(f"{name}:{rel.static_weight:.2f}")
        return "w-" + "|".join(parts) if parts else "w-none"
