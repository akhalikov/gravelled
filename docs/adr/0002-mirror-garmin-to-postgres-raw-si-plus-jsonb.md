# 0002 — Mirror Garmin to Postgres: raw SI + JSONB, conversions in views

- **Status**: Accepted
- **Date**: 2026-08-06 (written retroactively, Aug 2026)

## Context

Markdown (ADR 0001) holds narrative well but can't answer analytical questions
(weekly load, speed-vs-HR trends, per-bike mileage). Garmin Connect holds the
data but offers no SQL and limited history views. A local, queryable mirror was
needed for Grafana dashboards and ad-hoc analysis.

## Decision

Ingest Garmin activities into Postgres via `pipeline/ingest.py` (backfill +
incremental sync), using the same saved OAuth tokens as the Garmin MCP
(`~/.garminconnect`, garminconnect 0.3.2). Base tables store Garmin's **raw SI
units** (meters, m/s, seconds, °C) **plus the full API payload in a `raw JSONB`
column**; all unit conversion and presentation live in SQL **views**. Ingestion
**upserts on `activity_id`** so re-runs are idempotent.

## Alternatives considered

- **Convert units at ingest** — loses fidelity, bakes display choices into
  storage, makes bugs permanent. Views are cheap to fix; re-ingestion isn't.
- **Store only selected columns (no JSONB)** — every future need (new metric,
  e.g. power fields after the 4iiii arrived) would force re-backfill. JSONB keeps
  the whole payload for later extraction.
- **SQLite** — simpler, but Grafana + home-server multi-client access favors
  Postgres; already running one container anyway (ADR 0003).
- **Query Garmin API live each time** — rate limits, latency, no SQL, no joins
  with local annotations.

## Consequences

- Any future field is already stored (in `raw`) even if not yet a column.
- Unit bugs are view-level fixes; base data never rewritten.
- Idempotent sync means cron-safe operation; duplicate-free by construction.
- Cost: JSONB storage overhead (negligible at personal scale) and a schema that
  looks "raw" without the views.

## Implementation notes

`db/schema.sql` (base tables), `db/views.sql` (unit conversion + `rides` view,
see ADR 0004). Secrets in git-ignored `.env` files; only `*.env.example`
committed. GPS start/end coordinates are **never committed** anywhere.

## Verification

Full-history backfill + repeated `--dry-run`/sync runs produced stable counts
(no duplicates). Grafana totals (145 rides / ~2,880 km at go-live) reconciled
against Garmin Connect's own history.
