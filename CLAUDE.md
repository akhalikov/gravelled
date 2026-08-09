# CLAUDE.md

Guidance for Claude when working in this repository.

## What this is

`gravelled` is a personal **context repository** for Artur's gravel-cycling journey — a small,
hand-maintained knowledge base in plain Markdown, meant to be read by Claude/LLMs (and by Artur).
It is primarily **data** — the Markdown knowledge base — but now with a small **data pipeline**
alongside it (`db/`, `pipeline/`, `infra/`) that mirrors Garmin activities into Postgres for
querying and Grafana dashboards. The Markdown stays the narrative source of truth; the database
is the analytical layer beside it. Rider is based in Kraków; main bike is a Canyon Grizl CF 8 ESC.

## File map

All content lives as flat, root-level `.md` files. Register every new content file in the README
`## Contents` index.

- `README.md` — entry point: linked index of all files, Quick Facts (bike + rider vitals), Notes
- `bikes.md` — current & sold bikes with full specs; body measurements at the bottom
- `rides.md` — ride log (newest-first)
- `goals.md` — end-of-year goals (checkboxes)
- `training-plan.md` — Tatra Loop season plan (the season goal)
- `plans.md` — bikepacking trip planning + gear procurement / upgrade to-dos
- `equipment.md` — bike computers, bikepacking bags, clothing
- `atlas-insights.md` — fitness baselines & benchmarks carried over from the previous bike ("Atlas era")
- `garmin-mcp.md` — runbook for wiring Garmin Connect into Claude via MCP

Code + infra (the data pipeline) live in subdirectories:

- `db/` — Postgres schema (`schema.sql`) and views (`views.sql`) for the riding dataset
- `pipeline/` — Garmin → Postgres ingestion (`ingest.py`): backfill + incremental sync
- `infra/` — Docker Compose (Postgres 16 + Grafana) for the home server (192.168.1.9)

## Conventions

- **Files:** Markdown content is lowercase-hyphenated `.md` at the repo root (no subdirectories for
  the knowledge base). Pipeline code/infra live in `db/`, `pipeline/`, `infra/`. `.claude/workspace/`
  is git-ignored scratch.
- **Structure:** one `#` H1 title, then `##` sections, then `-` bullet lists. Bold marks key entities
  (product names, decisions).
- **Ride log entries:** newest-first; header `## YYYY-MM-DD — Title`; then metric bullets (Distance,
  Time, Elevation, Avg/Max HR, Training load / Training Effect, RPE, notes). Metric names mirror Garmin.
- **Status markers:** `- [ ]` / `- [x]` for checklists; inline `✅ ordered`, `**for sale**`, `⚠️` for warnings.
- **Provenance:** cite the source and date of any data point inline (e.g. "per Garmin gear stats, Aug 2026");
  flag stale numbers ("FTP 186 W from 2021 — stale, ignore").
- **Tables:** Markdown tables for comparative data (e.g. the Vistula Loop benchmark).
- **Cross-links:** reference related files with relative links.
- **Data pipeline:** base tables store Garmin's **raw SI** (meters, m/s, seconds, °C) plus the full
  payload in a `raw JSONB` column; all unit conversion lives in views. Ingestion upserts on
  `activity_id` (idempotent). Secrets live in `.env` files (git-ignored — commit only `*.env.example`).
  Never commit GPS coordinates (`start/end_lat/lon`).
- **Rides scope:** ingestion stores **cycling only** by default (`type_id = 2 OR parent_type_id = 2`;
  `--all-types` overrides) and tags each ride with its bike (`gear_uuid/gear_name/gear_make`, resolved
  via `get_gear_activities`). The `rides` view = cycling minus short **Kona "Rove DL"** commutes
  (< 10 km) — a view filter, not a delete (the rows remain in `activities`).

## Maintaining the repo

- When vitals change (bike, weight, saddle height, foot length, etc.), also update the README
  **Quick Facts** — it's the at-a-glance source of truth.
- Ride data: the Markdown `rides.md` log is still curated **by hand**; the Postgres dataset is
  populated by `pipeline/ingest.py` (backfill + sync). Garmin can be pulled directly from Claude
  Code — see "Claude Code (direct pull, no MCP)" in `garmin-mcp.md`.
- Keep the linked web intact: new content file → add to README Contents; new fact → cross-link where relevant.

## Commits

One concise **imperative-mood** line per logical change, sentence case, **no type prefixes**
(no `feat:`/`fix:`), no body — except the standing trailer `Co-Authored-By: Claude <noreply@anthropic.com>`
on commits Claude makes. Name specifics and rationale — e.g. "Record shoe order: Fizik Terra
Atlas 42.5 black", "Choose standard Thundero 44 over HD (weight/rolling resistance)". The log reads
as a changelog of decisions.
