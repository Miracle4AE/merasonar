from __future__ import annotations

from dataclasses import dataclass
from math import asin, atan2, cos, degrees, radians, sin, sqrt
from typing import Dict, Optional, Sequence, Tuple

import numpy as np


EARTH_RADIUS_M = 6_371_008.8


class GeoNavigationError(RuntimeError):
    """Raised when geospatial calculations cannot be completed."""


@dataclass(frozen=True)
class GeoPoint:
    """Geographic coordinate in decimal degrees."""

    lat: float
    lon: float


@dataclass(frozen=True)
class PixelPoint:
    """Image pixel coordinate."""

    x: float
    y: float


class CoordinateMapper:
    """
    Map image pixel coordinates to geographic coordinates.

    Supports:
    - Linear interpolation from image bounds (default)
    - Optional affine mapping from 3 pixel->geo control points
    """

    def __init__(
        self,
        image_width: int,
        image_height: int,
        top_left: GeoPoint,
        bottom_right: GeoPoint,
        affine_control_points: Optional[Sequence[Tuple[PixelPoint, GeoPoint]]] = None,
    ) -> None:
        if image_width <= 0 or image_height <= 0:
            raise ValueError("image_width and image_height must be > 0")

        self.image_width = float(image_width)
        self.image_height = float(image_height)
        norm_top_left, norm_bottom_right = self._normalize_corner_bounds(top_left, bottom_right)
        self.top_left = norm_top_left
        self.bottom_right = norm_bottom_right
        self._lat_span = self.top_left.lat - self.bottom_right.lat
        self._lon_span = self.bottom_right.lon - self.top_left.lon
        if abs(self._lat_span) < 1e-12 or abs(self._lon_span) < 1e-12:
            raise ValueError("Invalid geo bounds: latitude/longitude span is zero.")

        self._affine_matrix: Optional[np.ndarray] = None
        self._affine_inverse_xy: Optional[np.ndarray] = None
        self._affine_offset: Optional[np.ndarray] = None
        if affine_control_points is not None:
            self._affine_matrix = self._solve_affine_matrix(affine_control_points)
            linear = self._affine_matrix[:, :2]
            if abs(np.linalg.det(linear)) < 1e-12:
                raise ValueError("Affine control points produced a non-invertible transform.")
            self._affine_inverse_xy = np.linalg.inv(linear)
            self._affine_offset = self._affine_matrix[:, 2]

    def pixel_to_geo(self, x: float, y: float) -> GeoPoint:
        """Convert a pixel coordinate `(x, y)` to geographic `(lat, lon)`."""
        if not (np.isfinite(x) and np.isfinite(y)):
            raise ValueError("Pixel coordinates must be finite numbers.")

        if self._affine_matrix is not None:
            vec = np.array([x, y, 1.0], dtype=np.float64)
            lat, lon = self._affine_matrix @ vec
            return GeoPoint(lat=float(lat), lon=float(lon))

        nx = np.clip(x / max(self.image_width - 1.0, 1.0), 0.0, 1.0)
        ny = np.clip(y / max(self.image_height - 1.0, 1.0), 0.0, 1.0)
        lat = self.top_left.lat - ny * self._lat_span
        lon = self.top_left.lon + nx * self._lon_span
        return GeoPoint(lat=float(lat), lon=float(lon))

    def geo_to_pixel(self, lat: float, lon: float) -> PixelPoint:
        """Convert a geographic coordinate `(lat, lon)` to pixel `(x, y)`."""
        if not (np.isfinite(lat) and np.isfinite(lon)):
            raise ValueError("Geographic coordinates must be finite numbers.")

        if self._affine_inverse_xy is not None and self._affine_offset is not None:
            target = np.array([lat, lon], dtype=np.float64) - self._affine_offset
            x, y = self._affine_inverse_xy @ target
            return PixelPoint(x=float(x), y=float(y))

        nx = (lon - self.top_left.lon) / self._lon_span
        ny = (self.top_left.lat - lat) / self._lat_span
        x = np.clip(nx, 0.0, 1.0) * (self.image_width - 1.0)
        y = np.clip(ny, 0.0, 1.0) * (self.image_height - 1.0)
        return PixelPoint(x=float(x), y=float(y))

    @staticmethod
    def _normalize_corner_bounds(top_left: GeoPoint, bottom_right: GeoPoint) -> Tuple[GeoPoint, GeoPoint]:
        min_lat = min(top_left.lat, bottom_right.lat)
        max_lat = max(top_left.lat, bottom_right.lat)
        min_lon = min(top_left.lon, bottom_right.lon)
        max_lon = max(top_left.lon, bottom_right.lon)
        eps = 1e-6
        if abs(max_lat - min_lat) < eps:
            max_lat += eps
            min_lat -= eps
        if abs(max_lon - min_lon) < eps:
            max_lon += eps
            min_lon -= eps
        return GeoPoint(lat=max_lat, lon=min_lon), GeoPoint(lat=min_lat, lon=max_lon)

    @staticmethod
    def _solve_affine_matrix(
        control_points: Sequence[Tuple[PixelPoint, GeoPoint]]
    ) -> np.ndarray:
        if len(control_points) < 3:
            raise ValueError("At least 3 control points are required for affine mapping.")
        a = []
        b_lat = []
        b_lon = []
        for pix, geo in control_points:
            a.append([pix.x, pix.y, 1.0])
            b_lat.append(geo.lat)
            b_lon.append(geo.lon)
        mat = np.array(a, dtype=np.float64)
        rank = int(np.linalg.matrix_rank(mat))
        if rank < 3 and len(control_points) == 3:
            pix2, geo2 = control_points[2]
            nudged = (
                PixelPoint(x=float(pix2.x), y=float(pix2.y) + 1.0),
                geo2,
            )
            control_points = (control_points[0], control_points[1], nudged)
            a = [
                [control_points[0][0].x, control_points[0][0].y, 1.0],
                [control_points[1][0].x, control_points[1][0].y, 1.0],
                [nudged[0].x, nudged[0].y, 1.0],
            ]
            b_lat = [control_points[0][1].lat, control_points[1][1].lat, geo2.lat]
            b_lon = [control_points[0][1].lon, control_points[1][1].lon, geo2.lon]
            mat = np.array(a, dtype=np.float64)
            rank = int(np.linalg.matrix_rank(mat))
        if rank < 3:
            raise ValueError("Affine control points are collinear or singular.")
        if len(control_points) == 3:
            coeff_lat = np.linalg.solve(mat, np.array(b_lat, dtype=np.float64))
            coeff_lon = np.linalg.solve(mat, np.array(b_lon, dtype=np.float64))
        else:
            coeff_lat = np.linalg.lstsq(mat, np.array(b_lat, dtype=np.float64), rcond=None)[0]
            coeff_lon = np.linalg.lstsq(mat, np.array(b_lon, dtype=np.float64), rcond=None)[0]
        return np.vstack([coeff_lat, coeff_lon])


class PrecisionGPS:
    """
    Lightweight 2D Kalman filter for noisy mobile GPS streams.

    State vector: [lat, lon, lat_velocity, lon_velocity]^T
    Measurement: [lat, lon]^T
    """

    def __init__(
        self,
        process_noise: float = 1e-8,
        measurement_noise: float = 4e-8,
        outlier_gate: float = 9.21,
    ) -> None:
        if process_noise <= 0.0 or measurement_noise <= 0.0:
            raise ValueError("process_noise and measurement_noise must be > 0")
        if outlier_gate <= 0.0:
            raise ValueError("outlier_gate must be > 0")

        self._base_q = float(process_noise)
        self._base_r = float(measurement_noise)
        self._outlier_gate = float(outlier_gate)

        self._x: Optional[np.ndarray] = None
        self._p: Optional[np.ndarray] = None
        self._last_timestamp_s: Optional[float] = None
        self._trajectory: list[GeoPoint] = []

    def reset(self) -> None:
        """Reset the filter state."""
        self._x = None
        self._p = None
        self._last_timestamp_s = None
        self._trajectory.clear()

    def update(
        self,
        lat: float,
        lon: float,
        speed_mps: Optional[float] = None,
        timestamp_s: Optional[float] = None,
    ) -> Dict[str, float]:
        """
        Ingest one GPS sample and return filtered state.

        Parameters
        ----------
        lat, lon:
            Raw GPS sample in decimal degrees.
        speed_mps:
            Optional speed telemetry to adapt process noise.
        timestamp_s:
            Optional sample time in seconds. If omitted, assumes 1-second steps.
        """
        if not (np.isfinite(lat) and np.isfinite(lon)):
            raise ValueError("lat/lon must be finite.")
        if speed_mps is not None and (not np.isfinite(speed_mps) or speed_mps < 0.0):
            raise ValueError("speed_mps must be finite and >= 0.")

        z = np.array([[lat], [lon]], dtype=np.float64)
        if self._x is None:
            self._x = np.array([[lat], [lon], [0.0], [0.0]], dtype=np.float64)
            self._p = np.eye(4, dtype=np.float64) * 1e-6
            self._last_timestamp_s = timestamp_s
            self._trajectory.append(GeoPoint(lat=lat, lon=lon))
            return self._state_dict(accepted=True, innovation=0.0)

        dt = self._compute_dt(timestamp_s)
        f = np.array(
            [
                [1.0, 0.0, dt, 0.0],
                [0.0, 1.0, 0.0, dt],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0],
            ],
            dtype=np.float64,
        )
        h = np.array([[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0]], dtype=np.float64)

        speed_scale = 1.0 + min((speed_mps or 0.0) / 25.0, 5.0)
        q = self._build_q(dt, self._base_q * speed_scale)
        r = np.eye(2, dtype=np.float64) * self._base_r

        self._x = f @ self._x
        self._p = f @ self._p @ f.T + q

        y = z - h @ self._x
        s = h @ self._p @ h.T + r
        inv_s = np.linalg.inv(s)
        mahalanobis = float((y.T @ inv_s @ y)[0, 0])

        accepted = mahalanobis <= self._outlier_gate
        if accepted:
            k = self._p @ h.T @ inv_s
            self._x = self._x + k @ y
            i = np.eye(4, dtype=np.float64)
            self._p = (i - k @ h) @ self._p

        self._trajectory.append(GeoPoint(lat=float(self._x[0, 0]), lon=float(self._x[1, 0])))
        return self._state_dict(accepted=accepted, innovation=mahalanobis)

    def current_position(self) -> Optional[GeoPoint]:
        """Return latest filtered coordinate, if available."""
        if self._x is None:
            return None
        return GeoPoint(lat=float(self._x[0, 0]), lon=float(self._x[1, 0]))

    def trajectory(self) -> Tuple[GeoPoint, ...]:
        """Return immutable filtered trajectory history."""
        return tuple(self._trajectory)

    def _compute_dt(self, timestamp_s: Optional[float]) -> float:
        if timestamp_s is None or self._last_timestamp_s is None:
            self._last_timestamp_s = timestamp_s
            return 1.0
        dt = float(timestamp_s - self._last_timestamp_s)
        self._last_timestamp_s = timestamp_s
        return float(np.clip(dt, 0.05, 10.0))

    @staticmethod
    def _build_q(dt: float, q_scalar: float) -> np.ndarray:
        dt2 = dt * dt
        dt3 = dt2 * dt
        dt4 = dt3 * dt
        q_block = np.array([[dt4 / 4.0, dt3 / 2.0], [dt3 / 2.0, dt2]], dtype=np.float64) * q_scalar
        q = np.zeros((4, 4), dtype=np.float64)
        q[np.ix_([0, 2], [0, 2])] = q_block
        q[np.ix_([1, 3], [1, 3])] = q_block
        return q

    def _state_dict(self, accepted: bool, innovation: float) -> Dict[str, float]:
        if self._x is None or self._p is None:
            raise GeoNavigationError("Filter state is uninitialized.")
        return {
            "lat": float(self._x[0, 0]),
            "lon": float(self._x[1, 0]),
            "lat_velocity": float(self._x[2, 0]),
            "lon_velocity": float(self._x[3, 0]),
            "variance_lat": float(self._p[0, 0]),
            "variance_lon": float(self._p[1, 1]),
            "measurement_accepted": 1.0 if accepted else 0.0,
            "innovation_mahalanobis": float(innovation),
        }


def calculate_bearing_and_distance(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> Dict[str, float]:
    """
    Calculate great-circle distance and initial bearing from point A to B.

    Returns a dictionary with:
    - distance_m
    - distance_km
    - bearing_deg (0-360, clockwise from true north)
    """
    for value in (lat1, lon1, lat2, lon2):
        if not np.isfinite(value):
            raise ValueError("All coordinate values must be finite.")

    phi1 = radians(lat1)
    phi2 = radians(lat2)
    d_phi = radians(lat2 - lat1)
    d_lambda = radians(lon2 - lon1)

    a = sin(d_phi / 2.0) ** 2 + cos(phi1) * cos(phi2) * sin(d_lambda / 2.0) ** 2
    c = 2.0 * asin(min(1.0, sqrt(max(a, 0.0))))
    distance_m = EARTH_RADIUS_M * c

    y = sin(d_lambda) * cos(phi2)
    x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(d_lambda)
    bearing_deg = (degrees(atan2(y, x)) + 360.0) % 360.0

    return {
        "distance_m": float(distance_m),
        "distance_km": float(distance_m / 1000.0),
        "bearing_deg": float(bearing_deg),
    }
