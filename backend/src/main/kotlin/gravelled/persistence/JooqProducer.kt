package gravelled.persistence

import io.agroal.api.AgroalDataSource
import jakarta.enterprise.context.ApplicationScoped
import jakarta.enterprise.inject.Produces
import org.jooq.DSLContext
import org.jooq.SQLDialect
import org.jooq.impl.DSL

/**
 * Bridges Quarkus's managed datasource (Agroal pool) to jOOQ.
 *
 * Java comparison: this is a plain CDI producer — the same @Produces you'd
 * write in Java EE. Inject `DSLContext` anywhere and query with the typed DSL:
 *
 *     @ApplicationScoped
 *     class ActivityRepo(private val dsl: DSLContext) {   // constructor injection,
 *         fun count() = dsl.fetchCount(ACTIVITIES)        // no @Inject needed for
 *     }                                                   // a single constructor
 */
@ApplicationScoped
class JooqProducer {

    @Produces
    @ApplicationScoped
    fun dsl(dataSource: AgroalDataSource): DSLContext =
        DSL.using(dataSource, SQLDialect.POSTGRES)
}
