# gravelled-backend

Kotlin + Quarkus (3.33 LTS) + Gradle + jOOQ. Owns the DB schema via Flyway
(ADR 0005); v2 schema (ADR 0006) will land as the first migrations.

Persistence workflow: **Flyway migrate → `./gradlew jooqCodegen` → typed queries.**
Generated Kotlin classes land in `build/generated-sources/jooq` (never committed);
after any migration, regenerate and let the compiler find broken queries.

## Prerequisites

- JDK 21 — `sdk install java 21-tem` (SDKMAN already in use on this machine)
- Gradle (once): `sdk install gradle`, then generate the wrapper — see below

## First run

```bash
cd backend
gradle wrapper            # generates ./gradlew — commit the wrapper files
./gradlew quarkusDev      # dev mode: live reload at http://localhost:8080
```

Then:

- `GET http://localhost:8080/api/ping` → `{"status":"ok",...}`
- `GET http://localhost:8080/q/health` → readiness incl. DB check

## Configuration

Defaults point at the home-server Postgres (`192.168.1.9`). Override via env:

| Env var       | Default                                          |
|---------------|--------------------------------------------------|
| `DB_JDBC_URL` | `jdbc:postgresql://192.168.1.9:5432/gravelled`   |
| `DB_USER`     | `gravelled`                                      |
| `DB_PASSWORD` | *(empty — set it)*                               |

No reachable DB while developing? Comment out `quarkus.datasource.jdbc.url` in
`application.properties` and dev mode spins up a throwaway Postgres container
(Dev Services) automatically.

## Kotlin-for-Java crib notes used in this codebase

- `val` = final variable, `var` = mutable; fields+getters come from constructor params
- `data class` ≈ Java record, plus `copy()` and named args
- Classes are **final by default** → the `allopen` plugin opens `@Path`/`@ApplicationScoped`
  beans so CDI can proxy them (see `build.gradle.kts`)
- Single-expression functions: `fun f() = expr`
- No semicolons, no `new`, string templates: `"hello $name"`
