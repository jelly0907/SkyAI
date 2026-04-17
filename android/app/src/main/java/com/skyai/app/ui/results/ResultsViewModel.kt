package com.skyai.app.ui.results

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.skyai.app.data.model.SearchResponse
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject

@HiltViewModel
class ResultsViewModel @Inject constructor() : ViewModel() {

    private val _uiState = MutableStateFlow(ResultsUiState())
    val uiState: StateFlow<ResultsUiState> = _uiState.asStateFlow()

    fun loadResults(response: SearchResponse) {
        _uiState.update { it.copy(response = response, isLoading = false, error = null) }
    }

    fun setSortOption(option: SortOption) {
        _uiState.update { it.copy(sortOption = option) }
    }

    fun retry() {
        _uiState.update { it.copy(error = null, isLoading = true) }
        // In a real app, would re-call the search endpoint
        _uiState.update { it.copy(isLoading = false) }
    }
}
