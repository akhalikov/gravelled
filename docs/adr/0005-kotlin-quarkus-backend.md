# 0005 — Backend: Kotlin + Quarkus + Gradle, Flyway migrations

- **Status**: Accepted
- **Date**: 2026-08-09

## Context

The project is growing from "Markdown + a Python ingest script" into a personal
athlete coach (see ADR 0006 for the schema direction). That needs a real backend:
something that owns the database schema (migrations), can serve an API over
Postgres, and can eventually absorb ingestion and coaching logic. Artur's
background is Java; the company he works at is moving to Kotlin, so the backend
doubles as a **Kotlin learning vehicle** on the JVM ecosystem he already knows.

## Decision

Build the backend in **Kotlin** on **Quarkus** (current LTS, 3.33.x), built with
**Gradle** (Kotlin DSL), living in **`backend/`** in this repo. Schema changes are
**Flyway** SQL migrations owned by the backend (`backend/src/main/resources/db/migration`).

Persistence layer: **jOOQ** with Kotlin code generation (`KotlinGenerator`) from
the live schema — SQL-first, matching the repo's existing style (raw SQL in
`db/`, logic in views). The flow is: Flyway migrate → `jooqCodegen` → typed,
compile-checked queries. No ORM entity mapping.

Initial scope:

1. Project skeleton + health endpoint
2. Flyway wired to the existing home-server Postgres — **v2 schema (ADR 0006)
   ships as the first migrations**
3. Read-only REST API over activities/recovery (Grafana keeps reading SQL directly)

Explicitly out of scope for now: replacing the Python pipeline (it keeps
ingesting; the backend takes ingestion over in a later ADR), auth, deployment
hardening.

## Alternatives considered

- **Ktor** — the Kotlin-native lightweight choice, but DSL-centric: everything
  (routing, DI, config) is idiomatic-Kotlin-first. Steeper for a Java developer;
  Quarkus's JAX-RS annotations + CDI are familiar ground, letting Kotlin the
  *language* be the only new thing.
- **Spring Boot** — most familiar, heaviest; slow dev-loop and bigger memory
  footprint on a home server. Quarkus dev mode (live reload, dev services) is the
  better learning environment.
- **Micronaut** — fine, but smaller community; no compelling edge over Quarkus here.
- **Maven** — Gradle chosen deliberately (company direction + Kotlin DSL doubles
  as Kotlin practice).
- **Liquibase** — Flyway's plain-SQL migrations match the repo's existing
  SQL-first style (`db/*.sql`) and are easier to review.
- **Hibernate ORM / Panache** — the Quarkus default, but entity-first: the
  schema would be a projection of Kotlin classes. This project is the opposite
  (schema is truth, ADR 0002/0006); jOOQ's generated-from-schema model fits.
  Also: analytical queries (zone aggregation, load trends) are jOOQ's home turf
  and ORM-hostile.
- **Kotlin Exposed** — Kotlin-native DSL, but schema defined in code (same
  inversion as Hibernate) and far smaller ecosystem than jOOQ.
- **Plain JDBC** — no codegen safety net; jOOQ is the type-checked version of
  the same SQL-first idea.
- **Separate repo** — rejected: schema + pipeline + infra already live here;
  monorepo keeps a schema change and its consumers in one PR.

## Consequences

- Two languages in the repo (Python pipeline + Kotlin backend) until ingestion
  moves — accepted transitional state.
- `db/schema.sql` + `db/views.sql` stop being the change mechanism once Flyway
  owns the schema: they become **generated documentation** of current state, or
  are folded into migrations (decided during ADR 0006 implementation).
- Quarkus LTS cadence (~6 months) sets the upgrade rhythm.
- JVM toolchain (JDK 21) required on dev machine and home server — SDKMAN is
  already in use locally.

## Implementation notes

- `backend/` scaffold: Gradle Kotlin DSL, Quarkus BOM (`enforcedPlatform`),
  extensions: `quarkus-kotlin`, `quarkus-rest-jackson`, `quarkus-jdbc-postgresql`,
  `quarkus-flyway`, `quarkus-smallrye-health`.
- jOOQ: official `org.jooq.jooq-codegen-gradle` plugin; generated Kotlin sources
  in `build/generated-sources/jooq` (not committed — regenerate after each
  migration); `DSLContext` exposed to CDI via a producer over the Agroal
  datasource (`JooqProducer.kt`). Codegen needs a reachable migrated DB
  (home server by default, env-overridable). OSS edition — free for Postgres.
- Kotlin gotcha, documented for future reference: Kotlin classes are **final by
  default** (unlike Java); CDI needs proxyable beans, so the `allopen` compiler
  plugin opens classes annotated with `@Path`/`@ApplicationScoped` etc.
- Config via env vars with local defaults (`application.properties`), pointing at
  the home-server Postgres; secrets stay in git-ignored `.env` (ADR 0003 rule).
- Dev loop: `./gradlew quarkusDev` (live reload; continuous testing available).

## Verification

- `./gradlew quarkusDev` boots; `GET /q/health` returns UP with the Postgres
  connection check green
- Flyway runs at startup against a scratch database and records its history
  (`flyway_schema_history`)
- First real migration lands with ADR 0006 implementation
