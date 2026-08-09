# 0003 — Home-server deployment: Docker Compose, Postgres 16 + Grafana

- **Status**: Accepted
- **Date**: 2026-08-06 (written retroactively, Aug 2026)

## Context

The Garmin mirror (ADR 0002) needs somewhere to run Postgres and Grafana.
Requirements: near-zero cost, private by default (personal health data), easy to
rebuild, reachable from home devices.

## Decision

Run **Postgres 16 + Grafana via Docker Compose** on the home server
(`192.168.1.9`), configuration in `infra/` (compose file + Grafana provisioning
for datasource and dashboards). LAN-only; no public exposure.

## Alternatives considered

- **Managed cloud (Neon/Supabase + Grafana Cloud)** — free tiers exist, but
  health data leaves the house, and free tiers change; overkill for one user.
- **Bare-metal installs** — harder to rebuild/version; compose file *is* the
  documentation.
- **SQLite + static charts** — no live dashboards, weaker query ergonomics.

## Consequences

- Data stays on-premises; zero recurring cost.
- Dashboards only reachable at home (or via VPN) — accepted; if remote access is
  ever needed, that's a superseding ADR (VPN/tunnel/cloud).
- Server availability is Artur's responsibility (no SLA — it's a hobby).

## Implementation notes

`infra/docker-compose.yml`; Grafana provisioning under `infra/grafana/`
(datasource: Postgres; dashboard JSON: `gravelled.json`). Secrets via `.env`
(git-ignored, `*.env.example` committed). Grafana at `http://192.168.1.9:3000`.

## Verification

Stack boots from a clean checkout with `docker compose up -d`; provisioned
dashboard renders totals, weekly distance/load, HR-zone and speed-vs-HR panels
against the live database.
