# SkyAI — Multi-Agent Flight Finder: Agent Design Document

> **Target Platforms:** iOS (Swift/SwiftUI) · Android (Kotlin)  
> **Data Sources:** Amadeus API · Skyscanner API · Google Flights · Airline Official Sites  
> **AI Capabilities:** NLP · Multi-Agent Negotiation · Personalization · ML/Statistics · Classification  

---

## 1. System Overview

SkyAI uses a **hierarchical multi-agent architecture** organized in three tiers:

```
┌─────────────────────────────────────────────────┐
│                  TIER 1: INTERFACE               │
│          User Intent Agent  ·  UX Agent          │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│              TIER 2: ORCHESTRATION               │
│       Search Orchestrator · Price Analyst        │
│       Comparison Agent · Personalization Agent   │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│               TIER 3: DATA WORKERS               │
│  Amadeus Agent · Skyscanner Agent · GFlight Agent│
│  Airline Scraper Agents (one per major airline)  │
└─────────────────────────────────────────────────┘
```

All agents communicate through a **shared message bus** (event-driven, async). Each agent is stateless per session but can read/write to shared stores (User Profile Store, Flight Cache, Price History DB).

---

## 2. Agent Catalog

### 2.1 User Intent Agent (NLU/NLG)

**Role:** The entry point. Translates raw user input (text, voice) into a structured `SearchIntent` object. Also generates human-readable replies.

| Property | Detail |
|---|---|
| **Input** | Free-text / voice query (e.g. "Find me the cheapest flight to Tokyo in July, I prefer morning departures") |
| **Output** | `SearchIntent { origin, destination, dateRange, flexibility, priceTarget, preferences[], urgency }` |
| **AI Techniques** | Large Language Model (on-device distilled model or API call to GPT-4o/Claude), Named Entity Recognition, Intent Classification |
| **Models** | On-device: Apple NLFramework / Android ML Kit for basic NER. Cloud: Claude or GPT-4o for complex intent |
| **Key Behaviors** | - Handles vague inputs ("beach trip in summer") by inferring popular destinations<br>- Asks clarifying questions if ambiguity is high<br>- Understands multi-leg trips, open-jaw itineraries<br>- Supports follow-up refinements ("actually, make it business class") |

```
Example SearchIntent output:
{
  "origin": "SFO",
  "destination": "TYO",           // resolved to NRT/HND
  "dateRange": { "from": "2026-07-01", "to": "2026-07-31" },
  "flexibility": 3,               // ±3 days
  "cabin": "economy",
  "maxPrice": null,               // not stated
  "preferences": ["morning_departure", "direct_preferred"],
  "tripType": "roundtrip",
  "urgency": "low"                // user is not in a rush → price-watch mode
}
```

---

### 2.2 Search Orchestrator Agent

**Role:** The brain of Tier 2. Receives a `SearchIntent`, fans out tasks to all Tier 3 data worker agents in parallel, collects results, deduplicates, and forwards to the analysis pipeline.

| Property | Detail |
|---|---|
| **Input** | `SearchIntent` from User Intent Agent |
| **Output** | Merged, deduplicated `FlightPool[]` (raw list of all candidate flights) |
| **AI Techniques** | Rule-based routing + reinforcement-learned prioritization (which data sources to hit first based on route/region) |
| **Key Behaviors** | - Dispatches all Tier 3 agents simultaneously (async/parallel)<br>- Sets per-source timeouts (e.g. 8s) and continues with available data if a source is slow<br>- Deduplicates identical flights from multiple sources (match on airline + flight number + date)<br>- Tags each result with its source for transparency<br>- Caches results in Flight Cache (TTL: 15 min) to avoid redundant API calls |

```
Orchestration Flow:
SearchIntent ──► [Amadeus Agent]  ──┐
               ├─[Skyscanner Agent]──┤
               ├─[GFlight Agent]  ───┼──► Merge & Deduplicate ──► FlightPool[]
               ├─[Delta Agent]    ───┤
               ├─[United Agent]   ───┤
               └─[ANA Agent]      ──┘
```

---

### 2.3 Data Worker Agents (Tier 3)

Each worker agent is responsible for a single data source. They are stateless microservices that accept a `SearchIntent` and return `FlightResult[]`.

#### 2.3.1 Amadeus Agent
- **API:** Amadeus Flight Offers Search API (OAuth2)
- **Strengths:** Comprehensive GDS data, 500+ airlines, fare rules, seat maps
- **Output fields:** price, itinerary, baggage, fare class, refundability, CO2 estimate
- **Rate handling:** Respects Amadeus quota limits; uses exponential backoff

#### 2.3.2 Skyscanner Agent
- **API:** Skyscanner Flights Search API
- **Strengths:** Strong for budget airlines and OTA-aggregated prices
- **Special:** Can poll "Everywhere" searches for open-destination queries
- **Output fields:** deeplink to book, price, legs, carrier

#### 2.3.3 Google Flights Scraper Agent
- **Method:** Headless browser (Playwright) or structured HTTP requests mimicking browser behavior
- **Strengths:** Often shows the lowest prices; shows calendar view with cheapest days
- **Challenges:** Anti-scraping measures → requires rotating proxies + CAPTCHA handling strategy
- **Ethics note:** Subject to ToS; use as supplementary source, not primary
- **Output fields:** price, itinerary, booking URL

#### 2.3.4 Airline Direct Site Agents (one per airline)
- **Coverage:** American, Delta, United, Southwest, Emirates, Singapore Airlines, ANA, JAL, Cathay Pacific, Lufthansa, Air France, British Airways (expandable)
- **Method:** Each airline has a custom scraper OR uses the airline's own API where available (e.g., Southwest has a private API used by some aggregators)
- **Why direct?** Airlines sometimes offer exclusive direct-booking prices not on OTAs
- **Output:** Same `FlightResult` schema as other agents
- **Maintenance:** Scrapers break when airlines update their UI — needs a scraper health monitor sub-agent

---

### 2.4 Price Analysis Agent

**Role:** Analyzes the `FlightPool[]` using ML and statistics to enrich each flight with price intelligence.

| Property | Detail |
|---|---|
| **Input** | `FlightPool[]` + 12-month price history for the same route |
| **Output** | Enriched `FlightPool[]` with price scores, predictions, and labels |
| **AI Techniques** | Time-series forecasting (Prophet / ARIMA), anomaly detection, percentile ranking, regression |

**What it computes per flight:**

```
PriceIntelligence {
  currentPrice: $842,
  historicalMedian: $1,100,       // last 12 months, same route
  pricePercentile: 23,            // cheaper than 77% of historical prices
  priceLabel: "GREAT_DEAL",       // STEAL / GREAT_DEAL / FAIR / EXPENSIVE
  predictedIn7Days: $890,         // ML forecast
  predictedIn14Days: $1,020,
  recommendation: "BUY_NOW",      // BUY_NOW / WAIT / SET_ALERT
  confidenceScore: 0.81,
  trendDirection: "RISING"
}
```

**ML Pipeline:**
- Historical data ingested daily from all sources into a Price History DB
- Route-specific models trained weekly (high-traffic routes have more data)
- Classification model labels each price: `STEAL`, `GREAT_DEAL`, `FAIR`, `OVERPRICED`
- Feature engineering: day of week, days until departure, season, events (holidays, conferences), fuel price index

---

### 2.5 Comparison & Negotiation Agent

**Role:** Ranks and compares all enriched flights to find the true "best" options. Uses a multi-criteria negotiation framework rather than just sorting by price.

| Property | Detail |
|---|---|
| **Input** | Enriched `FlightPool[]` + User Profile (from Personalization Agent) |
| **Output** | Ranked `RecommendedFlights[]` with explanations |
| **AI Techniques** | Multi-criteria decision analysis (MCDA), weighted scoring, Pareto-front optimization |

**Scoring Dimensions:**

| Dimension | Weight (default) | Notes |
|---|---|---|
| Total price | 35% | Including fees and taxes |
| Price deal quality | 20% | Based on Price Analysis Agent score |
| Travel time | 15% | Total door-to-door time |
| Number of stops | 10% | Direct = bonus |
| Airline reliability | 8% | On-time performance data |
| Cabin comfort | 7% | Seat width, legroom data |
| Refundability | 5% | Flexible ticket bonus |

**Negotiation Mechanism:**
- Runs a "debate" between top candidates: each candidate "argues" its strengths against others
- Surfaced as user-readable explanations: "This flight is $200 cheaper but adds 3 hours of travel time"
- Produces a Pareto front: cheapest, fastest, best overall, best deal
- Weights are dynamically adjusted by the Personalization Agent

---

### 2.6 Personalization Agent

**Role:** Maintains a persistent user profile and continuously updates weights and preferences based on behavior. The system "gets smarter" with every interaction.

| Property | Detail |
|---|---|
| **Input** | User interactions (clicks, bookings, dismissals, ratings, explicit preferences) |
| **Output** | Updated User Profile + adjusted weight vector for Comparison Agent |
| **AI Techniques** | Collaborative filtering, bandit algorithms (Thompson Sampling), preference learning |
| **Storage** | On-device (private by default) + optional cloud sync (encrypted) |

**User Profile Schema:**
```
UserProfile {
  preferredAirlines: ["ANA", "Singapore Airlines"],
  avoidAirlines: ["Spirit"],
  seatPreference: "aisle",
  cabinPreference: "economy",      // upgrades to business for 8h+ flights
  maxLayoverTime: 120,             // minutes
  preferredDepartureWindow: ["06:00", "10:00"],
  loyaltyPrograms: { "ANA": "Gold", "United": "Silver" },
  budgetSensitivity: 0.7,          // 0=price-insensitive, 1=pure cheapest
  carbonSensitivity: 0.3,
  typicalLeadTime: 21,             // books ~3 weeks in advance
  bookingHistory: [...]
}
```

**Learning Behaviors:**
- If user always skips long layovers → auto-penalize them in ranking
- If user books ANA 70% of the time → boost ANA listings
- A/B tests different recommendation strategies per user using bandit algorithm
- Detects "anomalous" sessions (booking for others) to avoid polluting profile

---

### 2.7 Alert & Price Watch Agent

**Role:** Runs in the background (even when app is closed) to monitor price changes for routes the user is watching.

| Property | Detail |
|---|---|
| **Input** | User's watchlist + price change threshold |
| **Output** | Push notifications with price alerts |
| **AI Techniques** | Anomaly detection, threshold classification |
| **Schedule** | Polls every 4 hours for active watches; every 30 min for urgent/imminent departures |
| **Key Behaviors** | - "Price dropped 18% on your Tokyo watch — now at $720 (historically great deal)" <br>- Predicts when price will likely hit user's target<br>- Auto-expires watches after departure date |

---

## 3. Inter-Agent Communication Protocol

All agents communicate via a **typed message bus** (async pub/sub). No agent calls another directly.

### Message Types

```
SEARCH_INTENT_CREATED      → triggers Search Orchestrator
SOURCE_RESULTS_READY       → from each Tier 3 agent to Orchestrator
FLIGHT_POOL_READY          → triggers Price Analysis Agent
ENRICHED_POOL_READY        → triggers Comparison Agent + Personalization Agent
RECOMMENDATIONS_READY      → triggers UI rendering
USER_INTERACTION_EVENT     → triggers Personalization Agent
PRICE_ALERT_TRIGGERED      → triggers push notification
```

### Communication Diagram

```
User Input
   │
   ▼
[User Intent Agent]
   │ SEARCH_INTENT_CREATED
   ▼
[Search Orchestrator] ──── dispatches ────► [Amadeus Agent]
   │                                        [Skyscanner Agent]
   │                                        [GFlight Agent]
   │                                        [Airline Agents...]
   │         ◄──── SOURCE_RESULTS_READY ────
   │ FLIGHT_POOL_READY
   ▼
[Price Analysis Agent]
   │ ENRICHED_POOL_READY
   ├──────────────────────────────────────► [Personalization Agent]
   ▼                                                │
[Comparison Agent] ◄──── weights ─────────────────┘
   │ RECOMMENDATIONS_READY
   ▼
[UI Layer (iOS/Android)]
```

---

## 4. Data Stores

| Store | Purpose | Technology |
|---|---|---|
| **Flight Cache** | Short-lived (15 min TTL) cache of raw search results | Redis / in-memory |
| **Price History DB** | 12+ months of historical prices per route for ML training | TimescaleDB / InfluxDB |
| **User Profile Store** | Encrypted user preference profiles | SQLite (on-device) + optional cloud (Firestore) |
| **Scraper Health Monitor** | Tracks success/failure rates of each scraper agent | PostgreSQL |
| **Airline Reference DB** | Airport codes, airline data, route maps, seat maps | PostgreSQL |

---

## 5. Key Technical Considerations

### On-Device vs. Cloud AI
| Task | Where | Reason |
|---|---|---|
| Basic NER (city names, dates) | On-device | Privacy, speed |
| Complex intent understanding | Cloud (LLM API) | Accuracy |
| Price classification inference | On-device (CoreML/TFLite) | Real-time, offline |
| ML model training | Cloud | Compute-intensive |
| Personalization inference | On-device | Privacy |

### Scraping Reliability Strategy
- Each scraper agent reports health metrics (success rate, avg latency)
- A **Scraper Health Monitor** auto-disables broken scrapers and alerts the team
- Results are never blocked by one failing source — degraded-mode fallback always available

### Privacy & Data Ethics
- User profiles stored on-device by default (opt-in for cloud sync)
- No PII sent to scraper agents
- Price history data is fully anonymized
- Loyalty program data never leaves the device

---

## 6. Suggested Next Steps

1. **Backend:** Build the message bus and agent scaffolding (Python FastAPI microservices or Node.js)
2. **Data Pipeline:** Set up Amadeus + Skyscanner API integration first (most reliable)
3. **ML Baseline:** Train initial price classification model on Amadeus historical data
4. **Mobile:** Build the iOS (SwiftUI) and Android (Kotlin) clients with the recommendation UI
5. **Scrapers:** Add Google Flights + airline scrapers incrementally, starting with the 3 largest carriers
6. **Personalization:** Deploy after sufficient user interaction data is collected (cold-start with reasonable defaults)

---

*Document version: 1.0 — Generated April 2026*
