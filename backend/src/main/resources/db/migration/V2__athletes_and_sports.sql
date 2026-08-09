-- V2: athletes + sports taxonomy (ADR 0006).

CREATE TABLE athletes (
    athlete_id          SMALLSERIAL PRIMARY KEY,
    name                TEXT NOT NULL,
    garmin_user_id      BIGINT UNIQUE,      -- Garmin's numeric profile id (userProfilePk)
    garmin_display_name TEXT,               -- Garmin's UUID; activities carry it as ownerDisplayName
    birth_date          DATE,
    height_cm           REAL,
    weight_kg           REAL,               -- current weight; history belongs in daily biometrics (phase two)

    -- current training parameters (same snapshot convention as weight_kg:
    -- current value here, dated history is phase two; Garmin serves trends via API)
    max_hr_bpm          SMALLINT,
    lthr_bpm            SMALLINT,           -- lactate threshold HR — anchors HR zones
    ftp_watts           SMALLINT,           -- deliberately NULL until a real FTP test (186 W on file is from 2021 — stale)
    vo2max_cycling      REAL,
    vo2max_running      REAL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Multi-athlete ready = FK everywhere + this seed row. Nothing more (ADR 0006).
-- Seed values per Garmin user profile, Aug 2026. ftp_watts stays NULL on purpose.
INSERT INTO athletes (name, garmin_user_id, garmin_display_name, birth_date, height_cm, weight_kg,
                      lthr_bpm, vo2max_cycling, vo2max_running)
VALUES ('Artur', 92739213, 'da86c261-682c-46d2-a1fc-748f884c138f', '1984-04-27', 175, 71.5,
        165, 51, 50);

-- Our coaching taxonomy — deliberately small. Garmin's granular type keys map
-- onto these via sport_mappings.
CREATE TABLE sports (
    sport_id  SMALLSERIAL PRIMARY KEY,
    sport_key TEXT NOT NULL UNIQUE,     -- machine name: 'cycling', 'running', ...
    name      TEXT NOT NULL             -- display name
);

INSERT INTO sports (sport_key, name) VALUES
    ('cycling',        'Cycling'),
    ('running',        'Running'),
    ('climbing',       'Climbing'),
    ('swimming',       'Swimming'),
    ('strength',       'Strength Training'),
    ('walking_hiking', 'Walking & Hiking'),
    ('surfing',        'Surfing'),
    ('other',          'Other');

-- Garmin type_key -> sport. Unmapped keys fall back to 'other' at ingest;
-- adding a mapping later is an INSERT + re-resolve, never a code change.
CREATE TABLE sport_mappings (
    garmin_type_key TEXT PRIMARY KEY,
    sport_id        SMALLINT NOT NULL REFERENCES sports (sport_id)
);

INSERT INTO sport_mappings (garmin_type_key, sport_id) VALUES
    -- cycling
    ('cycling',              (SELECT sport_id FROM sports WHERE sport_key = 'cycling')),
    ('gravel_cycling',       (SELECT sport_id FROM sports WHERE sport_key = 'cycling')),
    ('road_biking',          (SELECT sport_id FROM sports WHERE sport_key = 'cycling')),
    ('mountain_biking',      (SELECT sport_id FROM sports WHERE sport_key = 'cycling')),
    ('indoor_cycling',       (SELECT sport_id FROM sports WHERE sport_key = 'cycling')),
    ('virtual_ride',         (SELECT sport_id FROM sports WHERE sport_key = 'cycling')),
    -- running
    ('running',              (SELECT sport_id FROM sports WHERE sport_key = 'running')),
    ('trail_running',        (SELECT sport_id FROM sports WHERE sport_key = 'running')),
    ('treadmill_running',    (SELECT sport_id FROM sports WHERE sport_key = 'running')),
    ('track_running',        (SELECT sport_id FROM sports WHERE sport_key = 'running')),
    -- climbing
    ('bouldering',           (SELECT sport_id FROM sports WHERE sport_key = 'climbing')),
    ('rock_climbing',        (SELECT sport_id FROM sports WHERE sport_key = 'climbing')),
    ('indoor_climbing',      (SELECT sport_id FROM sports WHERE sport_key = 'climbing')),
    -- swimming
    ('lap_swimming',         (SELECT sport_id FROM sports WHERE sport_key = 'swimming')),
    ('open_water_swimming',  (SELECT sport_id FROM sports WHERE sport_key = 'swimming')),
    -- strength
    ('strength_training',    (SELECT sport_id FROM sports WHERE sport_key = 'strength')),
    ('indoor_cardio',        (SELECT sport_id FROM sports WHERE sport_key = 'strength')),
    ('hiit',                 (SELECT sport_id FROM sports WHERE sport_key = 'strength')),
    -- walking & hiking
    ('walking',              (SELECT sport_id FROM sports WHERE sport_key = 'walking_hiking')),
    ('hiking',               (SELECT sport_id FROM sports WHERE sport_key = 'walking_hiking')),
    -- surfing
    ('surfing_v2',           (SELECT sport_id FROM sports WHERE sport_key = 'surfing')),
    ('surfing',              (SELECT sport_id FROM sports WHERE sport_key = 'surfing'));
