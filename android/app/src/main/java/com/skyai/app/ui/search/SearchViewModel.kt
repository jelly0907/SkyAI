package com.skyai.app.ui.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.skyai.app.data.model.CabinClass
import com.skyai.app.data.model.SearchRequest
import com.skyai.app.data.model.TripType
import com.skyai.app.data.repository.FlightRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SearchViewModel @Inject constructor(
    private val repository: FlightRepository
) : ViewModel() {

    private val _formState = MutableStateFlow(SearchFormState())
    val formState: StateFlow<SearchFormState> = _formState.asStateFlow()

    private val _intentParseState = MutableStateFlow<IntentParseState>(IntentParseState.Idle)
    val intentParseState: StateFlow<IntentParseState> = _intentParseState.asStateFlow()

    private val _searchState = MutableStateFlow<SearchState>(SearchState.Idle)
    val searchState: StateFlow<SearchState> = _searchState.asStateFlow()

    fun onQueryChanged(query: String) {
        _formState.update { it.copy(query = query) }
    }

    fun parseIntent() {
        val query = _formState.value.query
        if (query.isBlank()) {
            _intentParseState.update { IntentParseState.Error("Please enter a search query") }
            return
        }

        viewModelScope.launch {
            _intentParseState.update { IntentParseState.Loading }
            val result = repository.parseIntent(query)
            result.onSuccess { response ->
                _formState.update { currentState ->
                    currentState.copy(
                        origin = response.parsedRequest.origin,
                        destination = response.parsedRequest.destination,
                        departureDate = response.parsedRequest.departureDate,
                        returnDate = response.parsedRequest.returnDate ?: "",
                        adults = response.parsedRequest.adults,
                        children = response.parsedRequest.children,
                        infants = response.parsedRequest.infants,
                        cabinClass = response.parsedRequest.cabinClass,
                        directOnly = response.parsedRequest.directOnly,
                        tripType = response.parsedRequest.tripType
                    )
                }
                _intentParseState.update { IntentParseState.Success(response) }
            }
            result.onFailure { error ->
                _intentParseState.update { IntentParseState.Error(error.message ?: "Unknown error") }
            }
        }
    }

    fun searchFlights() {
        val state = _formState.value
        if (state.origin.isBlank() || state.destination.isBlank() || state.departureDate.isBlank()) {
            _searchState.update { SearchState.Error("Please fill in all required fields") }
            return
        }

        val searchRequest = SearchRequest(
            origin = state.origin,
            destination = state.destination,
            departureDate = state.departureDate,
            returnDate = state.returnDate.takeIf { it.isNotBlank() },
            adults = state.adults,
            children = state.children,
            infants = state.infants,
            cabinClass = state.cabinClass,
            directOnly = state.directOnly,
            tripType = state.tripType
        )

        viewModelScope.launch {
            _searchState.update { SearchState.Loading }
            val result = repository.searchFlights(searchRequest)
            result.onSuccess { response ->
                _searchState.update { SearchState.Success(response) }
            }
            result.onFailure { error ->
                _searchState.update { SearchState.Error(error.message ?: "Unknown error") }
            }
        }
    }

    fun updateOrigin(origin: String) {
        _formState.update { it.copy(origin = origin) }
    }

    fun updateDestination(destination: String) {
        _formState.update { it.copy(destination = destination) }
    }

    fun updateDepartureDate(date: String) {
        _formState.update { it.copy(departureDate = date) }
    }

    fun updateReturnDate(date: String) {
        _formState.update { it.copy(returnDate = date) }
    }

    fun updateAdults(count: Int) {
        _formState.update { it.copy(adults = count.coerceIn(1, 9)) }
    }

    fun updateChildren(count: Int) {
        _formState.update { it.copy(children = count.coerceIn(0, 9)) }
    }

    fun updateInfants(count: Int) {
        _formState.update { it.copy(infants = count.coerceIn(0, 9)) }
    }

    fun updateCabinClass(cabinClass: CabinClass) {
        _formState.update { it.copy(cabinClass = cabinClass) }
    }

    fun updateDirectOnly(directOnly: Boolean) {
        _formState.update { it.copy(directOnly = directOnly) }
    }

    fun updateTripType(tripType: TripType) {
        _formState.update { it.copy(tripType = tripType) }
    }

    fun toggleStructuredForm() {
        _formState.update { it.copy(showStructuredForm = !it.showStructuredForm) }
    }

    fun clearIntent() {
        _intentParseState.update { IntentParseState.Idle }
    }
}
