package gravelled.api

import jakarta.ws.rs.GET
import jakarta.ws.rs.Path
import jakarta.ws.rs.Produces
import jakarta.ws.rs.core.MediaType

/**
 * Smoke-test endpoint: GET /api/ping
 *
 * Kotlin notes for Java eyes:
 *  - `data class` generates equals/hashCode/toString/copy — no Lombok needed.
 *  - Constructor parameters declared with `val` become immutable properties
 *    (field + getter in one token).
 *  - No `public` keyword: public is the default visibility in Kotlin.
 *  - The class body `{}` can be omitted entirely when it's empty.
 */
data class Pong(val status: String, val app: String, val version: String)

@Path("/api/ping")
class PingResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    // Single-expression function: `= expr` replaces `{ return expr; }`.
    // The return type (Pong) is inferred — you may still write it explicitly.
    fun ping() = Pong(status = "ok", app = "gravelled-backend", version = "0.1.0")
}
