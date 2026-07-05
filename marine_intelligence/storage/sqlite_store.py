from __future__ import annotations

import json
import sqlite3
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from marine_intelligence.models import SpotIntelligenceModel

_CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS spot_intelligence (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    lat REAL NOT NULL,
    lon REAL NOT NULL,
    note TEXT,
    favorite INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_report_json TEXT,
    last_report_at TEXT,
    visit_count INTEGER NOT NULL DEFAULT 0,
    learning_json TEXT,
    reputation_json TEXT
);
"""


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _default_learning_json(personal_tags: Optional[List[str]] = None) -> Dict[str, Any]:
    return {
        "personal_tags": personal_tags or [],
        "ai_learning_score": None,
        "last_success_date": None,
        "last_success_species": None,
        "last_success_weight": None,
        "preferred_fishing_style": None,
        "bottom_type": None,
        "estimated_depth": None,
    }


def _default_reputation_json() -> Dict[str, Any]:
    return {
        "spot_reputation": None,
        "spot_reputation_updated_at": None,
        "spot_reputation_factors": None,
    }


def _row_to_model(row: sqlite3.Row) -> SpotIntelligenceModel:
    learning = json.loads(row["learning_json"]) if row["learning_json"] else {}
    reputation = json.loads(row["reputation_json"]) if row["reputation_json"] else {}
    last_report = json.loads(row["last_report_json"]) if row["last_report_json"] else None
    return SpotIntelligenceModel(
        id=row["id"],
        name=row["name"],
        lat=row["lat"],
        lon=row["lon"],
        note=row["note"],
        favorite=bool(row["favorite"]),
        created_at=row["created_at"],
        updated_at=row["updated_at"],
        last_report=last_report,
        last_report_at=row["last_report_at"],
        visit_count=int(row["visit_count"]),
        personal_tags=learning.get("personal_tags") or [],
        ai_learning_score=learning.get("ai_learning_score"),
        last_success_date=learning.get("last_success_date"),
        last_success_species=learning.get("last_success_species"),
        last_success_weight=learning.get("last_success_weight"),
        preferred_fishing_style=learning.get("preferred_fishing_style"),
        bottom_type=learning.get("bottom_type"),
        estimated_depth=learning.get("estimated_depth"),
        spot_reputation=reputation.get("spot_reputation"),
        spot_reputation_updated_at=reputation.get("spot_reputation_updated_at"),
        spot_reputation_factors=reputation.get("spot_reputation_factors"),
    )


class SqliteSpotIntelligenceStore:
    """SQLite implementasyonu — production'da PostgreSQL JSONB ile değiştirilebilir."""

    def __init__(self, db_path: str) -> None:
        self._db_path = db_path
        self._lock = threading.Lock()
        if not db_path.startswith("file:"):
            Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        uri_mode = self._db_path.startswith("file:")
        conn = sqlite3.connect(
            self._db_path,
            check_same_thread=False,
            uri=uri_mode,
            timeout=30.0,
        )
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        with self._lock:
            with self._connect() as conn:
                conn.execute(_CREATE_TABLE_SQL)
                conn.commit()

    def create_spot(
        self,
        *,
        name: str,
        lat: float,
        lon: float,
        note: Optional[str] = None,
        favorite: bool = False,
        personal_tags: Optional[List[str]] = None,
    ) -> SpotIntelligenceModel:
        spot_id = str(uuid.uuid4())
        now = _utc_now_iso()
        learning = _default_learning_json(personal_tags)
        reputation = _default_reputation_json()
        with self._lock:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO spot_intelligence (
                        id, name, lat, lon, note, favorite,
                        created_at, updated_at, visit_count,
                        learning_json, reputation_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
                    """,
                    (
                        spot_id,
                        name,
                        lat,
                        lon,
                        note,
                        1 if favorite else 0,
                        now,
                        now,
                        json.dumps(learning, ensure_ascii=False),
                        json.dumps(reputation, ensure_ascii=False),
                    ),
                )
                conn.commit()
                row = conn.execute(
                    "SELECT * FROM spot_intelligence WHERE id = ?",
                    (spot_id,),
                ).fetchone()
        assert row is not None
        return _row_to_model(row)

    def list_spots(self, *, favorite: Optional[bool] = None) -> List[SpotIntelligenceModel]:
        query = "SELECT * FROM spot_intelligence"
        params: List[Any] = []
        if favorite is not None:
            query += " WHERE favorite = ?"
            params.append(1 if favorite else 0)
        query += " ORDER BY favorite DESC, updated_at DESC"
        with self._lock:
            with self._connect() as conn:
                rows = conn.execute(query, params).fetchall()
        return [_row_to_model(row) for row in rows]

    def get_spot(self, spot_id: str) -> Optional[SpotIntelligenceModel]:
        with self._lock:
            with self._connect() as conn:
                row = conn.execute(
                    "SELECT * FROM spot_intelligence WHERE id = ?",
                    (spot_id,),
                ).fetchone()
        return _row_to_model(row) if row else None

    def update_spot(
        self,
        spot_id: str,
        *,
        name: Optional[str] = None,
        note: Optional[str] = None,
        favorite: Optional[bool] = None,
        personal_tags: Optional[List[str]] = None,
    ) -> Optional[SpotIntelligenceModel]:
        existing = self.get_spot(spot_id)
        if existing is None:
            return None

        new_name = name if name is not None else existing.name
        new_note = note if note is not None else existing.note
        new_favorite = favorite if favorite is not None else existing.favorite
        new_tags = personal_tags if personal_tags is not None else existing.personal_tags

        learning = _default_learning_json(new_tags)
        learning.update(
            {
                "ai_learning_score": existing.ai_learning_score,
                "last_success_date": existing.last_success_date,
                "last_success_species": existing.last_success_species,
                "last_success_weight": existing.last_success_weight,
                "preferred_fishing_style": existing.preferred_fishing_style,
                "bottom_type": existing.bottom_type,
                "estimated_depth": existing.estimated_depth,
            }
        )
        now = _utc_now_iso()
        with self._lock:
            with self._connect() as conn:
                conn.execute(
                    """
                    UPDATE spot_intelligence
                    SET name = ?, note = ?, favorite = ?, updated_at = ?, learning_json = ?
                    WHERE id = ?
                    """,
                    (
                        new_name,
                        new_note,
                        1 if new_favorite else 0,
                        now,
                        json.dumps(learning, ensure_ascii=False),
                        spot_id,
                    ),
                )
                conn.commit()
                row = conn.execute(
                    "SELECT * FROM spot_intelligence WHERE id = ?",
                    (spot_id,),
                ).fetchone()
        return _row_to_model(row) if row else None

    def delete_spot(self, spot_id: str) -> bool:
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(
                    "DELETE FROM spot_intelligence WHERE id = ?",
                    (spot_id,),
                )
                conn.commit()
                return cur.rowcount > 0

    def update_last_report(
        self,
        spot_id: str,
        report: Dict[str, Any],
        *,
        report_at: str,
    ) -> Optional[SpotIntelligenceModel]:
        now = _utc_now_iso()
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(
                    """
                    UPDATE spot_intelligence
                    SET last_report_json = ?, last_report_at = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    (
                        json.dumps(report, ensure_ascii=False),
                        report_at,
                        now,
                        spot_id,
                    ),
                )
                conn.commit()
                if cur.rowcount == 0:
                    return None
                row = conn.execute(
                    "SELECT * FROM spot_intelligence WHERE id = ?",
                    (spot_id,),
                ).fetchone()
        return _row_to_model(row) if row else None

    def increment_visit_count(self, spot_id: str) -> Optional[SpotIntelligenceModel]:
        now = _utc_now_iso()
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(
                    """
                    UPDATE spot_intelligence
                    SET visit_count = visit_count + 1, updated_at = ?
                    WHERE id = ?
                    """,
                    (now, spot_id),
                )
                conn.commit()
                if cur.rowcount == 0:
                    return None
                row = conn.execute(
                    "SELECT * FROM spot_intelligence WHERE id = ?",
                    (spot_id,),
                ).fetchone()
        return _row_to_model(row) if row else None

    def apply_catch_success(
        self,
        spot_id: str,
        *,
        caught_at: str,
        species: str,
        weight_kg: Optional[float],
        spot_reputation: float,
        spot_reputation_factors: List[str],
        reputation_updated_at: str,
    ) -> Optional[SpotIntelligenceModel]:
        return self.apply_spot_learning_state(
            spot_id,
            last_success_date=caught_at,
            last_success_species=species,
            last_success_weight=weight_kg,
            spot_reputation=spot_reputation,
            spot_reputation_factors=spot_reputation_factors,
            reputation_updated_at=reputation_updated_at,
        )

    def apply_spot_learning_state(
        self,
        spot_id: str,
        *,
        last_success_date: Optional[str],
        last_success_species: Optional[str],
        last_success_weight: Optional[float],
        spot_reputation: float,
        spot_reputation_factors: List[str],
        reputation_updated_at: str,
    ) -> Optional[SpotIntelligenceModel]:
        existing = self.get_spot(spot_id)
        if existing is None:
            return None

        learning = _default_learning_json(existing.personal_tags)
        learning.update(
            {
                "ai_learning_score": existing.ai_learning_score,
                "last_success_date": last_success_date,
                "last_success_species": last_success_species,
                "last_success_weight": last_success_weight,
                "preferred_fishing_style": existing.preferred_fishing_style,
                "bottom_type": existing.bottom_type,
                "estimated_depth": existing.estimated_depth,
            }
        )
        reputation = {
            "spot_reputation": spot_reputation,
            "spot_reputation_updated_at": reputation_updated_at,
            "spot_reputation_factors": spot_reputation_factors,
        }
        now = _utc_now_iso()
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(
                    """
                    UPDATE spot_intelligence
                    SET learning_json = ?, reputation_json = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    (
                        json.dumps(learning, ensure_ascii=False),
                        json.dumps(reputation, ensure_ascii=False),
                        now,
                        spot_id,
                    ),
                )
                conn.commit()
                if cur.rowcount == 0:
                    return None
                row = conn.execute(
                    "SELECT * FROM spot_intelligence WHERE id = ?",
                    (spot_id,),
                ).fetchone()
        return _row_to_model(row) if row else None
