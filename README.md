# Gravelled 🚴

Context repository for my gravel bike and overall cycling journey.

## Contents

- [docs/bikes.md](docs/bikes.md) — current bikes (Canyon Grizl CF 8 ESC, Kona Rove DL) and sold bikes, full specs
- [docs/equipment.md](docs/equipment.md) — computers, bikepacking bags, clothing
- [docs/rides.md](docs/rides.md) — ride log
- [docs/plans.md](docs/plans.md) — planned upgrades and to-dos
- [docs/garmin-mcp.md](docs/garmin-mcp.md) — Garmin Connect ↔ Claude setup (install steps, gotchas)
- [docs/bike-fit.md](docs/bike-fit.md) — Retül fit coordinates (Aug 2026)
- [docs/atlas-insights.md](docs/atlas-insights.md) — training baselines from the Atlas era
- [docs/goals.md](docs/goals.md) — goals for end of 2026
- [docs/training-plan.md](docs/training-plan.md) — Tatra Loop season goal: training progression
- [docs/ftp-test.md](docs/ftp-test.md) — 20-min FTP test protocol, zone table and results log
- [backend/](backend/) — Kotlin + Quarkus backend: Flyway schema migrations, REST API (ADR 0005)
- [db/](db/) — Postgres schema + views for the riding dataset
- [pipeline/](pipeline/) — Garmin → Postgres ingestion (backfill + sync)
- [infra/](infra/) — Docker Compose (Postgres + Grafana) for the home server

## Quick Facts

- Main bike: **Canyon Grizl CF 8 ESC w/ ECLIPS** (since July 2026)
- City bike: **Kona Rove DL 2019**
- Rider: 175 cm, 83.5 cm inseam, 72 kg, saddle height ~745 mm, foot length 27 cm (shoes ≈ EU 42.5–43)
- Location: Kraków

## Notes

- Canyon box kept — useful for transport during autumn trip
- Spoke protector: remove after testing 51T sprocket
- Aerobar seen in Canyon marketing photos is not stock — appears to be Ergon + Profile Design or similar
- Riding data is mirrored to **Postgres on 192.168.1.9** (`pipeline/` → `db/`); **Grafana** dashboards at http://192.168.1.9:3000
