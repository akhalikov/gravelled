#!/usr/bin/env bash
# Sync the last week of cycling activities from Garmin into Postgres.
#
# Idempotent: ingest.py upserts on activity_id, so re-running never duplicates —
# it just refreshes/adds any rides from the window. Runs on this Mac (Garmin
# tokens live in ~/.garminconnect; DB creds in pipeline/.env).
#
# Usage:  ./sync.sh [DAYS]        # DAYS defaults to 7
# Cron:   0 20 * * *  /Users/artur/github/gravelled/pipeline/sync.sh >> /tmp/gravelled-sync.log 2>&1
set -euo pipefail

DAYS="${1:-7}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve uv by absolute path too, so this works under cron's minimal PATH.
UV="$(command -v uv || echo /opt/homebrew/bin/uv)"

# N days ago as YYYY-MM-DD — BSD date (macOS) first, then GNU date (Linux).
since="$(date -v-"${DAYS}"d +%F 2>/dev/null || date -d "${DAYS} days ago" +%F)"

echo "[$(date '+%F %T')] gravelled: syncing cycling activities since ${since}"
exec "$UV" run \
  --with "garminconnect==0.3.2" \
  --with "psycopg[binary]" \
  --with python-dotenv \
  python "${SCRIPT_DIR}/ingest.py" --since "${since}"
