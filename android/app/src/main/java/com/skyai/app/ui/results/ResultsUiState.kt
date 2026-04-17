package com.skyai.app.ui.results

import com.skyai.app.data.model.FlightOffer
import com.skyai.app.data.model.SearchResponse

enum class SortOption {
    PRICE,
    DURATION,
    BEST_DEAL
}

data class ResultsUiState(
    val response: SearchResponse? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val sortOption: SortOption = SortOption.PRICE
) {
    val sortedOffers: List<FlightOffer>
        get() {
            val offers = response?.offers ?: emptyList()
            return when (sortOption) {
                SortOption.PRICE -> offers.sortedBy { it.price.total }
                SortOption.DURATION -> offers.sortedBy { it.outboundItinerary.totalDurationMinutes }
                SortOption.BEST_DEAL -> offers.sortedByDescending { it.priceIntelligence.percentile }
            }
        }
}
