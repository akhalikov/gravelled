#!/usr/bin/env python3
"""Backfill / sync Garmin cycling activities into Postgres.

Pulls activity summaries from Garmin Connect (using the saved tokens at
``~/.garminconnect``), tags each with the bike it was ridden on, and upserts
them into ``activities``, ``activity_hr_zones`` and ``activity_splits``.
Idempotent — the same script serves the one-time backfill and incremental syncs.

By default only **cycling** activities are stored (type 2 / parent 2); pass
``--all-types`` to store everything. The short-Kona-commute exclusion is applied
in the ``rides`` view (see db/views.sql), not here — every cycling ride is stored
and bike-tagged.

Run (dependencies are ephemeral via uv — nothing is installed globally):

    uv run --with "garminconnect==0.3.2" --with "psycopg[binary]" \\
           --with python-dotenv python pipeline/ingest.py

Config: ``pipeline/.env`` with
    DATABASE_URL=postgresql://gravelled:PASSWORD@192.168.1.9:5432/gravelled

Flags: --dry-run, --limit N, --since YYYY-MM-DD, --all-types
"""
from __future__ import annotations

import argparse
import contextlib
import os
import sys
from collections import Counter
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from garminconnect import Garmin
from psycopg.types.json import Jsonb

TOKEN_DIR = os.path.expanduser(os.getenv("GARMINTOKENS", "~/.garminconnect"))
ENV_PATH = Path(__file__).with_name(".env")

# Kona "Rove DL" — short rides on this bike (<10 km) are city commutes, excluded
# from the `rides` view. Kept here only for the --dry-run exclusion preview.
KONA_GEAR_UUID = "5593e10268314faebd8b26136e705d37"


def is_cycling(a: dict) -> bool:
    """Garmin cycling: the activity is 'cycling' (typeId 2) or a cycling subtype
    (parentTypeId 2 — gravel_cycling, road_biking, indoor_cycling, …)."""
    at = a.get("activityType") or {}
    return at.get("typeId") == 2 or at.get("parentTypeId") == 2


def _gmt(s: str | None) -> str | None:
    """Garmin GMT strings are naive 'YYYY-MM-DD HH:MM:SS' (UTC). Tag them UTC
    so a TIMESTAMPTZ column stores the correct instant regardless of session TZ."""
    return f"{s}+00:00" if s else None


def build_gear_map(garmin: Garmin) -> dict[int, tuple]:
    """Map activity_id -> (gear_uuid, gear_name, gear_make) for every Bike gear.
    Uses get_gear_activities (one call per bike), so this is a handful of calls."""
    gear_map: dict[int, tuple] = {}
    dev = garmin.get_device_last_used() or {}
    pid = dev.get("userProfileNumber")
    if not pid:
        print("WARN: no userProfileNumber; gear will be null", file=sys.stderr)
        return gear_map
    for g in garmin.get_gear(pid) or []:
        if (g.get("gearTypeName") or "").lower() != "bike":
            continue
        uuid, name, make = g.get("uuid"), g.get("displayName"), g.get("customMakeModel")
        try:
            acts = garmin.get_gear_activities(uuid) or []
        except Exception as e:  # retired gear can 404 in the library; keep going
            print(f"WARN: gear activities failed for {name!r}: {e}", file=sys.stderr)
            acts = []
        for act in acts:
            aid = act.get("activityId")
            if aid is not None:
                gear_map[aid] = (uuid, name, make)
    return gear_map


def activity_row(a: dict, gear_uuid=None, gear_name=None, gear_make=None) -> dict:
    """Map one raw Garmin activity dict (+ resolved gear) to the `activities` columns."""
    at = a.get("activityType") or {}
    et = a.get("eventType") or {}
    pv = a.get("privacy") or {}
    return {
        "activity_id": a.get("activityId"),
        "activity_uuid": a.get("activityUUID"),
        "name": a.get("activityName"),
        "type_key": at.get("typeKey"),
        "type_id": at.get("typeId"),
        "parent_type_id": at.get("parentTypeId"),
        "event_type_key": et.get("typeKey"),
        "sport_type_id": a.get("sportTypeId"),
        "start_time_local": a.get("startTimeLocal"),
        "start_time_gmt": _gmt(a.get("startTimeGMT")),
        "end_time_gmt": _gmt(a.get("endTimeGMT")),
        "time_zone_id": a.get("timeZoneId"),
        "duration_s": a.get("duration"),
        "elapsed_duration_s": a.get("elapsedDuration"),
        "moving_duration_s": a.get("movingDuration"),
        "distance_m": a.get("distance"),
        "average_speed_mps": a.get("averageSpeed"),
        "max_speed_mps": a.get("maxSpeed"),
        "max_vertical_speed_mps": a.get("maxVerticalSpeed"),
        "elevation_gain_m": a.get("elevationGain"),
        "elevation_loss_m": a.get("elevationLoss"),
        "min_elevation_m": a.get("minElevation"),
        "max_elevation_m": a.get("maxElevation"),
        "avg_elevation_m": a.get("avgElevation"),
        "elevation_corrected": a.get("elevationCorrected"),
        "start_lat": a.get("startLatitude"),
        "start_lon": a.get("startLongitude"),
        "end_lat": a.get("endLatitude"),
        "end_lon": a.get("endLongitude"),
        "location_name": a.get("locationName"),
        "average_hr": a.get("averageHR"),
        "max_hr": a.get("maxHR"),
        "calories": a.get("calories"),
        "bmr_calories": a.get("bmrCalories"),
        "water_estimated_ml": a.get("waterEstimated"),
        "min_respiration_rate": a.get("minRespirationRate"),
        "max_respiration_rate": a.get("maxRespirationRate"),
        "avg_respiration_rate": a.get("avgRespirationRate"),
        "moderate_intensity_minutes": a.get("moderateIntensityMinutes"),
        "vigorous_intensity_minutes": a.get("vigorousIntensityMinutes"),
        "aerobic_training_effect": a.get("aerobicTrainingEffect"),
        "anaerobic_training_effect": a.get("anaerobicTrainingEffect"),
        "training_effect_label": a.get("trainingEffectLabel"),
        "aerobic_training_effect_message": a.get("aerobicTrainingEffectMessage"),
        "anaerobic_training_effect_message": a.get("anaerobicTrainingEffectMessage"),
        "activity_training_load": a.get("activityTrainingLoad"),
        "min_temperature_c": a.get("minTemperature"),
        "max_temperature_c": a.get("maxTemperature"),
        "lap_count": a.get("lapCount"),
        "min_activity_lap_duration_s": a.get("minActivityLapDuration"),
        "device_id": a.get("deviceId"),
        "manufacturer": a.get("manufacturer"),
        "workout_id": a.get("workoutId"),
        "has_polyline": a.get("hasPolyline"),
        "has_splits": a.get("hasSplits"),
        "has_intensity_intervals": a.get("hasIntensityIntervals"),
        "is_manual_activity": a.get("isManualActivity"),
        "privacy_type_key": pv.get("typeKey"),
        "gear_uuid": gear_uuid,
        "gear_name": gear_name,
        "gear_make": gear_make,
        "raw": Jsonb(a),
    }


def upsert_activity(cur, row: dict) -> None:
    cols = list(row.keys())
    placeholders = ", ".join(["%s"] * len(cols))
    updates = ", ".join(f"{c} = EXCLUDED.{c}" for c in cols if c != "activity_id")
    cur.execute(
        f"INSERT INTO activities ({', '.join(cols)}) VALUES ({placeholders}) "
        f"ON CONFLICT (activity_id) DO UPDATE SET {updates}, ingested_at = now()",
        [row[c] for c in cols],
    )


def upsert_hr_zones(cur, activity_id: int, a: dict) -> int:
    n = 0
    for zone in range(1, 6):
        seconds = a.get(f"hrTimeInZone_{zone}")
        if seconds is None:
            continue
        cur.execute(
            "INSERT INTO activity_hr_zones (activity_id, zone, seconds) VALUES (%s, %s, %s) "
            "ON CONFLICT (activity_id, zone) DO UPDATE SET seconds = EXCLUDED.seconds",
            (activity_id, zone, seconds),
        )
        n += 1
    return n


SPLIT_COLS = (
    ("no_of_splits", "noOfSplits"),
    ("distance_m", "distance"),
    ("duration_s", "duration"),
    ("average_speed_mps", "averageSpeed"),
    ("max_speed_mps", "maxSpeed"),
    ("total_ascent_m", "totalAscent"),
    ("elevation_loss_m", "elevationLoss"),
    ("max_elevation_gain_m", "maxElevationGain"),
    ("avg_elevation_gain_m", "averageElevationGain"),
    ("num_climb_sends", "numClimbSends"),
    ("num_falls", "numFalls"),
)


def upsert_splits(cur, activity_id: int, a: dict) -> int:
    n = 0
    for s in a.get("splitSummaries") or []:
        split_type = s.get("splitType")
        if not split_type:
            continue
        cols = ["activity_id", "split_type"] + [c for c, _ in SPLIT_COLS]
        vals = [activity_id, split_type] + [s.get(src) for _, src in SPLIT_COLS]
        updates = ", ".join(f"{c} = EXCLUDED.{c}" for c, _ in SPLIT_COLS)
        cur.execute(
            f"INSERT INTO activity_splits ({', '.join(cols)}) "
            f"VALUES ({', '.join(['%s'] * len(cols))}) "
            f"ON CONFLICT (activity_id, split_type) DO UPDATE SET {updates}",
            vals,
        )
        n += 1
    return n


def fetch_all(garmin: Garmin, page: int, limit: int | None) -> list[dict]:
    out: list[dict] = []
    start = 0
    while True:
        want = page if limit is None else min(page, limit - len(out))
        if want <= 0:
            break
        batch = garmin.get_activities(start, want)
        if not batch:
            break
        out.extend(batch)
        if len(batch) < want:
            break
        start += len(batch)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Backfill/sync Garmin cycling activities into Postgres.")
    ap.add_argument("--limit", type=int, default=None, help="fetch only the N most-recent activities")
    ap.add_argument("--since", type=str, default=None, help="only keep activities on/after YYYY-MM-DD (local)")
    ap.add_argument("--page", type=int, default=100, help="Garmin page size (default 100)")
    ap.add_argument("--all-types", action="store_true", help="store all activity types, not just cycling")
    ap.add_argument("--dry-run", action="store_true", help="fetch + report, write nothing")
    args = ap.parse_args()

    load_dotenv(ENV_PATH)
    dsn = os.getenv("DATABASE_URL")
    if not dsn and not args.dry_run:
        sys.exit(f"DATABASE_URL not set (expected in {ENV_PATH} or the environment)")

    garmin = Garmin()
    with open(os.devnull, "w") as dn, contextlib.redirect_stdout(dn):
        garmin.login(TOKEN_DIR)

    activities = fetch_all(garmin, page=args.page, limit=args.limit)
    if args.since:
        activities = [a for a in activities if (a.get("startTimeLocal") or "") >= args.since]
    if not args.all_types:
        activities = [a for a in activities if is_cycling(a)]

    gear_map = build_gear_map(garmin)
    scope = "all types" if args.all_types else "cycling only"
    print(f"Fetched {len(activities)} activities ({scope}); {len(gear_map)} activities have bike gear", file=sys.stderr)

    if args.dry_run:
        by_type = Counter((a.get("activityType") or {}).get("typeKey") or "?" for a in activities)
        for tk, c in by_type.most_common():
            print(f"  [type] {c:4d}  {tk}", file=sys.stderr)
        by_bike = Counter(gear_map.get(a.get("activityId"), (None, None, None))[1] or "(untagged)" for a in activities)
        for name, c in by_bike.most_common():
            print(f"  [bike] {c:4d}  {name}", file=sys.stderr)
        n_excl = sum(
            1 for a in activities
            if gear_map.get(a.get("activityId"), (None,))[0] == KONA_GEAR_UUID
            and (a.get("distance") or 0) < 10000
        )
        print(f"  [rides view] {n_excl} short Kona ride(s) (<10 km) would be EXCLUDED", file=sys.stderr)
        return

    n_act = n_zones = n_splits = 0
    with psycopg.connect(dsn) as conn, conn.cursor() as cur:
        for a in activities:
            activity_id = a.get("activityId")
            if activity_id is None:
                continue
            gu, gn, gm = gear_map.get(activity_id, (None, None, None))
            upsert_activity(cur, activity_row(a, gu, gn, gm))
            n_act += 1
            n_zones += upsert_hr_zones(cur, activity_id, a)
            n_splits += upsert_splits(cur, activity_id, a)
        conn.commit()

    print(f"Upserted {n_act} activities, {n_zones} hr-zone rows, {n_splits} split rows", file=sys.stderr)


if __name__ == "__main__":
    main()
