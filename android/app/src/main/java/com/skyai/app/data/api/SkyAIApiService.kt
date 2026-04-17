package com.skyai.app.data.api

import com.skyai.app.data.model.IntentRequest
import com.skyai.app.data.model.IntentResponse
import com.skyai.app.data.model.SearchRequest
import com.skyai.app.data.model.SearchResponse
import retrofit2.http.Body
import retrofit2.http.POST

interface SkyAIApiService {

    @POST("search/intent")
    suspend fun parseIntent(@Body request: IntentRequest): IntentResponse

    @POST("search/flights")
    suspend fun searchFlights(@Body request: SearchRequest): SearchResponse
}
