package com.skyai.app.data.repository

import com.skyai.app.data.model.FlightOffer
import com.skyai.app.data.model.SearchResponse

/**
 * In-memory holder for the most recent search response and the offers it
 * contains. Used so navigation between Search → Results → Detail can pass
 * a tiny ID through the route string instead of the full payload.
 *
 * Why: Android's NavController routes are URI strings stored in a Bundle.
 * For a 50-offer SearchResponse the JSON is ~68 KB and the URL-encoded
 * variant is ~100 KB. `navigate()` silently fails on payloads of that
 * size — the destination composable mounts but its arguments parse to
 * null, so the screen renders blank. Keeping the data here and routing
 * by `query_id` / `offer_id` sidesteps the limit entirely.
 *
 * This is process-scoped state, intentionally simple. If the process dies
 * mid-flow (configuration change kills the singleton on some launchers),
 * the user just re-runs the search — same UX as a back button.
 */
object SearchResultsCache {

    private var latest: SearchResponse? = null
    private val offersById: MutableMap<String, FlightOffer> = mutableMapOf()

    /** Replace the cached response and reindex its offers by id. */
    fun put(response: SearchResponse) {
        latest = response
        offersById.clear()
        response.offers.forEach { offersById[it.offerId] = it }
    }

    /** Return the most recent response if its query_id matches. */
    fun get(queryId: String): SearchResponse? =
        latest?.takeIf { it.queryId == queryId }

    /** Look up a single offer from the most recent response by offer_id. */
    fun getOffer(offerId: String): FlightOffer? = offersById[offerId]

    /** Optional clear — useful in tests or "start fresh" affordances. */
    fun clear() {
        latest = null
        offersById.clear()
    }
}
