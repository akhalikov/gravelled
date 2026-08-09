-- gravelled — riding dataset schema (Postgres 16)
--
-- Design rules (see CLAUDE.md):
--   * Store Garmin's RAW SI values (meters, m/s, seconds, °C). No unit conversion here —
--     that lives in views.sql. Ingestion stays "dumb" and lossless.
--   * Every activity also keeps its FULL raw payload in `raw JSONB`, so nothing is ever
--     lost and new Garmin fields (e.g. power once the 4iiii is installed) are captured
--     with zero schema change.
--   * Upsert key is `activity_id`. This file is idempotent — safe to re-run.

CREATE TABLE IF NOT EXISTS activities (
    activity_id                       BIGINT PRIMARY KEY,      -- activityId
    activity_uuid                     UUID,                    -- activityUUID
    name                              TEXT,                    -- activityName
    type_key                          TEXT,                    -- activityType.typeKey (e.g. gravel_cycling)
    type_id                           INTEGER,                 -- activityType.typeId
    parent_type_id                    INTEGER,                 -- activityType.parentTypeId (2 = cycling parent; generic "cycling" is typeId 2 / parent 17)
    event_type_key                    TEXT,                    -- eventType.typeKey
    sport_type_id                     INTEGER,

    start_time_local                  TIMESTAMP,               -- naive local wall-clock
    start_time_gmt                    TIMESTAMPTZ,             -- UTC
    end_time_gmt                      TIMESTAMPTZ,
    time_zone_id                      INTEGER,

    duration_s                        DOUBLE PRECISION,
    elapsed_duration_s                DOUBLE PRECISION,
    moving_duration_s                 DOUBLE PRECISION,

    distance_m                        DOUBLE PRECISION,
    average_speed_mps                 DOUBLE PRECISION,
    max_speed_mps                     DOUBLE PRECISION,
    max_vertical_speed_mps            DOUBLE PRECISION,

    elevation_gain_m                  DOUBLE PRECISION,
    elevation_loss_m                  DOUBLE PRECISION,
    min_elevation_m                   DOUBLE PRECISION,
    max_elevation_m                   DOUBLE PRECISION,
    avg_elevation_m                   DOUBLE PRECISION,
    elevation_corrected               BOOLEAN,

    -- Private: home/route coordinates. Live only in this LAN DB; never commit to git.
    start_lat                         DOUBLE PRECISION,
    start_lon                         DOUBLE PRECISION,
    end_lat                           DOUBLE PRECISION,
    end_lon                           DOUBLE PRECISION,
    location_name                     TEXT,

    average_hr                        REAL,
    max_hr                            REAL,

    calories                          REAL,
    bmr_calories                      REAL,
    water_estimated_ml                REAL,

    min_respiration_rate              REAL,
    max_respiration_rate              REAL,
    avg_respiration_rate              REAL,
    moderate_intensity_minutes        INTEGER,
    vigorous_intensity_minutes        INTEGER,

    aerobic_training_effect           REAL,
    anaerobic_training_effect         REAL,
    training_effect_label             TEXT,
    aerobic_training_effect_message   TEXT,
    anaerobic_training_effect_message TEXT,
    activity_training_load            REAL,

    min_temperature_c                 REAL,
    max_temperature_c                 REAL,

    lap_count                         INTEGER,
    min_activity_lap_duration_s       REAL,

    device_id                         BIGINT,
    manufacturer                      TEXT,
    workout_id                        BIGINT,

    has_polyline                      BOOLEAN,
    has_splits                        BOOLEAN,
    has_intensity_intervals           BOOLEAN,
    is_manual_activity                BOOLEAN,
    privacy_type_key                  TEXT,

    gear_uuid                         TEXT,                    -- Garmin bike gear UUID (from get_gear_activities)
    gear_name                         TEXT,                    -- gear displayName (e.g. "Rove DL", "Grizzl")
    gear_make                         TEXT,                    -- gear make/model (e.g. "Kona", "Canyon Grizl")

    raw                               JSONB NOT NULL,          -- full Garmin activity payload
    ingested_at                       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activities_start_gmt   ON activities (start_time_gmt DESC);
CREATE INDEX IF NOT EXISTS idx_activities_parent_type ON activities (parent_type_id);
CREATE INDEX IF NOT EXISTS idx_activities_type_key    ON activities (type_key);
CREATE INDEX IF NOT EXISTS idx_activities_gear        ON activities (gear_uuid);

-- Time-in-HR-zone (Garmin hrTimeInZone_1..5, seconds).
CREATE TABLE IF NOT EXISTS activity_hr_zones (
    activity_id BIGINT   NOT NULL REFERENCES activities (activity_id) ON DELETE CASCADE,
    zone        SMALLINT NOT NULL CHECK (zone BETWEEN 1 AND 5),
    seconds     REAL,
    PRIMARY KEY (activity_id, zone)
);

-- Split summaries (Garmin splitSummaries[]): one row per split_type
-- (surface types SURFACE_TYPE_PAVED/UNPAVED and interval types INTERVAL_ACTIVE/WARMUP/…).
CREATE TABLE IF NOT EXISTS activity_splits (
    activity_id          BIGINT NOT NULL REFERENCES activities (activity_id) ON DELETE CASCADE,
    split_type           TEXT   NOT NULL,
    no_of_splits         INTEGER,
    distance_m           REAL,
    duration_s           REAL,
    average_speed_mps    REAL,
    max_speed_mps        REAL,
    total_ascent_m       REAL,
    elevation_loss_m     REAL,
    max_elevation_gain_m REAL,
    avg_elevation_gain_m REAL,
    num_climb_sends      INTEGER,
    num_falls            INTEGER,
    PRIMARY KEY (activity_id, split_type)
);
