package com.skyai.app.ui.search

import com.skyai.app.data.model.CabinClass
import com.skyai.app.data.model.IntentResponse
import com.skyai.app.data.model.SearchResponse
import com.skyai.app.data.model.TripType

data class SearchFormState(
    val query: String = "",
    val origin: String = "",
    val destination: String = "",
    val departureDate: String = "",
    val returnDate: String = "",
    val adults: Int = 1,
    val children: Int = 0,
    val infants: Int = 0,
    val cabinClass: CabinClass = CabinClass.ECONOMY,
    // Defaulting to true papers over an unresolved edge case: searches with
    // multi-stop offers in the response sometimes don't render results on
    // Android. Nonstop searches always work end-to-end. Flip back to false
    // once the multi-stop render bug is identified and fixed.
    val directOnly: Boolean = true,
    val tripType: TripType = TripType.ROUNDTRIP,
    val showStructuredForm: Boolean = false
)

sealed class IntentParseState {
    data object Idle : IntentParseState()
    data object Loading : IntentParseState()
    data class Success(val response: IntentResponse) : IntentParseState()
    data class Error(val message: String) : IntentParseState()
}

sealed class SearchState {
    data object Idle : SearchState()
    data object Loading : SearchState()
    data class Success(val response: SearchResponse) : SearchState()
    data class Error(val message: String) : SearchState()
}
