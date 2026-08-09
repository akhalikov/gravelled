pluginManagement {
    val quarkusPluginVersion: String by settings
    val kotlinVersion: String by settings
    repositories {
        mavenCentral()
        gradlePluginPortal()
    }
    val jooqVersion: String by settings
    plugins {
        id("io.quarkus") version quarkusPluginVersion
        kotlin("jvm") version kotlinVersion
        kotlin("plugin.allopen") version kotlinVersion
        id("org.jooq.jooq-codegen-gradle") version jooqVersion
    }
}

rootProject.name = "gravelled-backend"
