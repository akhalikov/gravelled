-- V5: training plans + planned workouts (ADR 0006).
--
-- training_plans: app-domain entity (a deliberate amendment of the original
-- "DB observes, humans author" boundary) — the structured counterpart of the
-- Markdown training plan, for coach logic to reason over.
--
-- planned_workouts: a MIRROR of Garmin's calendar, not an authoring system.
-- A scheduled workout may serve a plan (plan_id) or be ad-hoc (NULL).
-- Completion analysis = join activities.workout_id to source_workout_id.

CREATE TABLE training_plans (
    plan_id      SMALLSERIAL PRIMARY KEY,
    athlete_id   SMALLINT NOT NULL REFERENCES athletes (athlete_id),

    name         TEXT NOT NULL,                  -- e.g. 'Tatra Loop 2026'
    goal         TEXT NOT NULL,                  -- e.g. 'Tatra Loop (196 km / 2,700 m) in one day'
    goal_date    DATE,                           -- optional: target event day
    summary      TEXT,

    state        TEXT NOT NULL DEFAULT 'CREATED'
                 CHECK (state IN ('CREATED', 'ACTIVE', 'COMPLETED', 'DELETED')),

    -- weekly progression structure; deliberately JSONB while the shape settles
    -- (normalize into plan_weeks later only if queries need it)
    weeks        JSONB,
    weekly_hours REAL,                           -- target training hours per week

    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()  -- set app-side on every write
);

CREATE INDEX idx_training_plans_athlete ON training_plans (athlete_id, state);

CREATE TABLE planned_workouts (
    athlete_id        SMALLINT NOT NULL REFERENCES athletes (athlete_id),
    source            TEXT     NOT NULL DEFAULT 'garmin',
    source_workout_id TEXT     NOT NULL,
    scheduled_date    DATE     NOT NULL,

    plan_id           SMALLINT REFERENCES training_plans (plan_id),  -- NULL = ad-hoc
    sport_id          SMALLINT REFERENCES sports (sport_id),
    name              TEXT,
    description       TEXT,
    workout_type      TEXT,              -- structure: intervals / steady / strength / ...
    intensity         TEXT,              -- effort: Z2 / tempo / sweet_spot / threshold / recovery
    duration_s        REAL,              -- planned duration, seconds (SI, like activities.duration_s)

    state             TEXT NOT NULL DEFAULT 'PLANNED'
                      CHECK (state IN ('PLANNED',    -- scheduled, in the future (or not yet reconciled)
                                       'COMPLETED',  -- matching activity found
                                       'SKIPPED',    -- deliberately not done (e.g. recovery-gated)
                                       'NOT_DONE')), -- date passed, no activity, no decision

    source_raw        JSONB NOT NULL,
    ingested_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (athlete_id, source, source_workout_id, scheduled_date)
);

CREATE INDEX idx_planned_workouts_date ON planned_workouts (scheduled_date);
CREATE INDEX idx_planned_workouts_plan ON planned_workouts (plan_id);
