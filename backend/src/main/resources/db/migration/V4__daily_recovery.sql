-- V4: daily recovery snapshot per athlete (ADR 0006).
-- Fed from Garmin wellness endpoints; enables load-vs-recovery analysis
-- (e.g. "does yesterday's training load depress today's HRV?").

CREATE TABLE daily_recovery (
    athlete_id        SMALLINT NOT NULL REFERENCES athletes (athlete_id),
    date              DATE     NOT NULL,

    sleep_start       TIMESTAMPTZ,      -- bedtime drift vs HRV is a first-class question
    sleep_end         TIMESTAMPTZ,
    sleep_seconds     INTEGER,
    sleep_score       SMALLINT,
    deep_seconds      INTEGER,
    rem_seconds       INTEGER,
    light_seconds     INTEGER,
    awake_seconds     INTEGER,

    hrv_overnight_ms  REAL,
    hrv_status        TEXT,             -- Garmin's qualifier: balanced / unbalanced / low
    hrv_weekly_avg_ms REAL,

    resting_hr        SMALLINT,
    body_battery_wake SMALLINT,
    body_battery_high SMALLINT,
    body_battery_low  SMALLINT,
    stress_avg        SMALLINT,

    source_raw        JSONB NOT NULL,   -- full wellness payloads (same raw-first rule)
    ingested_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (athlete_id, date)
);
