# 0006 — Multi-sport, multi-athlete schema (v2)

- **Status**: Accepted
- **Date**: 2026-08-09
- **Supersedes**: parts of [0004](0004-cycling-only-ingestion-with-gear-tagging.md) (cycling-only ingestion default)

## Context

The repo is evolving from gravel-centric to a **personal athlete coach** covering
running, climbing, swimming and strength training. The v1 schema (ADR 0002/0004)
has three tables — `activities`, `activity_hr_zones`, `activity_splits` — all
Garmin-shaped and cycling-leaning. Concerns:

- `activities` would accumulate sport-specific columns for every new sport
- No notion of an athlete → nothing is multi-athlete ready
- Recovery data (sleep, HRV, RHR, body battery) is consumed live by the morning
  brief but never stored → no load-vs-recovery analysis possible
- No planned-vs-actual view of training

## Decision

Introduce schema **v2** — athletes, sports (+ mappings), activities (+ zones,
splits), daily recovery, training plans and planned workouts — all keyed to an
athlete. Implemented as Flyway migrations `V1`–`V5` in
`backend/src/main/resources/db/migration/` (ADR 0005).

### `athletes`

- `athlete_id SMALLSERIAL PK`, `name`, `garmin_user_id` (numeric profile id,
  UNIQUE), `garmin_display_name` (Garmin's UUID — activities carry it as
  `ownerDisplayName`, enabling ownership checks), `birth_date`, `height_cm`,
  `weight_kg` (current value; history = phase-two daily biometrics),
  current training parameters (`max_hr_bpm`, `lthr_bpm`, `ftp_watts`,
  `vo2max_cycling`, `vo2max_running` — same snapshot convention; `ftp_watts`
  seeded NULL, the 2021 value on file is stale by decree),
  `created_at`, `updated_at` (set app-side — Postgres has no ON UPDATE)
- Seeded with one row (Artur). **Multi-athlete ready = FK everywhere + a seed row**,
  not credential management or per-athlete pipeline config (deferred until a real
  second athlete exists).

### `activities` (slimmed, generic)

- **Surrogate PK** + `UNIQUE (source, source_activity_id)` — Garmin stops being
  the implicit universe; a future Strava/manual import is an insert, not a redesign.
- `athlete_id FK`
- Universal columns: sport/type keys, start/end times, durations (total / moving /
  elapsed), avg/max HR, calories, training effect (aerobic/anaerobic/label),
  training load, `source_raw JSONB` (full source payload — named to pair with
  `source`/`source_activity_id`/`source_type_key`), `ingested_at`. Cold
  source-specific fields (device, event type, granular type ids) are NOT columns —
  they live in `source_raw` and get promoted to columns only when queries need them
- Broadly-shared movement columns stay (NULL where meaningless): `distance_m`,
  avg/max speed, elevation gain/loss
- **Sport-specific metrics live in `source_raw` JSONB**, surfaced by per-sport views
  (`rides`, `runs`, `climbs`, `strength_sessions`) — same raw-first principle as
  ADR 0002. Extension tables only when a sport needs relational structure
  (first candidate: strength exercise sets).
- Gear: keep denormalized `gear_*` columns for now; a proper `gear` table
  (bikes + running shoes, mileage tracking) is phase two.

### `sports` + `sport_mappings`

- `sports`: our coaching taxonomy (`cycling`, `running`, `climbing`, `swimming`,
  `strength`, `walking_hiking`, `surfing`, `other`) — small, seeded, rarely changes
- `sport_mappings`: Garmin `type_key` → `sport_id` (e.g. `gravel_cycling` →
  cycling, `bouldering` → climbing). New Garmin type = one `INSERT`, no code change
- `activities.sport_id` is resolved at ingest via this mapping; unmapped types
  fall back to `other` (and can be re-mapped later — `source_type_key` is kept verbatim)

### `daily_recovery`

- PK `(athlete_id, date)`
- Sleep (start/end timestamps — bedtime drift is a first-class question — plus
  duration, score, deep/REM/light seconds), overnight HRV (+ status), resting HR,
  body battery (wake/high/low), stress avg, `source_raw JSONB`
- Fed by the same garminconnect token; enables the key training question:
  **does yesterday's load depress today's HRV?**
- Weigh-ins/body composition can join later (either columns here or a sibling
  `daily_biometrics` if this table gets fat).

### `training_plans`

- App-domain entity (a deliberate amendment of the original "DB observes, humans
  author" boundary): a plan has a goal, optional `goal_date`, lifecycle `state`
  (`CREATED → ACTIVE → COMPLETED`, `DELETED` = soft delete), `summary`,
  `weekly_hours` target and a JSONB `weeks` progression (normalized later only if
  queried). The Markdown training plan remains the narrative; this is its
  structured counterpart the coach logic can reason over.

### `planned_workouts`

- **A mirror of Garmin's scheduled workouts, not an authoring system.** Authoring
  stays in Markdown (training-plan.md), Garmin Connect (which Claude can write
  to via MCP), and now `training_plans`; a scheduled workout may reference the
  plan it serves (`plan_id`, nullable for ad-hoc workouts).
- PK `(athlete_id, source, source_workout_id, scheduled_date)`; `plan_id` (nullable),
  sport, name, description, `workout_type` (structure: intervals/steady/…),
  `intensity` (effort: Z2/tempo/sweet_spot/…), `duration_s` (planned, SI seconds),
  `source_raw JSONB`
- Lifecycle `state`: `PLANNED → COMPLETED` (matching activity found via
  `activities.workout_id`) | `SKIPPED` (deliberate, e.g. recovery-gated — a good
  decision, not non-compliance) | `NOT_DONE` (date passed, no activity)
- Plan-vs-actual compliance = planned intensity/duration joined to actual
  training load/zones, per week.

### Ingestion changes

- Drop the cycling-only default: **ingest all activity types** (supersedes ADR
  0004's filter; the `--all-types` flag becomes the default behavior).
- The Kona commute exclusion stays where it was — in the `rides` view, unchanged.
- New sync steps: daily recovery pull, scheduled-workout pull.

## Alternatives considered

- **Keep one wide table, add columns per sport** — the problem being solved;
  rejected (sparse columns, unbounded growth).
- **Full supertype/subtype (extension table per sport)** — maximal rigor, but
  duplicates what `raw JSONB` + views already deliver; ceremony without queries
  that need it. Adopt per-sport tables only on demand.
- **EAV (key/value metrics table)** — flexible but query-hostile; JSONB is the
  Postgres-native version of this with better ergonomics.
- **Keep Garmin's `activityId` as natural PK** (v1 behavior) — simpler, but bakes
  Garmin-only and single-athlete assumptions into every FK; cheap to fix now,
  painful later. (The v2 surrogate is *named* `activity_id`; Garmin's ID lives in
  `source_activity_id`.)
- **No plan entity in the DB (pure "DB observes, humans author")** — the original
  position, partially amended: `training_plans` is app-authored, while
  `planned_workouts` remains a source mirror. Markdown keeps the narrative.
- **Per-source payload columns (`garmin_raw`, `strava_raw`, …)** — rejected: each
  row has exactly one source, so all but one column would always be NULL and every
  new source would need a migration; single `source_raw` + `source` discriminator instead.

## Consequences

- Every new sport is ingestible with zero schema change; analysis appears when a
  view is written for it.
- Load-vs-recovery correlation becomes a SQL query (and a Grafana panel).
- Grafana dashboards need updating (athlete filter, per-sport panels, true weekly
  load including non-cycling).
- **Migration = recreate + re-backfill**, not ALTER: all data is re-derivable
  from Garmin + `source_raw JSONB` (the ADR 0002 payoff). v1 tables are dropped
  (migration `V1` — destructive by design, cascades to v1 views; run against the
  live DB only when pipeline v2 + views v2 are ready).
- Multi-athlete remains dormant until needed; the cost paid now is one FK column
  and one seed row.

## Implementation notes

- Schema lives in Flyway migrations (`backend/src/main/resources/db/migration/`,
  ADR 0005) — `db/schema.sql` is superseded and will be removed or kept as
  generated documentation; `db/views.sql` gains per-sport views; the existing
  `rides` view keeps its contract (Grafana panels keep working).
- `pipeline/ingest.py`: remove type filter, add `daily_recovery` and
  `planned_workouts` sync, resolve `athlete_id` from config (default 1).
- Backfill order: athletes seed → activities (all types, full history) → recovery
  history (as far back as Garmin returns) → scheduled workouts.

## Verification

- Re-backfill completes idempotently (re-run produces identical counts)
- Row counts per sport match Garmin Connect totals (spot-check: cycling count
  must equal v1's count; running/strength/bouldering appear)
- `rides` view returns identical results to v1 (Grafana unchanged)
- `daily_recovery` for a known date matches the morning brief's numbers
- A planned workout scheduled via MCP appears in `planned_workouts` and joins to
  its completed activity
