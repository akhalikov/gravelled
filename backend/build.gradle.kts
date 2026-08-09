plugins {
    kotlin("jvm")
    // Kotlin classes are FINAL by default (in Java you'd have to write `final class`).
    // CDI/Quarkus needs to subclass beans to proxy them, so this compiler plugin
    // "opens" classes carrying the annotations listed in the allOpen block below.
    kotlin("plugin.allopen")
    id("io.quarkus")
    // jOOQ code generation: reads the live DB schema, emits typed query classes.
    // Workflow: Flyway migrates → `./gradlew jooqCodegen` → compiler catches
    // every query the schema change broke.
    id("org.jooq.jooq-codegen-gradle")
}

repositories {
    mavenCentral()
}

val quarkusPlatformGroupId: String by project
val quarkusPlatformArtifactId: String by project
val quarkusPlatformVersion: String by project

dependencies {
    // BOM: pins versions of all Quarkus extensions (like a Maven parent POM)
    implementation(enforcedPlatform("$quarkusPlatformGroupId:$quarkusPlatformArtifactId:$quarkusPlatformVersion"))

    implementation("io.quarkus:quarkus-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")

    // REST with Jackson JSON (JAX-RS annotations — familiar from Java EE / MicroProfile)
    implementation("io.quarkus:quarkus-rest-jackson")

    // Postgres + Flyway migrations
    implementation("io.quarkus:quarkus-jdbc-postgresql")
    implementation("io.quarkus:quarkus-flyway")

    // /q/health endpoints (readiness includes a DB connection check)
    implementation("io.quarkus:quarkus-smallrye-health")

    // jOOQ runtime (not managed by the Quarkus BOM — version pinned explicitly)
    val jooqVersion: String by project
    implementation("org.jooq:jooq:$jooqVersion")
    // JDBC driver for the code generator itself
    jooqCodegen("org.postgresql:postgresql:42.7.4")

    testImplementation("io.quarkus:quarkus-junit5")
    testImplementation("io.rest-assured:rest-assured")
}

// --- jOOQ code generation ----------------------------------------------------
// Needs a reachable, migrated database (home server by default; override via env).
// Generated sources land in build/ (not committed) — regenerate after migrations.
jooq {
    configuration {
        jdbc {
            driver = "org.postgresql.Driver"
            url = System.getenv("DB_JDBC_URL") ?: "jdbc:postgresql://192.168.1.9:5432/gravelled"
            user = System.getenv("DB_USER") ?: "gravelled"
            password = System.getenv("DB_PASSWORD") ?: ""
        }
        generator {
            // KotlinGenerator: generated records are Kotlin, with nullability
            // taken from the schema — NOT NULL columns become non-null types.
            name = "org.jooq.codegen.KotlinGenerator"
            database {
                name = "org.jooq.meta.postgres.PostgresDatabase"
                inputSchema = "public"
                excludes = "flyway_schema_history"
            }
            target {
                packageName = "gravelled.jooq"
                directory = "build/generated-sources/jooq"
            }
        }
    }
}

sourceSets["main"].kotlin.srcDir("build/generated-sources/jooq")

group = "gravelled"
version = "0.1.0-SNAPSHOT"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

allOpen {
    annotation("jakarta.ws.rs.Path")
    annotation("jakarta.enterprise.context.ApplicationScoped")
    annotation("jakarta.persistence.Entity")
    annotation("io.quarkus.test.junit.QuarkusTest")
}

kotlin {
    compilerOptions {
        // emit method parameter names into bytecode — Jakarta REST relies on this
        javaParameters.set(true)
    }
}

tasks.withType<Test> {
    systemProperty("java.util.logging.manager", "org.jboss.logmanager.LogManager")
}
