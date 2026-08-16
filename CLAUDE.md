# CLAUDE.md

Guidance for Claude when working in this repository.

## Communication style

Respond in **simple, plain English (CEFR B2 level)**. Short sentences. Common
words. One idea per sentence. Explain technical terms when they are needed
(e.g. "LTHR — the heart rate you can hold for about an hour"). Keep exact
numbers, file paths and product names precise.

## What this is

`gravelled` is a personal **context repository** for Artur's gravel-cycling journey — a small,
hand-maintained knowledge base in plain Markdown, meant to be read by Claude/LLMs (and by Artur).
It is primarily **data** — the Markdown knowledge base — but now with a small **data pipeline**
alongside it (`db/`, `pipeline/`, `infra/`) that mirrors Garmin activities into Postgres for
querying and Grafana dashboards. The Markdown stays the narrative source of truth; the database
is the analytical layer beside it. Rider is based in Kraków; main bike is a Canyon Grizl CF 8 ESC.

## File map

Knowledge-base content lives as flat `.md` files in `docs/`; only `README.md` and `CLAUDE.md`
stay at the repo root. Register every new content file in the README `## Contents` index.

- `README.md` (root) — entry point: linked index of all files, Quick Facts (bike + rider vitals), Notes
- `docs/bikes.md` — current & sold bikes with full specs; body measurements at the bottom
- `docs/rides.md` — ride log (newest-first)
- `docs/goals.md` — end-of-year goals (checkboxes)
- `docs/training-plan.md` — Tatra Loop season plan (the season goal)
- `docs/plans.md` — bikepacking trip planning + gear procurement / upgrade to-dos
- `docs/equipment.md` — bike computers, bikepacking bags, clothing
- `docs/atlas-insights.md` — fitness baselines & benchmarks carried over from the previous bike ("Atlas era")
- `docs/bike-fit.md` — Retül fit coordinates (Aug 2026)
- `docs/garmin-mcp.md` — runbook for wiring Garmin Connect into Claude via MCP
- `docs/adr/` — Architecture Decision Records for **system** decisions (pipeline, schema,
  infra, tooling); see `docs/adr/README.md` for the convention. Athletic/gear decisions
  stay in the knowledge base, not ADRs.

Code + infra (the data pipeline) live in subdirectories:

- `backend/` — Kotlin + Quarkus (Gradle) backend: owns schema via Flyway migrations, REST API (ADR 0005)
- `db/` — Postgres schema (`schema.sql`) and views (`views.sql`) for the riding dataset
- `pipeline/` — Garmin → Postgres ingestion (`ingest.py`): backfill + incremental sync
- `infra/` — Docker Compose (Postgres 16 + Grafana) for the home server (192.168.1.9)

## Conventions

- **Files:** Markdown content is lowercase-hyphenated `.md` in `docs/` (flat — no nesting inside,
  except `docs/adr/`). `README.md` and `CLAUDE.md` stay at the repo root. Pipeline code/infra live
  in `db/`, `pipeline/`, `infra/`. `.claude/workspace/` is git-ignored scratch.
- **ADRs:** every new **code/infra feature** is built in its own git worktree (branch off `main`)
  and ships with an ADR (`docs/adr/NNNN-*.md`, from `0000-template.md`) committed on that branch.
  Docs-only changes go straight to `main`, no ADR. Accepted ADRs are immutable — supersede, don't edit.
- **Links:** files inside `docs/` link to each other bare (`[bikes.md](bikes.md)`); README links with
  the `docs/` prefix; docs → code links go up a level (`../pipeline/`).
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
- Ride data: the Markdown `docs/rides.md` log is still curated **by hand**; the Postgres dataset is
  populated by `pipeline/ingest.py` (backfill + sync). Garmin can be pulled directly from Claude
  Code — see "Claude Code (direct pull, no MCP)" in `docs/garmin-mcp.md`.
- Keep the linked web intact: new content file → add to README Contents; new fact → cross-link where relevant.

## Commits

**Claude does not commit.** Claude edits/creates files and leaves them uncommitted; Artur reviews
and commits himself (author: `akhalikoff@gmail.com` — set via repo-local `git config user.email`).

Style, for reference: one concise **imperative-mood** line per logical change, sentence case,
**no type prefixes** (no `feat:`/`fix:`), no body. Name specifics and rationale — e.g. "Record shoe
order: Fizik Terra Atlas 42.5 black", "Choose standard Thundero 44 over HD (weight/rolling
resistance)". The log reads as a changelog of decisions.
