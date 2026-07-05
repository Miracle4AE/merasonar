from __future__ import annotations

import logging
import math
from math import isfinite
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple

from bathymetry_analyzer import BathymetryAnalyzer
from geo_navigation import (
    CoordinateMapper,
    GeoPoint,
    PrecisionGPS,
    calculate_bearing_and_distance,
)
from marine_data_client import MarineDataClient
from image_space_overlay_export import DEFAULT_OVERLAY_MAX_LABELED_RANKS, default_overlay_png_path
from fishing_reasoning_text import apply_reasoning_text_to_hotspots
from species_structure_match import compute_species_matches
from fishing_recommendation_ranking import attach_fishing_recommendation_metrics
from session_advice import build_session_advice

_logger = logging.getLogger(__name__)

# Dünya haritasında geo mera işaretleri: kalibrasyon kalitesi eşikleri (API contract ile uyumlu).
GEO_WORLD_MAP_MIN_TRANSFORM_QUALITY = 0.28
GEO_WORLD_MAP_MAX_GEOREFERENCE_ERROR_M = 42.0

_IMAGE_SPACE_CALIBRATION_HINT_TR = (
    "Bu analiz fotoğraf üzerindedir; gerçek dünya konumu olarak gösterilemez. "
    "Haritada mera görmek için en az 3 geçerli kontrol noktası ile kalibrasyon yapın."
)
_WARN_UNSAFE_GEO_TR = (
    "Kalibrasyon güveni bu oturum için yetersiz. "
    "Dünya haritasında mera gösterilmedi; kontrol noktalarını gözden geçirip yeniden tarayın."
)
_WARN_APPROXIMATE_GEO_TR = (
    "Hizalama yaklaşık kabul edilir; mera konumları sapma gösterebilir. "
    "Kritik seyir ve güvenlik için resmi deniz haritasına güvenin."
)
# Kontrol noktalarının WGS84 üzerindeki yayılımı (m); çok küçükse affine dönüşüm zayıf olabilir.
_MIN_CONTROL_POINT_SPREAD_M = 80.0


class MaritimeOrchestrationError(RuntimeError):
    """Raised when hotspot orchestration fails due to invalid state or data."""


@dataclass(frozen=True)
class ImageGeoBounds:
    """Geographic bounding box of a chart image."""

    top_left: GeoPoint
    bottom_right: GeoPoint


@dataclass(frozen=True)
class PixelGeoControlPoint:
    pixel_x: float
    pixel_y: float
    geo_lat: float
    geo_lon: float


@dataclass(frozen=True)
class BoatPixelAnchor:
    x: float
    y: float
    confidence: float
    source: str
    detection_method: str
    status: str


@dataclass(frozen=True)
class ControlPointDiagnostics:
    received: int
    valid: int
    invalid: int
    status: str
    georeference_error_m: float = 0.0
    transform_quality: float = 0.0


class FishingHotspotManager:
    """
    Orchestrates bathymetry detection, geospatial mapping, and filtered navigation.

    Pipeline:
    1) Analyze chart and detect bathymetric features in pixel space.
    2) Convert feature centroids from pixel coordinates to geographic coordinates.
    3) Update Kalman-filtered GPS position.
    4) Compute distance and true bearing from boat position to each hotspot.
    5) Rank hotspots by score, then distance.
    """

    def __init__(
        self,
        bathymetry_analyzer: BathymetryAnalyzer,
        coordinate_mapper: Optional[CoordinateMapper],
        precision_gps: PrecisionGPS,
        marine_data_client: Optional[MarineDataClient] = None,
        enrichment_workers: int = 4,
    ) -> None:
        if bathymetry_analyzer is None or precision_gps is None:
            raise ValueError("Bathymetry analyzer and precision_gps must be provided.")
        if enrichment_workers < 1:
            raise ValueError("enrichment_workers must be >= 1.")
        self.bathymetry_analyzer = bathymetry_analyzer
        self.coordinate_mapper = coordinate_mapper
        self.precision_gps = precision_gps
        self.marine_data_client = marine_data_client
        self.enrichment_workers = int(enrichment_workers)

    @staticmethod
    def _control_point_spread_meters(points: Sequence[PixelGeoControlPoint]) -> float:
        if len(points) < 2:
            return 0.0
        lats = [float(p.geo_lat) for p in points]
        lons = [float(p.geo_lon) for p in points]
        mid_lat = sum(lats) / len(lats)
        dlat_m = (max(lats) - min(lats)) * 111_000.0
        dlon_m = (max(lons) - min(lons)) * 111_000.0 * max(0.05, abs(math.cos(math.radians(mid_lat))))
        return float((dlat_m * dlat_m + dlon_m * dlon_m) ** 0.5)

    @staticmethod
    def compute_calibration_reliability_bundle(
        *,
        coordinate_mode: str,
        mapping_mode: str,
        cp_diag: ControlPointDiagnostics,
        control_points: Optional[Sequence[PixelGeoControlPoint]],
    ) -> Tuple[str, bool, str]:
        """
        Returns (calibration_reliability, geo_map_display_allowed, reason_code).

        ``geo_map_display_allowed`` is True for excellent / good / approximate (markers on basemap).
        ``unsafe`` disables real-world hotspot markers (image_space or failed geo).
        """
        cm = str(coordinate_mode).strip().lower()
        if cm != "geo_referenced":
            return "unsafe", False, "not_geo_referenced"
        if mapping_mode != "affine_control_points":
            return "unsafe", False, "mapping_not_affine"
        rmse = float(cp_diag.georeference_error_m)
        q = float(cp_diag.transform_quality)
        spread = FishingHotspotManager._control_point_spread_meters(control_points or ())

        if rmse > GEO_WORLD_MAP_MAX_GEOREFERENCE_ERROR_M or q < GEO_WORLD_MAP_MIN_TRANSFORM_QUALITY:
            if mapping_mode == "affine_control_points" and cp_diag.valid >= 3:
                return "approximate", True, "marginal_rmse_or_quality"
            return "unsafe", False, "rmse_or_quality_below_min"

        if spread > 0.0 and spread < _MIN_CONTROL_POINT_SPREAD_M:
            return "approximate", True, "control_point_spread_low"
        if rmse > 28.0 or q < 0.50:
            return "approximate", True, "marginal_rmse_or_quality"
        if rmse > 15.0 or q < 0.72:
            return "good", True, "mid_tier"
        return "excellent", True, "high_confidence"

    @staticmethod
    def geo_world_map_display_allowed(
        *,
        coordinate_mode: str,
        mapping_mode: str,
        cp_diag: ControlPointDiagnostics,
        control_points: Optional[Sequence[PixelGeoControlPoint]] = None,
    ) -> bool:
        _rel, allowed, _reason = FishingHotspotManager.compute_calibration_reliability_bundle(
            coordinate_mode=coordinate_mode,
            mapping_mode=mapping_mode,
            cp_diag=cp_diag,
            control_points=control_points,
        )
        return bool(allowed)

    @staticmethod
    def user_warning_tr_for_reliability(reliability: str) -> Optional[str]:
        r = str(reliability).strip().lower()
        if r == "unsafe":
            return _WARN_UNSAFE_GEO_TR
        if r == "approximate":
            return _WARN_APPROXIMATE_GEO_TR
        return None

    def process_new_chart_and_state(
        self,
        image_path: str,
        current_gps_lat: float,
        current_gps_lon: float,
        image_geo_bounds: Mapping[str, Any],
        enrich_data: bool = True,
        *,
        debug_save_image_space_overlay: bool = False,
        debug_overlay_output_path: Optional[str] = None,
        debug_overlay_show_all_labels: bool = False,
        debug_overlay_max_labeled_ranks: int = DEFAULT_OVERLAY_MAX_LABELED_RANKS,
        debug_overlay_zoom_scale: float = 1.0,
    ) -> Dict[str, Any]:
        """
        Process a new chart and current GPS state into ranked fishing hotspots.

        Parameters
        ----------
        image_path:
            Path to the nautical chart image.
        current_gps_lat, current_gps_lon:
            Raw incoming GPS sample.
        image_geo_bounds:
            Geographic image bounds. Accepted formats:
            - {"top_left": {"lat": ..., "lon": ...}, "bottom_right": {"lat": ..., "lon": ...}}
            - {"top_left": [lat, lon], "bottom_right": [lat, lon]}

        Returns
        -------
        Dict[str, Any]
            JSON-serializable response containing ranked hotspots and navigation context.
        """
        if not image_path:
            raise ValueError("image_path is required.")

        analysis = self.bathymetry_analyzer.analyze_chart(image_path)
        image_size = analysis.get("image_size", {})
        width = int(image_size.get("width", 0))
        height = int(image_size.get("height", 0))
        if width <= 0 or height <= 0:
            raise MaritimeOrchestrationError("Bathymetry analysis did not return a valid image size.")

        if not isinstance(image_geo_bounds, Mapping):
            raise ValueError("image_geo_bounds must be a mapping.")
        control_points, cp_diag = self._parse_control_points(
            image_geo_bounds.get("control_points")
        )
        analysis_diagnostics = analysis.get("diagnostics", {})
        request_boat_anchor = self._parse_boat_pixel_anchor(
            image_geo_bounds.get("boat_pixel_anchor")
        )
        detected_boat_anchor = self._parse_boat_pixel_anchor(
            (analysis_diagnostics.get("boat_pixel_anchor") if isinstance(analysis_diagnostics, Mapping) else None)
        )

        if control_points is None:
            # No affine control points: default is image_space.
            # Exception: GPS + boat pixel anchor → boat_anchor_estimated (approximate, not geo_referenced).
            # Prefer linear bounds mapper when available; otherwise a nominal m/px heuristic on a
            # local tangent plane (explicit diagnostics; never labeled geo_referenced).
            bounds = None
            mapper = None
            heuristic_m_per_px: Optional[float] = None
            allow_boat_anchor_estimate = False
            attempted_boat_anchor_estimate = False
            boat_anchor_estimate_reason = ""
            gps_ok = (
                isfinite(float(current_gps_lat))
                and isfinite(float(current_gps_lon))
                and abs(float(current_gps_lat)) <= 90.0
                and abs(float(current_gps_lon)) <= 180.0
                and not (
                    abs(float(current_gps_lat)) < 1e-9
                    and abs(float(current_gps_lon)) < 1e-9
                )
            )
            pixel_hotspot_candidates = self._count_pixel_hotspot_candidates(analysis)
            raw_anchor_req = (
                image_geo_bounds.get("boat_pixel_anchor")
                if isinstance(image_geo_bounds, Mapping)
                else None
            )
            has_boat_pixel_anchor_request_payload = (
                isinstance(raw_anchor_req, Mapping)
                and raw_anchor_req.get("x") is not None
                and raw_anchor_req.get("y") is not None
            )

            effective_request_anchor = request_boat_anchor
            if effective_request_anchor is not None:
                src = (effective_request_anchor.source or "").strip().lower()
                conf = float(effective_request_anchor.confidence or 0.0)
                if src in ("photo_center_fallback", "image_center", "center_fallback") or conf < 0.45:
                    effective_request_anchor = None

            attempted_boat_anchor_estimate = bool(gps_ok and pixel_hotspot_candidates > 0)
            anchor_resolution = ""

            if not gps_ok:
                boat_anchor_estimate_reason = "no_current_gps"
            elif pixel_hotspot_candidates == 0:
                boat_anchor_estimate_reason = "no_hotspots_in_image"
            else:
                boat_anchor_estimate_reason = "pending_mapper"

            if gps_ok and pixel_hotspot_candidates > 0:
                if "top_left" in image_geo_bounds and "bottom_right" in image_geo_bounds:
                    try:
                        bounds2, _control_points2, _req_anchor2, _cp_diag2 = self._parse_bounds(image_geo_bounds)
                        if self._chart_bounds_geographically_valid(bounds2):
                            bounds = bounds2
                            mapper, _mapper_mode = self._build_mapper_for_chart(
                                width=width,
                                height=height,
                                bounds=bounds2,
                                control_points=None,
                            )
                            allow_boat_anchor_estimate = True
                            boat_anchor_estimate_reason = "ok_bounds_mapper"
                    except Exception:
                        bounds = None
                        mapper = None
                        boat_anchor_estimate_reason = "invalid_bounds"
                if not allow_boat_anchor_estimate:
                    current_mapper = self.coordinate_mapper
                    if current_mapper is not None:
                        bounds2 = ImageGeoBounds(
                            top_left=current_mapper.top_left,
                            bottom_right=current_mapper.bottom_right,
                        )
                        if self._chart_bounds_geographically_valid(bounds2):
                            bounds = bounds2
                            mapper, _mapper_mode = self._build_mapper_for_chart(
                                width=width,
                                height=height,
                                bounds=bounds2,
                                control_points=None,
                            )
                            allow_boat_anchor_estimate = True
                            boat_anchor_estimate_reason = "ok_cached_bounds"
                if not allow_boat_anchor_estimate:
                    allow_boat_anchor_estimate = True
                    heuristic_m_per_px = self._nominal_meters_per_pixel_heuristic(width, height)
                    boat_anchor_estimate_reason = "ok_gps_hotspots_heuristic_scale"

            mapping_mode = "boat_anchor_estimated" if allow_boat_anchor_estimate else "image_space"

            if mapping_mode == "boat_anchor_estimated":
                active_boat_anchor, boat_anchor_source, anchor_resolution = self._resolve_boat_anchor_for_estimate(
                    image_geo_bounds=image_geo_bounds,
                    request_boat_anchor=request_boat_anchor,
                    detected_boat_anchor=detected_boat_anchor,
                    analysis=analysis,
                    width=width,
                    height=height,
                )
            else:
                effective_anchor = effective_request_anchor or detected_boat_anchor
                active_boat_anchor = self._image_center_anchor(width=width, height=height)
                boat_anchor_source = "image_center"
                anchor_resolution = "image_space_default"
                if effective_anchor is not None:
                    active_boat_anchor = effective_anchor
                    boat_anchor_source = effective_anchor.source or (
                        "detected_boat_anchor" if effective_request_anchor is None else "manual_image_anchor"
                    )

            gps_filter_state = self.precision_gps.update(current_gps_lat, current_gps_lon)
            raw_gps_lat = float(current_gps_lat)
            raw_gps_lon = float(current_gps_lon)
            smoothed_lat = float(gps_filter_state["lat"])
            smoothed_lon = float(gps_filter_state["lon"])

            _logger.info(
                "[no_control_points] gps_ok=%s pixel_candidates=%s gps_raw=(%.6f,%.6f) "
                "detected_anchor=%s req_anchor_payload=%s anchor_xy=(%.1f,%.1f) anchor_src=%s "
                "resolution=%s mode=%s reason=%s",
                gps_ok,
                pixel_hotspot_candidates,
                float(current_gps_lat),
                float(current_gps_lon),
                detected_boat_anchor is not None,
                has_boat_pixel_anchor_request_payload,
                float(active_boat_anchor.x),
                float(active_boat_anchor.y),
                boat_anchor_source,
                anchor_resolution,
                mapping_mode,
                boat_anchor_estimate_reason,
            )

            if mapping_mode == "boat_anchor_estimated":
                hotspots = self._build_ranked_hotspots_boat_gps_anchored(
                    analysis=analysis,
                    boat_anchor=active_boat_anchor,
                    boat_lat=smoothed_lat,
                    boat_lon=smoothed_lon,
                    mapper=mapper,
                    heuristic_m_per_px=heuristic_m_per_px,
                )
                apply_reasoning_text_to_hotspots(hotspots, width, height)
                for hs in hotspots:
                    hs["regional_species_context"] = None
                    hs["species_match"] = []
                self._ensure_hotspot_detail_fields(
                    hotspots,
                    coordinate_mode="boat_anchor_estimated",
                    enrichment_enabled=bool(enrich_data and self.marine_data_client is not None),
                )
            else:
                hotspots = self._build_ranked_hotspots_image_space(
                    analysis=analysis,
                    boat_anchor=active_boat_anchor,
                )
            top_recommendation_ids = attach_fishing_recommendation_metrics(
                hotspots,
                width=width,
                height=height,
            )
            session_advice_text = build_session_advice(hotspots, top_recommendation_ids)
            _geo_plausible = self._hotspot_geo_count_plausible(hotspots)
            _logger.info(
                "[no_control_points] selected_mode=%s ranked_hotspots=%s hotspot_geo_count=%s "
                "estimate_reason=%s",
                mapping_mode,
                len(hotspots),
                _geo_plausible,
                boat_anchor_estimate_reason,
            )
            img_enrich = self._apply_image_space_enrichment_policy(
                hotspots=hotspots,
                enrich_data=bool(enrich_data),
                smoothed_lat=smoothed_lat,
                smoothed_lon=smoothed_lon,
            )
            counts = analysis.get("counts", {})
            candidate_stats = dict(
                analysis_diagnostics.get("candidate_stats", {})
                if isinstance(analysis_diagnostics, Mapping)
                else {}
            )
            payload: Dict[str, Any] = {
                "image_path": image_path,
                "image_size": {"width": width, "height": height},
                "coordinate_mode": "boat_anchor_estimated" if mapping_mode == "boat_anchor_estimated" else "image_space",
                "is_geo_referenced": False,
                "calibration_quality": 0.0,
                "transform_confidence": 0.0,
                "geo_map_display_allowed": bool(mapping_mode == "boat_anchor_estimated"),
                "calibration_reliability": (
                    "approximate" if mapping_mode == "boat_anchor_estimated" else "unsafe"
                ),
                "user_warning_tr": (
                    "Yaklaşık tekne referanslı konum: Bu koordinatlar kontrol noktasıyla doğrulanmış değildir."
                    if mapping_mode == "boat_anchor_estimated"
                    else _IMAGE_SPACE_CALIBRATION_HINT_TR
                ),
                "boat": {
                    "raw_gps": {"lat": raw_gps_lat, "lon": raw_gps_lon},
                    "smoothed_gps": {"lat": smoothed_lat, "lon": smoothed_lon},
                    "navigation_anchor_geo": (
                        {"lat": smoothed_lat, "lon": smoothed_lon}
                        if mapping_mode == "boat_anchor_estimated"
                        else None
                    ),
                    "pixel_anchor": {
                        "x": float(active_boat_anchor.x),
                        "y": float(active_boat_anchor.y),
                        "confidence": float(active_boat_anchor.confidence),
                        "source": boat_anchor_source,
                        "detection_method": active_boat_anchor.detection_method,
                        "status": active_boat_anchor.status,
                    },
                    "boat_pixel_anchor": {
                        "x": float(active_boat_anchor.x),
                        "y": float(active_boat_anchor.y),
                    },
                    "boat_anchor_confidence": float(active_boat_anchor.confidence),
                    "boat_anchor_source": boat_anchor_source,
                    "filter_state": gps_filter_state,
                },
                "image_geo_bounds": (
                    {
                        "top_left": {"lat": bounds.top_left.lat, "lon": bounds.top_left.lon},
                        "bottom_right": {"lat": bounds.bottom_right.lat, "lon": bounds.bottom_right.lon},
                    }
                    if mapping_mode == "boat_anchor_estimated" and bounds is not None
                    else {}
                ),
                "counts": {
                    "total_features_detected": int(sum(len(v) for v in analysis.get("features", {}).values())),
                    "ranked_hotspots": len(hotspots),
                },
                "hotspots": hotspots,
                "ranked_hotspots": hotspots,
                "top_recommendations": top_recommendation_ids,
                "session_advice": session_advice_text,
                "diagnostics": {
                    "coordinate_mode": "boat_anchor_estimated" if mapping_mode == "boat_anchor_estimated" else "image_space",
                    "geo_map_display_allowed": bool(mapping_mode == "boat_anchor_estimated"),
                    "calibration_reliability": (
                        "approximate" if mapping_mode == "boat_anchor_estimated" else "unsafe"
                    ),
                    "control_point_spread_m": 0.0,
                    "mapping_mode": mapping_mode,
                    "boat_anchor_heuristic_meters_per_pixel": (
                        float(heuristic_m_per_px)
                        if mapping_mode == "boat_anchor_estimated" and heuristic_m_per_px is not None
                        else None
                    ),
                    "boat_anchor_scale_source": (
                        "nominal_phone_chart_assumption"
                        if mapping_mode == "boat_anchor_estimated" and heuristic_m_per_px is not None
                        else (
                            "linear_bounds_relative_to_gps"
                            if mapping_mode == "boat_anchor_estimated" and mapper is not None
                            else None
                        )
                    ),
                    "hotspot_geo_count": int(_geo_plausible),
                    "pixel_hotspot_candidates": int(pixel_hotspot_candidates),
                    "boat_anchor_resolution": (
                        str(anchor_resolution) if mapping_mode == "boat_anchor_estimated" else None
                    ),
                    "attempted_boat_anchor_estimate": bool(attempted_boat_anchor_estimate),
                    "boat_anchor_estimate_reason": boat_anchor_estimate_reason,
                    "has_current_gps": bool(gps_ok),
                    "has_boat_pixel_anchor_request": bool(has_boat_pixel_anchor_request_payload),
                    "has_boat_pixel_anchor_detected": bool(detected_boat_anchor is not None),
                    "has_bounds_request": bool("top_left" in image_geo_bounds and "bottom_right" in image_geo_bounds),
                    "has_bounds_mapper": bool(mapper is not None and bounds is not None),
                    "output_coordinate_mode": "boat_anchor_estimated" if mapping_mode == "boat_anchor_estimated" else "image_space",
                    "feature_counts": counts,
                    "enrichment_enabled": bool(img_enrich["enrichment_enabled"]),
                    "enrichment_scope": str(img_enrich["enrichment_scope"]),
                    "image_space_enrichment_detail": img_enrich.get("image_space_enrichment_detail"),
                    "screenshot_aligned_mapping_used": False,
                    "mapping_trust_state": (
                        "boat_anchor_approximate"
                        if mapping_mode == "boat_anchor_estimated"
                        else "image_space_only"
                    ),
                    "chart_reference_primary": True,
                    "render_mode_recommendation": "chart_overlay_primary",
                    "control_points_received": cp_diag.received,
                    "control_points_valid": cp_diag.valid,
                    "control_points_invalid": cp_diag.invalid,
                    "control_points_status": cp_diag.status,
                    "georeference_error": 0.0,
                    "transform_quality": 0.0,
                    "suspicious_hotspot_count": 0,
                    "boat_pixel_anchor": {
                        "x": float(active_boat_anchor.x),
                        "y": float(active_boat_anchor.y),
                        "confidence": float(active_boat_anchor.confidence),
                        "source": boat_anchor_source,
                        "detection_method": active_boat_anchor.detection_method,
                        "status": active_boat_anchor.status,
                    },
                    "boat_anchor_confidence": float(active_boat_anchor.confidence),
                    "boat_anchor_source": boat_anchor_source,
                    "boat_render_recommendation": "chart_pixel_anchor",
                    "total_candidates_before_filter": int(candidate_stats.get("total_candidates_before_filter", 0)),
                    "total_after_filter": int(candidate_stats.get("total_after_filter", len(hotspots))),
                    "rejected_near_land": int(candidate_stats.get("rejected_near_land", 0)),
                    "rejected_low_score": int(candidate_stats.get("rejected_low_score", 0)),
                    "fishing_priority_disclaimer": (
                        "Heuristic visit-order suggestions only—not a prediction of outcome or guaranteed success."
                    ),
                    "bathymetry": analysis_diagnostics,
                },
            }
            if debug_save_image_space_overlay:
                try:
                    from image_space_overlay_export import (
                        attach_image_space_overlay_paths,
                        export_image_space_overlay_from_response,
                    )

                    labeled_target = debug_overlay_output_path or str(default_overlay_png_path())
                    paths = export_image_space_overlay_from_response(
                        image_path,
                        payload,
                        labeled_target,
                        overlay_show_all_labels=bool(debug_overlay_show_all_labels),
                        overlay_max_labeled_ranks=int(debug_overlay_max_labeled_ranks),
                        overlay_zoom_scale=float(debug_overlay_zoom_scale),
                        write_clean_version=True,
                    )
                    attach_image_space_overlay_paths(
                        payload,
                        labeled_path=paths["labeled"],
                        clean_path=paths.get("clean") or "",
                    )
                except Exception:
                    _logger.warning(
                        "image_space debug overlay export failed",
                        exc_info=True,
                    )
            return payload

        bounds, _control_points2, _req_anchor2, _cp_diag2 = self._parse_bounds(image_geo_bounds)
        mapper, mapping_mode = self._build_mapper_for_chart(
            width=width,
            height=height,
            bounds=bounds,
            control_points=control_points,
        )
        if mapping_mode != "affine_control_points":
            raise MaritimeOrchestrationError(
                f"Forbidden fallback mapping mode: {mapping_mode}. "
                "At least 3 valid control points are required for geo mode."
            )
        cp_diag = self._evaluate_control_point_quality(
            mapper=mapper,
            mapping_mode=mapping_mode,
            base_diag=cp_diag,
            control_points=control_points,
        )

        detected_boat_anchor = self._extract_detected_boat_anchor(analysis_diagnostics)
        active_boat_anchor = request_boat_anchor or detected_boat_anchor
        boat_anchor_source = (
            (request_boat_anchor.source if request_boat_anchor is not None else None)
            or ("detected" if detected_boat_anchor is not None else "gps_fallback")
        )

        gps_state = self.precision_gps.update(current_gps_lat, current_gps_lon)
        smoothed_lat = float(gps_state["lat"])
        smoothed_lon = float(gps_state["lon"])
        boat_nav_lat = smoothed_lat
        boat_nav_lon = smoothed_lon
        boat_anchor_geo: Optional[GeoPoint] = None
        if active_boat_anchor is not None:
            boat_anchor_geo = mapper.pixel_to_geo(active_boat_anchor.x, active_boat_anchor.y)
            boat_nav_lat = float(boat_anchor_geo.lat)
            boat_nav_lon = float(boat_anchor_geo.lon)

        hotspots = self._build_ranked_hotspots(
            analysis=analysis,
            mapper=mapper,
            boat_lat=boat_nav_lat,
            boat_lon=boat_nav_lon,
            mapping_mode=mapping_mode,
        )
        suspicious_hotspot_count = 0
        enrichment_enabled = bool(enrich_data and self.marine_data_client is not None)
        if enrichment_enabled and hotspots:
            hotspots = self._enrich_hotspots(hotspots)

        # Even when enrichment is disabled/unavailable, the detail sheet expects
        # stable shapes for key nested fields. Provide deterministic fallbacks
        # that avoid fake precision.
        self._ensure_hotspot_detail_fields(
            hotspots,
            coordinate_mode="geo_referenced",
            enrichment_enabled=enrichment_enabled,
        )

        apply_reasoning_text_to_hotspots(hotspots, width, height)
        self._attach_regional_species_context(hotspots, bounds)
        top_recommendation_ids = attach_fishing_recommendation_metrics(
            hotspots,
            width=width,
            height=height,
        )
        session_advice_text = build_session_advice(hotspots, top_recommendation_ids)

        spread_m = self._control_point_spread_meters(control_points or ())
        rel, geo_map_allowed, rel_reason = self.compute_calibration_reliability_bundle(
            coordinate_mode="geo_referenced",
            mapping_mode=mapping_mode,
            cp_diag=cp_diag,
            control_points=control_points,
        )
        user_warning_tr = self.user_warning_tr_for_reliability(rel)

        return {
            "image_path": image_path,
            "image_size": {"width": width, "height": height},
            "coordinate_mode": "geo_referenced",
            "is_geo_referenced": True,
            "calibration_quality": float(cp_diag.transform_quality),
            "transform_confidence": float(cp_diag.transform_quality),
            "calibration_reliability": rel,
            "geo_map_display_allowed": geo_map_allowed,
            "user_warning_tr": user_warning_tr,
            "boat": {
                "raw_gps": {"lat": float(current_gps_lat), "lon": float(current_gps_lon)},
                "smoothed_gps": {"lat": smoothed_lat, "lon": smoothed_lon},
                "navigation_anchor_geo": (
                    {"lat": float(boat_anchor_geo.lat), "lon": float(boat_anchor_geo.lon)}
                    if boat_anchor_geo is not None
                    else None
                ),
                "pixel_anchor": (
                    {
                        "x": float(active_boat_anchor.x),
                        "y": float(active_boat_anchor.y),
                        "confidence": float(active_boat_anchor.confidence),
                        "source": boat_anchor_source,
                        "detection_method": active_boat_anchor.detection_method,
                        "status": active_boat_anchor.status,
                    }
                    if active_boat_anchor is not None
                    else None
                ),
                "boat_pixel_anchor": (
                    {"x": float(active_boat_anchor.x), "y": float(active_boat_anchor.y)}
                    if active_boat_anchor is not None
                    else None
                ),
                "boat_anchor_confidence": float(active_boat_anchor.confidence) if active_boat_anchor is not None else 0.0,
                "boat_anchor_source": boat_anchor_source,
                "filter_state": gps_state,
            },
            "image_geo_bounds": {
                "top_left": {"lat": bounds.top_left.lat, "lon": bounds.top_left.lon},
                "bottom_right": {"lat": bounds.bottom_right.lat, "lon": bounds.bottom_right.lon},
            },
            "counts": {
                "total_features_detected": int(sum(len(v) for v in analysis.get("features", {}).values())),
                "ranked_hotspots": len(hotspots),
            },
            "ranked_hotspots": hotspots,
            "top_recommendations": top_recommendation_ids,
            "session_advice": session_advice_text,
            "diagnostics": {
                "coordinate_mode": "geo_referenced",
                "geo_map_display_allowed": geo_map_allowed,
                "calibration_reliability": rel,
                "calibration_reliability_reason": rel_reason,
                "control_point_spread_m": float(spread_m),
                "bathymetry": analysis_diagnostics,
                "feature_counts": analysis.get("counts", {}),
                "enrichment_enabled": enrichment_enabled,
                "mapping_mode": mapping_mode,
                "screenshot_aligned_mapping_used": mapping_mode == "affine_control_points",
                "mapping_trust_state": (
                    "chart_georeferenced_precise"
                    if self._is_chart_aligned_mapping_mode(mapping_mode)
                    else "approximate_bounds_fallback"
                ),
                "chart_reference_primary": True,
                "render_mode_recommendation": (
                    "chart_overlay_primary"
                    if self._is_chart_aligned_mapping_mode(mapping_mode)
                    else "chart_overlay_primary_with_world_fallback"
                ),
                "control_points_received": cp_diag.received,
                "control_points_valid": cp_diag.valid,
                "control_points_invalid": cp_diag.invalid,
                "control_points_status": cp_diag.status,
                "georeference_error": float(cp_diag.georeference_error_m),
                "transform_quality": float(cp_diag.transform_quality),
                "suspicious_hotspot_count": int(suspicious_hotspot_count),
                "boat_pixel_anchor": (
                    {
                        "x": float(active_boat_anchor.x),
                        "y": float(active_boat_anchor.y),
                        "confidence": float(active_boat_anchor.confidence),
                        "source": boat_anchor_source,
                        "detection_method": active_boat_anchor.detection_method,
                        "status": active_boat_anchor.status,
                    }
                    if active_boat_anchor is not None
                    else None
                ),
                "boat_anchor_confidence": float(active_boat_anchor.confidence) if active_boat_anchor is not None else 0.0,
                "boat_anchor_source": boat_anchor_source,
                "boat_render_recommendation": (
                    "chart_pixel_anchor"
                    if active_boat_anchor is not None
                    else "gps_fallback_approximate"
                ),
                "total_candidates_before_filter": int(
                    (analysis_diagnostics.get("candidate_stats", {}) or {}).get(
                        "total_candidates_before_filter", 0
                    )
                ),
                "total_after_filter": int(
                    (analysis_diagnostics.get("candidate_stats", {}) or {}).get(
                        "total_after_filter", len(hotspots)
                    )
                ),
                "rejected_near_land": int(
                    (analysis_diagnostics.get("candidate_stats", {}) or {}).get(
                        "rejected_near_land", 0
                    )
                ),
                "rejected_low_score": int(
                    (analysis_diagnostics.get("candidate_stats", {}) or {}).get(
                        "rejected_low_score", 0
                    )
                ),
                "fishing_priority_disclaimer": (
                    "Heuristic visit-order suggestions only—not a prediction of outcome or guaranteed success."
                ),
            },
        }

    @staticmethod
    def _ensure_hotspot_detail_fields(
        hotspots: List[Dict[str, Any]],
        *,
        coordinate_mode: str,
        enrichment_enabled: bool,
    ) -> None:
        """
        Guarantee presence of nested fields that the client renders in hotspot detail.

        - In geo mode, if enrichment is disabled/unavailable, provide rule-based fallbacks
          (source=rule_based_fallback, confidence=approximate) without claiming certainty.
        - In image_space, stubs are already attached elsewhere; don't override them here.
        """
        if not hotspots:
            return
        if str(coordinate_mode).lower().strip() == "image_space":
            return

        for hs in hotspots:
            # Fishing advice is always created in geo pipeline, but guard for legacy/custom payloads.
            fa = hs.get("fishing_advice")
            if not isinstance(fa, dict):
                hs["fishing_advice"] = {
                    "species_predictions": [],
                    "bait": [],
                    "best_times": [],
                    "tackle": [],
                    "selection_reasons": [],
                    "metrics_used": {},
                    "source": "rule_based_fallback",
                    "confidence": "approximate",
                }
                fa = hs["fishing_advice"]

            # Convenience aliases (non-breaking additive) for clients that expect top-level keys.
            hs.setdefault("bait_recommendation", list(fa.get("bait") or []))
            hs.setdefault("tackle_recommendation", list(fa.get("tackle") or []))
            hs.setdefault("best_fishing_times", list(fa.get("best_times") or []))
            hs.setdefault("species_reasoning", list(fa.get("selection_reasons") or []))

            # confirmed_depth fallback (only if missing).
            if "confirmed_depth" not in hs or not isinstance(hs.get("confirmed_depth"), dict):
                hs["confirmed_depth"] = {
                    "depth_m": None,
                    "raw_elevation_m": None,
                    "dataset": None,
                    "source": "rule_based_fallback",
                    "fallback": True,
                    "confidence": "approximate",
                    "reason": (
                        "Harici derinlik verisi bu oturumda alınamadı; yapı/metriklerden "
                        "türetilen sınırlı bir özet gösterilir."
                        if not enrichment_enabled
                        else "Derinlik verisi şu anda doğrulanamadı."
                    ),
                }
            else:
                hs.get("confirmed_depth", {}).setdefault("confidence", "approximate")

            # likely_species fallback (only if missing).
            if "likely_species" not in hs or not isinstance(hs.get("likely_species"), dict):
                preds = []
                if isinstance(fa, dict):
                    preds = fa.get("species_predictions") or []
                top_species = []
                if isinstance(preds, list):
                    for p in preds[:3]:
                        if isinstance(p, dict) and str(p.get("species", "")).strip():
                            top_species.append(
                                {"species": str(p.get("species")).strip(), "occurrence_count": 0}
                            )
                hs["likely_species"] = {
                    "radius_km": None,
                    "query_geometry_wkt": None,
                    "top_species": top_species,
                    "total_records_considered": 0,
                    "source": "rule_based_fallback",
                    "fallback": True,
                    "confidence": "approximate",
                    "reason": (
                        "Bölgesel tür verisi şu anda alınamadı; yapı temelli tahmini sinyal gösterilir."
                        if not enrichment_enabled
                        else "Biyoçeşitlilik verisi şu anda doğrulanamadı."
                    ),
                }
            else:
                hs.get("likely_species", {}).setdefault("confidence", "approximate")

            # regional_species_context fallback if missing/empty and no OBIS bundle.
            if not isinstance(hs.get("regional_species_context"), str) or not str(
                hs.get("regional_species_context") or ""
            ).strip():
                feature_type = str(hs.get("feature_type", "candidate")).strip()
                metrics = hs.get("supporting_metrics") or {}
                slope = float(metrics.get("slope", 0.0) or 0.0)
                contour = float(metrics.get("contour_density", 0.0) or 0.0)
                transition = float(metrics.get("transition_band", 0.0) or 0.0)
                hint_bits = []
                if contour >= 0.55:
                    hint_bits.append("kontur yoğunluğu yüksek")
                if slope >= 0.55:
                    hint_bits.append("eğim belirgin")
                if transition >= 0.55:
                    hint_bits.append("geçiş bandı güçlü")
                hint = ", ".join(hint_bits) if hint_bits else "sınırlı batimetri sinyali"
                hs["regional_species_context"] = (
                    "Bölgesel dış tür verisi bu oturumda alınamadı. "
                    f"Bu noktada {feature_type} yapısı ve {hint} görülüyor; "
                    "tür önerileri bu sinyallere dayalı yaklaşık bir tahmindir."
                )

    @staticmethod
    def _image_center_anchor(width: int, height: int) -> BoatPixelAnchor:
        cx = (max(1, width) - 1) / 2.0
        cy = (max(1, height) - 1) / 2.0
        return BoatPixelAnchor(
            x=float(cx),
            y=float(cy),
            confidence=1.0,
            source="image_center",
            detection_method="image_center_default",
            status="manual",
        )

    @staticmethod
    def _gps_sample_plausible(lat: float, lon: float) -> bool:
        if not (isfinite(lat) and isfinite(lon)):
            return False
        if abs(lat) > 90.0 or abs(lon) > 180.0:
            return False
        if abs(lat) < 1e-8 and abs(lon) < 1e-8:
            return False
        return True

    def _apply_image_space_enrichment_policy(
        self,
        *,
        hotspots: List[Dict[str, Any]],
        enrich_data: bool,
        smoothed_lat: float,
        smoothed_lon: float,
    ) -> Dict[str, Any]:
        """
        Image-space hotspots are not geo-located: never call OBIS/GEBCO/biodiversity
        on pixel-derived pseudo-coordinates.

        When GPS is plausible and a marine client exists, fetch open-marine conditions
        at the boat position only and attach the same ``sea_state`` to each hotspot
        (display layer labels this as boat-position scope).
        """
        client_ok = self.marine_data_client is not None
        enrichment_requested = bool(enrich_data and client_ok)
        plausible_gps = self._gps_sample_plausible(smoothed_lat, smoothed_lon)
        scope = "boat_gps" if plausible_gps else "unavailable_no_gps"
        boat_marine: Optional[Dict[str, Any]] = None
        if plausible_gps and enrichment_requested:
            boat_marine = dict(
                self.marine_data_client.get_sea_state(smoothed_lat, smoothed_lon)
            )
            boat_marine["marine_at_boat_position"] = True

        stub_depth: Dict[str, Any] = {
            "depth_m": None,
            "raw_elevation_m": None,
            "dataset": None,
            "source": "calibration_required",
            "fallback": True,
            "reason": "image_space",
        }
        stub_species: Dict[str, Any] = {
            "radius_km": None,
            "query_geometry_wkt": None,
            "top_species": [],
            "total_records_considered": 0,
            "source": "calibration_required",
            "fallback": True,
            "reason": "image_space",
        }
        stub_sea_no_gps: Dict[str, Any] = {
            "wave_height_m": None,
            "water_temperature_c": None,
            "wind_speed_knots": None,
            "wind_direction_deg": None,
            "current_speed_knots": None,
            "current_direction_deg": None,
            "pressure_hpa": None,
            "ocean_current_velocity_mps": None,
            "source": "requires_gps_or_server",
            "fallback": True,
            "reason": "image_space_no_boat_gps",
            "simulated_components": [],
        }

        for hs in hotspots:
            hs["confirmed_depth"] = dict(stub_depth)
            hs["likely_species"] = dict(stub_species)
            if boat_marine is not None:
                hs["sea_state"] = dict(boat_marine)
            elif plausible_gps and enrich_data and not client_ok:
                missing = dict(stub_sea_no_gps)
                missing["reason"] = "marine_client_unavailable"
                hs["sea_state"] = missing
            else:
                hs["sea_state"] = dict(stub_sea_no_gps)

        detail: Optional[str] = None
        if enrich_data:
            detail = (
                "Derinlik ve tür verisi için kalibre edilmiş harita koordinatları gerekir."
            )

        return {
            "enrichment_enabled": bool(enrich_data and client_ok and plausible_gps),
            "enrichment_scope": scope,
            "image_space_enrichment_detail": detail,
            "boat_marine": boat_marine,
        }

    def _build_ranked_hotspots_image_space(
        self,
        analysis: Mapping[str, Any],
        boat_anchor: BoatPixelAnchor,
    ) -> List[Dict[str, Any]]:
        candidates = analysis.get("candidate_hotspots")
        if not self._is_nonstring_sequence(candidates):
            return []
        hotspots: List[Dict[str, Any]] = []
        for index, candidate in enumerate(candidates):
            if not isinstance(candidate, Mapping):
                continue
            centroid = candidate.get("pixel_centroid")
            if not isinstance(centroid, Mapping):
                continue
            cx = centroid.get("x")
            cy = centroid.get("y")
            if cx is None or cy is None:
                continue
            dx = float(cx) - float(boat_anchor.x)
            dy = float(cy) - float(boat_anchor.y)
            distance_px = (dx * dx + dy * dy) ** 0.5
            hotspots.append(
                {
                    "id": index,
                    "feature_type": str(candidate.get("feature_type", "candidate")),
                    "pixel_centroid": {"x": float(cx), "y": float(cy)},
                    "hotspot_pixel_anchor": {"x": float(cx), "y": float(cy)},
                    "x": float(cx),
                    "y": float(cy),
                    "score": float(candidate.get("score", 0.0)),
                    "classification": str(candidate.get("classification", "C")),
                    "class": str(candidate.get("classification", "C")),
                    "reasoning": list(candidate.get("reasoning", [])),
                    "supporting_metrics": dict(candidate.get("metrics", {})),
                    "distance_px": float(distance_px),
                    "trust_state": "trusted",
                    "trust_score": 1.0,
                    "mapping_trust": "image_space",
                    "is_renderable": True,
                }
            )
        hotspots.sort(key=lambda item: (-float(item.get("score", 0.0)), float(item.get("distance_px", 0.0))))
        for rank, hotspot in enumerate(hotspots, start=1):
            hotspot["rank"] = rank
            hotspot["rank_overall"] = rank
            hotspot["rank_by_score_then_distance"] = rank
        proximity_order = sorted(hotspots, key=lambda item: float(item.get("distance_px", 0.0)))
        for proximity_rank, hotspot in enumerate(proximity_order, start=1):
            hotspot["rank_by_proximity"] = proximity_rank
        image_size = analysis.get("image_size", {})
        if isinstance(image_size, Mapping):
            iw = max(1, int(image_size.get("width", 1)))
            ih = max(1, int(image_size.get("height", 1)))
        else:
            iw, ih = 1, 1
        apply_reasoning_text_to_hotspots(hotspots, iw, ih)
        for hs in hotspots:
            hs["regional_species_context"] = None
            hs["species_match"] = []
        return hotspots

    @staticmethod
    def _nominal_meters_per_pixel_heuristic(width: int, height: int) -> float:
        span_px = max(float(width), float(height), 1.0)
        assumed_span_m = 4800.0
        return float(max(0.35, min(28.0, assumed_span_m / span_px)))

    @staticmethod
    def _passes_heuristic_spatial_candidate(candidate: Mapping[str, Any]) -> bool:
        metrics = candidate.get("metrics")
        if isinstance(metrics, Mapping):
            water_conf = float(metrics.get("water_confidence", 1.0))
            land_dist = float(metrics.get("land_distance_px", 999.0))
            if water_conf < 0.60:
                return False
            if land_dist < 4.0:
                return False
        return True

    @staticmethod
    def _geo_from_pixel_offset_local_tangent(
        boat_lat: float,
        boat_lon: float,
        dx_px: float,
        dy_px: float,
        meters_per_pixel: float,
    ) -> GeoPoint:
        r_earth = 6371000.0
        east_m = dx_px * float(meters_per_pixel)
        north_m = -dy_px * float(meters_per_pixel)
        phi = math.radians(float(boat_lat))
        cos_phi = math.cos(phi)
        if abs(cos_phi) < 1e-6:
            cos_phi = 1e-6 if cos_phi >= 0.0 else -1e-6
        d_lat = north_m / r_earth * (180.0 / math.pi)
        d_lon = east_m / (r_earth * cos_phi) * (180.0 / math.pi)
        return GeoPoint(lat=float(boat_lat) + d_lat, lon=float(boat_lon) + d_lon)

    def _build_ranked_hotspots_boat_gps_anchored(
        self,
        analysis: Mapping[str, Any],
        boat_anchor: BoatPixelAnchor,
        boat_lat: float,
        boat_lon: float,
        mapper: Optional[CoordinateMapper],
        heuristic_m_per_px: Optional[float],
    ) -> List[Dict[str, Any]]:
        bx = float(boat_anchor.x)
        by = float(boat_anchor.y)
        use_mapper = mapper is not None
        if not use_mapper:
            if heuristic_m_per_px is None:
                return []
            mpp = float(heuristic_m_per_px)
        else:
            mpp = 0.0

        boat_ref_geo: Optional[GeoPoint] = mapper.pixel_to_geo(bx, by) if use_mapper else None

        hotspots: List[Dict[str, Any]] = []
        rejected_geo_invalid = 0
        candidates = analysis.get("candidate_hotspots")
        if self._is_nonstring_sequence(candidates):
            for index, candidate in enumerate(candidates):
                if not isinstance(candidate, Mapping):
                    continue
                centroid = candidate.get("pixel_centroid")
                if not isinstance(centroid, Mapping):
                    continue
                cx = centroid.get("x")
                cy = centroid.get("y")
                if cx is None or cy is None:
                    continue
                if use_mapper:
                    assert mapper is not None and boat_ref_geo is not None
                    geo_raw = mapper.pixel_to_geo(float(cx), float(cy))
                    if not self._passes_geo_validity_relaxed(candidate=candidate, mapper=mapper, geo=geo_raw):
                        rejected_geo_invalid += 1
                        continue
                    h_lat = float(boat_lat) + (float(geo_raw.lat) - float(boat_ref_geo.lat))
                    h_lon = float(boat_lon) + (float(geo_raw.lon) - float(boat_ref_geo.lon))
                else:
                    dx = float(cx) - bx
                    dy = float(cy) - by
                    g = self._geo_from_pixel_offset_local_tangent(
                        boat_lat, boat_lon, dx, dy, mpp
                    )
                    h_lat, h_lon = float(g.lat), float(g.lon)

                if not (abs(h_lat) <= 90.0 and abs(h_lon) <= 180.0):
                    rejected_geo_invalid += 1
                    continue

                nav = calculate_bearing_and_distance(boat_lat, boat_lon, h_lat, h_lon)
                trust_state, trust_score = self._hotspot_trust_from_metrics(
                    candidate.get("metrics")
                )
                trust_state = "trusted"
                trust_score = max(0.55, float(trust_score))
                fishing_advice = self._build_fishing_advice(
                    metrics=candidate.get("metrics"),
                    feature_type=str(candidate.get("feature_type", "candidate")),
                )
                hotspots.append(
                    {
                        "id": index,
                        "feature_type": str(candidate.get("feature_type", "candidate")),
                        "pixel_centroid": {"x": float(cx), "y": float(cy)},
                        "hotspot_pixel_anchor": {"x": float(cx), "y": float(cy)},
                        "geo_coordinate": {"lat": h_lat, "lon": h_lon},
                        "latitude": h_lat,
                        "longitude": h_lon,
                        "distance_m": float(nav["distance_m"]),
                        "bearing_deg": float(nav["bearing_deg"]),
                        "score": float(candidate.get("score", 0.0)),
                        "classification": str(candidate.get("classification", "C")),
                        "reasoning": list(candidate.get("reasoning", [])),
                        "supporting_metrics": dict(candidate.get("metrics", {})),
                        "trust_state": trust_state,
                        "trust_score": trust_score,
                        "fishing_advice": fishing_advice,
                        "mapping_trust": "boat_anchor_estimated",
                        "is_renderable": True,
                    }
                )

        if not hotspots:
            feature_groups = analysis.get("features", {})
            flattened: List[Tuple[str, Dict[str, Any]]] = []
            if isinstance(feature_groups, Mapping):
                for feature_type, items in feature_groups.items():
                    if self._is_nonstring_sequence(items):
                        for item in items:
                            if isinstance(item, Mapping):
                                flattened.append((str(feature_type), dict(item)))

            for index, (feature_type, feature) in enumerate(flattened):
                centroid = feature.get("centroid")
                if not isinstance(centroid, Mapping):
                    continue
                cx = centroid.get("x")
                cy = centroid.get("y")
                if cx is None or cy is None:
                    continue
                synthetic = {"pixel_centroid": {"x": float(cx), "y": float(cy)}, "metrics": {}}
                if use_mapper:
                    assert mapper is not None and boat_ref_geo is not None
                    geo_raw = mapper.pixel_to_geo(float(cx), float(cy))
                    if not self._passes_geo_validity_relaxed(
                        candidate=synthetic, mapper=mapper, geo=geo_raw
                    ):
                        rejected_geo_invalid += 1
                        continue
                    h_lat = float(boat_lat) + (float(geo_raw.lat) - float(boat_ref_geo.lat))
                    h_lon = float(boat_lon) + (float(geo_raw.lon) - float(boat_ref_geo.lon))
                else:
                    dx = float(cx) - bx
                    dy = float(cy) - by
                    g = self._geo_from_pixel_offset_local_tangent(
                        boat_lat, boat_lon, dx, dy, mpp
                    )
                    h_lat, h_lon = float(g.lat), float(g.lon)

                if not (abs(h_lat) <= 90.0 and abs(h_lon) <= 180.0):
                    rejected_geo_invalid += 1
                    continue
                nav = calculate_bearing_and_distance(boat_lat, boat_lon, h_lat, h_lon)
                hotspots.append(
                    {
                        "id": index,
                        "feature_type": feature_type,
                        "pixel_centroid": {"x": float(cx), "y": float(cy)},
                        "hotspot_pixel_anchor": {"x": float(cx), "y": float(cy)},
                        "geo_coordinate": {"lat": h_lat, "lon": h_lon},
                        "latitude": h_lat,
                        "longitude": h_lon,
                        "distance_m": float(nav["distance_m"]),
                        "bearing_deg": float(nav["bearing_deg"]),
                        "bbox": feature.get("bbox"),
                        "area_px": feature.get("area_px"),
                        "score": 0.0,
                        "classification": "C",
                        "reasoning": ["Eski özellik boru hattı çıktısı"],
                        "supporting_metrics": {},
                        "trust_state": "suspicious_unknown",
                        "trust_score": 0.0,
                        "fishing_advice": self._build_fishing_advice(
                            metrics={},
                            feature_type=feature_type,
                        ),
                        "mapping_trust": "boat_anchor_estimated",
                        "is_renderable": True,
                    }
                )

        hotspots.sort(key=lambda item: (-float(item.get("score", 0.0)), float(item["distance_m"])))
        for rank, hotspot in enumerate(hotspots, start=1):
            hotspot["rank"] = rank
            hotspot["rank_overall"] = rank
            hotspot["rank_by_score_then_distance"] = rank
        proximity_order = sorted(hotspots, key=lambda item: float(item["distance_m"]))
        for proximity_rank, hotspot in enumerate(proximity_order, start=1):
            hotspot["rank_by_proximity"] = proximity_rank
        for hotspot in hotspots:
            hotspot["geo_validity_rejections_before_ranking"] = rejected_geo_invalid
        return hotspots

    def _build_ranked_hotspots(
        self,
        analysis: Mapping[str, Any],
        mapper: CoordinateMapper,
        boat_lat: float,
        boat_lon: float,
        mapping_mode: str,
    ) -> List[Dict[str, Any]]:
        hotspots: List[Dict[str, Any]] = []
        rejected_geo_invalid = 0
        candidates = analysis.get("candidate_hotspots")
        if self._is_nonstring_sequence(candidates):
            for index, candidate in enumerate(candidates):
                if not isinstance(candidate, Mapping):
                    continue
                centroid = candidate.get("pixel_centroid")
                if not isinstance(centroid, Mapping):
                    continue
                cx = centroid.get("x")
                cy = centroid.get("y")
                if cx is None or cy is None:
                    continue

                geo = mapper.pixel_to_geo(float(cx), float(cy))
                if not self._passes_geo_validity(candidate=candidate, mapper=mapper, geo=geo):
                    rejected_geo_invalid += 1
                    continue
                nav = calculate_bearing_and_distance(
                    boat_lat,
                    boat_lon,
                    geo.lat,
                    geo.lon,
                )
                trust_state, trust_score = self._hotspot_trust_from_metrics(
                    candidate.get("metrics")
                )
                fishing_advice = self._build_fishing_advice(
                    metrics=candidate.get("metrics"),
                    feature_type=str(candidate.get("feature_type", "candidate")),
                )
                hotspots.append(
                    {
                        "id": index,
                        "feature_type": str(candidate.get("feature_type", "candidate")),
                        "pixel_centroid": {"x": float(cx), "y": float(cy)},
                        "hotspot_pixel_anchor": {"x": float(cx), "y": float(cy)},
                        "geo_coordinate": {"lat": float(geo.lat), "lon": float(geo.lon)},
                        "latitude": float(geo.lat),
                        "longitude": float(geo.lon),
                        "distance_m": float(nav["distance_m"]),
                        "bearing_deg": float(nav["bearing_deg"]),
                        "score": float(candidate.get("score", 0.0)),
                        "classification": str(candidate.get("classification", "C")),
                        "reasoning": list(candidate.get("reasoning", [])),
                        "supporting_metrics": dict(candidate.get("metrics", {})),
                        "trust_state": trust_state,
                        "trust_score": trust_score,
                        "fishing_advice": fishing_advice,
                        "mapping_trust": (
                            "chart_aligned"
                            if self._is_chart_aligned_mapping_mode(mapping_mode)
                            else "approximate_world_fallback"
                        ),
                        "is_renderable": trust_state == "trusted",
                    }
                )

        if not hotspots:
            feature_groups = analysis.get("features", {})
            flattened: List[Tuple[str, Dict[str, Any]]] = []
            if isinstance(feature_groups, Mapping):
                for feature_type, items in feature_groups.items():
                    if self._is_nonstring_sequence(items):
                        for item in items:
                            if isinstance(item, Mapping):
                                flattened.append((str(feature_type), dict(item)))

            for index, (feature_type, feature) in enumerate(flattened):
                centroid = feature.get("centroid")
                if not isinstance(centroid, Mapping):
                    continue
                cx = centroid.get("x")
                cy = centroid.get("y")
                if cx is None or cy is None:
                    continue

                geo = mapper.pixel_to_geo(float(cx), float(cy))
                synthetic_candidate = {"pixel_centroid": {"x": float(cx), "y": float(cy)}, "metrics": {}}
                if not self._passes_geo_validity(candidate=synthetic_candidate, mapper=mapper, geo=geo):
                    rejected_geo_invalid += 1
                    continue
                nav = calculate_bearing_and_distance(
                    boat_lat,
                    boat_lon,
                    geo.lat,
                    geo.lon,
                )
                hotspots.append(
                    {
                        "id": index,
                        "feature_type": feature_type,
                        "pixel_centroid": {"x": float(cx), "y": float(cy)},
                        "hotspot_pixel_anchor": {"x": float(cx), "y": float(cy)},
                        "geo_coordinate": {"lat": float(geo.lat), "lon": float(geo.lon)},
                        "latitude": float(geo.lat),
                        "longitude": float(geo.lon),
                        "distance_m": float(nav["distance_m"]),
                        "bearing_deg": float(nav["bearing_deg"]),
                        "bbox": feature.get("bbox"),
                        "area_px": feature.get("area_px"),
                        "score": 0.0,
                        "classification": "C",
                        "reasoning": ["Eski özellik boru hattı çıktısı"],
                        "supporting_metrics": {},
                        "trust_state": "suspicious_unknown",
                        "trust_score": 0.0,
                        "fishing_advice": self._build_fishing_advice(
                            metrics={},
                            feature_type=feature_type,
                        ),
                        "mapping_trust": (
                            "chart_aligned"
                            if self._is_chart_aligned_mapping_mode(mapping_mode)
                            else "approximate_world_fallback"
                        ),
                        "is_renderable": False,
                    }
                )

        hotspots.sort(key=lambda item: (-float(item.get("score", 0.0)), float(item["distance_m"])))
        for rank, hotspot in enumerate(hotspots, start=1):
            hotspot["rank"] = rank
            hotspot["rank_overall"] = rank
            hotspot["rank_by_score_then_distance"] = rank
        proximity_order = sorted(hotspots, key=lambda item: float(item["distance_m"]))
        for proximity_rank, hotspot in enumerate(proximity_order, start=1):
            # Backward compatibility field; now mapped to true proximity-only ordering.
            hotspot["rank_by_proximity"] = proximity_rank
        for hotspot in hotspots:
            hotspot["geo_validity_rejections_before_ranking"] = rejected_geo_invalid
        return hotspots

    @staticmethod
    def _is_chart_aligned_mapping_mode(mapping_mode: str) -> bool:
        mode = str(mapping_mode).lower()
        return (
            mode == "affine_control_points"
            or "affine" in mode
            or "control_point" in mode
            or "screenshot" in mode
        )

    @staticmethod
    def _hotspot_trust_from_metrics(metrics: Any) -> Tuple[str, float]:
        if not isinstance(metrics, Mapping):
            return "suspicious_unknown", 0.0
        water_conf = float(metrics.get("water_confidence", 0.0))
        land_dist = float(metrics.get("land_distance_px", 0.0))
        coast_dist = float(metrics.get("coast_distance_px", 0.0))
        structure = float(metrics.get("structure_score", 0.0))
        trust_score = max(0.0, min(1.0, 0.50 * water_conf + 0.25 * min(1.0, land_dist / 10.0) + 0.25 * structure))
        if water_conf < 0.60:
            return "suspicious_low_water_confidence", trust_score
        if land_dist < 4.0:
            return "suspicious_near_land", trust_score
        if coast_dist < 3.0:
            return "suspicious_coastline_collision", trust_score
        return "trusted", trust_score

    @staticmethod
    def _build_fishing_advice(metrics: Any, feature_type: str) -> Dict[str, Any]:
        m = dict(metrics) if isinstance(metrics, Mapping) else {}
        slope = float(m.get("slope", 0.0))
        contour_density = float(m.get("contour_density", 0.0))
        structure_score = float(m.get("structure_score", 0.0))
        ridge_probability = float(m.get("ridge_likelihood", 0.0))
        basin_probability = float(m.get("basin_likelihood", 0.0))
        transition_band = float(m.get("transition_band", 0.0))
        local_relief = float(m.get("local_relief", 0.0))
        water_confidence = float(m.get("water_confidence", 0.0))
        distance_to_coast = float(m.get("coast_distance_px", 0.0))

        normalized_feature = str(feature_type).lower()

        species_scores: Dict[str, float] = {
            "Levrek": 0.0,
            "Sinarit": 0.0,
            "Lahoz": 0.0,
            "Akya": 0.0,
            "Mercan": 0.0,
            "Çupra": 0.0,
            "Orfoz": 0.0,
            "Karagöz": 0.0,
            "Trança": 0.0,
        }
        reasons: List[str] = []

        if slope > 0.55 and contour_density > 0.60:
            species_scores["Sinarit"] += 0.35
            species_scores["Lahoz"] += 0.30
            species_scores["Akya"] += 0.22
            reasons.append("Keskin derinlik kırığı ve yüksek kontur yoğunluğu")

        if structure_score > 0.60 or ridge_probability > 0.55:
            species_scores["Akya"] += 0.26
            species_scores["Orfoz"] += 0.25
            species_scores["Lahoz"] += 0.22
            reasons.append("Güçlü yapı skoru ve sırt etkisi")

        if transition_band > 0.55:
            species_scores["Mercan"] += 0.30
            species_scores["Çupra"] += 0.26
            species_scores["Karagöz"] += 0.20
            reasons.append("Geçiş bandı uygunluğu")

        if basin_probability > 0.55:
            species_scores["Trança"] += 0.28
            species_scores["Mercan"] += 0.18
            reasons.append("Çanak eğilimi dip türleri için uygun")

        if local_relief > 0.45 and distance_to_coast < 10.0:
            species_scores["Levrek"] += 0.28
            species_scores["Karagöz"] += 0.25
            reasons.append("Kıyıya yakın yapı ve yerel kabartı mevcut")

        if normalized_feature == "drop_off":
            species_scores["Sinarit"] += 0.20
            species_scores["Akya"] += 0.15
            reasons.append("Drop-off yapısı avcı türleri destekliyor")
        elif normalized_feature == "ridge_spur":
            species_scores["Akya"] += 0.20
            species_scores["Lahoz"] += 0.15
            reasons.append("Sırt/çıkıntı formu pusu avcılarını destekliyor")
        elif normalized_feature == "basin_bowl":
            species_scores["Trança"] += 0.20
            species_scores["Mercan"] += 0.16
            reasons.append("Çanak/çukur formu dip beslenmesine uygun")
        elif normalized_feature == "shelf":
            species_scores["Çupra"] += 0.18
            species_scores["Karagöz"] += 0.15
            reasons.append("Sığlık geçişi kıyı türleri için avantajlı")

        if water_confidence < 0.60:
            # Belirsiz bölgede öneri güvenini düşür.
            for k in species_scores:
                species_scores[k] *= 0.75
            reasons.append("Su güveni orta/düşük, öneriler temkinli değerlendirilmeli")

        sorted_species = sorted(
            species_scores.items(),
            key=lambda item: item[1],
            reverse=True,
        )
        top_species = [item for item in sorted_species if item[1] > 0.10][:4]
        if not top_species:
            top_species = [("Mercan", 0.20), ("Karagöz", 0.18), ("Çupra", 0.16)]
            reasons.append("Yapı sinyali düşük, genel dip-geçiş türleri öne alındı")

        def _prob_label(score: float) -> str:
            if score >= 0.45:
                return "yüksek"
            if score >= 0.28:
                return "orta"
            return "düşük"

        species_predictions = [
            {"species": name, "probability": _prob_label(score)}
            for name, score in top_species
        ]

        predator_set = {"Sinarit", "Akya", "Lahoz", "Orfoz", "Levrek"}
        bottom_set = {"Mercan", "Çupra", "Karagöz", "Trança"}
        selected_names = {item["species"] for item in species_predictions}

        bait: List[str] = []
        if selected_names & predator_set:
            bait.extend(["Canlı yem", "Kalamar", "Zargana", "İstavrit"])
        if selected_names & bottom_set:
            bait.extend(["Canlı karides", "Sardalya parçası"])
        bait = list(dict.fromkeys(bait))[:5]

        best_times: List[str] = []
        if selected_names & predator_set:
            best_times.extend(["Gün doğumu civarı", "Gün batımı öncesi"])
        if selected_names & {"Lahoz", "Orfoz", "Trança", "Mercan"}:
            best_times.append("Gece saatleri (özellikle dip avı)")
        if not best_times:
            best_times = ["Gün doğumu civarı", "Gün batımı öncesi"]
        best_times = list(dict.fromkeys(best_times))

        tackle: List[str] = []
        if normalized_feature in {"drop_off", "ridge_spur"} or selected_names & {"Akya", "Sinarit"}:
            tackle.extend(["Jigging takımı", "Slow jig sistemi"])
        if normalized_feature in {"basin_bowl", "shelf"} or selected_names & bottom_set:
            tackle.append("Dip oltası (2 iğneli takım)")
        if distance_to_coast < 10.0 or selected_names & {"Levrek", "Karagöz"}:
            tackle.append("Spin takımı (kıyı yakınsa)")
        if not tackle:
            tackle = ["Dip oltası (2 iğneli takım)"]
        tackle = list(dict.fromkeys(tackle))

        return {
            "species_predictions": species_predictions,
            "bait": bait,
            "best_times": best_times,
            "tackle": tackle,
            "selection_reasons": reasons[:5],
            "metrics_used": {
                "slope": slope,
                "contour_density": contour_density,
                "structure_score": structure_score,
                "ridge_probability": ridge_probability,
                "basin_probability": basin_probability,
                "transition_band": transition_band,
                "local_relief": local_relief,
                "water_confidence": water_confidence,
                "distance_to_coast": distance_to_coast,
            },
        }

    def _enrich_hotspots(self, hotspots: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        client = self.marine_data_client
        if client is None:
            return hotspots

        enriched: List[Optional[Dict[str, Any]]] = [None] * len(hotspots)
        max_workers = min(self.enrichment_workers, len(hotspots))
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(client.enrich_hotspot_data, hotspot): idx
                for idx, hotspot in enumerate(hotspots)
            }
            for future in as_completed(futures):
                idx = futures[future]
                try:
                    result = future.result()
                    enriched[idx] = result if isinstance(result, dict) else hotspots[idx]
                except Exception:
                    enriched[idx] = hotspots[idx]

        return [item if item is not None else hotspots[idx] for idx, item in enumerate(enriched)]

    @staticmethod
    def _chart_bounds_geographically_valid(bounds: ImageGeoBounds) -> bool:
        tl, br = bounds.top_left, bounds.bottom_right
        for p in (tl, br):
            if not isfinite(p.lat) or not isfinite(p.lon):
                return False
            if abs(p.lat) > 90.0 or abs(p.lon) > 180.0:
                return False
        min_lat = min(tl.lat, br.lat)
        max_lat = max(tl.lat, br.lat)
        min_lon = min(tl.lon, br.lon)
        max_lon = max(tl.lon, br.lon)
        if abs(max_lat - min_lat) < 1e-7 or abs(max_lon - min_lon) < 1e-7:
            return False
        return True

    def _attach_regional_species_context(
        self,
        hotspots: List[Dict[str, Any]],
        bounds: ImageGeoBounds,
    ) -> None:
        """OBIS-first regional occurrence text plus structure-aware species_match (geo-calibrated charts only)."""
        for h in hotspots:
            h["regional_species_context"] = None
            h["species_match"] = []
        if not hotspots:
            return
        if not self._chart_bounds_geographically_valid(bounds):
            return
        client = self.marine_data_client
        if client is None:
            return
        try:
            bundle = client.get_regional_species_bundle_for_bounds(
                bounds.top_left.lat,
                bounds.top_left.lon,
                bounds.bottom_right.lat,
                bounds.bottom_right.lon,
            )
        except Exception:
            return
        ctx, names_bundle = bundle
        names = names_bundle if isinstance(names_bundle, list) else []
        regional_text = str(ctx).strip() if isinstance(ctx, str) and str(ctx).strip() else None
        if regional_text:
            for h in hotspots:
                h["regional_species_context"] = regional_text
        names_list = [str(x).strip() for x in names if str(x).strip()]
        for h in hotspots:
            h["species_match"] = compute_species_matches(h, names_list, max_items=3)

    def _build_mapper_for_chart(
        self,
        width: int,
        height: int,
        bounds: ImageGeoBounds,
        control_points: Optional[Sequence[PixelGeoControlPoint]],
    ) -> Tuple[CoordinateMapper, str]:
        """
        Build a chart-specific mapper from runtime image dimensions and bounds.

        Uses the existing mapper only if dimensions and bounds already match.
        Otherwise creates a fresh mapper for deterministic conversion.
        """
        if control_points and len(control_points) >= 3:
            primary = list(control_points)
            cp = tuple(
                (
                    GeoPoint(lat=float(item.geo_lat), lon=float(item.geo_lon)),
                    (float(item.pixel_x), float(item.pixel_y)),
                )
                for item in primary
            )
            affine_points = tuple(
                (self._to_pixel_point(item[1]), item[0])
                for item in cp
            )
            return (
                CoordinateMapper(
                    image_width=width,
                    image_height=height,
                    top_left=bounds.top_left,
                    bottom_right=bounds.bottom_right,
                    affine_control_points=affine_points,
                ),
                "affine_control_points",
            )

        current = self.coordinate_mapper
        if current is None:
            return (
                CoordinateMapper(
                    image_width=width,
                    image_height=height,
                    top_left=bounds.top_left,
                    bottom_right=bounds.bottom_right,
                ),
                "linear_bounds",
            )
        same_shape = int(current.image_width) == int(width) and int(current.image_height) == int(height)
        same_bounds = (
            abs(current.top_left.lat - bounds.top_left.lat) < 1e-12
            and abs(current.top_left.lon - bounds.top_left.lon) < 1e-12
            and abs(current.bottom_right.lat - bounds.bottom_right.lat) < 1e-12
            and abs(current.bottom_right.lon - bounds.bottom_right.lon) < 1e-12
        )

        if same_shape and same_bounds:
            return current, "linear_bounds_cached"

        return (
            CoordinateMapper(
                image_width=width,
                image_height=height,
                top_left=bounds.top_left,
                bottom_right=bounds.bottom_right,
            ),
            "linear_bounds",
        )

    @staticmethod
    def _derive_bounds_from_geo_points(
        lats: Sequence[float],
        lons: Sequence[float],
    ) -> Tuple[GeoPoint, GeoPoint]:
        if not lats or not lons:
            raise ValueError("Cannot derive chart bounds without geographic coordinates.")
        min_lat = min(lats)
        max_lat = max(lats)
        min_lon = min(lons)
        max_lon = max(lons)
        lat_pad = max((max_lat - min_lat) * 0.05, 1e-4)
        lon_pad = max((max_lon - min_lon) * 0.05, 1e-4)
        return (
            GeoPoint(lat=max_lat + lat_pad, lon=min_lon - lon_pad),
            GeoPoint(lat=min_lat - lat_pad, lon=max_lon + lon_pad),
        )

    @staticmethod
    def _parse_bounds(
        image_geo_bounds: Mapping[str, Any],
    ) -> Tuple[
        ImageGeoBounds,
        Optional[List[PixelGeoControlPoint]],
        Optional[BoatPixelAnchor],
        ControlPointDiagnostics,
    ]:
        if not isinstance(image_geo_bounds, Mapping):
            raise ValueError("image_geo_bounds must be a mapping.")

        control_points, cp_diag = FishingHotspotManager._parse_control_points(
            image_geo_bounds.get("control_points")
        )
        boat_anchor = FishingHotspotManager._parse_boat_pixel_anchor(
            image_geo_bounds.get("boat_pixel_anchor")
        )

        top_left_raw = image_geo_bounds.get("top_left")
        bottom_right_raw = image_geo_bounds.get("bottom_right")
        if top_left_raw is not None and bottom_right_raw is not None:
            top_left = FishingHotspotManager._to_geopoint(top_left_raw, key_name="top_left")
            bottom_right = FishingHotspotManager._to_geopoint(
                bottom_right_raw, key_name="bottom_right"
            )
        elif control_points and len(control_points) >= 2:
            lats = [cp.geo_lat for cp in control_points]
            lons = [cp.geo_lon for cp in control_points]
            top_left, bottom_right = FishingHotspotManager._derive_bounds_from_geo_points(
                lats, lons
            )
        else:
            raise ValueError(
                "image_geo_bounds must include 'top_left' and 'bottom_right', "
                "or at least two valid control_points."
            )

        norm_tl, norm_br = CoordinateMapper._normalize_corner_bounds(top_left, bottom_right)
        return (
            ImageGeoBounds(top_left=norm_tl, bottom_right=norm_br),
            control_points,
            boat_anchor,
            cp_diag,
        )

    @staticmethod
    def _to_geopoint(raw: Any, key_name: str) -> GeoPoint:
        if isinstance(raw, Mapping):
            lat = raw.get("lat")
            lon = raw.get("lon")
        elif isinstance(raw, Sequence) and len(raw) == 2 and not isinstance(raw, (str, bytes)):
            lat, lon = raw[0], raw[1]
        else:
            raise ValueError(f"'{key_name}' must be a dict {{lat, lon}} or [lat, lon].")

        if lat is None or lon is None:
            raise ValueError(f"'{key_name}' is missing lat/lon.")
        return GeoPoint(lat=float(lat), lon=float(lon))

    @staticmethod
    def _is_nonstring_sequence(value: Any) -> bool:
        return isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray))

    @staticmethod
    def _to_pixel_point(raw: Tuple[float, float]):
        from geo_navigation import PixelPoint

        return PixelPoint(x=float(raw[0]), y=float(raw[1]))

    @staticmethod
    def _parse_control_points(raw: Any) -> Tuple[Optional[List[PixelGeoControlPoint]], ControlPointDiagnostics]:
        if raw is None:
            return None, ControlPointDiagnostics(received=0, valid=0, invalid=0, status="not_provided")
        if not isinstance(raw, Sequence) or isinstance(raw, (str, bytes, bytearray)):
            return None, ControlPointDiagnostics(received=0, valid=0, invalid=0, status="invalid_type")

        points: List[PixelGeoControlPoint] = []
        received = 0
        invalid = 0
        for item in raw:
            received += 1
            if not isinstance(item, Mapping):
                invalid += 1
                continue
            pixel = item.get("pixel")
            geo = item.get("geo")
            if not isinstance(pixel, Mapping) or not isinstance(geo, Mapping):
                invalid += 1
                continue
            x = pixel.get("x")
            y = pixel.get("y")
            lat = geo.get("lat")
            lon = geo.get("lon")
            if None in (x, y, lat, lon):
                invalid += 1
                continue
            try:
                fx = float(x)
                fy = float(y)
                flat = float(lat)
                flon = float(lon)
            except (TypeError, ValueError):
                invalid += 1
                continue
            if not all(
                (
                    isfinite(fx),
                    isfinite(fy),
                    isfinite(flat),
                    isfinite(flon),
                    abs(flat) <= 90.0,
                    abs(flon) <= 180.0,
                    fx >= 0.0,
                    fy >= 0.0,
                )
            ):
                invalid += 1
                continue
            points.append(
                PixelGeoControlPoint(
                    pixel_x=fx,
                    pixel_y=fy,
                    geo_lat=flat,
                    geo_lon=flon,
                )
            )
        valid = len(points)
        if valid >= 3:
            return points, ControlPointDiagnostics(
                received=received,
                valid=valid,
                invalid=invalid,
                status="accepted",
            )
        if received > 0:
            return None, ControlPointDiagnostics(
                received=received,
                valid=valid,
                invalid=invalid,
                status="insufficient_valid_points",
            )
        return None, ControlPointDiagnostics(received=0, valid=0, invalid=0, status="not_provided")

    @staticmethod
    def _evaluate_control_point_quality(
        mapper: CoordinateMapper,
        mapping_mode: str,
        base_diag: ControlPointDiagnostics,
        control_points: Optional[Sequence[PixelGeoControlPoint]],
    ) -> ControlPointDiagnostics:
        if mapping_mode != "affine_control_points" or not control_points:
            return base_diag
        primary = list(control_points)
        errors_m: List[float] = []
        for cp in primary:
            mapped = mapper.pixel_to_geo(cp.pixel_x, cp.pixel_y)
            dist = calculate_bearing_and_distance(
                cp.geo_lat,
                cp.geo_lon,
                mapped.lat,
                mapped.lon,
            )["distance_m"]
            errors_m.append(float(dist))
        if not errors_m:
            return base_diag
        rmse = float((sum(e * e for e in errors_m) / len(errors_m)) ** 0.5)
        # 0m => 1.0; ~2km RMSE => ~0 kalite (yaklaşık mod eşiği).
        quality = max(0.0, min(1.0, 1.0 - (rmse / 2000.0)))
        return ControlPointDiagnostics(
            received=base_diag.received,
            valid=base_diag.valid,
            invalid=base_diag.invalid,
            status=base_diag.status,
            georeference_error_m=rmse,
            transform_quality=quality,
        )

    @staticmethod
    def _parse_boat_pixel_anchor(raw: Any) -> Optional[BoatPixelAnchor]:
        if not isinstance(raw, Mapping):
            return None
        x = raw.get("x")
        y = raw.get("y")
        if x is None or y is None:
            return None
        confidence = float(raw.get("confidence", 1.0))
        source = str(raw.get("source", "manual_bounds_fallback"))
        return BoatPixelAnchor(
            x=float(x),
            y=float(y),
            confidence=confidence,
            source=source,
            detection_method="manual_input",
            status="manual",
        )

    @staticmethod
    def _count_pixel_hotspot_candidates(analysis: Mapping[str, Any]) -> int:
        n = 0
        candidates = analysis.get("candidate_hotspots")
        if FishingHotspotManager._is_nonstring_sequence(candidates):
            for c in candidates:
                if not isinstance(c, Mapping):
                    continue
                centroid = c.get("pixel_centroid")
                if isinstance(centroid, Mapping) and centroid.get("x") is not None and centroid.get("y") is not None:
                    n += 1
        feature_groups = analysis.get("features", {})
        if isinstance(feature_groups, Mapping):
            for _ft, items in feature_groups.items():
                if not FishingHotspotManager._is_nonstring_sequence(items):
                    continue
                for item in items:
                    if not isinstance(item, Mapping):
                        continue
                    centroid = item.get("centroid")
                    if isinstance(centroid, Mapping) and centroid.get("x") is not None and centroid.get("y") is not None:
                        n += 1
        return int(n)

    @staticmethod
    def _hotspot_geo_count_plausible(hotspots: Sequence[Mapping[str, Any]]) -> int:
        k = 0
        for h in hotspots:
            if not isinstance(h, Mapping):
                continue
            lat = h.get("latitude")
            lon = h.get("longitude")
            if lat is None or lon is None:
                continue
            try:
                flat = float(lat)
                flon = float(lon)
            except (TypeError, ValueError):
                continue
            if not isfinite(flat) or not isfinite(flon):
                continue
            if abs(flat) < 1e-9 and abs(flon) < 1e-9:
                continue
            k += 1
        return int(k)

    def _resolve_boat_anchor_for_estimate(
        self,
        *,
        image_geo_bounds: Mapping[str, Any],
        request_boat_anchor: Optional[BoatPixelAnchor],
        detected_boat_anchor: Optional[BoatPixelAnchor],
        analysis: Mapping[str, Any],
        width: int,
        height: int,
    ) -> Tuple[BoatPixelAnchor, str, str]:
        """
        Product fallback chain: detected → lenient client anchor → highest-score centroid → image center.
        """
        if detected_boat_anchor is not None:
            return (
                detected_boat_anchor,
                detected_boat_anchor.source or "detected",
                "detected_boat_anchor",
            )
        raw_req = image_geo_bounds.get("boat_pixel_anchor") if isinstance(image_geo_bounds, Mapping) else None
        lenient = self._parse_boat_pixel_anchor(raw_req)
        if lenient is not None:
            return lenient, lenient.source or "manual_image_anchor", "request_boat_pixel_anchor"

        best: Optional[Tuple[float, BoatPixelAnchor]] = None
        candidates = analysis.get("candidate_hotspots")
        if self._is_nonstring_sequence(candidates):
            for c in candidates:
                if not isinstance(c, Mapping):
                    continue
                centroid = c.get("pixel_centroid")
                if not isinstance(centroid, Mapping):
                    continue
                cx, cy = centroid.get("x"), centroid.get("y")
                if cx is None or cy is None:
                    continue
                score = float(c.get("score", 0.0))
                anchor = BoatPixelAnchor(
                    x=float(cx),
                    y=float(cy),
                    confidence=min(1.0, max(0.35, score)),
                    source="hotspot_centroid_proxy",
                    detection_method="rank_proxy",
                    status="fallback",
                )
                if best is None or score > best[0]:
                    best = (score, anchor)
        if best is not None:
            return best[1], "hotspot_centroid_proxy", "best_candidate_centroid_anchor"

        center = self._image_center_anchor(width=width, height=height)
        return center, "image_center", "fallback_image_center"

    @staticmethod
    def _extract_detected_boat_anchor(diagnostics: Mapping[str, Any]) -> Optional[BoatPixelAnchor]:
        detection = diagnostics.get("boat_anchor_detection")
        if not isinstance(detection, Mapping):
            return None
        raw_anchor = detection.get("boat_pixel_anchor")
        if not isinstance(raw_anchor, Mapping):
            return None
        x = raw_anchor.get("x")
        y = raw_anchor.get("y")
        if x is None or y is None:
            return None
        confidence = float(detection.get("anchor_confidence", 0.0))
        status = str(detection.get("status", "low_confidence"))
        if status != "detected" or confidence < 0.45:
            return None
        return BoatPixelAnchor(
            x=float(x),
            y=float(y),
            confidence=confidence,
            source="detected",
            detection_method=str(detection.get("anchor_detection_method", "hsv_component_scoring_v1")),
            status=status,
        )

    @staticmethod
    def _passes_geo_validity(candidate: Mapping[str, Any], mapper: CoordinateMapper, geo: GeoPoint) -> bool:
        centroid = candidate.get("pixel_centroid")
        if not isinstance(centroid, Mapping):
            return False
        cx = centroid.get("x")
        cy = centroid.get("y")
        if cx is None or cy is None:
            return False
        reproj = mapper.geo_to_pixel(float(geo.lat), float(geo.lon))
        reproj_error = ((float(cx) - float(reproj.x)) ** 2 + (float(cy) - float(reproj.y)) ** 2) ** 0.5
        if reproj_error > 2.5:
            return False
        metrics = candidate.get("metrics")
        if isinstance(metrics, Mapping):
            water_conf = float(metrics.get("water_confidence", 1.0))
            land_dist = float(metrics.get("land_distance_px", 999.0))
            if water_conf < 0.60:
                return False
            if land_dist < 4.0:
                return False
        return True

    @staticmethod
    def _passes_geo_validity_relaxed(
        candidate: Mapping[str, Any],
        mapper: CoordinateMapper,
        geo: GeoPoint,
        *,
        reproj_max_px: float = 96.0,
    ) -> bool:
        centroid = candidate.get("pixel_centroid")
        if not isinstance(centroid, Mapping):
            return False
        cx = centroid.get("x")
        cy = centroid.get("y")
        if cx is None or cy is None:
            return False
        reproj = mapper.geo_to_pixel(float(geo.lat), float(geo.lon))
        reproj_error = ((float(cx) - float(reproj.x)) ** 2 + (float(cy) - float(reproj.y)) ** 2) ** 0.5
        if reproj_error > reproj_max_px:
            return False
        metrics = candidate.get("metrics")
        if isinstance(metrics, Mapping):
            water_conf = float(metrics.get("water_confidence", 1.0))
            land_dist = float(metrics.get("land_distance_px", 999.0))
            if water_conf < 0.35:
                return False
            if land_dist < 2.0:
                return False
        return True
