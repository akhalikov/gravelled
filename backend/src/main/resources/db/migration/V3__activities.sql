-- V3: generic activities (v2) + HR zones + splits (ADR 0006).
--
-- Design carried over from ADR 0002: raw SI units in columns, full payload in
-- source_raw JSONB, unit conversion in views. Sport-specific metrics stay in
-- source_raw and surface through per-sport views.

CREATE TABLE activities (
    activity_id        BIGSERIAL PRIMARY KEY,                     -- surrogate: Garmin is a source, not the universe
    source             TEXT NOT NULL DEFAULT 'garmin',
    source_activity_id TEXT NOT NULL,                             -- Garmin activityId (stringified); other sources vary
    athlete_id         SMALLINT NOT NULL REFERENCES athletes (athlete_id),
    sport_id           SMALLINT NOT NULL REFERENCES sports (sport_id),

    -- the source's own classification, kept verbatim (sport_id is our resolution of it);
    -- e.g. Garmin's 'gravel_cycling'. Other source-specific details live in source_raw.
    source_type_key    TEXT,

    name               TEXT,

    start_time_gmt     TIMESTAMPTZ NOT NULL,
    start_time_local   TIMESTAMP,
    end_time_gmt       TIMESTAMPTZ,

    duration_s         DOUBLE PRECISION,
    moving_duration_s  DOUBLE PRECISION,
    elapsed_duration_s DOUBLE PRECISION,

    -- broadly-shared movement metrics; NULL where meaningless (strength, climbing)
    distance_m         DOUBLE PRECISION,
    avg_speed_mps      DOUBLE PRECISION,
    max_speed_mps      DOUBLE PRECISION,
    elevation_gain_m   DOUBLE PRECISION,
    elevation_loss_m   DOUBLE PRECISION,

    avg_hr             REAL,
    max_hr             REAL,
    calories           REAL,

    aerobic_te         REAL,
    anaerobic_te       REAL,
    te_label           TEXT,
    training_load      REAL,

    -- Private: home/route coordinates. Live only in the LAN DB; never in git.
    start_lat          DOUBLE PRECISION,
    start_lon          DOUBLE PRECISION,
    end_lat            DOUBLE PRECISION,
    end_lon            DOUBLE PRECISION,
    location_name      TEXT,

    workout_id         BIGINT,                                    -- joins planned_workouts (V5)

    -- denormalized gear; a proper gear table is phase two (ADR 0006)
    gear_uuid          TEXT,
    gear_name          TEXT,
    gear_make          TEXT,

    -- full payload from `source` (Garmin API response today; Strava export tomorrow).
    -- Columns are for queries; source_raw is for completeness — anything not
    -- promoted to a column (device, event type, TE messages…) lives here.
    source_raw         JSONB NOT NULL,
    ingested_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (source, source_activity_id)
);

CREATE INDEX idx_activities_start    ON activities (start_time_gmt DESC);
CREATE INDEX idx_activities_athlete  ON activities (athlete_id);
CREATE INDEX idx_activities_sport    ON activities (sport_id);
CREATE INDEX idx_activities_type_key ON activities (source_type_key);
CREATE INDEX idx_activities_gear     ON activities (gear_uuid);

CREATE TABLE activity_hr_zones (
    activity_id BIGINT   NOT NULL REFERENCES activities (activity_id) ON DELETE CASCADE,
    zone        SMALLINT NOT NULL CHECK (zone BETWEEN 1 AND 5),
    seconds     REAL,
    PRIMARY KEY (activity_id, zone)
);

CREATE TABLE activity_splits (
    activity_id          BIGINT NOT NULL REFERENCES activities (activity_id) ON DELETE CASCADE,
    split_type           TEXT   NOT NULL,
    no_of_splits         INTEGER,
    distance_m           REAL,
    duration_s           REAL,
    average_speed_mps    REAL,
    max_speed_mps        REAL,
    total_ascent_m       REAL,
    elevation_loss_m     REAL,
    num_climb_sends      INTEGER,
    num_falls            INTEGER,
    PRIMARY KEY (activity_id, split_type)
);
