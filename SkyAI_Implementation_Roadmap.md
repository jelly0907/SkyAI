# SkyAI — Implementation Roadmap

> A phased plan from zero to production-ready app.  
> Each phase produces a working, testable artifact — no big-bang releases.

---

## Phase Overview

```
Phase 0 │ Foundation           │ 2 weeks   │ Infra, APIs, DB
Phase 1 │ Core Search          │ 4 weeks   │ Search + basic results
Phase 2 │ Price Intelligence   │ 4 weeks   │ ML models + classification
Phase 3 │ Personalization      │ 4 weeks   │ Registration + label engine
Phase 4 │ Mobile Apps          │ 6 weeks   │ iOS + Android native builds
Phase 5 │ Alerts & Polish      │ 3 weeks   │ Watchlist + push + bandit
Phase 6 │ Beta & Launch        │ 3 weeks   │ TestFlight / Play Beta → App Stores
```

**Total: ~26 weeks (6.5 months) to public launch**

---

## Phase 0 — Foundation (Weeks 1–2)

**Goal:** Everything needed before writing product code.

### Backend
- [ ] Set up cloud infrastructure (AWS or GCP): VPC, subnets, IAM
- [ ] Deploy PostgreSQL + TimescaleDB (Price History DB)
- [ ] Deploy Redis (Flight Cache)
- [ ] Set up Kafka cluster (message bus for agent communication)
- [ ] Set up API Gateway + auth service (JWT, refresh tokens)
- [ ] CI/CD pipelines (GitHub Actions): lint → test → build → deploy
- [ ] Staging and production environments

### API Credentials
- [ ] Register for Amadeus Self-Service API (free tier for dev)
- [ ] Register for Skyscanner Flights API (partner access)
- [ ] Set up rotating proxy service for scraper agents (e.g. Bright Data)
- [ ] Set up FX rate feed (e.g. Open Exchange Rates API)

### Data Seeding
- [ ] Backfill 6 months of historical price data from Amadeus for top 50 routes
- [ ] Build Airline Reference DB (IATA codes, routes, on-time data)
- [ ] Build Airport Reference DB (IATA codes, cities, timezones, coordinates)

### Deliverable: Deployed empty infrastructure, all credentials working, DB seeded.

---

## Phase 1 — Core Search (Weeks 3–6)

**Goal:** A working search that returns real flight results from multiple sources.

### Agent Backend
- [ ] Build Search Orchestrator agent (fan-out + merge logic)
- [ ] Build Amadeus Agent (OAuth2 + Flight Offers Search API)
- [ ] Build Skyscanner Agent (Search API integration)
- [ ] Build Google Flights scraper agent (Playwright, basic version)
- [ ] Build 3 airline direct scrapers (ANA, United, Delta as pilot)
- [ ] Implement deduplication logic (match on airline + flight# + date)
- [ ] Implement result caching (Redis, 15-min TTL)
- [ ] Build User Intent Agent (NER for cities/dates, basic intent parsing)
- [ ] REST API: `POST /search/intent` and `POST /search/flights`
- [ ] WebSocket: stream partial results as sources return

### Basic Price Context (non-ML, rule-based)
- [ ] Compute price percentile vs. 6-month history (no ML yet)
- [ ] Assign basic label: above/below median
- [ ] This is superseded by Phase 2 but keeps Phase 1 useful

### Mobile (Prototype)
- [ ] iOS: Search screen + Results screen (basic, no design polish)
- [ ] Android: Search screen + Results screen (basic)
- [ ] Both connect to live backend — real results
- [ ] Hardcoded ranking (price ascending, for now)

### Deliverable: Working app — type "SFO to Tokyo" → get real ranked results from 3+ sources.

---

## Phase 2 — Price Intelligence (Weeks 7–10)

**Goal:** ML-powered price classification and forecasting live in the app.

### Data Pipeline
- [ ] Start continuous price observation logging (all searches → TimescaleDB)
- [ ] Build Feature Store: hourly computation of `RouteStats` for top 200 routes
- [ ] Build training data pipeline (label historical observations by percentile)

### ML Models
- [ ] Train XGBoost Price Classifier (v1) on 6-month backfill data
- [ ] Train Prophet forecasting model per top-50 routes
- [ ] Train LSTM forecasting model per top-50 routes
- [ ] Build ensemble forecasting layer
- [ ] Build Action Recommendation logic (BUY_NOW / WAIT / SET_ALERT)
- [ ] Export models: CoreML for iOS, TFLite for Android
- [ ] Build model versioning + silent background update delivery

### Price Analysis Agent
- [ ] Integrate classifier + forecaster into Price Analysis Agent
- [ ] Enrich `FlightPool[]` with `PriceIntelligence` objects
- [ ] Build explanation text generator (template-based, Phase 2; LLM-enhanced, Phase 5)
- [ ] Model performance monitoring dashboard (internal)

### Mobile (Update)
- [ ] Add deal badges to flight cards (STEAL / GREAT DEAL / FAIR badges)
- [ ] Add price intelligence section to Flight Detail screen
- [ ] Add forecast trend chart (mini line chart on detail screen)
- [ ] Add action recommendation CTA (BUY NOW / WAIT / SET ALERT)

### Deliverable: App shows ML-powered price labels and forecasts. Users can see if a price is a "Steal."

---

## Phase 3 — Personalization (Weeks 11–14)

**Goal:** Registration flow, label engine, and personalized ranking live.

### Registration Flow
- [ ] Build auth service: register / login / JWT / refresh
- [ ] iOS: Onboarding 3-step registration UI
- [ ] Android: Onboarding 3-step registration UI
- [ ] Backend: `POST /profile` (save static profile)
- [ ] Age bucket computation (store bucket, not raw DOB)
- [ ] All PII encryption at rest

### Label Engine
- [ ] Build Feature Vector Builder (static profile + session signals)
- [ ] Train multi-label classifier (XGBoost, multi-output)
  - Primary traveler type (12 labels)
  - Budget label (5 labels)
  - Loyalty label (3 labels)
  - Flex label (4 labels)
- [ ] Build contextual bandit framework (Thompson Sampling, per context bucket)
- [ ] Build ranking weight resolver (label weights + bandit weights blended)
- [ ] Integrate with Comparison Agent: personalized ranking live

### Travel Purpose Inference
- [ ] Build Intent Inference Engine (rule-based layer)
- [ ] Integrate LLM fallback for ambiguous cases (Claude API)
- [ ] Group size detector (from passenger count + NLU text)
- [ ] Urgency classifier (from lead time)

### Home Feed
- [ ] Build personalized feed API (`GET /feed`)
- [ ] Per-label feed templates (e.g. BUDGET_BACKPACKER sees cheapest-from-home)
- [ ] iOS: Home screen with personalized feed sections
- [ ] Android: Home screen with personalized feed sections

### Profile Screen
- [ ] iOS + Android: Profile screen (view label, memberships, preferences)
- [ ] Edit profile flow
- [ ] Privacy controls (reset, export)

### Deliverable: Personalized app — two users searching the same route see differently ranked results. Home screen shows relevant deals per user type.

---

## Phase 4 — Mobile Apps (Weeks 15–20)

**Goal:** Production-quality native apps for both platforms.

### iOS
- [ ] Full design system (colors, typography, spacing, components)
- [ ] Polished Search screen with NL input + structured form toggle
- [ ] Animated results streaming (cards animate in as sources return)
- [ ] Flight Detail screen (full layout per spec)
- [ ] Pareto bar (Cheapest / Fastest / Best Deal pinned)
- [ ] Haptic feedback on badge renders, BUY NOW tap
- [ ] VoiceOver accessibility audit
- [ ] Dark mode support
- [ ] iPad layout (split view)
- [ ] App icon + launch screen

### Android
- [ ] Material 3 design system
- [ ] Full parity with iOS feature set
- [ ] Motion animations (shared element transitions on result → detail)
- [ ] Edge-to-edge layout (Android 14)
- [ ] Accessibility: TalkBack audit
- [ ] Dark mode + dynamic color (Android 12+)
- [ ] Tablet layout (two-pane)
- [ ] Adaptive app icon

### Shared (Both Platforms)
- [ ] Skeleton loading states (never show empty screens)
- [ ] Error states with retry (no dead ends)
- [ ] Network offline detection + graceful degradation
- [ ] Deeplinks (share a flight → opens in app)
- [ ] Booking handoff deep links (airline / OTA apps or web)

### Deliverable: App Store-ready builds for both platforms.

---

## Phase 5 — Alerts, Polish & Bandit Activation (Weeks 21–23)

**Goal:** Price watch system live; bandit learning activated; app fully polished.

### Price Watch System
- [ ] Alert & Price Watch Agent (background polling every 4h)
- [ ] iOS: `BGAppRefreshTask` for background price checks
- [ ] Android: `WorkManager` periodic task
- [ ] Push notification integration: APNs (iOS) + FCM (Android)
- [ ] Watchlist screen (view, edit, pause, delete watches)
- [ ] Notification templates: price drop, forecast alert, price spike warning
- [ ] Smart default alert threshold (set from forecast `predicted_low`)

### Bandit Activation
- [ ] Interaction event logging live (`POST /events`)
- [ ] Bandit update pipeline: events → Beta distribution updates (nightly)
- [ ] Confidence score grows over time: label → bandit blend activates
- [ ] A/B test framework for ranking strategy experiments

### Airline Scraper Expansion
- [ ] Add scrapers: Emirates, Singapore Airlines, Cathay Pacific, Lufthansa, British Airways
- [ ] Build Scraper Health Monitor (auto-disable broken scrapers, alert team)
- [ ] Proxy rotation strategy for anti-scraping resilience

### LLM-Enhanced Explanations
- [ ] Replace template explanations with Claude-generated natural language
- [ ] Tone: conversational, confident, not overly salesy
- [ ] Explanation personalized to user label (different detail level for EXPERT vs CASUAL)

### Deliverable: Full feature-complete app with live price alerts and improving personalization.

---

## Phase 6 — Beta & Launch (Weeks 24–26)

**Goal:** Public launch in both App Stores.

### Beta Testing
- [ ] iOS: TestFlight invite to 200 beta users
- [ ] Android: Google Play Closed Testing (200 users)
- [ ] Feedback collection: in-app feedback form + Mixpanel/Amplitude funnels
- [ ] Key metrics to track: Search → Result CTR, Result → Detail CTR, Detail → Booking Handoff rate
- [ ] Bug fix sprint (1 week)

### App Store Preparation
- [ ] iOS App Store: screenshots (6.5", 5.5", iPad), description, keywords, privacy labels
- [ ] Android Play Store: feature graphic, screenshots, description, data safety section
- [ ] Privacy policy + terms of service (legal review)
- [ ] GDPR compliance audit (EU users)
- [ ] CCPA compliance audit (California users)
- [ ] Age rating: 4+ (no user content)

### Launch
- [ ] Phased rollout: 10% → 50% → 100% over 2 weeks
- [ ] Monitor crash rates, ANR rates, API error rates
- [ ] On-call rotation for launch week
- [ ] Rollback plan if critical issues detected

### Deliverable: 🚀 SkyAI live on App Store and Google Play.

---

## Post-Launch Priorities (Months 7–12)

| Feature | Why |
|---|---|
| Multi-city search | High user demand, complex routing |
| Hotel bundling | Revenue opportunity + UX convenience |
| Group booking coordination | Shared watchlist for FRIENDS_GROUP / CORPORATE labels |
| Calendar view ("cheapest day to fly") | Key engagement feature, drives repeat opens |
| Fare alert for loyalty sweet spots | Serve LOYALTY_DRIVEN label deeply |
| Airline seat map integration | COMFORT_FIRST and LUXURY labels want this |
| CO₂ emissions per flight | ADVENTURE / ECO-conscious emerging segment |
| Price history chart (full) | Power users want to see the full curve |
| Corporate booking mode | CORPORATE_TRAVELER — policy-aware booking |
| Apple Watch / Wear OS app | Price alert glance + quick watch set |

---

## Team Structure Recommendation

| Role | Phase | Responsibility |
|---|---|---|
| Backend Engineer (×2) | 0–6 | Agent services, APIs, DB, Kafka |
| ML Engineer (×1) | 2–5 | Price classifier, forecasting, bandit |
| iOS Engineer (×1) | 1–6 | Swift/SwiftUI native app |
| Android Engineer (×1) | 1–6 | Kotlin/Compose native app |
| Scraper Engineer (×1) | 1–5 | Tier 3 agents, proxy management, health monitor |
| Product Designer (×1) | 1–5 | UI/UX, design system, screen specs |
| DevOps / Infra (×0.5) | 0–6 | Cloud infra, CI/CD, monitoring |
| Product Manager (×1) | 0–6 | Roadmap, priorities, user research |

---

*Document version: 1.0 — Generated April 2026*
