# Architecture Decision Records

This directory records the **WHY** behind significant architecture and design
decisions in personal athlete coach "Gravelled" — not just what the code does, 
but the context, the options weighed, and the trade-offs accepted.

## Convention

- ADRs cover system/architecture decisions (pipeline, schema, infra, tooling); 
  athletic and gear decisions stay in the knowledge base.
- Every new **code/infra feature** is built in its own **git worktree** (branch
  isolated from `main`); when it's implemented, an ADR is written and committed on
  that branch so it lands in the PR. Docs-only changes commit straight to `main`
  and need no ADR.
- Files are named `NNNN-short-kebab-title.md`, numbered sequentially. Start new
  ADRs from [0000-template.md](0000-template.md).
- Format (lightweight [MADR](https://adr.github.io/madr/)): **Status · Context ·
  Decision · Alternatives considered · Consequences · Implementation notes ·
  Verification**.
- Statuses: `Proposed` → `Accepted` | `Rejected`; later `Superseded by NNNN`.
- ADRs are immutable once **Accepted**. To change a decision, write a new ADR that
  **supersedes** the old one (note it in both).

ADRs 0001–0004 were written **retroactively** (Aug 2026) to capture decisions made
before this convention existed — the greenfield build and the shipped pipeline/infra.

## Index

| # | Title | Date | Status |
|---|-------|------|--------|
| [0001](0001-markdown-knowledge-base-as-source-of-truth.md) | Markdown knowledge base as source of truth | 2026-07-31 | Accepted |
| [0002](0002-mirror-garmin-to-postgres-raw-si-plus-jsonb.md) | Mirror Garmin to Postgres: raw SI + JSONB, conversions in views | 2026-08-06 | Accepted |
| [0003](0003-home-server-docker-compose-postgres-grafana.md) | Home-server deployment: Docker Compose, Postgres 16 + Grafana | 2026-08-06 | Accepted |
| [0004](0004-cycling-only-ingestion-with-gear-tagging.md) | Cycling-only ingestion with gear tagging; rides view filters commutes | 2026-08-06 | Accepted |