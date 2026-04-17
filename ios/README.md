# SkyAI iOS App - Production-Ready SwiftUI Implementation

A complete, production-quality iOS flight search app built with SwiftUI, async/await, and modern Swift patterns.

## File Structure

```
SkyAI/
├── Models/
│   └── Flight.swift              # All Codable data models matching backend
├── Services/
│   └── APIClient.swift           # Actor-based async API client
├── ViewModels/
│   ├── SearchViewModel.swift     # Search + intent parsing logic
│   └── ResultsViewModel.swift    # Results + sorting logic
├── Views/
│   ├── SearchView.swift          # Natural language search UI
│   ├── ResultsView.swift         # Results list with filters
│   ├── FlightCardView.swift      # Flight card component
│   ├── FlightDetailView.swift    # Flight detail page
│   └── ContentView.swift         # Tab bar root
└── SkyAIApp.swift                # App entry point
```

## Core Models

### SearchRequest
- `originCode`, `destinationCode` (airport codes)
- `departureDate`, `returnDate` (Date objects)
- `adults`, `children`, `infants` (passenger counts)
- `cabinClass` (economy, premiumEconomy, business, first)
- `tripType` (roundtrip, oneWay, multiCity)
- `directFlightsOnly`, `maxStops` (optional filters)
- Defaults: tomorrow departure, +30 days return, 1 adult, economy roundtrip

### FlightOffer (Main Result Object)
- `id`, `outbound` (Itinerary), `inbound` (Itinerary?)
- `priceBreakdown`, `baggageInfo`, `fareConditions`
- `priceIntelligence` (label, trend, recommendation, percentile)
- `bookingUrl`, `availableSeats`

### Enums with Display Names
- `CabinClass`, `TripType`, `PriceLabel`, `PriceTrend`, `ActionType`
- All have `.displayName` computed properties

## Key Features

### Search Screen
- Large text input: "Where do you want to go?"
- Live interpretation display (animates in)
- Collapsible structured form with all filters
- Airport code inputs (auto-uppercase)
- Date pickers for departure/return
- Passenger stepper (1-9 adults)
- Cabin class picker
- Direct flights toggle
- Smart return date handling (auto-sets for roundtrip)

### Intent Parsing
- Natural language query → API call to `/search/intent`
- Returns `IntentResponse` with parsed `SearchRequest`
- Shows interpretation text below query
- Confidence score available
- Loading spinner during parse

### Results View
- **Sort Options**: Price | Duration | Best Deal (segmented picker)
- **Loading**: 5 skeleton cards with shimmer animation
- **Error**: Retry button with error message
- **Empty**: "No flights found" placeholder
- **Pareto Bar** (sticky bottom):
  - Cheapest price shortcut
  - Fastest duration shortcut
  - Best deal recommendation
  - Colored chips with icons

### Flight Cards
- Deal badge (STEAL=orange, GREAT DEAL=green, FAIR=gray, etc.)
- Airline code + flight number
- Route visualization with times and stops
- Total duration and stop count
- Large price display
- Savings amount/percent if available
- Action button: "Buy Now" (green) or "Watch" (orange) based on recommendation
- Tap to view full details

### Flight Detail Page
- Full route breakdown with all segments
- Price intelligence section
  - Deal badge
  - Percentile rank bar (visual 0-100)
  - Price trend with icon (↑↓−shuffle)
  - Savings amount if applicable
  - Recommendation with icon + explanation
- Fare conditions
  - Refundable/changeable status
  - Baggage info
  - Available seats
  - On-time rate (placeholder)
- "Book on Airline" primary button
- "Set Price Alert" secondary button

### Navigation
- `NavigationStack` with `.navigationDestination` for type-safe navigation
- SearchRequest passed as state through navigation
- Back buttons properly handled with `@Environment(\.dismiss)`

## API Integration

### Endpoints

**POST /search/intent**
```json
Request: { "query": "flights from SFO to Tokyo next month" }
Response: {
  "search_request": { ... },
  "interpretation": "Round-trip flights from San Francisco to Tokyo, departing in one month",
  "confidence": 0.95
}
```

**POST /search/flights**
```json
Request: SearchRequest { ... }
Response: { "offers": [FlightOffer, ...], "currency": "USD", "search_timestamp": "2026-04-13T..." }
```

### APIClient Features
- **Actor-based** for thread-safe operations
- **Async/await** throughout (no completion handlers)
- **Automatic snake_case conversion** via JSONEncoder/Decoder keyEncodingStrategy
- **ISO8601 date handling**
- **Error types**: `networkError`, `decodingError`, `serverError(String)`
- **30s request timeout, 60s resource timeout**
- Configurable base URL (default: http://localhost:8000)

## Design System

### Colors
- **Primary**: Deep blue `#1A3C6B` (rgb(26, 60, 107))
- **Accent**: Orange `#FF6B35` (rgb(255, 107, 53))
- **Price Badges**:
  - STEAL: Orange
  - GREAT DEAL: Green
  - FAIR: Gray
  - EXPENSIVE: Amber
  - OVERPRICED: Red

### Components
- Cards: white background, `cornerRadius: 16`, `shadow(radius: 4, y: 2)`
- Badges: capsule shape, colored backgrounds
- Input fields: `.textFieldStyle(.roundedBorder)`
- Dividers: subtle color separation

### Typography
- Headlines: `.system(size: 32, weight: .bold)` or `.system(size: 28, weight: .bold)`
- Section headers: `.system(size: 16, weight: .semibold)`
- Body text: `.system(size: 14)` default
- Small labels: `.system(size: 12, weight: .semibold)`
- Prices: `.system(size: 24, weight: .bold)`

## ViewModels

### SearchViewModel
- `@Published` properties: `naturalQuery`, `searchRequest`, `interpretation`, `isParsingIntent`, `intentError`, `showStructuredForm`, `shouldNavigateToResults`
- `parseIntent()` → calls APIClient, updates request + interpretation
- `search()` → routes to parseIntent or uses structured form
- Input validation
- Form state management

### ResultsViewModel
- `@Published` properties: `offers`, `isLoading`, `errorMessage`, `sortOption`
- `sortedOffers` computed property (applies current sort)
- `load(request:)` → fetches flights via APIClient
- `sort(by:)` → updates sort option and re-sorts
- `retry(request:)` → re-fetches on error

## State Management
- ViewModels use `@StateObject` in views
- `@Published` properties trigger SwiftUI updates
- Navigation state via `NavigationStack` + `@State var navigationPath`
- Form state directly on `searchRequest` binding

## Loading States
- **Skeleton cards**: Gray rectangles with shimmer animation
- **Shimmer modifier**: Repeating opacity animation
- **Error screen**: Icon + message + retry button
- **Empty state**: Icon + "No flights found" message

## Data Flow

1. **Search**: User enters query or fills form
2. **Intent Parse** (if natural language):
   - SearchView calls `viewModel.parseIntent()`
   - APIClient → POST /search/intent
   - Update SearchRequest and show interpretation
3. **Navigate**: `shouldNavigateToResults = true` triggers NavigationStack
4. **Load Results**: ResultsView calls `viewModel.load(request:)`
   - APIClient → POST /search/flights
   - Parse JSON (snake_case → camelCase)
   - Display offers with default sort (price)
5. **Sort/Filter**: User changes sort option, `sortedOffers` recomputes
6. **Detail View**: Tap card → NavigationStack navigates to FlightDetailView
7. **Back Navigation**: Dismiss via `@Environment(\.dismiss)`

## Testing Considerations

### Mock API Responses
The APIClient is easily testable:
- Create mock `SearchResponse` objects
- Use dependency injection to swap out APIClient for tests
- Mock `IntentResponse` with various confidence levels

### Preview Providers
All views have `#Preview` blocks with sample data:
- FlightCardView: Complete offer with savings
- FlightDetailView: Full detail with all fields
- SearchView, ResultsView: Default empty states

## Performance Notes

- Skeleton loading cards use simple opacity animation (efficient)
- LazyVStack in results (only renders visible cards)
- Computed `sortedOffers` property (sorts only when sort option changes)
- Actor-based APIClient prevents race conditions
- ISO8601 date strategy avoids custom formatters

## Extending the App

### Adding Filters
- Add properties to SearchRequest
- Update StructuredFormView with new inputs
- FilterManager in ViewModels

### Persistence
- Add @AppStorage for user preferences
- Core Data for saved flights/watchlist
- UserDefaults for simple settings

### Notifications
- Add background task for price alerts
- Use UserNotifications framework
- APNs for server-sent alerts

### Maps
- MapKit for airport visualization
- Route visualization between cities

## Requirements
- iOS 17+
- Swift 5.9+
- Xcode 15+

## No External Dependencies
- SwiftUI handles all UI
- Foundation handles networking
- No CocoaPods or SPM packages required
