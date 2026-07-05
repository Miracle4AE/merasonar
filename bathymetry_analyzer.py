from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Sequence, Tuple

import cv2
import numpy as np
from scipy import ndimage


class BathymetryAnalysisError(RuntimeError):
    """Raised when bathymetry analysis cannot be completed."""


@dataclass(frozen=True)
class HSVRange:
    """Inclusive HSV range for color masking."""

    lower: Tuple[int, int, int]
    upper: Tuple[int, int, int]


@dataclass(frozen=True)
class HotspotScoringWeights:
    slope: float = 0.30
    contour_density: float = 0.30
    dropoff_proximity: float = 0.25
    structure_score: float = 0.15
    transition_band: float = 0.10
    flat_penalty: float = 0.02
    invalid_region_penalty: float = 0.10


@dataclass(frozen=True)
class StructureStackPoints:
    base_slope: float = 3.4
    base_contour_density: float = 3.0
    base_dropoff: float = 2.1
    base_transition_band: float = 1.2
    base_structure: float = 1.6
    ridge_tip_bonus: float = 1.8
    saddle_bonus: float = 1.6
    intersection_bonus: float = 2.2
    breakline_edge_bonus: float = 1.5
    isolation_bonus: float = 1.7
    pocket_bonus: float = 1.4
    stack_bonus_multiplier: float = 0.6
    flat_penalty: float = 1.6
    invalid_region_penalty: float = 2.0


@dataclass(frozen=True)
class HotspotThresholds:
    min_score: float = 0.20
    class_a: float = 0.55
    class_b: float = 0.40
    min_contour_density: float = 0.03
    min_coast_distance_px: float = 3.0
    min_water_confidence: float = 0.72
    min_land_distance_px: float = 6.0
    min_structure_evidence: float = 0.32
    min_local_relief: float = 0.14


class BathymetryAnalyzer:
    """
    Analyze nautical chart imagery with explainable pseudo-bathymetric scoring.

    Pipeline:
    1) Extract water mask, coastline mask, contour mask.
    2) Build pseudo-depth grid and terrain feature maps.
    3) Compute weighted explainable hotspot score.
    4) Apply non-max suppression and water/land validation.
    5) Return candidate hotspots + legacy feature groups for compatibility.
    """

    def __init__(
        self,
        depth_color_ranges: Optional[Sequence[HSVRange]] = None,
        land_color_ranges: Optional[Sequence[HSVRange]] = None,
        canny_sigma: float = 0.33,
        min_region_area_px: int = 60,
        peak_window_size: int = 19,
        suppression_radius_px: float = 24.0,
        max_hotspots: int = 80,
        scoring_weights: HotspotScoringWeights = HotspotScoringWeights(),
        structure_stack_points: StructureStackPoints = StructureStackPoints(),
        thresholds: HotspotThresholds = HotspotThresholds(),
    ) -> None:
        if canny_sigma <= 0.0:
            raise ValueError("canny_sigma must be > 0")
        if min_region_area_px < 1:
            raise ValueError("min_region_area_px must be >= 1")
        if peak_window_size < 3 or peak_window_size % 2 == 0:
            raise ValueError("peak_window_size must be odd and >= 3")
        if suppression_radius_px <= 0.0:
            raise ValueError("suppression_radius_px must be > 0")
        if max_hotspots < 1:
            raise ValueError("max_hotspots must be >= 1")

        self.depth_color_ranges: Sequence[HSVRange] = depth_color_ranges or (
            HSVRange((0, 0, 0), (180, 100, 135)),
            HSVRange((0, 80, 90), (15, 255, 255)),
            HSVRange((165, 80, 90), (180, 255, 255)),
        )
        self.land_color_ranges: Sequence[HSVRange] = land_color_ranges or (
            HSVRange((10, 25, 65), (42, 255, 255)),
            HSVRange((0, 0, 205), (180, 40, 255)),
            HSVRange((22, 130, 135), (38, 255, 245)),
        )
        self.canny_sigma = canny_sigma
        self.min_region_area_px = min_region_area_px
        self.peak_window_size = peak_window_size
        self.suppression_radius_px = float(suppression_radius_px)
        self.max_hotspots = int(max_hotspots)
        self.scoring_weights = scoring_weights
        self.structure_stack_points = structure_stack_points
        self.thresholds = thresholds

    def analyze_chart(self, image_path: str) -> Dict[str, Any]:
        image = self._load_image(image_path)
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

        chart_mask = self._build_chart_content_mask(hsv)
        land_mask = self._build_mask_from_ranges(hsv, self.land_color_ranges)
        land_mask = cv2.bitwise_and(
            self._refine_binary_mask(land_mask, kernel_size=5),
            chart_mask,
        )
        water_mask = self._build_water_mask(hsv=hsv, chart_mask=chart_mask, land_mask=land_mask)
        coastline_mask = self._build_coastline_mask(water_mask)

        contour_mask = self._extract_contour_mask(image, hsv, water_mask)
        pseudo_depth_grid = self._build_pseudo_depth_grid(contour_mask, water_mask, coastline_mask)
        feature_maps = self._compute_feature_maps(
            pseudo_depth_grid=pseudo_depth_grid,
            contour_mask=contour_mask,
            water_mask=water_mask,
            land_mask=land_mask,
            coastline_mask=coastline_mask,
        )
        score_map = self._compute_score_map(feature_maps, water_mask)

        candidate_hotspots, candidate_stats = self._extract_hotspot_candidates(
            score_map=score_map,
            feature_maps=feature_maps,
            water_mask=water_mask,
            land_mask=land_mask,
            coastline_mask=coastline_mask,
        )
        boat_anchor_detection = self._detect_boat_pixel_anchor(
            image_bgr=image,
            water_mask=water_mask,
            land_mask=land_mask,
        )

        legacy_features = self._build_legacy_feature_groups(candidate_hotspots)

        return {
            "image_path": image_path,
            "image_size": {"width": int(image.shape[1]), "height": int(image.shape[0])},
            "counts": {
                "drop_offs": len(legacy_features["drop_offs"]),
                "ridges_spurs": len(legacy_features["ridges_spurs"]),
                "basins_bowls": len(legacy_features["basins_bowls"]),
                "shelves": len(legacy_features["shelves"]),
                "candidate_hotspots": len(candidate_hotspots),
            },
            "features": legacy_features,
            "candidate_hotspots": candidate_hotspots,
            "diagnostics": {
                "contour_pixels": int(np.count_nonzero(contour_mask)),
                "water_pixels": int(np.count_nonzero(water_mask)),
                "land_pixels": int(np.count_nonzero(land_mask)),
                "chart_pixels": int(np.count_nonzero(chart_mask)),
                "coastline_pixels": int(np.count_nonzero(coastline_mask)),
                "coastline_confidence": self._coastline_confidence(water_mask=water_mask, coastline_mask=coastline_mask),
                "score_mean": float(np.mean(score_map[water_mask > 0])) if np.any(water_mask > 0) else 0.0,
                "score_max": float(np.max(score_map)) if score_map.size else 0.0,
                "candidate_stats": candidate_stats,
                "boat_anchor_detection": boat_anchor_detection,
                "boat_pixel_anchor": boat_anchor_detection.get("boat_pixel_anchor"),
                "grid_stats": {
                    "pseudo_depth_min": float(np.min(pseudo_depth_grid[water_mask > 0])) if np.any(water_mask > 0) else 0.0,
                    "pseudo_depth_max": float(np.max(pseudo_depth_grid[water_mask > 0])) if np.any(water_mask > 0) else 0.0,
                },
                "weights": {
                    "slope": self.scoring_weights.slope,
                    "contour_density": self.scoring_weights.contour_density,
                    "dropoff_proximity": self.scoring_weights.dropoff_proximity,
                    "structure_score": self.scoring_weights.structure_score,
                    "transition_band": self.scoring_weights.transition_band,
                    "flat_penalty": self.scoring_weights.flat_penalty,
                    "invalid_region_penalty": self.scoring_weights.invalid_region_penalty,
                },
                "structure_stack_points": {
                    "base_slope": self.structure_stack_points.base_slope,
                    "base_contour_density": self.structure_stack_points.base_contour_density,
                    "base_dropoff": self.structure_stack_points.base_dropoff,
                    "base_transition_band": self.structure_stack_points.base_transition_band,
                    "base_structure": self.structure_stack_points.base_structure,
                    "ridge_tip_bonus": self.structure_stack_points.ridge_tip_bonus,
                    "saddle_bonus": self.structure_stack_points.saddle_bonus,
                    "intersection_bonus": self.structure_stack_points.intersection_bonus,
                    "breakline_edge_bonus": self.structure_stack_points.breakline_edge_bonus,
                    "isolation_bonus": self.structure_stack_points.isolation_bonus,
                    "pocket_bonus": self.structure_stack_points.pocket_bonus,
                    "stack_bonus_multiplier": self.structure_stack_points.stack_bonus_multiplier,
                },
            },
        }

    def _load_image(self, image_path: str) -> np.ndarray:
        image = cv2.imread(image_path, cv2.IMREAD_COLOR)
        if image is None or image.size == 0:
            raise BathymetryAnalysisError(f"Could not read image from path: {image_path}")
        return image

    def _build_mask_from_ranges(self, hsv: np.ndarray, ranges: Sequence[HSVRange]) -> np.ndarray:
        mask = np.zeros(hsv.shape[:2], dtype=np.uint8)
        for hsv_range in ranges:
            current = cv2.inRange(hsv, hsv_range.lower, hsv_range.upper)
            mask = cv2.bitwise_or(mask, current)
        return mask

    def _build_chart_content_mask(self, hsv: np.ndarray) -> np.ndarray:
        height, width = hsv.shape[:2]
        hue = hsv[:, :, 0]
        sat = hsv[:, :, 1]
        val = hsv[:, :, 2]

        blue_water = (hue >= 76) & (hue <= 112) & (sat >= 18) & (val >= 125)
        red_shallow = ((hue <= 12) | (hue >= 164)) & (sat >= 55) & (val >= 105)
        yellow_land = (hue >= 18) & (hue <= 48) & (sat >= 45) & (val >= 120)
        chart_like = blue_water | red_shallow | yellow_land

        row_fraction = chart_like.mean(axis=1)
        threshold = 0.18
        window = max(8, min(32, height // 80))

        top = 0
        for y in range(0, max(1, height - window)):
            if float(np.mean(row_fraction[y : y + window])) >= threshold:
                top = max(0, y - 2)
                break

        bottom = height
        for y in range(height - window, 0, -1):
            if float(np.mean(row_fraction[y : y + window])) >= threshold:
                bottom = min(height, y + window + 2)
                break

        mask = np.zeros((height, width), dtype=np.uint8)
        if bottom > top:
            mask[top:bottom, :] = 255

        ui_dark_blue = (
            (hue >= 88)
            & (hue <= 118)
            & (sat >= 85)
            & (val <= 175)
            & (mask > 0)
        )
        ui_dark_blue = self._remove_small_components(
            ui_dark_blue.astype(np.uint8) * 255,
            min_area_px=max(160, (height * width) // 8000),
        )
        bottom_overlay_top = self._bottom_overlay_top(
            ui_dark_blue,
            min_width_px=max(120, width // 5),
            min_y_px=int(height * 0.68),
        )
        if bottom_overlay_top is not None:
            mask[max(0, bottom_overlay_top - max(12, height // 120)) :, :] = 0

        ui_dark_blue = self._expand_component_boxes(
            ui_dark_blue,
            pad=max(16, min(height, width) // 35),
            min_area_px=max(160, (height * width) // 8000),
        )
        ui_dark_blue = cv2.dilate(
            ui_dark_blue,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19)),
            iterations=1,
        )

        very_dark = ((val <= 26) & (mask > 0)).astype(np.uint8) * 255
        top_bottom_dark = np.zeros_like(very_dark)
        edge_band = max(20, height // 35)
        top_bottom_dark[:edge_band, :] = very_dark[:edge_band, :]
        top_bottom_dark[height - edge_band :, :] = very_dark[height - edge_band :, :]
        top_bottom_dark = cv2.dilate(
            top_bottom_dark,
            cv2.getStructuringElement(cv2.MORPH_RECT, (9, 9)),
            iterations=1,
        )

        exclusion = cv2.bitwise_or(ui_dark_blue, top_bottom_dark)
        mask[exclusion > 0] = 0
        return mask

    def _build_water_mask(
        self,
        hsv: np.ndarray,
        chart_mask: np.ndarray,
        land_mask: np.ndarray,
    ) -> np.ndarray:
        hue = hsv[:, :, 0]
        sat = hsv[:, :, 1]
        val = hsv[:, :, 2]

        blue_water = (hue >= 76) & (hue <= 112) & (sat >= 16) & (val >= 128)
        cyan_water = (hue >= 70) & (hue <= 100) & (sat >= 8) & (val >= 170)
        red_depth_area = ((hue <= 12) | (hue >= 164)) & (sat >= 58) & (val >= 115)
        raw = (blue_water | cyan_water | red_depth_area) & (chart_mask > 0) & (land_mask == 0)

        water = raw.astype(np.uint8) * 255
        water = cv2.morphologyEx(
            water,
            cv2.MORPH_CLOSE,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)),
            iterations=1,
        )
        water = cv2.morphologyEx(
            water,
            cv2.MORPH_OPEN,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)),
            iterations=1,
        )
        water = cv2.dilate(
            water,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)),
            iterations=1,
        )
        water[chart_mask == 0] = 0
        water[land_mask > 0] = 0
        return self._remove_small_components(water, min_area_px=max(80, water.size // 2500))

    @staticmethod
    def _remove_small_components(mask: np.ndarray, min_area_px: int) -> np.ndarray:
        binary = (mask > 0).astype(np.uint8)
        num_labels, labels, stats, _centroids = cv2.connectedComponentsWithStats(binary, connectivity=8)
        cleaned = np.zeros_like(mask, dtype=np.uint8)
        for idx in range(1, num_labels):
            if int(stats[idx, cv2.CC_STAT_AREA]) >= min_area_px:
                cleaned[labels == idx] = 255
        return cleaned

    @staticmethod
    def _expand_component_boxes(mask: np.ndarray, pad: int, min_area_px: int) -> np.ndarray:
        binary = (mask > 0).astype(np.uint8)
        num_labels, _labels, stats, _centroids = cv2.connectedComponentsWithStats(binary, connectivity=8)
        expanded = np.zeros_like(mask, dtype=np.uint8)
        height, width = mask.shape[:2]
        for idx in range(1, num_labels):
            area = int(stats[idx, cv2.CC_STAT_AREA])
            if area < min_area_px:
                continue
            x = int(stats[idx, cv2.CC_STAT_LEFT])
            y = int(stats[idx, cv2.CC_STAT_TOP])
            w = int(stats[idx, cv2.CC_STAT_WIDTH])
            h = int(stats[idx, cv2.CC_STAT_HEIGHT])
            left = max(0, x - pad)
            top = max(0, y - pad)
            right = min(width, x + w + pad)
            bottom = min(height, y + h + pad)
            expanded[top:bottom, left:right] = 255
        return expanded

    @staticmethod
    def _bottom_overlay_top(
        mask: np.ndarray,
        min_width_px: int,
        min_y_px: int,
    ) -> Optional[int]:
        binary = (mask > 0).astype(np.uint8)
        num_labels, _labels, stats, _centroids = cv2.connectedComponentsWithStats(binary, connectivity=8)
        candidates: List[int] = []
        for idx in range(1, num_labels):
            x = int(stats[idx, cv2.CC_STAT_LEFT])
            y = int(stats[idx, cv2.CC_STAT_TOP])
            width = int(stats[idx, cv2.CC_STAT_WIDTH])
            height = int(stats[idx, cv2.CC_STAT_HEIGHT])
            area = int(stats[idx, cv2.CC_STAT_AREA])
            if y >= min_y_px and width >= min_width_px and height >= 24 and area >= min_width_px * 8:
                candidates.append(y)
        return min(candidates) if candidates else None

    @staticmethod
    def _refine_binary_mask(mask: np.ndarray, kernel_size: int) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kernel_size, kernel_size))
        refined = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=1)
        refined = cv2.morphologyEx(refined, cv2.MORPH_OPEN, kernel, iterations=1)
        return refined

    @staticmethod
    def _build_coastline_mask(water_mask: np.ndarray) -> np.ndarray:
        water = (water_mask > 0).astype(np.uint8)
        coast = cv2.morphologyEx(
            water,
            cv2.MORPH_GRADIENT,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)),
        )
        return (coast * 255).astype(np.uint8)

    def _extract_contour_mask(self, image_bgr: np.ndarray, hsv: np.ndarray, water_mask: np.ndarray) -> np.ndarray:
        color_mask = self._build_mask_from_ranges(hsv, self.depth_color_ranges)

        gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        eq_gray = clahe.apply(gray)
        blurred = cv2.GaussianBlur(eq_gray, (5, 5), 0)
        lower, upper = self._auto_canny_thresholds(blurred, self.canny_sigma)
        edges = cv2.Canny(blurred, lower, upper, L2gradient=True)

        color_mask = cv2.bitwise_and(color_mask, water_mask)
        edges = cv2.bitwise_and(edges, water_mask)

        merged = cv2.bitwise_or(color_mask, edges)
        merged = self._refine_binary_mask(merged, kernel_size=3)
        return merged

    def _build_pseudo_depth_grid(
        self,
        contour_mask: np.ndarray,
        water_mask: np.ndarray,
        coastline_mask: np.ndarray,
    ) -> np.ndarray:
        water_bool = water_mask > 0
        contour_bool = contour_mask > 0
        coast_bool = coastline_mask > 0

        spacing_distance = ndimage.distance_transform_edt(~contour_bool)
        spacing_inv = 1.0 - self._normalize_to_unit(spacing_distance, water_bool)

        coast_distance = ndimage.distance_transform_edt(~coast_bool)
        coast_depth = self._normalize_to_unit(coast_distance, water_bool)

        contour_density = cv2.GaussianBlur(contour_bool.astype(np.float32), (0, 0), sigmaX=4.0)
        contour_density = self._normalize_to_unit(contour_density, water_bool)

        pseudo_depth = 0.50 * coast_depth + 0.30 * spacing_inv + 0.20 * contour_density
        pseudo_depth = self._normalize_to_unit(pseudo_depth, water_bool)
        pseudo_depth[~water_bool] = 0.0
        return pseudo_depth.astype(np.float32)

    def _compute_feature_maps(
        self,
        pseudo_depth_grid: np.ndarray,
        contour_mask: np.ndarray,
        water_mask: np.ndarray,
        land_mask: np.ndarray,
        coastline_mask: np.ndarray,
    ) -> Dict[str, np.ndarray]:
        water_bool = water_mask > 0
        land_bool = land_mask > 0
        contour_bool = contour_mask > 0
        coast_bool = coastline_mask > 0

        contour_density = cv2.GaussianBlur(contour_bool.astype(np.float32), (0, 0), sigmaX=5.0)
        contour_density = self._normalize_to_unit(contour_density, water_bool)
        contour_density_ms = (
            0.35 * self._normalize_to_unit(cv2.GaussianBlur(contour_bool.astype(np.float32), (0, 0), sigmaX=2.0), water_bool)
            + 0.40 * contour_density
            + 0.25 * self._normalize_to_unit(cv2.GaussianBlur(contour_bool.astype(np.float32), (0, 0), sigmaX=8.0), water_bool)
        )

        smoothed_depth = ndimage.gaussian_filter(pseudo_depth_grid, sigma=4.0)
        gx = ndimage.sobel(smoothed_depth, axis=1)
        gy = ndimage.sobel(smoothed_depth, axis=0)
        slope = np.hypot(gx, gy)
        slope = self._normalize_to_unit(slope, water_bool)
        slope_ms = (
            0.30 * slope
            + 0.40 * self._normalize_to_unit(np.hypot(ndimage.sobel(pseudo_depth_grid, axis=1), ndimage.sobel(pseudo_depth_grid, axis=0)), water_bool)
            + 0.30 * self._normalize_to_unit(np.hypot(ndimage.sobel(smoothed_depth, axis=1), ndimage.sobel(smoothed_depth, axis=0)), water_bool)
        )

        max_local = ndimage.maximum_filter(smoothed_depth, size=19)
        min_local = ndimage.minimum_filter(smoothed_depth, size=19)
        local_relief = max_local - min_local
        local_relief = self._normalize_to_unit(local_relief, water_bool)

        lap = ndimage.laplace(smoothed_depth)
        basin_likelihood = self._normalize_to_unit(np.clip(-lap, 0.0, None), water_bool)
        ridge_likelihood = self._normalize_to_unit(np.clip(lap, 0.0, None), water_bool)

        spacing_distance = ndimage.distance_transform_edt(~contour_bool)
        spacing_norm = self._normalize_to_unit(spacing_distance, water_bool)
        dropoff_proximity = 1.0 - spacing_norm

        center_depth_pref = 1.0 - np.clip(np.abs(pseudo_depth_grid - 0.55) / 0.55, 0.0, 1.0)
        transition_band = self._normalize_to_unit(slope * center_depth_pref, water_bool)

        coast_distance = ndimage.distance_transform_edt(~coast_bool)
        coast_distance_norm = self._normalize_to_unit(coast_distance, water_bool)
        coastal_penalty = 1.0 - coast_distance_norm
        land_distance = ndimage.distance_transform_edt(~land_bool).astype(np.float32)
        water_confidence = cv2.GaussianBlur(water_bool.astype(np.float32), (0, 0), sigmaX=3.5)
        water_confidence = np.clip(water_confidence, 0.0, 1.0)

        second_dx = ndimage.sobel(gx, axis=1)
        second_dy = ndimage.sobel(gy, axis=0)
        mixed_dxy = ndimage.sobel(gx, axis=0)
        curvature_cross = np.abs(second_dx * second_dy)
        contour_curvature = self._normalize_to_unit(curvature_cross + np.abs(mixed_dxy), water_bool)
        signed_curvature_mix = np.clip(-(second_dx * second_dy), 0.0, None)
        gaussian_log = -ndimage.gaussian_laplace(smoothed_depth, sigma=2.1)
        local_contrast = self._normalize_to_unit(
            ndimage.maximum_filter(smoothed_depth, size=9) - ndimage.minimum_filter(smoothed_depth, size=9),
            water_bool,
        )
        edge_density_ms = self._normalize_to_unit(
            0.45 * contour_density_ms + 0.30 * slope_ms + 0.25 * contour_curvature,
            water_bool,
        )

        ridge_core = ridge_likelihood > 0.42
        ridge_neighbors = ndimage.convolve(
            ridge_core.astype(np.uint8),
            np.array([[1, 1, 1], [1, 10, 1], [1, 1, 1]], dtype=np.uint8),
            mode="constant",
            cval=0,
        )
        ridge_endpoint_mask = ridge_core & (ridge_neighbors <= 14)
        steep_ring = ndimage.maximum_filter(slope, size=7)
        directional_drop = ndimage.maximum_filter(
            np.clip(smoothed_depth - ndimage.minimum_filter(smoothed_depth, size=7), 0.0, None),
            size=5,
        )
        ridge_tip_seed = (
            0.55 * ridge_endpoint_mask.astype(np.float32)
            + 0.25 * ridge_likelihood
            + 0.20 * self._normalize_to_unit(directional_drop, water_bool)
        )
        ridge_tip = ridge_tip_seed * np.maximum(0.45, steep_ring)
        ridge_tip = self._normalize_to_unit(ridge_tip, water_bool)

        saddle_strength = (
            0.45 * self._normalize_to_unit(np.clip(signed_curvature_mix, 0.0, None), water_bool)
            + 0.35 * self._normalize_to_unit(np.abs(mixed_dxy), water_bool)
            + 0.20 * local_relief
        )
        saddle = self._normalize_to_unit(saddle_strength, water_bool)

        breakline_seed = (
            0.50 * self._normalize_to_unit(np.clip(gaussian_log, 0.0, None), water_bool)
            + 0.30 * slope
            + 0.20 * dropoff_proximity
        )
        shallower_than_neighborhood = np.clip(
            ndimage.maximum_filter(smoothed_depth, size=7) - smoothed_depth,
            0.0,
            None,
        )
        breakline_edge = self._normalize_to_unit(
            breakline_seed * (0.55 + 0.45 * self._normalize_to_unit(shallower_than_neighborhood, water_bool)),
            water_bool,
        )

        structure_intersection = (
            (0.45 * np.maximum(ridge_tip, ridge_likelihood) + 0.25 * breakline_edge)
            * (0.45 * np.maximum(breakline_edge, dropoff_proximity) + 0.25 * slope + 0.15 * contour_density)
        )
        structure_intersection = self._normalize_to_unit(structure_intersection, water_bool)

        local_min_5 = ndimage.minimum_filter(smoothed_depth, size=5)
        local_mean_7 = ndimage.uniform_filter(smoothed_depth, size=9)
        surrounding_deeper = np.clip(local_mean_7 - smoothed_depth, 0.0, None)
        isolated_peak_seed = (
            0.55 * (smoothed_depth <= (local_min_5 + 3e-3)).astype(np.float32)
            + 0.25 * self._normalize_to_unit(surrounding_deeper, water_bool)
            + 0.20 * local_relief
        )
        isolated_peak = isolated_peak_seed * np.maximum(0.40, ridge_likelihood)
        isolated_peak = self._normalize_to_unit(isolated_peak, water_bool)

        local_max_5 = ndimage.maximum_filter(smoothed_depth, size=5)
        pocket_depth = np.clip(smoothed_depth - ndimage.minimum_filter(smoothed_depth, size=7), 0.0, None)
        pocket_enclosure = np.clip(ridge_likelihood + 0.5 * contour_density + 0.35 * (1.0 - slope), 0.0, None)
        pocket = ((smoothed_depth >= (local_max_5 - 1e-4)).astype(np.float32) * pocket_depth * pocket_enclosure)
        pocket = self._normalize_to_unit(pocket, water_bool)

        flat_penalty = 1.0 - local_relief
        low_contour_penalty = 1.0 - contour_density
        invalid_region_penalty = np.clip(0.65 * coastal_penalty + 0.35 * low_contour_penalty, 0.0, 1.0)

        for grid in (
            contour_density,
            contour_density_ms,
            slope,
            slope_ms,
            local_relief,
            basin_likelihood,
            ridge_likelihood,
            dropoff_proximity,
            transition_band,
            ridge_tip,
            saddle,
            structure_intersection,
            breakline_edge,
            isolated_peak,
            pocket,
            flat_penalty,
            invalid_region_penalty,
            coast_distance,
            land_distance,
            water_confidence,
            local_contrast,
            edge_density_ms,
            contour_curvature,
        ):
            grid[~water_bool] = 0.0

        return {
            "pseudo_depth": pseudo_depth_grid,
            "contour_density": contour_density,
            "contour_density_ms": contour_density_ms,
            "slope": slope,
            "slope_ms": slope_ms,
            "local_relief": local_relief,
            "dropoff_proximity": dropoff_proximity,
            "basin_likelihood": basin_likelihood,
            "ridge_likelihood": ridge_likelihood,
            "transition_band": transition_band,
            "ridge_tip": ridge_tip,
            "saddle": saddle,
            "structure_intersection": structure_intersection,
            "breakline_edge": breakline_edge,
            "isolated_peak": isolated_peak,
            "pocket": pocket,
            "flat_penalty": flat_penalty,
            "invalid_region_penalty": invalid_region_penalty,
            "coast_distance": coast_distance.astype(np.float32),
            "land_distance": land_distance.astype(np.float32),
            "water_confidence": water_confidence.astype(np.float32),
            "local_contrast": local_contrast.astype(np.float32),
            "edge_density_ms": edge_density_ms.astype(np.float32),
            "contour_curvature": contour_curvature.astype(np.float32),
        }

    def _compute_score_map(self, feature_maps: Dict[str, np.ndarray], water_mask: np.ndarray) -> np.ndarray:
        water_bool = water_mask > 0
        shape = water_mask.shape[:2]
        points = self.structure_stack_points

        slope = self._feature_map_or_zeros(feature_maps, "slope", shape)
        contour_density = self._feature_map_or_zeros(feature_maps, "contour_density", shape)
        dropoff_proximity = self._feature_map_or_zeros(feature_maps, "dropoff_proximity", shape)
        basin_likelihood = self._feature_map_or_zeros(feature_maps, "basin_likelihood", shape)
        ridge_likelihood = self._feature_map_or_zeros(feature_maps, "ridge_likelihood", shape)
        transition_band = self._feature_map_or_zeros(feature_maps, "transition_band", shape)
        ridge_tip = self._feature_map_or_zeros(feature_maps, "ridge_tip", shape)
        saddle = self._feature_map_or_zeros(feature_maps, "saddle", shape)
        structure_intersection = self._feature_map_or_zeros(feature_maps, "structure_intersection", shape)
        breakline_edge = self._feature_map_or_zeros(feature_maps, "breakline_edge", shape)
        isolated_peak = self._feature_map_or_zeros(feature_maps, "isolated_peak", shape)
        pocket = self._feature_map_or_zeros(feature_maps, "pocket", shape)
        flat_penalty = self._feature_map_or_zeros(feature_maps, "flat_penalty", shape)
        invalid_region_penalty = self._feature_map_or_zeros(feature_maps, "invalid_region_penalty", shape)
        edge_density_ms = self._feature_map_or_zeros(feature_maps, "edge_density_ms", shape)
        local_contrast = self._feature_map_or_zeros(feature_maps, "local_contrast", shape)
        contour_curvature = self._feature_map_or_zeros(feature_maps, "contour_curvature", shape)

        structure_score = np.maximum.reduce(
            [
                basin_likelihood,
                ridge_likelihood,
                ridge_tip,
                saddle,
                structure_intersection,
                breakline_edge,
                isolated_peak,
                pocket,
            ]
        )

        raw_score = (
            points.base_slope * slope
            + points.base_contour_density * contour_density
            + points.base_dropoff * dropoff_proximity
            + points.base_transition_band * transition_band
            + points.base_structure * structure_score
            + points.ridge_tip_bonus * ridge_tip
            + points.saddle_bonus * saddle
            + points.intersection_bonus * structure_intersection
            + points.breakline_edge_bonus * breakline_edge
            + points.isolation_bonus * isolated_peak
            + points.pocket_bonus * pocket
            + 1.25 * edge_density_ms
            + 1.10 * local_contrast
            + 0.90 * contour_curvature
        )

        stack_feature_count = (
            (ridge_tip >= 0.38).astype(np.float32)
            + (saddle >= 0.36).astype(np.float32)
            + (structure_intersection >= 0.34).astype(np.float32)
            + (breakline_edge >= 0.38).astype(np.float32)
            + (isolated_peak >= 0.34).astype(np.float32)
            + (pocket >= 0.38).astype(np.float32)
        )
        structure_stack_bonus = np.clip(stack_feature_count - 1.0, 0.0, None) * points.stack_bonus_multiplier
        raw_score = raw_score + structure_stack_bonus
        raw_score = raw_score - points.flat_penalty * flat_penalty - points.invalid_region_penalty * invalid_region_penalty
        raw_score = np.clip(raw_score, 0.0, None)

        max_points = max(
            9.5,
            (
                points.base_slope
                + points.base_contour_density
                + points.base_dropoff
                + points.base_transition_band
                + points.base_structure
            ),
        )
        score = np.clip(raw_score / max_points, 0.0, 1.0).astype(np.float32)
        score[water_mask == 0] = 0.0
        feature_maps["structure_score"] = structure_score.astype(np.float32)
        feature_maps["raw_score"] = raw_score.astype(np.float32)
        feature_maps["structure_stack_bonus"] = structure_stack_bonus.astype(np.float32)
        feature_maps["normalized_score"] = score.astype(np.float32)
        if not np.any(water_bool):
            return score
        return score

    def _extract_hotspot_candidates(
        self,
        score_map: np.ndarray,
        feature_maps: Dict[str, np.ndarray],
        water_mask: np.ndarray,
        land_mask: np.ndarray,
        coastline_mask: np.ndarray,
    ) -> Tuple[List[Dict[str, Any]], Dict[str, int]]:
        water_bool = water_mask > 0
        land_bool = land_mask > 0
        coast_bool = coastline_mask > 0

        coast_distance = feature_maps["coast_distance"]
        land_distance = feature_maps["land_distance"]
        water_confidence = feature_maps["water_confidence"]
        structure_evidence = np.maximum.reduce(
            [
                self._feature_map_or_zeros(feature_maps, "structure_score", score_map.shape),
                self._feature_map_or_zeros(feature_maps, "ridge_likelihood", score_map.shape),
                self._feature_map_or_zeros(feature_maps, "ridge_tip", score_map.shape),
                self._feature_map_or_zeros(feature_maps, "saddle", score_map.shape),
                self._feature_map_or_zeros(feature_maps, "structure_intersection", score_map.shape),
                self._feature_map_or_zeros(feature_maps, "breakline_edge", score_map.shape),
                self._feature_map_or_zeros(feature_maps, "transition_band", score_map.shape),
            ]
        )
        local_relief = self._feature_map_or_zeros(feature_maps, "local_relief", score_map.shape)
        if float(np.max(local_relief)) > 0.0:
            local_relief_ok = local_relief >= self.thresholds.min_local_relief
        else:
            local_relief_ok = np.ones_like(score_map, dtype=bool)
        valid_mask = (
            water_bool
            & (~land_bool)
            & (score_map >= self.thresholds.min_score)
            & (feature_maps["contour_density"] >= self.thresholds.min_contour_density)
            & (structure_evidence >= self.thresholds.min_structure_evidence)
            & local_relief_ok
            & (coast_distance >= self.thresholds.min_coast_distance_px)
            & (land_distance >= self.thresholds.min_land_distance_px)
            & (water_confidence >= self.thresholds.min_water_confidence)
        )

        valid_score = np.where(valid_mask, score_map, 0.0)
        max_filtered = ndimage.maximum_filter(valid_score, size=self.peak_window_size)
        peak_mask = valid_mask & (valid_score > 0.0) & (valid_score == max_filtered)
        peak_coords = np.argwhere(peak_mask)
        stats = {
            "total_candidates_before_filter": int(np.count_nonzero(score_map > 0.0)),
            "initial_peak_count": int(peak_coords.shape[0]),
            "rejected_non_water_neighborhood": 0,
            "rejected_too_close": 0,
            "rejected_low_confidence_or_land": 0,
            "valid_water_candidates": 0,
            "rejected_land_candidates": int(np.count_nonzero((score_map >= self.thresholds.min_score) & land_bool)),
            "rejected_near_land": 0,
            "rejected_low_score": int(np.count_nonzero((score_map > 0.0) & (score_map < self.thresholds.min_score))),
        }
        if peak_coords.size == 0:
            return [], stats

        scored_points = [
            (int(y), int(x), float(score_map[y, x]))
            for y, x in peak_coords
        ]
        scored_points.sort(key=lambda item: item[2], reverse=True)

        accepted: List[Dict[str, Any]] = []
        radius2 = self.suppression_radius_px * self.suppression_radius_px

        for y, x, score in scored_points:
            if len(accepted) >= self.max_hotspots:
                break

            if not self._is_confident_water_neighborhood(water_mask=water_mask, x=x, y=y, radius=4, min_ratio=0.78):
                stats["rejected_non_water_neighborhood"] += 1
                continue

            if (
                float(land_distance[y, x]) < self.thresholds.min_land_distance_px
                or float(water_confidence[y, x]) < self.thresholds.min_water_confidence
                or float(structure_evidence[y, x]) < self.thresholds.min_structure_evidence
            ):
                stats["rejected_low_confidence_or_land"] += 1
                if float(land_distance[y, x]) < self.thresholds.min_land_distance_px:
                    stats["rejected_near_land"] += 1
                continue

            too_close = False
            for existing in accepted:
                ex = float(existing["pixel_centroid"]["x"])
                ey = float(existing["pixel_centroid"]["y"])
                dx = float(x) - ex
                dy = float(y) - ey
                if (dx * dx + dy * dy) <= radius2:
                    too_close = True
                    break
            if too_close:
                stats["rejected_too_close"] += 1
                continue

            metrics = self._collect_metrics(feature_maps, x, y)
            classification = self._classification_from_score(score)
            reasoning = self._build_reasoning(metrics)
            dominant_feature = self._dominant_feature(metrics)

            accepted.append(
                {
                    "pixel_centroid": {"x": float(x), "y": float(y)},
                    "score": float(score),
                    "classification": classification,
                    "reasoning": reasoning,
                    "metrics": metrics,
                    "feature_type": dominant_feature,
                }
            )
            stats["valid_water_candidates"] += 1

        stats["total_after_filter"] = int(len(accepted))
        return accepted, stats

    def _collect_metrics(self, feature_maps: Dict[str, np.ndarray], x: int, y: int) -> Dict[str, float]:
        shape = next(iter(feature_maps.values())).shape[:2]
        basin_likelihood = self._value_at(feature_maps, "basin_likelihood", x, y, shape)
        ridge_likelihood = self._value_at(feature_maps, "ridge_likelihood", x, y, shape)
        ridge_tip = self._value_at(feature_maps, "ridge_tip", x, y, shape)
        saddle = self._value_at(feature_maps, "saddle", x, y, shape)
        structure_intersection = self._value_at(feature_maps, "structure_intersection", x, y, shape)
        breakline_edge = self._value_at(feature_maps, "breakline_edge", x, y, shape)
        isolated_peak = self._value_at(feature_maps, "isolated_peak", x, y, shape)
        pocket = self._value_at(feature_maps, "pocket", x, y, shape)
        structure_score = max(
            basin_likelihood,
            ridge_likelihood,
            ridge_tip,
            saddle,
            structure_intersection,
            breakline_edge,
            isolated_peak,
            pocket,
        )
        return {
            "slope": self._value_at(feature_maps, "slope", x, y, shape),
            "contour_density": self._value_at(feature_maps, "contour_density", x, y, shape),
            "local_relief": self._value_at(feature_maps, "local_relief", x, y, shape),
            "dropoff_proximity": self._value_at(feature_maps, "dropoff_proximity", x, y, shape),
            "basin_likelihood": basin_likelihood,
            "ridge_likelihood": ridge_likelihood,
            "transition_band": self._value_at(feature_maps, "transition_band", x, y, shape),
            "ridge_tip": ridge_tip,
            "saddle": saddle,
            "structure_intersection": structure_intersection,
            "breakline_edge": breakline_edge,
            "isolated_peak": isolated_peak,
            "pocket": pocket,
            "flat_penalty": self._value_at(feature_maps, "flat_penalty", x, y, shape),
            "invalid_region_penalty": self._value_at(feature_maps, "invalid_region_penalty", x, y, shape),
            "structure_score": float(structure_score),
            "raw_score": self._value_at(feature_maps, "raw_score", x, y, shape),
            "structure_stack_bonus": self._value_at(feature_maps, "structure_stack_bonus", x, y, shape),
            "water_confidence": self._value_at(feature_maps, "water_confidence", x, y, shape),
            "land_distance_px": self._value_at(feature_maps, "land_distance", x, y, shape),
            "coast_distance_px": self._value_at(feature_maps, "coast_distance", x, y, shape),
        }

    @staticmethod
    def _is_confident_water_neighborhood(
        water_mask: np.ndarray, x: int, y: int, radius: int, min_ratio: float
    ) -> bool:
        h, w = water_mask.shape[:2]
        x0 = max(0, int(x) - radius)
        x1 = min(w, int(x) + radius + 1)
        y0 = max(0, int(y) - radius)
        y1 = min(h, int(y) + radius + 1)
        patch = water_mask[y0:y1, x0:x1]
        if patch.size == 0:
            return False
        ratio = float(np.count_nonzero(patch > 0)) / float(patch.size)
        return ratio >= min_ratio

    @staticmethod
    def _coastline_confidence(water_mask: np.ndarray, coastline_mask: np.ndarray) -> float:
        water_pixels = int(np.count_nonzero(water_mask))
        if water_pixels == 0:
            return 0.0
        coast_pixels = int(np.count_nonzero(coastline_mask))
        ratio = coast_pixels / float(water_pixels)
        # Expected coastline band ratio is usually low but non-zero.
        return float(np.clip(ratio / 0.08, 0.0, 1.0))

    def _detect_boat_pixel_anchor(
        self,
        image_bgr: np.ndarray,
        water_mask: np.ndarray,
        land_mask: np.ndarray,
    ) -> Dict[str, Any]:
        hsv = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)
        # Common chart marker cues: bright whites and vivid reds on water.
        white = cv2.inRange(hsv, (0, 0, 210), (180, 55, 255))
        red1 = cv2.inRange(hsv, (0, 120, 120), (14, 255, 255))
        red2 = cv2.inRange(hsv, (166, 120, 120), (180, 255, 255))
        marker_mask_raw = cv2.bitwise_or(white, cv2.bitwise_or(red1, red2))
        marker_mask = cv2.bitwise_and(marker_mask_raw, water_mask)
        marker_mask = self._refine_binary_mask(marker_mask, kernel_size=3)
        land_distance = ndimage.distance_transform_edt(land_mask == 0)
        water_bool = water_mask > 0

        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(marker_mask, connectivity=8)
        if num_labels <= 1:
            return {
                "boat_pixel_anchor": None,
                "anchor_confidence": 0.0,
                "anchor_detection_method": "hsv_component_scoring_v1",
                "status": "not_found",
                "rejected_candidates": 0,
                "candidates_considered": 0,
            }

        h, w = marker_mask.shape[:2]
        img_center = np.array([w / 2.0, h / 2.0], dtype=np.float32)
        best_anchor: Optional[Dict[str, Any]] = None
        best_score = -1.0
        candidates_considered = 0
        rejected_candidates = 0
        for idx in range(1, num_labels):
            area = int(stats[idx, cv2.CC_STAT_AREA])
            if area < 8 or area > 1200:
                continue
            candidates_considered += 1
            cx, cy = centroids[idx]
            ix = int(np.clip(round(cx), 0, w - 1))
            iy = int(np.clip(round(cy), 0, h - 1))
            local_water_ok = self._is_confident_water_neighborhood(
                water_mask=water_mask,
                x=ix,
                y=iy,
                radius=5,
                min_ratio=0.80,
            )
            if (not water_bool[iy, ix]) or (not local_water_ok) or float(land_distance[iy, ix]) < 4.0:
                rejected_candidates += 1
                continue
            dist = float(np.linalg.norm(np.array([cx, cy], dtype=np.float32) - img_center))
            compactness = min(1.0, area / 80.0)
            center_bonus = 1.0 - min(1.0, dist / max(w, h))
            red_local = float((red1[iy, ix] > 0) or (red2[iy, ix] > 0))
            white_local = float(white[iy, ix] > 0)
            color_bonus = 0.20 * red_local + 0.10 * white_local
            score = 0.55 * compactness + 0.35 * center_bonus + color_bonus
            if score > best_score:
                best_score = score
                best_anchor = {
                    "x": float(cx),
                    "y": float(cy),
                }

        if best_anchor is None:
            return {
                "boat_pixel_anchor": None,
                "anchor_confidence": 0.0,
                "anchor_detection_method": "hsv_component_scoring_v1",
                "status": "low_confidence",
                "rejected_candidates": int(rejected_candidates),
                "candidates_considered": int(candidates_considered),
            }

        confidence = float(np.clip(best_score, 0.0, 1.0))
        if confidence < 0.45:
            return {
                "boat_pixel_anchor": None,
                "anchor_confidence": confidence,
                "anchor_detection_method": "hsv_component_scoring_v1",
                "status": "low_confidence",
                "rejected_candidates": int(rejected_candidates),
                "candidates_considered": int(candidates_considered),
            }

        return {
            "boat_pixel_anchor": best_anchor,
            "anchor_confidence": confidence,
            "anchor_detection_method": "hsv_component_scoring_v1",
            "status": "detected",
            "rejected_candidates": int(rejected_candidates),
            "candidates_considered": int(candidates_considered),
        }

    def _build_reasoning(self, metrics: Dict[str, float]) -> List[str]:
        reasons: List[str] = []
        if metrics["contour_density"] >= 0.60:
            reasons.append("Yüksek kontur yoğunluğu")
        if metrics["dropoff_proximity"] >= 0.60:
            reasons.append("Güçlü derinlik geçişine yakın")
        if metrics["breakline_edge"] >= 0.50 or metrics["slope"] >= 0.55:
            reasons.append("Derinlik kırığı başlangıcı")
        if metrics["basin_likelihood"] >= 0.55:
            reasons.append("Düşük kabartmalı çanak geçişi")
        if metrics["ridge_likelihood"] >= 0.55:
            reasons.append("Beslenme potansiyeli olan sırt yapısı")
        if metrics["ridge_tip"] >= 0.50:
            reasons.append("Sırt ucu")
        if metrics["saddle"] >= 0.50:
            reasons.append("Boyun / geçit")
        if metrics["structure_intersection"] >= 0.50:
            reasons.append("Yapı kesişimi")
        if metrics["isolated_peak"] >= 0.50:
            reasons.append("İzole tepe")
        if metrics["pocket"] >= 0.50:
            reasons.append("Küçük çukur")
        if metrics["structure_stack_bonus"] >= 0.30:
            reasons.append("Çoklu yapı bonusu")
        if metrics["transition_band"] >= 0.55:
            reasons.append("Geçiş bandına uygunluk")
        if not reasons:
            reasons.append("Orta düzey çoklu batimetri sinyali")
        return reasons[:7]

    @staticmethod
    def _dominant_feature(metrics: Dict[str, float]) -> str:
        candidates = {
            "drop_off": metrics["dropoff_proximity"],
            "ridge_spur": metrics["ridge_likelihood"],
            "basin_bowl": metrics["basin_likelihood"],
            "shelf": metrics["transition_band"],
        }
        if metrics.get("structure_intersection", 0.0) >= 0.60:
            candidates["ridge_spur"] = max(candidates["ridge_spur"], metrics["structure_intersection"])
        if metrics.get("ridge_tip", 0.0) >= 0.60 or metrics.get("isolated_peak", 0.0) >= 0.60:
            candidates["ridge_spur"] = max(candidates["ridge_spur"], metrics.get("ridge_tip", 0.0), metrics.get("isolated_peak", 0.0))
        if metrics.get("pocket", 0.0) >= 0.60:
            candidates["basin_bowl"] = max(candidates["basin_bowl"], metrics["pocket"])
        return max(candidates, key=candidates.get)

    @staticmethod
    def _feature_map_or_zeros(
        feature_maps: Dict[str, np.ndarray],
        key: str,
        shape: Tuple[int, int],
    ) -> np.ndarray:
        values = feature_maps.get(key)
        if isinstance(values, np.ndarray):
            return values
        return np.zeros(shape, dtype=np.float32)

    @classmethod
    def _value_at(
        cls,
        feature_maps: Dict[str, np.ndarray],
        key: str,
        x: int,
        y: int,
        shape: Tuple[int, int],
    ) -> float:
        grid = cls._feature_map_or_zeros(feature_maps, key, shape)
        return float(grid[y, x])

    def _classification_from_score(self, score: float) -> str:
        if score >= self.thresholds.class_a:
            return "A"
        if score >= self.thresholds.class_b:
            return "B"
        return "C"

    def _build_legacy_feature_groups(
        self, candidate_hotspots: Sequence[Dict[str, Any]]
    ) -> Dict[str, List[Dict[str, Any]]]:
        groups: Dict[str, List[Dict[str, Any]]] = {
            "drop_offs": [],
            "ridges_spurs": [],
            "basins_bowls": [],
            "shelves": [],
        }

        feature_key_map = {
            "drop_off": "drop_offs",
            "ridge_spur": "ridges_spurs",
            "basin_bowl": "basins_bowls",
            "shelf": "shelves",
        }

        for idx, hotspot in enumerate(candidate_hotspots):
            centroid = hotspot.get("pixel_centroid", {})
            x = float(centroid.get("x", 0.0))
            y = float(centroid.get("y", 0.0))
            size = max(8, int(round(6 + hotspot.get("score", 0.0) * 10)))
            feature_type = str(hotspot.get("feature_type", "shelf"))
            group_name = feature_key_map.get(feature_type, "shelves")
            groups[group_name].append(
                {
                    "type": feature_type,
                    "bbox": {
                        "x": int(max(0, x - size)),
                        "y": int(max(0, y - size)),
                        "width": int(size * 2),
                        "height": int(size * 2),
                    },
                    "centroid": {"x": x, "y": y},
                    "area_px": int(size * size),
                    "source_candidate_id": idx,
                }
            )

        return groups

    @staticmethod
    def _normalize_to_unit(values: np.ndarray, valid_mask: np.ndarray) -> np.ndarray:
        out = np.zeros_like(values, dtype=np.float32)
        if not np.any(valid_mask):
            return out
        valid_vals = values[valid_mask]
        vmin = float(np.min(valid_vals))
        vmax = float(np.max(valid_vals))
        if vmax - vmin < 1e-9:
            out[valid_mask] = 0.0
            return out
        out[valid_mask] = ((valid_vals - vmin) / (vmax - vmin)).astype(np.float32)
        return out

    @staticmethod
    def _auto_canny_thresholds(gray: np.ndarray, sigma: float) -> Tuple[int, int]:
        median = float(np.median(gray))
        lower = int(max(0, (1.0 - sigma) * median))
        upper = int(min(255, (1.0 + sigma) * median))
        if lower >= upper:
            upper = min(255, lower + 1)
        return lower, upper
