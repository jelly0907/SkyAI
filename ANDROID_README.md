# SkyAI Android App - Production Quality Kotlin/Jetpack Compose Implementation

A complete, production-quality Android flight search application built with Kotlin, Jetpack Compose, and MVVM Clean Architecture.

## Project Overview

**SkyAI** is a multi-agent flight finder app that connects to a FastAPI backend running at `http://10.0.2.2:8000` (Android emulator localhost alias).

### Key Features
- Natural language flight search parsing via AI backend
- Comprehensive flight search with multiple parameters (dates, passengers, cabin class, etc.)
- Rich flight results with sorting by price, duration, and best deal
- Detailed flight information with price intelligence and forecasting
- Material Design 3 UI throughout
- Full MVVM + Clean Architecture implementation
- Hilt dependency injection
- Jetpack Compose for all UI
- Type-safe navigation with Compose Navigation

## Architecture

```
com.skyai.app/
├── data/
│   ├── api/
│   │   ├── SkyAIApiService.kt       (Retrofit interface)
│   │   └── RetrofitClient.kt        (Hilt DI module)
│   ├── model/
│   │   └── Flight.kt                (Data classes + enums)
│   └── repository/
│       └── FlightRepository.kt       (API wrapper with Result)
├── ui/
│   ├── components/
│   │   ├── FlightCard.kt            (Reusable flight offer card)
│   │   └── ParetoBar.kt             (Bottom shortcut bar)
│   ├── detail/
│   │   └── FlightDetailScreen.kt    (Flight details with price intelligence)
│   ├── results/
│   │   ├── ResultsScreen.kt         (Flight list with sorting)
│   │   ├── ResultsUiState.kt        (UI state + sorting logic)
│   │   └── ResultsViewModel.kt      (Results state management)
│   ├── search/
│   │   ├── SearchScreen.kt          (Main search UI with form)
│   │   ├── SearchUiState.kt         (UI state sealed classes)
│   │   └── SearchViewModel.kt       (Search logic + parsing)
│   └── theme/
│       └── Theme.kt                 (Material 3 theme + typography)
├── MainActivity.kt                  (Compose navigation host)
└── SkyAIApplication.kt             (Hilt application class)
```

## File Manifest

### Gradle Build Files
- **build.gradle.kts** (project-level) - Plugin declarations, Kotlin 1.9+, Hilt plugin
- **app/build.gradle.kts** - All dependencies: Compose BOM, Retrofit, OkHttp, Hilt, Coroutines
- **settings.gradle.kts** - Repository configuration

### Data Layer
- **Flight.kt** - All data models with @SerializedName annotations:
  - Enums: `CabinClass`, `TripType`, `PriceLabel`, `PriceTrend`, `ActionType`
  - Request/Response: `IntentRequest`, `IntentResponse`, `SearchRequest`, `SearchResponse`
  - Flight details: `Segment`, `Itinerary`, `PriceBreakdown`, `BaggageInfo`, `FareConditions`, `PriceIntelligence`, `FlightOffer`
- **SkyAIApiService.kt** - Retrofit interface with 2 endpoints:
  - `POST /search/intent` - Parse natural language query
  - `POST /search/flights` - Execute flight search
- **RetrofitClient.kt** - Hilt @Module providing:
  - `Gson` instance (lenient)
  - `OkHttpClient` with HttpLoggingInterceptor
  - `Retrofit` with base URL `http://10.0.2.2:8000/`
  - `SkyAIApiService` singleton
- **FlightRepository.kt** - @ViewModelScoped repository wrapping API calls in Result<T>

### UI Layer - Search
- **SearchUiState.kt** - Sealed classes:
  - `SearchFormState` - All form fields (origin, destination, dates, passengers, etc.)
  - `IntentParseState` - Idle | Loading | Success | Error
  - `SearchState` - Idle | Loading | Success | Error
- **SearchViewModel.kt** - @HiltViewModel with:
  - State flows for form, intent parsing, and search
  - `parseIntent()` - Calls API and populates form
  - `searchFlights()` - Creates SearchRequest and searches
  - Update functions for all form fields
- **SearchScreen.kt** - Complete search UI:
  - Large query TextField with microphone icon
  - Interpretation card (animated slide-in when parsed)
  - Collapsible structured form with DatePickers
  - Passenger counter rows
  - Cabin class dropdown
  - Direct only toggle
  - Roundtrip/One-way tabs
  - Search button with loading indicator
  - Error/empty states

### UI Layer - Results
- **ResultsUiState.kt** - State class with:
  - `SortOption` enum: PRICE, DURATION, BEST_DEAL
  - Computed `sortedOffers` property based on sort option
- **ResultsViewModel.kt** - @HiltViewModel with:
  - `loadResults()` - Load search response
  - `setSortOption()` - Change sort order
  - `retry()` - Retry failed searches
- **ResultsScreen.kt** - Flight list UI:
  - Top bar showing route and date
  - Sort chips (Price, Duration, Best Deal)
  - Lazy list of FlightCard components
  - Loading state with 5 skeleton shimmer cards
  - Error state with retry button
  - Empty state with centered message
  - Sticky Pareto bottom bar with cheapest/fastest/best deal shortcuts

### UI Layer - Components
- **FlightCard.kt** - Reusable flight offer card:
  - Badge: STEAL (red) | GREAT_DEAL (green) | FAIR (gray)
  - Airline + flight number header
  - Route with visual connection (dots for stops)
  - Duration + stops info
  - Large price display
  - "Cheaper than X%" intelligence text
  - Smart action buttons based on `ActionType`:
    - BUY_NOW → Green "Book Now" button
    - WAIT → Blue "Watch 📉" button
    - SET_ALERT → Orange "Set Alert 🔔" button
  - Clickable to navigate to detail screen
- **ParetoBar.kt** - Bottom sticky bar:
  - Cheapest price chip with dollar icon
  - Fastest duration chip with timer icon
  - Best deal chip with trending icon
  - FilterChip with leading icons
  - Bottom elevation shadow

### UI Layer - Detail
- **FlightDetailScreen.kt** - Flight details screen:
  - Top bar with back button and title
  - Airline header card (airline name, fare class)
  - Route card showing all segments with times, airports, aircraft
  - Return itinerary card (if roundtrip)
  - Price intelligence card:
    - Large price display with badge
    - Percentile progress bar ("Cheaper than X%")
    - Trend indicator with arrow (up/down/stable)
    - Action reason text
    - Price forecast if available (+7d, +14d predictions)
  - Details card with icons:
    - Baggage info (carry-on + checked bags)
    - Changes allowed/not allowed
    - Refundable yes/no
    - Seats remaining
  - Two bottom buttons: "Book Now" (filled) + "Set Price Alert" (outlined)
  - Full vertical scroll

### Theme & Navigation
- **Theme.kt** - Material 3 theme:
  - Primary: #1A3C6B (deep blue)
  - Secondary: #FF6B35 (orange for badges)
  - Surface: #F8F9FA
  - Custom SkyAITypography with all Material 3 text styles
  - Light + dark color schemes
  - `SkyAITheme()` composable
- **MainActivity.kt** - @AndroidEntryPoint activity:
  - Sets content with SkyAITheme
  - NavHost with 3 routes:
    - "search" → SearchScreen
    - "results/{requestJson}" → ResultsScreen (deserialize SearchResponse from JSON)
    - "detail/{offerJson}" → FlightDetailScreen (deserialize FlightOffer from JSON)
  - Navigation arg decoding with URLDecoder
- **SkyAIApplication.kt** - @HiltAndroidApp application class

### Android Manifest & Resources
- **AndroidManifest.xml**:
  - INTERNET permission
  - MainActivity as launcher
  - SkyAIApplication declared
  - Standard Compose setup
- **strings.xml** - All UI strings
- **themes.xml** - AppTheme reference
- **backup_rules.xml** - Backup configuration
- **data_extraction_rules.xml** - Data extraction rules
- **proguard-rules.pro** - ProGuard rules for Retrofit, Gson, Hilt, etc.

## Dependencies

### Build
- Kotlin 1.9.22
- Android Gradle Plugin 8.2.0
- Kotlin Kapt 1.9.22
- Hilt 2.48

### Jetpack Compose
- Compose BOM 2024.04.01
- compose-ui, compose-material3, compose-navigation
- lifecycle-viewmodel-compose, activity-compose
- hilt-navigation-compose

### Networking
- Retrofit 2.10.0
- OkHttp 4.11.0 (with logging interceptor)
- Gson 2.10.1

### State Management
- Coroutines 1.7.3
- Core KTX 1.12.0

### Compatibility
- minSdk 26
- targetSdk 34
- compileSdk 34

## Backend Integration

### API Base URL
```
http://10.0.2.2:8000/
```
(10.0.2.2 is the special hostname in Android emulator that maps to the host machine's localhost)

### Endpoints

#### 1. POST /search/intent
**Request:**
```json
{
  "query": "flights from SFO to NRT on July 15 for 2 adults"
}
```

**Response:**
```json
{
  "parsed_request": { SearchRequest },
  "interpretation": "Round-trip flight search...",
  "confidence": 0.95
}
```

#### 2. POST /search/flights
**Request:**
```json
{
  "origin": "SFO",
  "destination": "NRT",
  "departure_date": "2024-07-15",
  "return_date": "2024-07-22",
  "adults": 2,
  "children": 0,
  "infants": 0,
  "cabin_class": "economy",
  "direct_only": false,
  "trip_type": "roundtrip"
}
```

**Response:**
```json
{
  "search_id": "...",
  "origin": "SFO",
  "destination": "NRT",
  "departure_date": "2024-07-15",
  "return_date": "2024-07-22",
  "offers": [ FlightOffer[] ],
  "search_completed_at": "2024-04-13T10:30:00Z",
  "currency": "USD"
}
```

## Running the App

### Prerequisites
1. Android Studio with SDK 34
2. FastAPI backend running on localhost:8000
3. Android emulator (API level 26+)

### Build & Run
```bash
cd android
./gradlew build
./gradlew installDebug  # or run from Android Studio
```

### Debug Mode
- OkHttp logging is enabled in DEBUG builds
- Check Logcat for HTTP request/response logs
- All errors are wrapped in Result<T> and logged

## Key Design Patterns

### MVVM + Clean Architecture
- **Data Layer** - Repository + API service
- **Presentation Layer** - ViewModels + UI State
- **UI Layer** - Composable functions with state collection

### Dependency Injection (Hilt)
- @HiltAndroidApp on Application
- @AndroidEntryPoint on MainActivity
- @HiltViewModel on all ViewModels
- @Module @Provides for Retrofit/OkHttp

### State Management
- StateFlow for reactive updates
- Sealed classes for state variants
- viewModelScope for lifecycle-aware coroutines
- LaunchedEffect(Unit) for initial loading

### Navigation
- Compose Navigation with NavHost
- Type-safe routes (string concatenation with URL encoding)
- JSON serialization for complex data passing between screens
- Graceful fallback if deserialization fails

### Error Handling
- Result<T> wrapper in repository
- Try/catch in API calls
- Sealed state classes for UI feedback
- User-friendly error messages

## Data Serialization

All data classes use `@SerializedName` for snake_case JSON mapping:
```kotlin
@SerializedName("cabin_class")
val cabinClass: CabinClass
```

Gson is configured with `.setLenient()` to handle slightly malformed JSON.

## Material Design 3 Compliance

- All buttons are filled/outlined Material 3 buttons
- Cards use CardDefaults for elevation
- FilterChip for sort options
- ExposedDropdownMenuBox for cabin class
- LinearProgressIndicator for percentile
- Material 3 colors and typography throughout
- Dark theme support with automatic detection

## Testing

- @Preview annotations on all Composables (though would need mock data)
- Modular architecture allows easy unit testing
- Repository can be mocked in ViewModel tests
- Composables can be tested with Compose test framework

## Future Enhancements (Phase 3+)

- Room database for favorites and search history
- Real-time price tracking service
- Push notifications for price alerts
- Google Pay integration for bookings
- Maps integration for routes
- Offline support with cached data
- Advanced filtering (airlines, departure times, etc.)
- User authentication and wishlist
- Flight share functionality
