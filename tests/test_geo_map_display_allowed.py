from __future__ import annotations

import unittest

from maritime_orchestrator import (
    ControlPointDiagnostics,
    FishingHotspotManager,
    GEO_WORLD_MAP_MAX_GEOREFERENCE_ERROR_M,
    GEO_WORLD_MAP_MIN_TRANSFORM_QUALITY,
)


class GeoMapDisplayAllowedTests(unittest.TestCase):
    def test_geo_allowed_when_affine_and_quality_ok(self) -> None:
        diag = ControlPointDiagnostics(
            received=4,
            valid=4,
            invalid=0,
            status="accepted",
            georeference_error_m=5.0,
            transform_quality=0.9,
        )
        self.assertTrue(
            FishingHotspotManager.geo_world_map_display_allowed(
                coordinate_mode="geo_referenced",
                mapping_mode="affine_control_points",
                cp_diag=diag,
            )
        )

    def test_geo_approximate_when_transform_quality_low_but_affine_ok(self) -> None:
        diag = ControlPointDiagnostics(
            received=4,
            valid=4,
            invalid=0,
            status="accepted",
            georeference_error_m=GEO_WORLD_MAP_MAX_GEOREFERENCE_ERROR_M,
            transform_quality=GEO_WORLD_MAP_MIN_TRANSFORM_QUALITY * 0.5,
        )
        self.assertTrue(
            FishingHotspotManager.geo_world_map_display_allowed(
                coordinate_mode="geo_referenced",
                mapping_mode="affine_control_points",
                cp_diag=diag,
            )
        )

    def test_geo_approximate_when_rmse_high_but_affine_ok(self) -> None:
        diag = ControlPointDiagnostics(
            received=4,
            valid=4,
            invalid=0,
            status="accepted",
            georeference_error_m=GEO_WORLD_MAP_MAX_GEOREFERENCE_ERROR_M + 10.0,
            transform_quality=0.95,
        )
        self.assertTrue(
            FishingHotspotManager.geo_world_map_display_allowed(
                coordinate_mode="geo_referenced",
                mapping_mode="affine_control_points",
                cp_diag=diag,
            )
        )

    def test_geo_blocked_when_insufficient_control_points(self) -> None:
        diag = ControlPointDiagnostics(
            received=2,
            valid=2,
            invalid=0,
            status="insufficient_valid_points",
            georeference_error_m=5000.0,
            transform_quality=0.0,
        )
        self.assertFalse(
            FishingHotspotManager.geo_world_map_display_allowed(
                coordinate_mode="geo_referenced",
                mapping_mode="affine_control_points",
                cp_diag=diag,
            )
        )

    def test_image_space_mode_never_allows(self) -> None:
        diag = ControlPointDiagnostics(
            received=0,
            valid=0,
            invalid=0,
            status="not_provided",
            georeference_error_m=0.0,
            transform_quality=0.0,
        )
        self.assertFalse(
            FishingHotspotManager.geo_world_map_display_allowed(
                coordinate_mode="image_space",
                mapping_mode="affine_control_points",
                cp_diag=diag,
            )
        )


if __name__ == "__main__":
    unittest.main()
