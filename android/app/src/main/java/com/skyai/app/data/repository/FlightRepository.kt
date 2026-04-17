package com.skyai.app.data.repository

import com.skyai.app.data.api.SkyAIApiService
import com.skyai.app.data.model.IntentRequest
import com.skyai.app.data.model.IntentResponse
import com.skyai.app.data.model.SearchRequest
import com.skyai.app.data.model.SearchResponse
import dagger.hilt.android.scopes.ViewModelScoped
import javax.inject.Inject

@ViewModelScoped
class FlightRepository @Inject constructor(
    private val apiService: SkyAIApiService
) {

    suspend fun parseIntent(query: String): Result<IntentResponse> {
        return try {
            val response = apiService.parseIntent(IntentRequest(query))
            Result.success(response)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun searchFlights(request: SearchRequest): Result<SearchResponse> {
        return try {
            val response = apiService.searchFlights(request)
            Result.success(response)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
