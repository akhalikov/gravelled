# 0001 — Markdown knowledge base as source of truth

- **Status**: Accepted
- **Date**: 2026-07-31 (written retroactively, Aug 2026)

## Context

Artur wanted a persistent, LLM-readable context store for his cycling life: bikes,
gear, rides, goals, decisions. It must be readable by both Claude (loaded as
conversation context) and a human on GitHub, survive tool churn, and be trivially
editable from any session. No requirement for queries or aggregation at this stage.

## Decision

Plain Markdown files in a git repo (`gravelled`), curated by hand (with Claude's
help), with `README.md` as a linked index and `CLAUDE.md` codifying conventions.
Narrative Markdown is the **source of truth**; any database is a derived,
analytical layer beside it.

## Alternatives considered

- **Notion / Obsidian / Google Docs** — richer editing, but weaker git history,
  worse LLM ingestion, vendor lock-in.
- **Database-first (everything in Postgres)** — great for metrics, terrible for
  narrative context (impressions, decisions, rationale); premature at day one.
- **One big file** — simplest, but merge-unfriendly and hard to navigate; rejected
  in favor of one file per domain, registered in the README index.

## Consequences

- Zero infrastructure; survives anything that can read text.
- History of decisions doubles as a changelog (commit style enforces this).
- Manual curation is the cost — mitigated later by the Garmin pipeline (ADR 0002)
  taking over the *metrics* half, leaving Markdown the *narrative* half.

## Implementation notes

Flat `.md` files, later moved into `docs/` (only `README.md` + `CLAUDE.md` at
root). Conventions in `CLAUDE.md`: lowercase-hyphenated names, newest-first ride
log, provenance citations, status markers.

## Verification

In daily use since creation: repo context successfully drives Claude sessions
(gear advice, training planning, Garmin analysis) without re-explaining history.
