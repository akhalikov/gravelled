# Flyway migrations

Naming: `V<version>__<description>.sql` (two underscores), e.g.
`V1__athletes_and_activities.sql`. Applied in version order at startup
(`quarkus.flyway.migrate-at-start=true`), history in `flyway_schema_history`.

The v2 schema (ADR 0006) lands here as the first migrations. Until then this
directory is intentionally empty.
