# 0004 — Cycling-only ingestion with gear tagging; rides view filters commutes

- **Status**: Accepted
- **Date**: 2026-08-06 (written retroactively, Aug 2026)

## Context

Garmin history contains many activity types (running, strength, bouldering,
walking, surfing…). The immediate analytical need was cycling: per-bike mileage,
ride trends, training benchmarks. Short Kona commutes distort ride statistics
(avg speed, distance distributions) but are still legitimate data.

## Decision

Ingest **cycling only** by default (`type_id = 2 OR parent_type_id = 2`), with an
`--all-types` override flag. Tag each ride with its bike (`gear_uuid`,
`gear_name`, `gear_make`, resolved via `get_gear_activities`). The `rides` view
excludes short **Kona "Rove DL" commutes (< 10 km)** — a **view-level filter,
not a delete**: the rows remain in `activities`.

## Alternatives considered

- **Ingest everything from day one** — more data, but the schema/views were
  designed around cycling metrics; other sports deserve deliberate modeling, not
  accidental inclusion.
- **Delete/skip commutes at ingest** — destroys data; filters belong in views
  (same principle as ADR 0002's raw-first storage).
- **Tag gear manually in SQL** — Garmin already knows the bike; resolving via
  API keeps one source of truth.

## Consequences

- Dashboards reflect *training* rides out of the box.
- Commutes and other sports are recoverable without re-ingestion (rows exist /
  `--all-types` exists).
- **Known likely supersession**: the repo is heading multi-sport ("personal
  athlete coach"). Expanding ingestion to all activity types + per-sport views
  should be a new ADR that supersedes the cycling-only default here.

## Implementation notes

Type filter + gear resolution in `pipeline/ingest.py`; commute exclusion in the
`rides` view (`db/views.sql`). Grafana "Rides by bike" panel reads the gear tags.

## Verification

Post-ingest counts by gear matched the cleaned-up Garmin gear stats (Atlas 35 /
Kona 39 / Grizl rides present); `rides` view totals exclude sub-10 km Kona rows
while `activities` retains them.
