from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.concurrency import run_in_threadpool

from marine_intelligence.config import MarineIntelligenceConfig
from marine_intelligence.dependencies import (
    get_catch_intelligence_service,
    get_catch_record_store,
    get_marine_compare_service,
    get_marine_intelligence_config,
    get_marine_intelligence_service,
    get_spot_intelligence_service,
    get_spot_intelligence_store,
)
from marine_intelligence.catch_service import CatchIntelligenceService
from marine_intelligence.compare_service import MarineCompareService
from marine_intelligence.models import (
    BulkLearningSummariesRequestModel,
    BulkLearningSummariesResponseModel,
    CatchDeleteResponseModel,
    CatchListResponseModel,
    CreateCatchRequestModel,
    CreateCatchResponseModel,
    CreateSpotRequestModel,
    LearningSummaryModel,
    MarineCompareRequestModel,
    MarineCompareResponseModel,
    MarineCoordinateRequestModel,
    MarineCoordinateResponseModel,
    PatchCatchRequestModel,
    PatchSpotRequestModel,
    SpotDeleteResponseModel,
    SpotIntelligenceModel,
    SpotListResponseModel,
    SpotRefreshRequestModel,
    SpotRefreshResponseModel,
    UpdateCatchResponseModel,
)
from marine_intelligence.service import MarineIntelligenceService
from marine_intelligence.spot_service import SpotIntelligenceService
from marine_intelligence.storage.base import SpotIntelligenceStoreProtocol

marine_intelligence_router = APIRouter(prefix="/api/v1/marine_intelligence", tags=["marine-intelligence"])


def _ensure_marine_enabled(config: MarineIntelligenceConfig) -> None:
    if not config.marine_intelligence_enabled:
        raise HTTPException(status_code=503, detail="marine_intelligence_disabled")


def _ensure_saved_spots_enabled(config: MarineIntelligenceConfig) -> None:
    _ensure_marine_enabled(config)
    if not config.saved_spots_enabled:
        raise HTTPException(status_code=503, detail="saved_spots_disabled")


def _ensure_catch_intelligence_enabled(config: MarineIntelligenceConfig) -> None:
    _ensure_saved_spots_enabled(config)
    if not config.marine_catch_storage_enabled:
        raise HTTPException(status_code=503, detail="catch_intelligence_disabled")


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client is not None and request.client.host:
        return request.client.host
    return "unknown"


@marine_intelligence_router.post("/coordinate", response_model=MarineCoordinateResponseModel)
async def marine_coordinate_endpoint(
    request: Request,
    body: MarineCoordinateRequestModel,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    service: MarineIntelligenceService = Depends(get_marine_intelligence_service),
) -> MarineCoordinateResponseModel:
    _ensure_marine_enabled(config)
    return await run_in_threadpool(
        service.get_coordinate_intelligence,
        body.lat,
        body.lon,
        force_refresh=body.force_refresh,
        include_ai_comment=body.include_ai_comment,
        client_ip=_client_ip(request),
    )


@marine_intelligence_router.post("/compare", response_model=MarineCompareResponseModel)
async def marine_compare_endpoint(
    request: Request,
    body: MarineCompareRequestModel,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    compare_service: MarineCompareService = Depends(get_marine_compare_service),
) -> MarineCompareResponseModel:
    _ensure_marine_enabled(config)
    if not config.marine_compare_enabled:
        raise HTTPException(status_code=503, detail="marine_compare_disabled")
    result = await run_in_threadpool(
        compare_service.compare,
        body,
        client_ip=_client_ip(request),
    )
    if result is None:
        raise HTTPException(status_code=404, detail="spot_not_found")
    return result


@marine_intelligence_router.post("/saved_spots", response_model=SpotIntelligenceModel)
async def create_saved_spot(
    body: CreateSpotRequestModel,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    store: SpotIntelligenceStoreProtocol = Depends(get_spot_intelligence_store),
) -> SpotIntelligenceModel:
    _ensure_saved_spots_enabled(config)
    return await run_in_threadpool(
        store.create_spot,
        name=body.name,
        lat=body.lat,
        lon=body.lon,
        note=body.note,
        favorite=body.favorite,
        personal_tags=body.personal_tags,
    )


@marine_intelligence_router.get("/saved_spots", response_model=SpotListResponseModel)
async def list_saved_spots(
    favorite: Optional[bool] = Query(default=None),
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    store: SpotIntelligenceStoreProtocol = Depends(get_spot_intelligence_store),
) -> SpotListResponseModel:
    _ensure_saved_spots_enabled(config)
    spots = await run_in_threadpool(store.list_spots, favorite=favorite)
    return SpotListResponseModel(spots=spots, count=len(spots))


@marine_intelligence_router.patch("/saved_spots/{spot_id}", response_model=SpotIntelligenceModel)
async def patch_saved_spot(
    spot_id: str,
    body: PatchSpotRequestModel,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    store: SpotIntelligenceStoreProtocol = Depends(get_spot_intelligence_store),
) -> SpotIntelligenceModel:
    _ensure_saved_spots_enabled(config)
    updated = await run_in_threadpool(
        store.update_spot,
        spot_id,
        name=body.name,
        note=body.note,
        favorite=body.favorite,
        personal_tags=body.personal_tags,
    )
    if updated is None:
        raise HTTPException(status_code=404, detail="spot_not_found")
    return updated


@marine_intelligence_router.delete("/saved_spots/{spot_id}", response_model=SpotDeleteResponseModel)
async def delete_saved_spot(
    spot_id: str,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    spot_service: SpotIntelligenceService = Depends(get_spot_intelligence_service),
    catch_store=Depends(get_catch_record_store),
) -> SpotDeleteResponseModel:
    _ensure_saved_spots_enabled(config)
    catch_store_arg = catch_store if config.marine_catch_storage_enabled else None
    deleted, deleted_catches = await run_in_threadpool(
        spot_service.delete_spot_with_catches,
        spot_id,
        catch_store=catch_store_arg,
    )
    if not deleted:
        raise HTTPException(status_code=404, detail="spot_not_found")
    return SpotDeleteResponseModel(
        deleted=True,
        id=spot_id,
        deleted_catches=deleted_catches,
    )


@marine_intelligence_router.post("/saved_spots/{spot_id}/refresh", response_model=SpotRefreshResponseModel)
async def refresh_saved_spot(
    spot_id: str,
    body: SpotRefreshRequestModel,
    request: Request,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    spot_service: SpotIntelligenceService = Depends(get_spot_intelligence_service),
) -> SpotRefreshResponseModel:
    _ensure_saved_spots_enabled(config)
    result = await run_in_threadpool(
        spot_service.refresh_spot,
        spot_id,
        force_refresh=body.force_refresh,
        include_ai_comment=body.include_ai_comment,
        client_ip=_client_ip(request),
    )
    if result is None:
        raise HTTPException(status_code=404, detail="spot_not_found")
    return result


@marine_intelligence_router.post(
    "/saved_spots/{spot_id}/catch",
    response_model=CreateCatchResponseModel,
)
async def create_catch_for_spot(
    spot_id: str,
    body: CreateCatchRequestModel,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    catch_service: CatchIntelligenceService = Depends(get_catch_intelligence_service),
) -> CreateCatchResponseModel:
    _ensure_catch_intelligence_enabled(config)
    result = await run_in_threadpool(catch_service.create_catch, spot_id, body)
    if result is None:
        raise HTTPException(status_code=404, detail="spot_not_found")
    return result


@marine_intelligence_router.get(
    "/saved_spots/{spot_id}/catches",
    response_model=CatchListResponseModel,
)
async def list_catches_for_spot(
    spot_id: str,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    catch_service: CatchIntelligenceService = Depends(get_catch_intelligence_service),
) -> CatchListResponseModel:
    _ensure_catch_intelligence_enabled(config)
    result = await run_in_threadpool(catch_service.list_catches, spot_id)
    if result is None:
        raise HTTPException(status_code=404, detail="spot_not_found")
    return result


@marine_intelligence_router.delete(
    "/catches/{catch_id}",
    response_model=CatchDeleteResponseModel,
)
async def delete_catch(
    catch_id: str,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    catch_service: CatchIntelligenceService = Depends(get_catch_intelligence_service),
) -> CatchDeleteResponseModel:
    _ensure_catch_intelligence_enabled(config)
    result = await run_in_threadpool(catch_service.delete_catch, catch_id)
    if result is None:
        raise HTTPException(status_code=404, detail="catch_not_found")
    return result


@marine_intelligence_router.patch(
    "/catches/{catch_id}",
    response_model=UpdateCatchResponseModel,
)
async def patch_catch(
    catch_id: str,
    body: PatchCatchRequestModel,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    catch_service: CatchIntelligenceService = Depends(get_catch_intelligence_service),
) -> UpdateCatchResponseModel:
    _ensure_catch_intelligence_enabled(config)
    result = await run_in_threadpool(catch_service.update_catch, catch_id, body)
    if result is None:
        raise HTTPException(status_code=404, detail="catch_not_found")
    return result


@marine_intelligence_router.post(
    "/saved_spots/learning_summaries",
    response_model=BulkLearningSummariesResponseModel,
)
async def bulk_learning_summaries(
    body: BulkLearningSummariesRequestModel,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    catch_service: CatchIntelligenceService = Depends(get_catch_intelligence_service),
) -> BulkLearningSummariesResponseModel:
    _ensure_catch_intelligence_enabled(config)
    if not config.bulk_learning_summary_enabled:
        raise HTTPException(status_code=503, detail="bulk_learning_summary_disabled")
    return await run_in_threadpool(catch_service.bulk_learning_summaries, body.spot_ids)


@marine_intelligence_router.get(
    "/saved_spots/{spot_id}/learning_summary",
    response_model=LearningSummaryModel,
)
async def learning_summary_for_spot(
    spot_id: str,
    config: MarineIntelligenceConfig = Depends(get_marine_intelligence_config),
    catch_service: CatchIntelligenceService = Depends(get_catch_intelligence_service),
    store: SpotIntelligenceStoreProtocol = Depends(get_spot_intelligence_store),
) -> LearningSummaryModel:
    _ensure_catch_intelligence_enabled(config)
    spot = await run_in_threadpool(store.get_spot, spot_id)
    if spot is None:
        raise HTTPException(status_code=404, detail="spot_not_found")
    return await run_in_threadpool(catch_service.build_learning_summary, spot_id, spot=spot)
