from __future__ import annotations

import json
import sqlite3
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Protocol

from marine_intelligence.models import CatchRecordModel

_CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS catch_records (
    id TEXT PRIMARY KEY,
    spot_id TEXT NOT NULL,
    species TEXT NOT NULL,
    length_cm REAL,
    weight_kg REAL,
    bait TEXT,
    method TEXT,
    caught_at TEXT NOT NULL,
    photo_path TEXT,
    notes TEXT,
    weather_snapshot_json TEXT,
    marine_snapshot_json TEXT,
    decision_snapshot_json TEXT,
    scenario_snapshot_json TEXT,
    moon_snapshot_json TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_catch_records_spot_id ON catch_records(spot_id);
CREATE INDEX IF NOT EXISTS idx_catch_records_caught_at ON catch_records(caught_at);
"""


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _row_to_model(row: sqlite3.Row) -> CatchRecordModel:
    return CatchRecordModel(
        id=row["id"],
        spot_id=row["spot_id"],
        species=row["species"],
        length_cm=row["length_cm"],
        weight_kg=row["weight_kg"],
        bait=row["bait"],
        method=row["method"],
        caught_at=row["caught_at"],
        photo_path=row["photo_path"],
        notes=row["notes"],
        weather_snapshot=json.loads(row["weather_snapshot_json"])
        if row["weather_snapshot_json"]
        else None,
        marine_snapshot=json.loads(row["marine_snapshot_json"])
        if row["marine_snapshot_json"]
        else None,
        decision_snapshot=json.loads(row["decision_snapshot_json"])
        if row["decision_snapshot_json"]
        else None,
        scenario_snapshot=json.loads(row["scenario_snapshot_json"])
        if row["scenario_snapshot_json"]
        else None,
        moon_snapshot=json.loads(row["moon_snapshot_json"]) if row["moon_snapshot_json"] else None,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


class CatchRecordStoreProtocol(Protocol):
    def create_catch(
        self,
        *,
        spot_id: str,
        species: str,
        caught_at: str,
        length_cm: Optional[float] = None,
        weight_kg: Optional[float] = None,
        bait: Optional[str] = None,
        method: Optional[str] = None,
        photo_path: Optional[str] = None,
        notes: Optional[str] = None,
        weather_snapshot: Optional[Dict[str, Any]] = None,
        marine_snapshot: Optional[Dict[str, Any]] = None,
        decision_snapshot: Optional[Dict[str, Any]] = None,
        scenario_snapshot: Optional[Dict[str, Any]] = None,
        moon_snapshot: Optional[Dict[str, Any]] = None,
    ) -> CatchRecordModel:
        ...

    def list_catches(self, *, spot_id: Optional[str] = None) -> List[CatchRecordModel]:
        ...

    def get_catch(self, catch_id: str) -> Optional[CatchRecordModel]:
        ...

    def delete_catch(self, catch_id: str) -> bool:
        ...

    def update_catch(
        self,
        catch_id: str,
        *,
        species: Optional[str] = None,
        length_cm: Optional[float] = None,
        weight_kg: Optional[float] = None,
        bait: Optional[str] = None,
        method: Optional[str] = None,
        caught_at: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> Optional[CatchRecordModel]:
        ...

    def summary_for_spot(self, spot_id: str) -> Dict[str, Any]:
        ...


class SqliteCatchRecordStore:
    """SQLite catch_records tablosu — spot store ile aynı DB dosyasını kullanır."""

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
                conn.executescript(_CREATE_TABLE_SQL)
                conn.commit()

    def create_catch(
        self,
        *,
        spot_id: str,
        species: str,
        caught_at: str,
        length_cm: Optional[float] = None,
        weight_kg: Optional[float] = None,
        bait: Optional[str] = None,
        method: Optional[str] = None,
        photo_path: Optional[str] = None,
        notes: Optional[str] = None,
        weather_snapshot: Optional[Dict[str, Any]] = None,
        marine_snapshot: Optional[Dict[str, Any]] = None,
        decision_snapshot: Optional[Dict[str, Any]] = None,
        scenario_snapshot: Optional[Dict[str, Any]] = None,
        moon_snapshot: Optional[Dict[str, Any]] = None,
    ) -> CatchRecordModel:
        catch_id = str(uuid.uuid4())
        now = _utc_now_iso()

        def _dump(value: Optional[Dict[str, Any]]) -> Optional[str]:
            if value is None:
                return None
            return json.dumps(value, ensure_ascii=False)

        with self._lock:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO catch_records (
                        id, spot_id, species, length_cm, weight_kg, bait, method,
                        caught_at, photo_path, notes,
                        weather_snapshot_json, marine_snapshot_json,
                        decision_snapshot_json, scenario_snapshot_json, moon_snapshot_json,
                        created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        catch_id,
                        spot_id,
                        species,
                        length_cm,
                        weight_kg,
                        bait,
                        method,
                        caught_at,
                        photo_path,
                        notes,
                        _dump(weather_snapshot),
                        _dump(marine_snapshot),
                        _dump(decision_snapshot),
                        _dump(scenario_snapshot),
                        _dump(moon_snapshot),
                        now,
                        now,
                    ),
                )
                conn.commit()
                row = conn.execute(
                    "SELECT * FROM catch_records WHERE id = ?",
                    (catch_id,),
                ).fetchone()
        assert row is not None
        return _row_to_model(row)

    def list_catches(self, *, spot_id: Optional[str] = None) -> List[CatchRecordModel]:
        query = "SELECT * FROM catch_records"
        params: List[Any] = []
        if spot_id is not None:
            query += " WHERE spot_id = ?"
            params.append(spot_id)
        query += " ORDER BY caught_at DESC"
        with self._lock:
            with self._connect() as conn:
                rows = conn.execute(query, params).fetchall()
        return [_row_to_model(row) for row in rows]

    def get_catch(self, catch_id: str) -> Optional[CatchRecordModel]:
        with self._lock:
            with self._connect() as conn:
                row = conn.execute(
                    "SELECT * FROM catch_records WHERE id = ?",
                    (catch_id,),
                ).fetchone()
        return _row_to_model(row) if row else None

    def delete_catch(self, catch_id: str) -> bool:
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute("DELETE FROM catch_records WHERE id = ?", (catch_id,))
                conn.commit()
                return cur.rowcount > 0

    def update_catch(
        self,
        catch_id: str,
        *,
        species: Optional[str] = None,
        length_cm: Optional[float] = None,
        weight_kg: Optional[float] = None,
        bait: Optional[str] = None,
        method: Optional[str] = None,
        caught_at: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> Optional[CatchRecordModel]:
        existing = self.get_catch(catch_id)
        if existing is None:
            return None

        fields: Dict[str, Any] = {}
        if species is not None:
            fields["species"] = species
        if length_cm is not None:
            fields["length_cm"] = length_cm
        if weight_kg is not None:
            fields["weight_kg"] = weight_kg
        if bait is not None:
            fields["bait"] = bait
        if method is not None:
            fields["method"] = method
        if caught_at is not None:
            fields["caught_at"] = caught_at
        if notes is not None:
            fields["notes"] = notes
        if not fields:
            return existing

        fields["updated_at"] = _utc_now_iso()
        set_clause = ", ".join(f"{key} = ?" for key in fields)
        params = list(fields.values()) + [catch_id]

        with self._lock:
            with self._connect() as conn:
                conn.execute(
                    f"UPDATE catch_records SET {set_clause} WHERE id = ?",
                    params,
                )
                conn.commit()
                row = conn.execute(
                    "SELECT * FROM catch_records WHERE id = ?",
                    (catch_id,),
                ).fetchone()
        return _row_to_model(row) if row else None

    def delete_catches_for_spot(self, spot_id: str) -> int:
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(
                    "DELETE FROM catch_records WHERE spot_id = ?",
                    (spot_id,),
                )
                conn.commit()
                return cur.rowcount

    def summary_for_spot(self, spot_id: str) -> Dict[str, Any]:
        catches = self.list_catches(spot_id=spot_id)
        species_counts: Dict[str, int] = {}
        weights: List[float] = []
        last_success_date: Optional[str] = None
        last_success_species: Optional[str] = None
        last_success_weight: Optional[float] = None
        for item in catches:
            species_counts[item.species] = species_counts.get(item.species, 0) + 1
            if item.weight_kg is not None:
                weights.append(float(item.weight_kg))
            if last_success_date is None or item.caught_at > last_success_date:
                last_success_date = item.caught_at
                last_success_species = item.species
                last_success_weight = item.weight_kg
        top_species = None
        if species_counts:
            top_species = max(species_counts.items(), key=lambda kv: kv[1])[0]
        average_weight = None
        if weights:
            average_weight = round(sum(weights) / len(weights), 2)
        return {
            "catch_count": len(catches),
            "top_species": top_species,
            "last_success_date": last_success_date,
            "last_success_species": last_success_species,
            "last_success_weight": last_success_weight,
            "average_weight_kg": average_weight,
            "species_counts": species_counts,
        }
