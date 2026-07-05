from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional


def _load_env_file() -> None:
    """Proje kökündeki .env dosyasını yükle (os.environ'da yoksa)."""
    env_path = Path(__file__).resolve().parent / ".env"
    if not env_path.is_file():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        if key and os.getenv(key) is None:
            os.environ[key] = value


_load_env_file()

from ai_assistant.openai_errors import log_ai_config_startup
from ai_assistant.dependencies import get_ai_assistant_config

log_ai_config_startup(get_ai_assistant_config())

from fastapi import APIRouter, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel, ConfigDict, ValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from bathymetry_analyzer import BathymetryAnalyzer
from geo_navigation import PrecisionGPS
from marine_data_client import MarineDataClient
from maritime_orchestrator import FishingHotspotManager
from live_fishing_score import compute_live_fishing_score
from ai_assistant.dependencies import get_ai_assistant_config
from ai_assistant.router import ai_assistant_router
from marine_intelligence.dependencies import get_marine_intelligence_config
from marine_intelligence.router import marine_intelligence_router

_RUN_LOGS_DIR = Path(__file__).resolve().parent / "run_logs"


class GeoPointModel(BaseModel):
    lat: Optional[float] = None
    lon: Optional[float] = None


class ImageGeoBoundsModel(BaseModel):
    top_left: Optional[GeoPointModel] = None
    bottom_right: Optional[GeoPointModel] = None
    control_points: Optional[List[Any]] = None
    boat_pixel_anchor: Optional[Dict[str, Any]] = None
    coordinate_mode_hint: Optional[str] = None


class SpeciesMatchModel(BaseModel):
    species: str
    confidence: str
    reason: str


class SeaStateModel(BaseModel):
    wave_height_m: Optional[float] = None
    water_temperature_c: Optional[float] = None
    wind_speed_knots: Optional[float] = None
    wind_direction_deg: Optional[float] = None
    current_speed_knots: Optional[float] = None
    current_direction_deg: Optional[float] = None
    pressure_hpa: Optional[float] = None
    ocean_current_velocity_mps: Optional[float] = None
    source: Optional[str] = None
    fallback: Optional[bool] = None
    reason: Optional[str] = None

    model_config = ConfigDict(extra="allow")


class HotspotModel(BaseModel):
    id: int
    feature_type: str
    pixel_centroid: Dict[str, float]
    geo_coordinate: Optional[GeoPointModel] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_m: Optional[float] = None
    bearing_deg: Optional[float] = None
    score: float
    classification: str
    reasoning: List[str]
    reasoning_text: Optional[str] = None
    fish_prediction: Optional[str] = None
    regional_species_context: Optional[str] = None
    species_match: Optional[List[SpeciesMatchModel]] = None
    final_fishing_score: Optional[float] = None
    recommendation_rank: Optional[int] = None
    supporting_metrics: Dict[str, Any]
    rank: int
    rank_overall: int
    rank_by_score_then_distance: int
    rank_by_proximity: int
    bbox: Optional[Dict[str, Any]] = None
    area_px: Optional[int] = None
    sea_state: Optional[SeaStateModel] = None
    fishing_advice: Optional[Dict[str, Any]] = None

    model_config = ConfigDict(extra="allow")


class BoatStateModel(BaseModel):
    raw_gps: Optional[GeoPointModel] = None
    smoothed_gps: Optional[GeoPointModel] = None
    navigation_anchor_geo: Optional[GeoPointModel] = None
    pixel_anchor: Optional[Dict[str, Any]] = None
    boat_pixel_anchor: Optional[Dict[str, float]] = None
    boat_anchor_confidence: float = 0.0
    boat_anchor_source: str = "gps_fallback"
    filter_state: Dict[str, Any]


class LiveFishingScoreRequestModel(BaseModel):
    current_lat: float
    current_lon: float
    gps_accuracy_m: Optional[float] = None
    latest_hotspots: Optional[List[Dict[str, Any]]] = None
    coordinate_mode: Optional[str] = None

    model_config = ConfigDict(extra="allow")


class AnalyzeFishingZoneResponseModel(BaseModel):
    image_path: str
    image_size: Dict[str, int]
    boat: BoatStateModel
    image_geo_bounds: ImageGeoBoundsModel
    counts: Dict[str, int]
    ranked_hotspots: List[HotspotModel]
    diagnostics: Dict[str, Any]
    top_recommendations: Optional[List[int]] = None
    session_advice: Optional[str] = None
    coordinate_mode: Optional[str] = None
    is_geo_referenced: Optional[bool] = None
    calibration_quality: Optional[float] = None
    transform_confidence: Optional[float] = None
    geo_map_display_allowed: Optional[bool] = None
    user_warning_tr: Optional[str] = None
    calibration_reliability: Optional[str] = None

    model_config = ConfigDict(extra="allow")


app = FastAPI(
    title="Maritime Fishing Zone Analyzer",
    version="1.0.0",
    description="Analyze nautical charts and return ranked, enriched fishing hotspots.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

api_v1_router = APIRouter(prefix="/api/v1", tags=["v1"])


@app.exception_handler(StarletteHTTPException)
async def _sanitize_api_http_exceptions(
    request: Request, exc: StarletteHTTPException
) -> JSONResponse:
    """Ham ``detail`` alanını uygulama istemcisine sızdırmamak için /api için sade yapı döndür."""
    if request.url.path.startswith("/api/"):
        if exc.status_code == 404:
            return JSONResponse(status_code=404, content={"error": "not_found"})
        if exc.status_code == 429:
            detail = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
            if detail == "quota_exceeded":
                return JSONResponse(status_code=429, content={"error": "quota_exceeded"})
            return JSONResponse(status_code=429, content={"error": "rate_limit_exceeded"})
        if exc.status_code == 403:
            return JSONResponse(status_code=403, content={"error": "forbidden"})
        detail = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
        if request.url.path.endswith("/analyze_fishing_zone") and detail:
            return JSONResponse(
                status_code=exc.status_code,
                content={"error": "request_failed", "detail": detail},
            )
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": "request_failed"},
        )
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail if isinstance(exc.detail, str) else str(exc.detail)},
    )


@app.exception_handler(RequestValidationError)
async def _sanitize_api_validation_errors(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    if request.url.path.startswith("/api/"):
        return JSONResponse(status_code=422, content={"error": "validation_error"})
    return JSONResponse(
        status_code=422,
        content=jsonable_encoder({"detail": exc.errors()}),
    )


def _parse_image_geo_bounds(raw_value: str) -> Dict[str, Any]:
    try:
        parsed = json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=422, detail=f"Invalid image_geo_bounds JSON: {exc}") from exc

    try:
        model = ImageGeoBoundsModel(**parsed)
    except ValidationError as exc:
        raise HTTPException(status_code=422, detail=f"Invalid image_geo_bounds schema: {exc.errors()}") from exc

    out: Dict[str, Any] = {
        "control_points": model.control_points,
        "boat_pixel_anchor": model.boat_pixel_anchor,
        "coordinate_mode_hint": model.coordinate_mode_hint,
    }
    if model.top_left is not None:
        out["top_left"] = {"lat": model.top_left.lat, "lon": model.top_left.lon}
    if model.bottom_right is not None:
        out["bottom_right"] = {
            "lat": model.bottom_right.lat,
            "lon": model.bottom_right.lon,
        }
    return out


def _build_hotspot_manager() -> FishingHotspotManager:
    return FishingHotspotManager(
        bathymetry_analyzer=BathymetryAnalyzer(),
        coordinate_mapper=None,
        precision_gps=PrecisionGPS(),
        marine_data_client=MarineDataClient(),
    )


@app.get("/health")
async def health() -> Dict[str, Any]:
    """Flutter keşfi bu yanıttaki ``service`` alanı ile sunucuyu doğrular."""
    return {
        "status": "ok",
        "service": "MeraSonar API",
        "version": "1.0.0",
        "ai_assistant": get_ai_assistant_config().health_payload(),
        "marine_intelligence": get_marine_intelligence_config().health_payload(),
    }


@api_v1_router.post("/live_fishing_score")
async def live_fishing_score_endpoint(body: LiveFishingScoreRequestModel) -> Dict[str, Any]:
    """
    Probabilistic live score from GPS and optional last-analyzed hotspots (georeferenced charts only).
    """
    return compute_live_fishing_score(body.model_dump())


@api_v1_router.post("/analyze_fishing_zone")
async def analyze_fishing_zone(
    chart_image: UploadFile = File(...),
    current_lat: float = Form(...),
    current_lon: float = Form(...),
    image_geo_bounds: str = Form(..., description="JSON string with top_left and bottom_right lat/lon"),
    enrich_data: bool = Form(True),
    debug: bool = Form(False),
    debug_show_all_labels: bool = Form(False),
    debug_overlay_zoom: float = Form(1.0),
) -> AnalyzeFishingZoneResponseModel:
    if not chart_image.filename:
        raise HTTPException(status_code=400, detail="Uploaded file must have a filename.")

    bounds = _parse_image_geo_bounds(image_geo_bounds)
    suffix = Path(chart_image.filename).suffix or ".png"

    overlay_output_path = str(_RUN_LOGS_DIR / "image_space_hotspot_overlay.png")
    temp_file_path = ""

    try:
        chunks: List[bytes] = []
        while True:
            chunk = await chart_image.read(1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        file_bytes = b"".join(chunks)

        if debug:
            _RUN_LOGS_DIR.mkdir(parents=True, exist_ok=True)
            processing_path = str(_RUN_LOGS_DIR / f"debug_input_chart{suffix}")
            Path(processing_path).write_bytes(file_bytes)
        else:
            with tempfile.NamedTemporaryFile(prefix="chart_", suffix=suffix, delete=False) as tmp:
                temp_file_path = tmp.name
                tmp.write(file_bytes)
            processing_path = temp_file_path

        manager = _build_hotspot_manager()
        result = await run_in_threadpool(
            manager.process_new_chart_and_state,
            processing_path,
            float(current_lat),
            float(current_lon),
            bounds,
            bool(enrich_data),
            debug_save_image_space_overlay=bool(debug),
            debug_overlay_output_path=overlay_output_path if debug else None,
            debug_overlay_show_all_labels=bool(debug_show_all_labels),
            debug_overlay_zoom_scale=float(debug_overlay_zoom),
        )
        return result
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        from maritime_orchestrator import MaritimeOrchestrationError

        if isinstance(exc, MaritimeOrchestrationError):
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        raise HTTPException(status_code=500, detail=f"Analysis pipeline failed: {exc}") from exc
    finally:
        try:
            await chart_image.close()
        finally:
            if temp_file_path and os.path.exists(temp_file_path):
                os.remove(temp_file_path)


app.include_router(api_v1_router)
app.include_router(ai_assistant_router)
app.include_router(marine_intelligence_router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
