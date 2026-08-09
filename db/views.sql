-- gravelled — convenience views (idempotent).
-- All unit conversion lives here; base tables stay raw SI (see schema.sql).
--
-- Cycling filter: (type_id = 2 OR parent_type_id = 2). Garmin's generic "cycling"
-- is typeId 2 with parentTypeId 17, while subtypes (gravel_cycling, road_biking,
-- mountain_biking, indoor_cycling, virtual_ride, …) have parentTypeId 2. This
-- predicate captures both.
--
-- Exclusion: short Kona commutes — rides on the Kona "Rove DL" (gear uuid below)
-- under 10 km are dropped from `rides` (and everything built on it). The rows
-- still exist in `activities`; this is a presentation filter, not a delete.

CREATE OR REPLACE VIEW rides AS
SELECT
    activity_id,
    name,
    type_key,
    gear_name,
    gear_make,
    start_time_local,
    start_time_gmt,
    start_time_local::date                    AS ride_date,
    distance_m / 1000.0                       AS distance_km,
    duration_s,
    make_interval(secs => duration_s)         AS duration,
    make_interval(secs => moving_duration_s)  AS moving_time,
    average_speed_mps * 3.6                   AS avg_speed_kmh,
    max_speed_mps * 3.6                       AS max_speed_kmh,
    elevation_gain_m,
    average_hr,
    max_hr,
    calories,
    aerobic_training_effect,
    anaerobic_training_effect,
    training_effect_label,
    activity_training_load,
    min_temperature_c,
    max_temperature_c,
    location_name
FROM activities
WHERE (type_id = 2 OR parent_type_id = 2)
  AND NOT (
        coalesce(gear_uuid, '') = '5593e10268314faebd8b26136e705d37'  -- Kona "Rove DL"
        AND coalesce(distance_m, 1e9) < 10000                          -- under 10 km
  );

-- Per-week cycling volume, built on `rides` so it inherits the same filters.
CREATE OR REPLACE VIEW ride_weekly AS
SELECT
    date_trunc('week', start_time_local)  AS week,
    count(*)                              AS rides,
    sum(distance_km)                      AS distance_km,
    sum(elevation_gain_m)                 AS elevation_gain_m,
    sum(activity_training_load)           AS training_load,
    sum(duration_s) / 3600.0              AS hours
FROM rides
GROUP BY 1
ORDER BY 1;
