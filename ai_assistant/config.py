from __future__ import annotations



import os

from dataclasses import dataclass

from typing import Optional





def _env_bool(name: str, default: bool) -> bool:

    raw = os.getenv(name)

    if raw is None:

        return default

    return raw.strip().lower() in {"1", "true", "yes", "on"}





def _env_float(name: str, default: float) -> float:

    raw = os.getenv(name)

    if raw is None or not raw.strip():

        return default

    return float(raw)





def _env_int(name: str, default: int) -> int:

    raw = os.getenv(name)

    if raw is None or not raw.strip():

        return default

    return int(raw)





def _env_str(name: str, default: Optional[str] = None) -> Optional[str]:

    raw = os.getenv(name)

    if raw is None:

        return default

    stripped = raw.strip()

    return stripped if stripped else default





@dataclass(frozen=True)

class AiAssistantConfig:

    """AI Assistant yapılandırması — yalnızca ortam değişkenlerinden okunur."""



    openai_api_key: Optional[str]

    openai_model: Optional[str]

    ai_assistant_enabled: bool

    ai_timeout_seconds: float

    ai_max_tokens: int

    ai_temperature: float

    prompt_version: str

    vision_enabled: bool

    streaming_enabled: bool

    cache_ttl_seconds: int

    cost_input_per_1m: float

    cost_output_per_1m: float

    ai_rate_limit_enabled: bool

    ai_rate_limit_per_minute: int

    ai_max_estimated_cost_per_request_usd: float

    ai_quota_enabled: bool

    ai_free_daily_limit: int

    ai_premium_daily_limit: int

    ai_telemetry_persist_enabled: bool

    ai_telemetry_jsonl_path: str

    ai_usage_admin_key: Optional[str]



    @classmethod

    def from_env(cls) -> AiAssistantConfig:

        return cls(

            openai_api_key=_env_str("OPENAI_API_KEY"),

            openai_model=_env_str("OPENAI_MODEL"),

            ai_assistant_enabled=_env_bool("AI_ASSISTANT_ENABLED", default=False),

            ai_timeout_seconds=_env_float("AI_TIMEOUT_SECONDS", default=25.0),

            ai_max_tokens=_env_int("AI_MAX_TOKENS", default=1800),

            ai_temperature=_env_float("AI_TEMPERATURE", default=0.2),

            prompt_version=_env_str("PROMPT_VERSION", default="v1") or "v1",

            vision_enabled=_env_bool("VISION_ENABLED", default=False),

            streaming_enabled=_env_bool("STREAMING_ENABLED", default=False),

            cache_ttl_seconds=_env_int("CACHE_TTL", default=900),

            cost_input_per_1m=_env_float("AI_COST_INPUT_PER_1M", default=0.0),

            cost_output_per_1m=_env_float("AI_COST_OUTPUT_PER_1M", default=0.0),

            ai_rate_limit_enabled=_env_bool("AI_RATE_LIMIT_ENABLED", default=False),

            ai_rate_limit_per_minute=_env_int("AI_RATE_LIMIT_PER_MINUTE", default=30),

            ai_max_estimated_cost_per_request_usd=_env_float(

                "AI_MAX_ESTIMATED_COST_PER_REQUEST_USD",

                default=0.0,

            ),

            ai_quota_enabled=_env_bool("AI_QUOTA_ENABLED", default=False),

            ai_free_daily_limit=_env_int("AI_FREE_DAILY_LIMIT", default=10),

            ai_premium_daily_limit=_env_int("AI_PREMIUM_DAILY_LIMIT", default=100),

            ai_telemetry_persist_enabled=_env_bool(

                "AI_TELEMETRY_PERSIST_ENABLED",

                default=False,

            ),

            ai_telemetry_jsonl_path=_env_str(

                "AI_TELEMETRY_JSONL_PATH",

                default="run_logs/ai_telemetry.jsonl",

            )

            or "run_logs/ai_telemetry.jsonl",

            ai_usage_admin_key=_env_str("AI_USAGE_ADMIN_KEY"),

        )



    def is_openai_configured(self) -> bool:

        return bool(self.openai_api_key and self.openai_model)



    def is_operational(self) -> bool:

        return self.ai_assistant_enabled and self.is_openai_configured()



    def health_payload(self) -> dict[str, bool | str | float | int]:

        return {

            "enabled": self.ai_assistant_enabled,

            "configured": self.is_openai_configured(),

            "vision_enabled": self.vision_enabled,

            "streaming_enabled": self.streaming_enabled,

            "prompt_version": self.prompt_version,

            "rate_limit_enabled": self.ai_rate_limit_enabled,

            "model_configured": bool(self.openai_model),

            "quota_enabled": self.ai_quota_enabled,

            "telemetry_persist_enabled": self.ai_telemetry_persist_enabled,

            "usage_summary_enabled": True,

            "openai_key_present": bool(self.openai_api_key),

            "openai_model": self.openai_model or "",

            "ai_runtime_ready": self.is_operational(),

            "timeout_seconds": self.ai_timeout_seconds,

            "cache_ttl_seconds": self.cache_ttl_seconds,

        }



    def estimate_cost_usd(

        self,

        *,

        input_tokens: int,

        output_tokens: int,

    ) -> float:

        if self.cost_input_per_1m <= 0.0 and self.cost_output_per_1m <= 0.0:

            return 0.0

        in_cost = (max(0, input_tokens) / 1_000_000.0) * self.cost_input_per_1m

        out_cost = (max(0, output_tokens) / 1_000_000.0) * self.cost_output_per_1m

        return round(in_cost + out_cost, 6)


