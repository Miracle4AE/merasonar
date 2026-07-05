from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.concurrency import run_in_threadpool

from ai_assistant.config import AiAssistantConfig
from ai_assistant.dependencies import (
    build_ai_assistant_service,
    get_ai_assistant_config,
    get_ai_quota_store,
    get_ai_rate_limiter,
    get_ai_telemetry_store,
)
from ai_assistant.identity import resolve_client_identity
from ai_assistant.models import (
    AiFishingAssistantRequestModel,
    AiFishingAssistantResponseModel,
    AiUsageSummaryResponseModel,
)
from ai_assistant.quota import AiQuotaStoreProtocol, check_ai_quota
from ai_assistant.rate_limiter import AiRateLimiterProtocol, check_ai_rate_limit
from ai_assistant.service import AiAssistantService
from ai_assistant.telemetry_store import AiTelemetryStoreProtocol
from ai_assistant.usage_summary import build_usage_summary, verify_usage_admin_key

ai_assistant_router = APIRouter(prefix="/api/v1", tags=["ai-assistant"])


def _get_ai_assistant_service() -> AiAssistantService:
    return build_ai_assistant_service()


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client is not None and request.client.host:
        return request.client.host
    return "unknown"


def _admin_key_from_request(request: Request, query_key: Optional[str]) -> Optional[str]:
    header = request.headers.get("x-ai-usage-admin-key")
    if header and header.strip():
        return header.strip()
    if query_key and query_key.strip():
        return query_key.strip()
    return None


@ai_assistant_router.post(
    "/ai_fishing_assistant",
    response_model=AiFishingAssistantResponseModel,
)
async def ai_fishing_assistant_endpoint(
    request: Request,
    body: AiFishingAssistantRequestModel,
    service: AiAssistantService = Depends(_get_ai_assistant_service),
    config: AiAssistantConfig = Depends(get_ai_assistant_config),
    limiter: AiRateLimiterProtocol = Depends(get_ai_rate_limiter),
    quota_store: AiQuotaStoreProtocol = Depends(get_ai_quota_store),
) -> AiFishingAssistantResponseModel:
    """
    Mevcut analiz özetini AI ile yorumlar — analiz pipeline'ına dokunmaz.
    """
    client_ip = _client_ip(request)
    resolved = resolve_client_identity(body.client_identity, client_ip)

    rl = check_ai_rate_limit(config, limiter, client_ip)
    if not rl.allowed:
        raise HTTPException(status_code=429, detail="rate_limit_exceeded")

    quota = check_ai_quota(
        config,
        quota_store,
        resolved.client_key,
        is_premium=resolved.is_premium,
    )
    if not quota.allowed:
        raise HTTPException(status_code=429, detail="quota_exceeded")

    rate_remaining = rl.remaining if config.ai_rate_limit_enabled else None
    quota_remaining = quota.remaining if config.ai_quota_enabled else None

    return await run_in_threadpool(
        service.handle,
        body,
        client_identity=resolved,
        rate_limit_remaining=rate_remaining,
        quota_remaining=quota_remaining,
    )


@ai_assistant_router.get(
    "/ai_usage_summary",
    response_model=AiUsageSummaryResponseModel,
)
async def ai_usage_summary_endpoint(
    request: Request,
    device_id: Optional[str] = Query(default=None),
    user_id: Optional[str] = Query(default=None),
    admin_key: Optional[str] = Query(default=None),
    config: AiAssistantConfig = Depends(get_ai_assistant_config),
    telemetry_store: AiTelemetryStoreProtocol = Depends(get_ai_telemetry_store),
    quota_store: AiQuotaStoreProtocol = Depends(get_ai_quota_store),
) -> AiUsageSummaryResponseModel:
    provided = _admin_key_from_request(request, admin_key)
    if not verify_usage_admin_key(config, provided_key=provided):
        raise HTTPException(status_code=403, detail="forbidden")

    summary = build_usage_summary(
        config,
        telemetry_store,
        quota_store,
        device_id=device_id,
        user_id=user_id,
        client_ip=_client_ip(request),
    )
    return AiUsageSummaryResponseModel.model_validate(summary)
