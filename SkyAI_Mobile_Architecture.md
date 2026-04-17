# SkyAI — Mobile App Architecture

> iOS (Swift/SwiftUI) · Android (Kotlin/Jetpack Compose)  
> Shared backend via REST + WebSocket APIs

---

## 1. Overall Architecture Pattern

SkyAI follows a **clean architecture** with strict layer separation. Both iOS and Android share the same conceptual layers — only the language and framework differ.

```
┌──────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                     │
│     SwiftUI (iOS)  ·  Jetpack Compose (Android)              │
│     ViewModels · UI State · Navigation                        │
└────────────────────────────┬─────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                         DOMAIN LAYER                          │
│     Use Cases · Business Logic · Models · Repository Interfaces│
└────────────────────────────┬─────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                          DATA LAYER                           │
│     API Client · Local DB · Cache · On-Device ML             │
└────────────────────────────┬─────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                      BACKEND / AGENT LAYER                    │
│     REST API · WebSocket (live price updates)                 │
│     Agent Orchestration Backend                               │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Screen Map & Navigation Flow

```
App Launch
   │
   ├── [Not Registered] ──► Onboarding Flow
   │                             ├── Step 1: Personal Profile
   │                             ├── Step 2: Travel Style
   │                             └── Step 3: Memberships
   │                                      │
   └── [Registered] ────────────────────┐ │
                                        ▼ ▼
                                   HOME SCREEN
                              (Personalized Feed)
                                        │
              ┌─────────────────────────┼──────────────────────┐
              ▼                         ▼                       ▼
       SEARCH SCREEN            WATCHLIST SCREEN         PROFILE SCREEN
    (NL input + form)           (Alerts & watches)     (Label + settings)
              │
              ▼
       RESULTS SCREEN
    (Ranked flight cards)
              │
              ▼
       FLIGHT DETAIL SCREEN
    (Full intel + explanation)
              │
              ▼
       BOOKING HANDOFF
    (Deep link → airline / OTA)
```

---

## 3. Screen-by-Screen Specifications

### 3.1 Onboarding Flow

**Design principle:** Fast, friendly, and value-forward. Each step explains why the data helps the user.

#### Step 1 — Personal Profile
```
UI Elements:
  - Full name (text field)
  - Date of birth (date picker — no keyboard, wheel picker)
  - Country of residence (searchable list)
  - Nationality (searchable list)
  - Job category (segmented picker with icons)
  - "Do you travel for work monthly?" (toggle)

Validation:
  - DOB: must be 5–100 years ago
  - Country: required (used for home airport inference)

Value copy shown: "We use this to surface student fares, senior discounts,
and age-appropriate travel suggestions."
```

#### Step 2 — Travel Style
```
UI Elements:
  - Budget attitude: horizontal card selector (4 options with icons)
    [💸 Price First] [⚖️ Balanced] [🛋️ Comfort First] [✨ Luxury]
  - Comfort priorities: draggable reorder list
  - Preferred departure times: multi-select chip row
  - Max layover: slider (0h = Direct only → 12h)
  - "I sometimes need special assistance" toggle

Skip button: visible, no friction
```

#### Step 3 — Memberships
```
UI Elements:
  - Loyalty programs: searchable list with logos
    → Tap to add: [Program name] + [Tier picker] + [Optional: Member ID]
  - Credit cards: card type selector + travel card toggle
  - Alliance preference: 3-button selector

"We'll prioritize flights that earn miles on your programs."
Import option: "Import from Apple Wallet / Google Wallet" (future feature)
```

---

### 3.2 Home Screen (Personalized Feed)

The home screen is fully dynamic — content adapts to the `UserLabelVector`.

```
┌──────────────────────────────────────┐
│  Good morning, Jerry ✈️              │
│  ─────────────────────────────────── │
│  [ Search bar: "Where to next?" ]    │  ← NL search entry point
│                                      │
│  🔥 Prices dropped on your watches  │  ← Price Alert strip
│  Tokyo (NRT) · $842 ↓18%            │
│                                      │
│  ── Based on your profile ────────── │
│                                      │
│  [STEAL] SFO → BKK                  │  ← Personalized deal card
│  $389 roundtrip · Jul 10–20          │
│  Bottom 8% historically · Buy Now   │
│                                      │
│  [📉 FALLING] SFO → LHR             │  ← Trend card
│  $780 and dropping · Set alert?      │
│                                      │
│  ── Cheapest from SFO this month ── │
│  [Bali $512] [Seoul $490] [Tokyo $842]│ ← Horizontal scroll
│                                      │
│  ── Your ANA routes ─────────────── │  ← Loyalty-aware section
│  SFO → NRT · 3 upcoming dates       │
└──────────────────────────────────────┘

Bottom tab bar:
  🏠 Home  |  🔍 Search  |  🔔 Watchlist  |  👤 Profile
```

**Tech:**
- iOS: `LazyVStack` in `ScrollView`, sectioned by feed category
- Android: `LazyColumn` with `items()` by feed section
- Feed data fetched from backend (REST, paginated), personalized per `UserLabelVector`
- Pull-to-refresh + background silent refresh every 30 min

---

### 3.3 Search Screen

Two input modes — seamlessly switchable:

#### Mode A: Natural Language Input
```
┌──────────────────────────────────────┐
│  ← Back                              │
│  ─────────────────────────────────── │
│                                      │
│  💬 "Where do you want to go?"       │
│  ┌────────────────────────────────┐  │
│  │ Cheapest beach in July for me  │  │  ← NL text field
│  │ and my wife                    │  │     (voice mic icon)
│  └────────────────────────────────┘  │
│                                      │
│  Interpreted as:                     │
│  ✈️ SFO → [Bali / Phuket / Cancun]  │  ← Intent display
│  📅 Jul 1–31 (flexible ±5 days)      │
│  👥 2 adults                         │
│  💡 Leisure · Couple                 │
│                                      │
│  Not quite right? Edit below ▼       │
└──────────────────────────────────────┘
```

#### Mode B: Structured Form (below NL input, or tap "Edit")
```
  Origin:         [SFO ×]  ← Airport chip, tappable
  Destination:    [Anywhere ▼] / specific airport
  Dates:          [Jul 10] → [Jul 20]  +  Flexible ±[3] days
  Passengers:     [2 Adults] [0 Children]
  Cabin:          [Economy ▼]
  Trip type:      [Roundtrip] [One-way] [Multi-city]
  Filters:        [Direct only] [My airlines] [Under $X]

  [  🔍  Search Flights  ]   ← Primary CTA
```

**State Management:**
- iOS: `@StateObject SearchViewModel` driving both UI modes
- Android: `SearchViewModel : ViewModel` with `StateFlow<SearchUiState>`
- NL input debounced 800ms → calls Intent Agent API → updates structured fields reactively
- Structured form changes immediately rebuild `SearchIntent`

---

### 3.4 Results Screen

```
┌──────────────────────────────────────┐
│  SFO → Tokyo · Jul 10–20 · 2 Adults  │
│  [Price ▼] [Duration] [Best] [Stops]  │  ← Sort bar
│  Filters: [Direct] [Under $1000] [+]  │
│  ─────────────────────────────────── │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 🔥 STEAL  · ANA NH8            │  │  ← Deal badge
│  │ SFO 10:30 ──────────► NRT 14:55│  │
│  │ Direct · 9h 55m · Boeing 787   │  │
│  │                                │  │
│  │ $842                 BUY NOW ► │  │  ← Action CTA
│  │ ↓19% vs historical avg         │  │
│  │ 🔮 Trending up — price rising  │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ✅ GREAT DEAL  · JAL JL61      │  │
│  │ SFO 13:00 ──────────► NRT 17:20│  │
│  │ Direct · 10h 20m · Boeing 777  │  │
│  │                                │  │
│  │ $909                 BUY NOW ► │  │
│  │ ↓13% vs historical avg         │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ FAIR  · United UA837           │  │
│  │ SFO 08:00 ──► NRT 13:00 +1    │  │
│  │ 1 stop (SFO→LAX→NRT) · 15h    │  │
│  │                                │  │
│  │ $684              📉 Wait →    │  │  ← Different action
│  │ Expected to drop to $610 soon  │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘

Sticky bottom bar:
  "Pareto picks: [Cheapest $684] [Fastest 9h55m] [Best Deal $842]"
```

**Tech:**
- iOS: `LazyVStack` + custom `FlightCard` view
- Android: `LazyColumn` + custom `FlightCardItem` composable
- Results stream in as sources return (not all-or-nothing): cards animate in as each source completes
- Sort is entirely client-side (data already received) — instant re-sort
- Infinite scroll for results > 50 items
- "Skeleton" loading cards shown during initial load

---

### 3.5 Flight Detail Screen

```
┌──────────────────────────────────────┐
│  ← Results           🔔 Watch        │
│  ─────────────────────────────────── │
│  ANA · NH8 · Boeing 787-9            │
│  SFO ────────────────────── NRT      │
│  10:30am              2:55pm (+1)    │
│  Direct · 9h 55m                     │
│                                      │
│  ── Price Intelligence ────────────  │
│  $842 · 🔥 STEAL                     │
│  Cheaper than 81% of historical fares│
│  ████████████░░░ (bar chart position)│
│                                      │
│  Price forecast:                     │
│  Today $842 → +7d $890 → +14d $1,020 │
│  [Trend line mini chart]             │
│                                      │
│  💡 "This is a genuinely rare price. │
│  ANA SFO→NRT averages $1,047. Prices │
│  are rising — we recommend booking   │
│  now to lock in this deal."          │
│                                      │
│  ── Flight Details ────────────────  │
│  Baggage: 23kg included              │
│  Seat selection: Included            │
│  Change fee: $200                    │
│  Refundable: No                      │
│  On-time: 91% (Excellent)            │
│                                      │
│  ── Loyalty ───────────────────────  │
│  Earns: 4,820 ANA miles (Gold +25%)  │
│  Also earns: United MileagePlus      │
│                                      │
│  ── Similar Flights ───────────────  │
│  [JAL $909] [United $684] [+3 more]  │
│                                      │
│  ┌──────────────────────────────┐    │
│  │  Book on ANA.com  →          │    │  ← Primary CTA (deep link)
│  └──────────────────────────────┘    │
│  Also available: Amadeus · Skyscanner│
└──────────────────────────────────────┘
```

---

### 3.6 Watchlist Screen

```
┌──────────────────────────────────────┐
│  Price Watches             + Add     │
│  ─────────────────────────────────── │
│  ┌────────────────────────────────┐  │
│  │ SFO → Tokyo (NRT)              │  │
│  │ Any dates in Jul 2026          │  │
│  │ Current best: $842  🔥 STEAL   │  │
│  │ Alert when: Under $800         │  │
│  │ Predicted low: $788 (Apr 18)   │  │
│  │ [Active] ────────── Edit  Stop │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ SFO → London (LHR)             │  │
│  │ Aug 5–15                       │  │
│  │ Current best: $1,120  FAIR     │  │
│  │ Alert when: Under $950         │  │
│  │ 📉 Trending down · Est. 12 days│  │
│  │ [Active] ────────── Edit  Stop │  │
│  └────────────────────────────────┘  │
│                                      │
│  Past Alerts (last 30 days)          │
│  ✅ Seoul (ICN) hit $490 · Apr 3    │
│  ✅ Bali (DPS) hit $389 · Mar 28   │
└──────────────────────────────────────┘
```

---

### 3.7 Profile Screen

```
┌──────────────────────────────────────┐
│  Your Traveler Profile               │
│  ─────────────────────────────────── │
│                                      │
│  👤  Jerry · Age 28                  │
│  🏠  San Francisco, CA               │
│  💼  Young Professional              │
│                                      │
│  Your Travel Label:                  │
│  ┌────────────────────────────────┐  │
│  │  🌍 YOUNG PROFESSIONAL         │  │
│  │  Budget: Value Seeker          │  │
│  │  Style: Balanced               │  │
│  │  Loyalty: Casual Member        │  │
│  │  Flexibility: Slightly Flexible│  │
│  │                    Edit label  │  │
│  └────────────────────────────────┘  │
│                                      │
│  Airline Memberships (2)             │
│  [ANA Mileage Club · Basic]  [+ Add] │
│                                      │
│  Preferences                         │
│  Departure: Morning / Afternoon      │
│  Max layover: 3 hours                │
│  Avoid: Spirit Airlines              │
│                                      │
│  ── Privacy & Data ───────────────── │
│  Personalization data:  On-device ✓  │
│  Cloud sync:            Off          │
│  [Reset all personalization data]    │
│  [Export my data]                    │
│                                      │
│  App version 1.0.0                   │
└──────────────────────────────────────┘
```

---

## 4. Technical Stack

### 4.1 iOS

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI (iOS 17+) |
| Architecture | MVVM + Clean Architecture |
| State management | `@StateObject`, `@ObservableObject`, Combine |
| Navigation | SwiftUI NavigationStack (type-safe routing) |
| Networking | URLSession + async/await + custom API client |
| Local DB | SwiftData (iOS 17+) for user profile + watch list |
| On-device ML | CoreML (price classifier model) + Create ML |
| NLP (basic) | NaturalLanguage framework (NER for cities/dates) |
| Push notifications | APNs via UNUserNotificationCenter |
| Background refresh | BGAppRefreshTask (price watch polling) |
| Keychain | Security framework (loyalty member IDs) |
| Analytics | Amplitude SDK (no PII events) |
| Crash reporting | Firebase Crashlytics |

### 4.2 Android

| Layer | Technology |
|---|---|
| UI Framework | Jetpack Compose (Material 3) |
| Architecture | MVVM + Clean Architecture (per Google guidelines) |
| State management | `ViewModel` + `StateFlow` + `collectAsStateWithLifecycle` |
| Navigation | Compose Navigation (type-safe, Kotlin serialization) |
| Networking | Retrofit 2 + OkHttp + Kotlin Coroutines |
| Local DB | Room (user profile, watchlist, cache) |
| On-device ML | TensorFlow Lite (price classifier) + ML Kit (NER) |
| Push notifications | FCM (Firebase Cloud Messaging) |
| Background work | WorkManager (price watch polling) |
| Secure storage | Android Keystore (loyalty IDs) + EncryptedSharedPreferences |
| Dependency injection | Hilt |
| Analytics | Amplitude SDK |
| Crash reporting | Firebase Crashlytics |

---

## 5. Backend API Design

### 5.1 Core REST Endpoints

```
Authentication:
  POST   /auth/register         → create account, return JWT
  POST   /auth/login
  POST   /auth/refresh

Profile:
  GET    /profile               → fetch UserProfile
  PUT    /profile               → update UserProfile
  GET    /profile/label         → get current UserLabelVector
  DELETE /profile/personalization → reset all learned data

Search:
  POST   /search/intent         → parse NL query → SearchIntent
  POST   /search/flights        → submit SearchIntent → jobId (async)
  GET    /search/{jobId}/status → poll: pending / partial / complete
  GET    /search/{jobId}/results → paginated FlightPool[]

Watchlist:
  GET    /watches               → list user's price watches
  POST   /watches               → create watch
  PUT    /watches/{id}          → update alert threshold
  DELETE /watches/{id}          → stop watch

Home Feed:
  GET    /feed                  → personalized recommendation feed

Analytics (internal, anonymized):
  POST   /events                → log user interaction events (for bandit)
```

### 5.2 WebSocket: Live Price Updates

When a search is in progress or a detail screen is open, the app maintains a WebSocket connection for real-time streaming:

```
WebSocket: wss://api.skyai.app/ws

Events pushed from server → client:
  source_result_ready   → new source has returned results (partial stream)
  price_updated         → price changed for a watched/viewed flight
  watch_triggered       → price alert threshold hit → push notification
  forecast_updated      → new forecast computed for viewed flight

Events pushed from client → server:
  flight_viewed         → user opened flight detail (for bandit signal)
  flight_clicked        → user tapped a result card
  flight_dismissed      → user swiped away a result
  search_abandoned      → user left results screen without clicking
```

---

## 6. On-Device ML Inference Flow

```
Server (weekly) ──► Export XGBoost model to CoreML / TFLite
                         │
                    Background download
                    (only on WiFi, silent)
                         │
                    App update check:
                    model version in /profile/ml-config
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
       iOS CoreML model         Android TFLite model
       stored in Documents/     stored in internal storage
             │                       │
             └───────────┬───────────┘
                         ▼
              Results screen loads →
              For each flight card:
              1. Build feature vector (from flight data + route stats)
              2. Run inference: model.prediction(features)
              3. Get label + confidence (<5ms)
              4. Render badge on flight card (STEAL / GREAT DEAL / etc.)
```

**Why on-device?**
- Zero latency for classification (no network round-trip)
- Works offline
- User's flight search data never leaves the device for ML purposes
- Models are general (not user-specific), so no privacy concern in model itself

---

## 7. Key UX Principles

**1. Progressive disclosure** — simple by default, detail on demand. The card shows the badge and price. Tap for the full intelligence breakdown.

**2. Confidence transparency** — if model confidence is low (<0.65), show a softer badge: "Possibly a deal" vs. "STEAL". Never overclaim.

**3. Explanation always available** — every recommendation has a "Why?" tap target that expands the plain-language explanation.

**4. Non-blocking search** — results stream in source by source. Users see ANA results in 2 seconds rather than waiting 8 seconds for all sources. Cards animate in as they arrive.

**5. Friction-free alerts** — one-tap to set a watch from any result card. No form, no threshold entry needed initially (we set a smart default threshold from the forecast).

**6. Privacy-first UI** — the Profile screen clearly shows what's stored where. Reset is one tap. Users never feel surveilled.

---

*Document version: 1.0 — Generated April 2026*
