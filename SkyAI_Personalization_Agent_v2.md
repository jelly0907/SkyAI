# SkyAI — Personalization Agent: Deep Design (v2)

> This document expands Section 2.6 of the main Agent Design Document with a full specification for the three-layer personalization system: **Static Profile → Dynamic Inference → User Label → Recommendation Engine**.

---

## Overview: Three-Layer Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 1: STATIC PROFILE                                         │
│  Collected at registration. Stable, explicit, user-declared.     │
│  → Demographics, job, airline memberships, travel preferences    │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  LAYER 2: DYNAMIC INFERENCE                                      │
│  Inferred per search session. Changes with context.              │
│  → Travel purpose, group size, urgency, budget signal            │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  LAYER 3: USER LABEL ENGINE                                      │
│  Combines L1 + L2 into a multi-dimensional user segment label.   │
│  Labels drive ranking weights and future recommendations.        │
└──────────────────────────────────────────────────────────────────┘
```

---

## Layer 1: Static Profile (Registration)

### 1.1 Registration Flow Design

The registration is split into **3 short steps** to maximize completion rate. Each step has a clear value proposition so the user understands *why* they're sharing data.

```
Step 1: "Tell us about yourself" (30 sec)
Step 2: "Your travel style"      (45 sec)
Step 3: "Your memberships"       (30 sec)
         ↓
      Skip option available on Steps 2 & 3
      (system degrades gracefully with less data)
```

---

### 1.2 Registration Schema

#### Step 1 — Personal Basics
*Value prop shown to user: "We use this to find age-appropriate deals, student discounts, and senior fares."*

```
PersonalProfile {
  // Identity
  dateOfBirth: Date                  // → age bucket (see below)
  nationality: String (ISO 3166)     // for visa-free route filtering
  countryOfResidence: String         // home airport suggestions

  // Occupation
  jobCategory: Enum {
    STUDENT,
    PROFESSIONAL_OFFICE,            // desk job, M–F
    PROFESSIONAL_MOBILE,            // consultant, sales, field work
    SELF_EMPLOYED,
    HEALTHCARE_WORKER,
    MILITARY,
    RETIRED,
    OTHER
  }
  employerIndustry: String?          // optional: "Finance", "Tech", "Education"
  isFrequentBusinessTraveler: Bool   // "Do you travel for work at least once a month?"
}
```

**Age Bucket Logic (never store raw DOB in recommendations engine):**
```
Under 12  → CHILD
12–17     → TEENAGER
18–25     → YOUNG_ADULT       (student discounts, budget airlines)
26–35     → YOUNG_PROFESSIONAL
36–50     → MID_PROFESSIONAL
51–64     → PRE_SENIOR
65+       → SENIOR            (senior fares, direct flights preference)
```

---

#### Step 2 — Travel Style
*Value prop shown to user: "We'll rank flights the way YOU want — not just cheapest."*

```
TravelStyle {
  // Budget Attitude
  budgetSensitivity: Enum {
    PRICE_FIRST,        // always cheapest, even 2 stops + 6h layover
    BALANCED,           // good value, reasonable comfort
    COMFORT_FIRST,      // willing to pay more for direct, legroom
    LUXURY              // business/first class preferred
  }

  // Comfort Priorities (rank 1–5, user drags to reorder)
  comfortPriorities: Ordered<Enum> {
    DIRECT_FLIGHT,
    DEPARTURE_TIME,
    TOTAL_DURATION,
    AIRLINE_QUALITY,
    SEAT_COMFORT,
    BAGGAGE_ALLOWANCE,
    PRICE
  }

  // Scheduling Preferences
  preferredDepartureWindows: MultiSelect {
    EARLY_MORNING,     // 05:00–08:00
    MORNING,           // 08:00–12:00
    AFTERNOON,         // 12:00–17:00
    EVENING,           // 17:00–21:00
    RED_EYE            // 21:00–05:00
  }

  // Layover Tolerance
  maxLayoverHours: Int              // 0 = direct only, up to 12
  acceptLayoverInDifferentCity: Bool

  // Special Requirements
  specialAssistanceNeeded: Bool    // accessibility, medical equipment
  dietaryRestrictions: MultiSelect { HALAL, KOSHER, VEGAN, VEGETARIAN, NONE }
}
```

---

#### Step 3 — Airline Memberships
*Value prop shown to user: "We'll prioritize flights that earn you miles on your existing programs."*

```
MembershipProfile {
  loyaltyPrograms: [
    {
      program: String,             // "ANA Mileage Club", "United MileagePlus", etc.
      tier: Enum { BASIC, SILVER, GOLD, PLATINUM, DIAMOND }
      memberId: String?            // optional — only for auto-fill at booking
    }
  ]

  creditCards: [
    {
      cardNetwork: Enum { VISA, MASTERCARD, AMEX, OTHER }
      travelCardType: Enum {
        AIRLINE_COBRANDED,         // e.g. Delta SkyMiles AMEX
        GENERAL_TRAVEL,            // e.g. Chase Sapphire
        NO_TRAVEL_BENEFITS
      }
      preferredAirlineForCard: String?   // which airline the card earns most on
    }
  ]

  alliancePreference: Enum? { STAR_ALLIANCE, ONEWORLD, SKYTEAM, NO_PREFERENCE }
}
```

---

## Layer 2: Dynamic Inference (Per Search Session)

Every time the user initiates a search, the **Intent Inference Engine** runs in parallel with the search to classify the session context. This is lightweight — no user friction.

### 2.1 Travel Purpose Classifier

**Input signals** (from the search query + app context):

| Signal | Example | Inferred purpose |
|---|---|---|
| Destination type | Las Vegas, Cancun, Bali | LEISURE / VACATION |
| Destination type | Washington D.C., Geneva, Davos | BUSINESS |
| Lead time < 48h | Booking for tomorrow | EMERGENCY or URGENT_BUSINESS |
| Roundtrip with Mon–Fri stay | Depart Sun, return Fri | BUSINESS |
| Roundtrip over weekend | Depart Fri, return Sun | SHORT_VACATION |
| Long stay (14+ days) | 3 weeks abroad | VACATION / RELOCATION |
| User's job = MILITARY + destination = domestic | — | MILITARY_TRAVEL |
| Holiday calendar match | Dec 23 – Jan 2 | HOLIDAY_TRAVEL |
| Multiple cities | NYC → London → Paris → NYC | MULTI_CITY_VACATION |
| NLU extraction | "My grandmother is in hospital" | FAMILY_EMERGENCY |

**Travel Purpose Enum:**
```
VACATION_LEISURE
VACATION_HOLIDAY        // around major holidays
SHORT_GETAWAY           // 1–3 night trip
BUSINESS_FORMAL         // conference, client meeting
BUSINESS_REMOTE         // digital nomad, working remotely
EMERGENCY_MEDICAL
EMERGENCY_FAMILY
RELOCATION
STUDENT_TRAVEL
HONEYMOON_ROMANCE       // detected via destination + keywords
ADVENTURE_TRAVEL        // extreme destinations, outdoor
```

**Classification Method:**
- Rule-based layer (fast): catches 80% of cases with deterministic rules
- LLM fallback (for ambiguous cases): passes search context to NLU model for classification
- Confidence score attached to every classification — if < 0.6, the app subtly asks: *"Is this trip for work or leisure?"* (one tap)

---

### 2.2 Group Size & Composition Detector

**Input signals:**

| Signal | Source | Inference |
|---|---|---|
| Passenger count selected | Search form | Direct — always captured |
| "Traveling with kids" toggle | Search form | Family trip |
| Age of passengers entered | Search form | Child ages → Family classification |
| Search history pattern | Previous trips | User always travels alone vs. in groups |
| NLU text clues | "Me and my wife", "family vacation", "team offsite" | Group composition |

**Group Profile Enum:**
```
SOLO
COUPLE
SMALL_FAMILY         // 2 adults + 1–2 children
LARGE_FAMILY         // 2 adults + 3+ children, or multi-gen
FRIENDS_GROUP        // 3–8 adults, leisure
CORPORATE_GROUP      // 3+ adults, business purpose
LARGE_GROUP          // 9+ passengers
```

---

### 2.3 Urgency & Budget Signal

**Urgency** is inferred from lead time:
```
VERY_URGENT    → departure within 24h
URGENT         → 2–5 days
SHORT_NOTICE   → 6–14 days
NORMAL         → 15–45 days
ADVANCE        → 46–90 days
FAR_ADVANCE    → 90+ days
```

**Budget Signal** is inferred from:
- User's stated `budgetSensitivity` (Layer 1) — baseline
- Cabin class searched (economy vs. business)
- Whether user clicks on cheap or premium results in history
- Average price of previously booked tickets
- Δ from baseline: if a "PRICE_FIRST" user suddenly searches business class → override signal

---

## Layer 3: User Label Engine

### 3.1 Label Taxonomy

Labels are **multi-dimensional** — a user gets one label per dimension, forming a label vector. This avoids over-simplifying users into a single bucket.

```
UserLabelVector {
  travelerType:   PrimaryLabel,      // who you are
  purposeLabel:   PurposeLabel,      // why you travel (per session)
  groupLabel:     GroupLabel,        // who you travel with
  budgetLabel:    BudgetLabel,       // how you spend
  loyaltyLabel:   LoyaltyLabel,      // how loyalty-driven you are
  flexLabel:      FlexLabel          // how flexible you are
}
```

#### Primary Traveler Type Labels

| Label | Profile Signals | Description |
|---|---|---|
| `BUDGET_BACKPACKER` | Age 18–25, PRICE_FIRST, no loyalty cards, long stays | Will take 2 stops to save $80 |
| `STUDENT_TRAVELER` | Age 18–25, STUDENT job, seasonal travel patterns | Travels in summer/winter break windows |
| `YOUNG_PROFESSIONAL` | Age 26–35, BALANCED, 1–2 loyalty cards | Values time but watches price |
| `BUSINESS_ROAD_WARRIOR` | PROFESSIONAL_MOBILE, isFrequentBusiness=true, GOLD+ loyalty | Books last-minute, needs flexibility |
| `CORPORATE_TRAVELER` | PROFESSIONAL_OFFICE, business-purpose trips, company policy | Often constrained by booking policy |
| `FAMILY_PLANNER` | LARGE_FAMILY or SMALL_FAMILY, advance bookings, school holidays | Needs multiple seats together, baggage |
| `COUPLE_EXPLORER` | COUPLE, varied destinations, mix of budget & comfort | Values experience over price |
| `LUXURY_TRAVELER` | LUXURY sensitivity, COMFORT_FIRST, Platinum+ loyalty | Business/first class, direct only |
| `SENIOR_TRAVELER` | Age 65+, DIRECT_FLIGHT priority, special assistance possible | Comfort, reliability, reachability |
| `DIGITAL_NOMAD` | SELF_EMPLOYED, long stays, one-way or open-jaw patterns | Flexible, non-traditional itineraries |
| `EMERGENCY_RESPONDER` | High urgency, EMERGENCY purpose, last-minute | Needs fastest booking, price secondary |
| `MILITARY_TRAVELER` | MILITARY job, specific route patterns | Military discounts, specific needs |

---

#### Purpose Labels (per session)
Applied dynamically each search — the same user can be `BUSINESS_ROAD_WARRIOR` on Monday and `FAMILY_PLANNER` on Saturday.

```
VACATION · BUSINESS · EMERGENCY · HONEYMOON · STUDENT_BREAK · HOLIDAY · ADVENTURE
```

#### Budget Labels
```
ULTRA_BUDGET      → always filters by cheapest
BUDGET_CONSCIOUS  → price-sensitive, some flexibility
VALUE_SEEKER      → best price/quality ratio
COMFORT_SPENDER   → pays for direct/comfort without thinking
LUXURY_SPENDER    → regularly books business/first class
```

#### Loyalty Labels
```
LOYALTY_DRIVEN    → has Gold+ in 1+ program, prioritizes miles
CASUAL_MEMBER     → has memberships but doesn't optimize for them
NON_MEMBER        → no loyalty programs
```

#### Flex Labels
```
RIGID             → fixed dates, no flexibility
SLIGHTLY_FLEXIBLE → ±1–2 days
FLEXIBLE          → ±3–7 days, open to suggestions
VERY_FLEXIBLE     → open destination or dates
```

---

### 3.2 Label Classification Pipeline

```
┌──────────────────────────────────────────────────────────────┐
│  INPUTS                                                       │
│  ┌─────────────────┐   ┌──────────────────────────────────┐  │
│  │  Static Profile  │   │  Dynamic Session Signals          │  │
│  │  (Layer 1)       │   │  (Layer 2: purpose, group, etc.) │  │
│  └────────┬────────┘   └─────────────┬────────────────────┘  │
│           │                           │                        │
│  ┌────────▼───────────────────────────▼──────────────────┐   │
│  │             Feature Vector Builder                      │   │
│  │  age_bucket, job, loyalty_tier, budget_sensitivity,    │   │
│  │  travel_purpose, group_size, urgency, booking_history  │   │
│  └────────────────────────┬───────────────────────────────┘   │
│                            │                                   │
│  ┌─────────────────────────▼─────────────────────────────┐   │
│  │              Multi-Label Classifier                     │   │
│  │  Model: Gradient Boosted Trees (XGBoost) or small MLP  │   │
│  │  Output: label probabilities per dimension              │   │
│  └─────────────────────────┬─────────────────────────────┘   │
│                             │                                  │
│  ┌──────────────────────────▼────────────────────────────┐   │
│  │              UserLabelVector                            │   │
│  │  { travelerType: "FAMILY_PLANNER",                     │   │
│  │    purposeLabel: "VACATION",                           │   │
│  │    groupLabel: "LARGE_FAMILY",                         │   │
│  │    budgetLabel: "VALUE_SEEKER",                        │   │
│  │    loyaltyLabel: "CASUAL_MEMBER",                      │   │
│  │    flexLabel: "SLIGHTLY_FLEXIBLE" }                    │   │
│  └────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**Cold Start Strategy** (new users with no history):
- Use static profile to assign initial labels with lower confidence scores
- After 3 searches → recalculate with session data
- After 1 booking → high-confidence label stabilization
- Bayesian updating: each interaction shifts label probabilities, never resets from scratch

---

## Layer 3 Output: Label → Recommendation Engine

### 3.3 Label-Driven Ranking Weights

Each label vector maps to a **ranking weight configuration** passed to the Comparison Agent. This replaces the hardcoded default weights from v1.

```
Label: BUSINESS_ROAD_WARRIOR + BUSINESS + SOLO + LUXURY_SPENDER + LOYALTY_DRIVEN + RIGID
→ Ranking Weights:
{
  totalPrice:       0.10,   // price barely matters
  dealQuality:      0.05,
  travelTime:       0.25,   // time is money
  numberOfStops:    0.20,   // direct strongly preferred
  airlineReliability: 0.15, // on-time critical for connections
  loyaltyMileEarn:  0.20,   // miles matter a lot
  refundability:    0.05    // company card — less critical
}

Label: BUDGET_BACKPACKER + VACATION + SOLO + ULTRA_BUDGET + NON_MEMBER + VERY_FLEXIBLE
→ Ranking Weights:
{
  totalPrice:       0.55,   // price is everything
  dealQuality:      0.20,   // loves a "STEAL" badge
  travelTime:       0.05,
  numberOfStops:    0.05,   // fine with 2 stops
  airlineReliability: 0.05,
  loyaltyMileEarn:  0.00,   // not relevant
  refundability:    0.10    // just in case
}

Label: FAMILY_PLANNER + VACATION + LARGE_FAMILY + VALUE_SEEKER + CASUAL_MEMBER + SLIGHTLY_FLEXIBLE
→ Ranking Weights:
{
  totalPrice:       0.30,   // important — 4 tickets adds up
  dealQuality:      0.15,
  travelTime:       0.15,
  numberOfStops:    0.15,   // prefers direct (kids on plane)
  seatsAvailableTogether: 0.15,  // FAMILY-SPECIFIC: adjacent seats
  baggageAllowance: 0.05,
  refundability:    0.05
}
```

---

### 3.4 Label-Driven UI Personalization

Beyond ranking, labels also drive **what the app shows and how**:

| Label | UI Personalization |
|---|---|
| `BUSINESS_ROAD_WARRIOR` | Default to "Flexible dates" view; show "Fastest" sort first; highlight lounge access |
| `FAMILY_PLANNER` | Show "Seats together" filter prominently; family cabin availability; baggage cost calculator |
| `BUDGET_BACKPACKER` | Highlight STEAL badges; show price calendar; "Cheapest month" feature front-and-center |
| `LUXURY_TRAVELER` | Default to Business class filter; show cabin photos; lounge access indicators |
| `SENIOR_TRAVELER` | Larger font in results; highlight direct flights and assistance options; show airline call number |
| `EMERGENCY_RESPONDER` | Skip date picker — default to next 24h; sort by departure time first |
| `DIGITAL_NOMAD` | Show one-way + multi-city options first; "Work-friendly" airport tags |
| `STUDENT_TRAVELER` | Surface student discount badges; show flexible date range by default |

---

### 3.5 Label-Driven Future Recommendations (Home Screen)

When the user opens the app without a specific search, the home screen is populated by the **Recommendation Feed** — driven by their label vector:

```
BUDGET_BACKPACKER + VERY_FLEXIBLE:
  → "Cheapest place to fly from SFO this month"
  → "Prices just dropped 30% to Bangkok"
  → "Under $400 roundtrip this weekend"

BUSINESS_ROAD_WARRIOR + LOYALTY_DRIVEN:
  → "Your next ANA Gold status trip: 3,200 miles needed"
  → "Direct SFO→NRT on ANA — your preferred route — 15% below average"
  → "Last-minute upgrade available on your watched route"

FAMILY_PLANNER + HOLIDAY:
  → "Book now: Spring Break fares rising fast"
  → "Best family-friendly direct flights from SFO to Orlando"
  → "Price alert: Disney destinations cheapest in 3 months"

SENIOR_TRAVELER + COUPLE:
  → "Direct flights only: your top 5 destinations"
  → "Best roundtrips under 8 hours with senior fares"
  → "Airline with best accessibility: ranked for your route"
```

---

## Data Flow Summary

```
REGISTRATION
  User fills profile (Step 1–3)
       │
       ▼
  UserProfile stored (on-device, encrypted)
       │
       ▼
  Initial UserLabelVector computed (cold-start heuristics)

EACH SEARCH SESSION
  User submits query
       │
       ├──► Intent Inference Engine → PurposeLabel + GroupLabel + UrgencySignal
       │
       ├──► UserProfile (Layer 1 static data)
       │
       ▼
  Feature Vector built
       │
       ▼
  Multi-Label Classifier → UserLabelVector (updated)
       │
       ├──► Ranking Weight Config → Comparison Agent
       │
       ├──► UI Personalization Config → Mobile App
       │
       └──► Recommendation Feed → Home Screen

AFTER BOOKING / INTERACTION
  Booking confirmed OR result clicked/dismissed
       │
       ▼
  Bayesian label update (confidence scores shift)
       │
       ▼
  UserLabelVector re-evaluated (gradual, not sudden)
```

---

---

## Layer 4: Silent Behavioral Learning (Bandit-Driven Continuous Adaptation)

While Layers 1–3 establish *who the user is*, Layer 4 learns *how their preferences drift over time* — silently, with no user input required. This is the system that makes the app feel like it "just gets you" the longer you use it.

### 4.1 What Is Silently Observed

Every user interaction is a signal. The system logs these **events** without ever asking the user:

| Event | Signal Extracted |
|---|---|
| Clicks a result | Which attributes (airline, price, stops, departure time) were prominent |
| Skips a result | What made it unattractive vs. competitors shown |
| Books a ticket | Strongest positive signal — validates all attributes of chosen flight |
| Dismisses a price alert | Price threshold too high / destination no longer relevant |
| Sorts results manually | User's preferred sort axis (price / duration / stops) |
| Uses filter (e.g., "direct only") | Preference strength for that attribute |
| Changes cabin class in search | Budget evolution over time |
| Searches same route multiple times | Price sensitivity — watching for a specific price point |
| Opens flight detail screen | Curiosity about specific attributes (seat map, baggage, refund) |
| Abandons search | Dissatisfaction signal — used to detect missing results or poor ranking |

---

### 4.2 The Multi-Armed Bandit Framework

Rather than waiting for enough data to retrain a full ML model, the bandit algorithm **learns in real-time** — updating preference estimates after each interaction.

**Problem framing:** The ranking weights (price, travel time, stops, airline quality, etc.) are the "arms" of a bandit. The system tries different weight configurations and observes which ones lead to clicks and bookings (reward). Over time it converges on the optimal weights for this specific user.

**Algorithm: Thompson Sampling (Bayesian Bandit)**

Each ranking weight dimension maintains a **Beta distribution** representing uncertainty about the user's true preference:

```
Weight Dimension: "number_of_stops"
  β(α, β) where:
  α = number of times user clicked a result where "stops" was a top differentiator
  β = number of times user ignored results despite having fewer stops

  New user (cold start):  β(1, 1)  → uniform, highly uncertain
  After 10 interactions:  β(7, 3)  → user prefers direct, confidence rising
  After 50 interactions:  β(38, 12) → strong confirmed preference for direct
```

At each ranking call, the system **samples** a weight vector from the joint distribution across all dimensions and uses it to rank — this naturally balances **exploitation** (use known preferences) with **exploration** (occasionally try different rankings to discover better configurations).

```
Bandit Exploration Example:
  Normal: User prefers direct flights → direct flights ranked high (EXPLOIT)
  Occasional: System shows a 1-stop flight that is 40% cheaper in top 3 (EXPLORE)
  If user clicks it → α for "price" increases, system learns price beats stops in this case
  If user skips it → β for "price" increases for this trade-off scenario
```

---

### 4.3 Preference Dimensions Tracked by the Bandit

```
BanditPreferenceModel {
  // Each is a Beta(α, β) distribution
  priceWeight:          Beta(α, β),
  travelTimeWeight:     Beta(α, β),
  directFlightWeight:   Beta(α, β),
  airlineQualityWeight: Beta(α, β),
  departureTimeWeight:  Beta(α, β),   // AM vs PM preference
  refundabilityWeight:  Beta(α, β),
  loyaltyMileWeight:    Beta(α, β),
  baggageWeight:        Beta(α, β),
  cabinComfortWeight:   Beta(α, β),

  // Airline affinity scores (separate per airline)
  airlineAffinity: {
    "ANA":              Beta(α, β),
    "Singapore":        Beta(α, β),
    "Delta":            Beta(α, β),
    ...                 Beta(1, 1)  // all others start neutral
  },

  // Departure time window affinity
  departureWindowAffinity: {
    EARLY_MORNING:      Beta(α, β),
    MORNING:            Beta(α, β),
    AFTERNOON:          Beta(α, β),
    EVENING:            Beta(α, β),
    RED_EYE:            Beta(α, β)
  },

  // Layover tolerance curve
  maxLayoverTolerance:  GaussianEstimate(μ, σ)   // mean + uncertainty in minutes
}
```

---

### 4.4 Contextual Bandits: Preferences Change by Context

A simple bandit learns one global preference, but users behave differently in different contexts. SkyAI uses **contextual bandits** — the preference model is conditioned on the current session context:

```
Context Dimensions:
  ├── TravelPurpose  (BUSINESS vs VACATION vs EMERGENCY)
  ├── GroupComposition (SOLO vs FAMILY vs COUPLE)
  └── Urgency (ADVANCE_BOOKING vs LAST_MINUTE)

Example:
  Same user:
  - BUSINESS + SOLO + URGENT     → prefers direct, ignores price, needs flexibility
  - VACATION + FAMILY + ADVANCE  → price-sensitive, needs seats together, baggage matters

  The bandit maintains SEPARATE Beta distributions per context bucket,
  so learning in one context does not corrupt preferences in another.
```

**Context Buckets (cross-product, stored as hash keys):**
```
{PURPOSE}_{GROUP}_{URGENCY}
e.g.:
  "BUSINESS_SOLO_URGENT"
  "VACATION_FAMILY_ADVANCE"
  "VACATION_COUPLE_NORMAL"
  "EMERGENCY_SOLO_VERY_URGENT"
```

---

### 4.5 Detecting Preference Drift

User preferences evolve over time (e.g., a BUDGET_BACKPACKER becomes a YOUNG_PROFESSIONAL and starts caring about comfort). The system detects drift and adapts:

**Drift Detection Method: ADWIN (Adaptive Windowing)**
- Monitors the reward rate of current weight configurations
- If a statistically significant drop in reward is detected → flags drift
- Response: temporarily increase exploration rate (ε-greedy boost) to re-learn
- Gradually shifts Beta priors toward the new emerging preference

```
Drift Scenario Example:
  Month 1–6:  User always clicks cheapest flight (price weight β high)
  Month 7:    User gets promoted, starts clicking business class
  ADWIN:      Detects drop in reward for cheapest-first ranking
  Response:   Increase exploration → try comfort-first ranking
  Month 8:    Confirms new preference → β(price) resets partially, β(comfort) rises
```

---

### 4.6 Integration with the Label Engine

The Bandit model runs **alongside** the Label Engine — they are complementary:

```
┌─────────────────────────────────────────────────────────────────┐
│                    RANKING WEIGHT RESOLVER                       │
│                                                                  │
│  Label Engine Output:                                            │
│  → "BUSINESS_ROAD_WARRIOR" preset weights (coarse-grained)      │
│                    +                                             │
│  Bandit Model Output:                                            │
│  → Personalized fine-grained adjustments (from 50+ interactions)│
│                    =                                             │
│  FINAL WEIGHT VECTOR (blended, weighted by confidence)          │
│                                                                  │
│  Blend formula:                                                  │
│  finalWeight[i] = (1 - confidence) × labelWeight[i]             │
│                 + confidence × banditWeight[i]                   │
│                                                                  │
│  confidence = f(total_interactions)                              │
│  → 0.0 at 0 interactions (fully label-driven)                   │
│  → 0.5 at 20 interactions (balanced)                            │
│  → 0.9 at 100+ interactions (fully bandit-driven)               │
└─────────────────────────────────────────────────────────────────┘
```

This ensures the app is **useful from Day 1** (label-based defaults) and **gets smarter over time** (bandit refinement) without any explicit user effort.

---

### 4.7 Airline Affinity Learning (Silent Loyalty Detection)

Even if a user doesn't register their loyalty card, the system detects implicit airline affinity:

```
Signals:
  - User repeatedly clicks ANA results over equivalent Delta results
  - User only books ANA even when 15% more expensive
  - User searches ANA.com direct agent results after seeing them in comparison

Effect:
  - ANA affinity Beta(α, β) shifts strongly positive
  - System boosts ANA in ranking automatically
  - Home screen shows "ANA deals from SFO" card
  - System subtly prompts: "Looks like you prefer ANA — add your Mileage Club number to earn miles!"
    (converts silent learner into registered member → better data)
```

---

## Privacy Considerations

| Data | Storage | Shared? |
|---|---|---|
| Date of birth | On-device only (stored as age bucket) | Never — raw DOB never leaves device |
| Job / occupation | On-device | Never |
| Loyalty member IDs | On-device (encrypted keychain) | Only at user-initiated booking |
| UserLabelVector | On-device + optional anonymized cloud | Cloud version has no PII |
| Search history | On-device (rolling 90 days) | Never |
| Booking history | On-device | Never |

**User controls:**
- View and edit their label in Settings ("Your Traveler Profile")
- Reset all personalization data
- Export their data (GDPR / CCPA compliance)
- Opt out of any cloud sync

---

*Document version: 2.0 — Generated April 2026*
