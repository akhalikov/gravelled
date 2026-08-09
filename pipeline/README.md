# pipeline — Garmin → Postgres ingestion

`ingest.py` pulls activity summaries from Garmin Connect (using the saved tokens at
`~/.garminconnect`), tags each with the bike it was ridden on, and upserts them into the
`activities`, `activity_hr_zones` and `activity_splits` tables. It runs **on this Mac** (where the
Garmin tokens live) and writes to Postgres on the home server (`192.168.1.9`). Idempotent — the same
script does the one-time backfill and future incremental syncs.

**Scope:** cycling only by default (`type_id = 2 OR parent_type_id = 2`). Every cycling ride is stored
and bike-tagged; the short-Kona-commute exclusion (Kona "Rove DL" rides under 10 km) is applied in the
`rides` view — see [`../db/views.sql`](../db/views.sql) — not at ingest.

## Setup

1. Bring up Postgres on `.9` and apply the schema (see [`../infra/`](../infra/) and [`../db/`](../db/)).
2. `cp .env.example .env` and set `DATABASE_URL`.

## Run

Dependencies are ephemeral via `uv` — nothing is installed globally.

```bash
# preview: cycling count, breakdown by type + by bike, and how many short-Kona rides
# would be excluded from the rides view. Writes nothing.
uv run --with "garminconnect==0.3.2" --with "psycopg[binary]" --with python-dotenv \
    python pipeline/ingest.py --dry-run

# full backfill (all cycling activities)
uv run --with "garminconnect==0.3.2" --with "psycopg[binary]" --with python-dotenv \
    python pipeline/ingest.py

# incremental: only recent rides
uv run --with "garminconnect==0.3.2" --with "psycopg[binary]" --with python-dotenv \
    python pipeline/ingest.py --since 2026-08-01
```

Flags: `--dry-run`, `--limit N` (N most-recent), `--since YYYY-MM-DD`, `--page N`,
`--all-types` (store every activity type, not just cycling).

### Recurring sync

`sync.sh` wraps `ingest.py --since <N days ago>` (default 7) for a quick, idempotent catch-up:

```bash
./pipeline/sync.sh        # last 7 days
./pipeline/sync.sh 14     # last 14 days
```

Cron-friendly (resolves `uv` by absolute path) — e.g. daily at 20:00:

```
0 20 * * *  /Users/artur/github/gravelled/pipeline/sync.sh >> /tmp/gravelled-sync.log 2>&1
```

## Notes

- **Tokens:** expects `~/.garminconnect/garmin_tokens.json` (see [`../garmin-mcp.md`](../garmin-mcp.md)).
  If a call 401s, tokens expired — re-auth with `garmin-mcp-auth --force-reauth`.
- **Bike tagging:** resolved via `get_gear_activities` (one call per bike). ~96 older cycling
  activities have no gear assigned in Garmin (`gear_name` NULL); the Kona exclusion only affects rides
  actually tagged with the Kona, so untagged short rides are not dropped.
- **Rate limits:** Garmin may return 429 if hammered; a full backfill is ~10 paginated calls + 3 gear calls.
- **Privacy:** `start/end_lat/lon` are stored in the DB (private, on the LAN) but must never be committed to git.
