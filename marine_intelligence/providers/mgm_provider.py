from __future__ import annotations

from marine_intelligence.providers.base import MarineProviderSnapshot


class _StubProvider:
    provider_name: str

    def __init__(self, name: str, *, enabled: bool) -> None:
        self.provider_name = name
        self._enabled = enabled

    def fetch(self, lat: float, lon: float) -> MarineProviderSnapshot:
        if not self._enabled:
            return MarineProviderSnapshot(
                provider_name=self.provider_name,
                success=False,
                error="disabled",
            )
        return MarineProviderSnapshot(
            provider_name=self.provider_name,
            success=False,
            error="not_implemented",
        )


class MgmProvider(_StubProvider):
    def __init__(self, *, enabled: bool = False) -> None:
        super().__init__("mgm", enabled=enabled)


class WindyProvider(_StubProvider):
    def __init__(self, *, enabled: bool = False) -> None:
        super().__init__("windy", enabled=enabled)


class WindyAppProvider(_StubProvider):
    def __init__(self, *, enabled: bool = False) -> None:
        super().__init__("windy_app", enabled=enabled)


class PoseidonProvider(_StubProvider):
    def __init__(self, *, enabled: bool = False) -> None:
        super().__init__("poseidon", enabled=enabled)
