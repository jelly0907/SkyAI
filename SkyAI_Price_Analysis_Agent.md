# SkyAI — Price Analysis Agent: Deep Design

> This document expands Section 2.4 of the main Agent Design Document with a full specification for the Price Analysis Agent: data ingestion, feature engineering, ML models, classification pipeline, and prediction outputs.

---

## 1. Agent Responsibilities

The Price Analysis Agent answers three questions for every flight in the `FlightPool[]`:

```
1. IS THIS PRICE GOOD RIGHT NOW?
   → Price classification: STEAL / GREAT_DEAL / FAIR / OVERPRICED

2. WILL THE PRICE GO UP OR DOWN?
   → Price forecast for +7, +14, +30 days

3. SHOULD THE USER BOOK NOW OR WAIT?
   → Action recommendation: BUY_NOW / WAIT / SET_ALERT / BOOK_DIRECT
```

---

## 2. Data Infrastructure

### 2.1 Price History Database Schema

All Tier 3 data worker agents write to a central **Price History DB** (TimescaleDB — a time-series extension of PostgreSQL) after every search.

```sql
-- Core price observation table
CREATE TABLE price_observations (
  id              BIGSERIAL PRIMARY KEY,
  observed_at     TIMESTAMPTZ NOT NULL,          -- when we saw this price
  origin          CHAR(3) NOT NULL,              -- IATA airport code (e.g. SFO)
  destination     CHAR(3) NOT NULL,              -- IATA airport code (e.g. NRT)
  departure_date  DATE NOT NULL,                 -- actual flight date
  airline         VARCHAR(3) NOT NULL,           -- IATA carrier code
  flight_number   VARCHAR(8),
  cabin_class     VARCHAR(16) NOT NULL,          -- ECONOMY / BUSINESS / FIRST
  price_usd       NUMERIC(10,2) NOT NULL,        -- total fare including taxes
  currency_source VARCHAR(3),                    -- original currency before conversion
  stops           SMALLINT NOT NULL,
  total_duration  INT NOT NULL,                  -- total trip minutes
  source          VARCHAR(32) NOT NULL,          -- amadeus / skyscanner / gflight / airline_direct
  is_refundable   BOOLEAN,
  baggage_kg      SMALLINT,
  seats_remaining SMALLINT                       -- scarcity signal
);

-- Hypertable for time-series performance (TimescaleDB-specific)
SELECT create_hypertable('price_observations', 'observed_at');

-- Key indexes for fast route lookups
CREATE INDEX ON price_observations (origin, destination, departure_date, cabin_class);
CREATE INDEX ON price_observations (airline, departure_date);
```

### 2.2 Data Ingestion Pipeline

```
Tier 3 Agents (Amadeus, Skyscanner, etc.)
        │
        │  emit PriceObservationEvent
        ▼
    Kafka Topic: raw-price-events
        │
        ▼
    Stream Processor (Apache Flink or Python Kafka consumer)
        ├── Validation (reject nulls, outlier prices)
        ├── Currency normalization → USD (via live FX feed)
        ├── Deduplication (same flight seen from 2 sources within 5 min)
        └── Write to TimescaleDB
        │
        ▼
    Price History DB (TimescaleDB)
        │
        ▼
    Feature Store (pre-computed route statistics, refreshed hourly)
```

### 2.3 Feature Store: Pre-Computed Route Statistics

Heavy aggregations are computed in advance and stored in the Feature Store so real-time analysis is fast:

```python
RouteStats {
  origin:              str,         # "SFO"
  destination:         str,         # "NRT"
  cabin_class:         str,         # "ECONOMY"
  days_out_bucket:     int,         # days until departure (0,1,3,7,14,21,30,45,60,90,120+)

  # Price statistics (rolling 12-month window)
  price_mean:          float,       # $1,047
  price_median:        float,       # $998
  price_stddev:        float,       # $187
  price_p10:           float,       # $712   (10th percentile = steal territory)
  price_p25:           float,       # $842
  price_p75:           float,       # $1,180
  price_p90:           float,       # $1,420  (90th percentile = overpriced)

  # Seasonal patterns
  price_by_month:      float[12],   # average price per calendar month
  price_by_dow:        float[7],    # average price per day of week (Mon–Sun)
  cheapest_month:      int,         # 1–12
  most_expensive_month: int,

  # Lead-time curve
  price_by_days_out:   float[],     # how price changes as departure approaches
  optimal_booking_days: int,        # days in advance that historically yield lowest price
  last_minute_premium: float,       # % price increase in final 7 days

  # Availability signals
  avg_seats_remaining_at_booking: float,
  typical_sellout_days_out:       int,

  # Data quality
  observation_count:   int,         # how many data points (confidence proxy)
  last_updated:        datetime
}
```

---

## 3. Feature Engineering (Per Flight, Real-Time)

When the Price Analysis Agent receives a `FlightPool[]`, it computes the following features for each flight in real-time by joining against the Feature Store:

### 3.1 Price Position Features

```python
def compute_price_features(flight, route_stats):
    current_price = flight.price_usd
    days_out = (flight.departure_date - today()).days

    features = {
        # How does this price compare to history?
        "price_vs_median":      (current_price - route_stats.price_median) / route_stats.price_median,
        "price_percentile":     percentile_rank(current_price, route_stats),
        "price_vs_p10":         current_price - route_stats.price_p10,      # distance from steal threshold
        "price_vs_p90":         current_price - route_stats.price_p90,      # distance from overpriced threshold
        "price_zscore":         (current_price - route_stats.price_mean) / route_stats.price_stddev,

        # Seasonal adjustment
        "seasonal_index":       current_price / route_stats.price_by_month[departure_month],
        "dow_index":            current_price / route_stats.price_by_dow[departure_dow],

        # Lead-time position
        "days_out":             days_out,
        "days_out_bucket":      bucket(days_out),   # 0/1/3/7/14/21/30/45/60/90/120+
        "price_vs_optimal":     current_price - get_optimal_price(days_out, route_stats),
        "vs_typical_at_days_out": current_price - route_stats.price_by_days_out[days_out],

        # Scarcity signals
        "seats_remaining":      flight.seats_remaining,
        "scarcity_flag":        flight.seats_remaining <= 5 if flight.seats_remaining else None,
    }
    return features
```

### 3.2 Temporal & Contextual Features

```python
{
    # Calendar context
    "departure_month":         int,           # 1–12
    "departure_dow":           int,           # 0=Mon, 6=Sun
    "departure_is_holiday":    bool,          # US/international public holiday
    "departure_is_school_break": bool,        # Summer, Spring Break, Christmas
    "booking_to_departure_days": int,         # lead time

    # Event context (major events near destination)
    "nearby_event_flag":       bool,          # Olympics, World Cup, major conference
    "nearby_event_scale":      Enum[SMALL, MEDIUM, LARGE, MEGA],

    # Fuel & macro context
    "fuel_price_index":        float,         # crude oil price (weekly snapshot)
    "route_competition_level": Enum[LOW, MEDIUM, HIGH],  # num airlines on route
    "airline_market_share":    float,         # this airline's share on this route

    # Trend signals (from last 7 days of observations)
    "price_7d_trend":          float,         # % change in the past 7 days
    "price_velocity":          float,         # rate of change (acceleration)
    "price_direction":         Enum[RISING, FALLING, STABLE],
}
```

### 3.3 Flight Quality Features

```python
{
    # Flight attributes
    "stops":                   int,           # 0 = direct
    "total_duration_hours":    float,
    "layover_total_hours":     float,
    "departure_hour":          int,           # 0–23
    "is_red_eye":              bool,          # 21:00–05:00 departure

    # Airline quality signals
    "airline_on_time_pct":     float,         # 0.0–1.0 (last 12 months)
    "airline_cancellation_pct": float,
    "airline_overall_rating":  float,         # 1.0–5.0 (Skytrax / aggregated reviews)
    "aircraft_type":           str,           # "Boeing 787", "Airbus A350"

    # Fare conditions
    "is_refundable":           bool,
    "change_fee_usd":          float,
    "baggage_kg_included":     int,
    "seat_selection_included": bool,
}
```

---

## 4. Model 1: Price Classification

### 4.1 Task Definition

**Input:** Feature vector (all features above, ~45 dimensions)  
**Output:** Price label + confidence score

```
Labels:
  STEAL         → price in bottom 10th percentile historically
  GREAT_DEAL    → price between 10th–30th percentile
  FAIR          → price between 30th–70th percentile
  EXPENSIVE     → price between 70th–90th percentile
  OVERPRICED    → price above 90th percentile
```

### 4.2 Model Architecture

**Primary Model: XGBoost Classifier (multi-class)**

Chosen for:
- Strong performance on tabular data with mixed feature types
- Handles missing values natively (e.g., seats_remaining not always available)
- Fast inference (<5ms per prediction) → suitable for real-time ranking
- Interpretable (SHAP values for explanations)
- Easy to export as CoreML / TFLite for on-device inference

```python
from xgboost import XGBClassifier

model = XGBClassifier(
    n_estimators=500,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    objective='multi:softprob',
    num_class=5,               # STEAL, GREAT_DEAL, FAIR, EXPENSIVE, OVERPRICED
    eval_metric='mlogloss',
    early_stopping_rounds=50,
    tree_method='hist',        # GPU-accelerated training
    device='cuda'
)
```

**Feature Importance (expected ranking after training):**

| Rank | Feature | Why |
|---|---|---|
| 1 | `price_percentile` | Direct historical position |
| 2 | `price_vs_optimal` | vs. best booking window price |
| 3 | `seasonal_index` | Seasonal adjustment |
| 4 | `price_7d_trend` | Momentum signal |
| 5 | `days_out_bucket` | Lead time context |
| 6 | `nearby_event_flag` | Demand shock |
| 7 | `scarcity_flag` | Urgency context |
| 8 | `route_competition_level` | Supply-side signal |

### 4.3 Training Pipeline

```
Data Preparation:
  1. Pull 24 months of price_observations from TimescaleDB
  2. Join with route statistics (Feature Store) to compute features
  3. Label each observation using percentile rules (ground truth)
  4. Handle class imbalance: FAIR dominates → undersample FAIR,
     oversample STEAL using SMOTE
  5. Train/val/test split: 70/15/15, stratified by route + month

Training Schedule:
  → Full retrain: every Sunday night (weekly)
  → Incremental fine-tune: daily (last 48h of new observations)
  → Route-specific models for top 200 routes (more data → better accuracy)
  → Global fallback model for rare routes (cold-start)

Validation Metrics:
  → Macro F1 score (target: >0.82)
  → Precision on STEAL class (target: >0.85) — critical: don't falsely label EXPENSIVE as STEAL
  → Calibration curve (confidence scores must be well-calibrated)
```

### 4.4 On-Device Deployment

The classifier is exported and deployed on mobile for real-time inference:

```
Training (Cloud, weekly):
  XGBoost model → export to ONNX format
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
    CoreML (.mlmodel)          TFLite (.tflite)
    for iOS                    for Android
          │                         │
    CoreML Runtime             ML Kit / TFLite Runtime
    (on-device, <5ms)          (on-device, <5ms)
```

**Model sizes (target):**
- Route-specific model: ~2MB per model (top 200 routes = ~400MB total, downloaded on-demand)
- Global fallback model: ~8MB (always bundled with app)
- Models cached locally, updated via silent background download

---

## 5. Model 2: Price Forecasting

### 5.1 Task Definition

**Input:** Price history for a specific route + current context features  
**Output:** Predicted price for +7, +14, +30 days + confidence interval

```
ForecastOutput {
  current_price:     float,      # $842
  forecast_7d:       float,      # $890  (+5.7%)
  forecast_14d:      float,      # $1,020 (+21.1%)
  forecast_30d:      float,      # $1,190 (+41.3%)

  confidence_7d:     float,      # 0.84 (high)
  confidence_14d:    float,      # 0.71 (medium)
  confidence_30d:    float,      # 0.53 (low — further = less certain)

  predicted_low:     float,      # $788  (expected minimum in next 30d)
  predicted_low_date: date,      # 2026-04-18
  trend:             Enum,       # RISING / FALLING / VOLATILE / STABLE
}
```

### 5.2 Forecasting Models

Two complementary models are ensembled:

#### Model A: Prophet (Facebook/Meta)
Handles seasonality well — captures weekly, monthly, and yearly cycles in flight prices.

```python
from prophet import Prophet

model = Prophet(
    yearly_seasonality=True,
    weekly_seasonality=True,
    daily_seasonality=False,    # not meaningful for flight prices
    seasonality_mode='multiplicative',  # price effects multiply, not add
    changepoint_prior_scale=0.15        # allows for sharp price changes
)

# Add external regressors
model.add_regressor('fuel_price_index')
model.add_regressor('nearby_event_flag')
model.add_regressor('days_until_departure')  # key for flight price dynamics
model.add_regressor('route_competition_level')
```

#### Model B: LSTM (Long Short-Term Memory)
Captures non-linear price dynamics and momentum that Prophet misses.

```python
# Sequence model: 60-day price history → next 30 days
Input:  price_observations[-60 days] + context features
Output: price_prediction[+1 to +30 days]

Architecture:
  Input Layer:  (60, n_features)
  LSTM Layer 1: 128 units, return_sequences=True, dropout=0.2
  LSTM Layer 2: 64 units, dropout=0.2
  Dense Layer:  32 units, ReLU
  Output Layer: 30 units (one per forecast day), Linear

Training:
  Loss:     Huber loss (robust to outliers)
  Optimizer: Adam (lr=0.001, weight decay=1e-4)
  Epochs:   200 with early stopping (patience=20)
  Data:     Route-specific (min 500 observations to train)
```

#### Ensemble Strategy

```python
def ensemble_forecast(prophet_pred, lstm_pred, days_out, observation_count):
    # Prophet is more reliable for seasonal patterns (long-range)
    # LSTM is more reliable for short-range momentum
    if days_out <= 7:
        weight_prophet = 0.35
        weight_lstm    = 0.65
    elif days_out <= 14:
        weight_prophet = 0.50
        weight_lstm    = 0.50
    else:  # 30d
        weight_prophet = 0.70
        weight_lstm    = 0.30

    # Reduce confidence if limited historical data
    data_confidence = min(1.0, observation_count / 500)

    ensemble = weight_prophet * prophet_pred + weight_lstm * lstm_pred
    confidence = base_confidence(days_out) * data_confidence
    return ensemble, confidence
```

---

## 6. Model 3: Action Recommendation Engine

### 6.1 Decision Logic

After classification and forecasting, the Action Recommendation Engine synthesizes both into a **single actionable recommendation** with an explanation.

```python
def recommend_action(classification, forecast, user_label, urgency):

    label = classification.label          # STEAL / GREAT_DEAL / FAIR / EXPENSIVE / OVERPRICED
    trend = forecast.trend                # RISING / FALLING / STABLE / VOLATILE
    days_out = forecast.days_out
    forecast_7d_change = (forecast.forecast_7d - forecast.current) / forecast.current

    # --- URGENT BOOKINGS ---
    if urgency in [VERY_URGENT, URGENT]:
        return Action(
            type=BUY_NOW,
            reason="Departure is soon — price is unlikely to improve significantly.",
            urgency_override=True
        )

    # --- STEAL PRICES ---
    if label == STEAL:
        return Action(
            type=BUY_NOW,
            reason=f"This price is in the bottom {classification.percentile:.0f}% historically. Rare find.",
            badge="🔥 STEAL"
        )

    # --- GREAT DEAL + RISING ---
    if label == GREAT_DEAL and trend == RISING:
        return Action(
            type=BUY_NOW,
            reason=f"Great price and trending up {forecast_7d_change*100:.0f}% in the next week.",
            badge="✅ GREAT DEAL"
        )

    # --- GREAT DEAL + STABLE ---
    if label == GREAT_DEAL and trend == STABLE:
        if user_label.flexLabel == VERY_FLEXIBLE and days_out > 30:
            return Action(
                type=WAIT,
                reason="Good price, but you have time. We'll alert you if it drops further.",
                badge="👀 WATCH"
            )
        else:
            return Action(
                type=BUY_NOW,
                reason="Good price, stable trend. Safe to book now.",
                badge="✅ GOOD VALUE"
            )

    # --- FAIR + FALLING ---
    if label == FAIR and trend == FALLING and days_out > 14:
        return Action(
            type=WAIT,
            reason=f"Price is trending down. Expected to fall ~{abs(forecast_7d_change)*100:.0f}% in 7 days.",
            badge="📉 WAIT"
        )

    # --- EXPENSIVE / OVERPRICED ---
    if label in [EXPENSIVE, OVERPRICED]:
        if days_out < 7:
            return Action(
                type=BUY_NOW,
                reason="Price is high, but departure is near. Unlikely to improve.",
                badge="⚠️ LAST RESORT"
            )
        else:
            return Action(
                type=SET_ALERT,
                reason=f"Price is above historical average. Set an alert for ${forecast.predicted_low:.0f}.",
                alert_target=forecast.predicted_low,
                badge="🔔 SET ALERT"
            )

    # --- FALLBACK ---
    return Action(type=MONITOR, reason="Watching for price changes.")
```

### 6.2 Action Types

| Action | Display | User Experience |
|---|---|---|
| `BUY_NOW` | Green button, badge | Strong CTA; explain why it's good now |
| `WAIT` | Grey button | Show predicted lower price + expected date |
| `SET_ALERT` | Bell icon | Auto-create price watch; user sets threshold |
| `BOOK_DIRECT` | Airline icon | Suggest booking on airline's own site (sometimes cheaper) |
| `MONITOR` | Eye icon | Passive watch; check back in 48h |

---

## 7. Full Agent Output: Enriched Flight Object

```json
{
  "flightId": "ANA-NH0008-20260715-SFO-NRT",
  "airline": "ANA",
  "flightNumber": "NH8",
  "departure": "2026-07-15T10:30:00",
  "arrival": "2026-07-16T14:55:00+09:00",
  "stops": 0,
  "totalDurationMin": 595,
  "cabin": "ECONOMY",
  "price": {
    "amountUSD": 842.00,
    "breakdown": { "baseFare": 701.00, "taxes": 141.00 }
  },
  "priceIntelligence": {
    "historicalMedianUSD": 1047.00,
    "pricePercentile": 19,
    "priceLabel": "GREAT_DEAL",
    "labelConfidence": 0.88,
    "priceBadge": "✅ GREAT DEAL",
    "savingsVsMedian": 205.00,
    "savingsPct": 19.6,
    "forecast": {
      "in7Days": 890.00,
      "in14Days": 1020.00,
      "in30Days": 1190.00,
      "confidence7d": 0.84,
      "trend": "RISING",
      "predictedLow": 810.00,
      "predictedLowDate": "2026-04-18"
    },
    "recommendation": {
      "action": "BUY_NOW",
      "reason": "Great price and rising fast — historically this route peaks above $1,000 by May.",
      "urgency": "HIGH"
    }
  },
  "qualitySignals": {
    "onTimePct": 0.91,
    "aircraftType": "Boeing 787-9",
    "seatWidthInches": 17.5,
    "baggageKgIncluded": 23,
    "isRefundable": false,
    "changeFeeUSD": 200
  },
  "loyaltyInfo": {
    "milesEarned": 4820,
    "eligiblePrograms": ["ANA Mileage Club", "United MileagePlus (Star Alliance)"]
  },
  "source": "amadeus",
  "bookingUrl": "https://..."
}
```

---

## 8. Explanation Layer (User-Facing)

Every price intelligence output generates a **plain-language explanation** for the user. This is critical for trust — users should always understand *why* SkyAI is recommending something.

### Explanation Templates

```
STEAL:
"This price is one of the cheapest we've ever seen on this route.
 Historically, flights from {origin} to {destination} average {median},
 and this is {pct}% below that. Our data shows prices typically
 start rising around {days} days before departure — act now."

GREAT_DEAL + BUY_NOW:
"At ${price}, this is a genuinely good deal — cheaper than {pct}%
 of flights we've recorded on this route. Prices are trending up
 {forecast_change}% this week, so booking now locks in the savings."

WAIT + FALLING:
"The price is fair but falling. Our forecast shows it could drop
 to around ${predicted_low} by {predicted_low_date}. We'll alert
 you the moment it hits that mark."

OVERPRICED + SET_ALERT:
"This price is higher than usual for this route. We're watching
 for prices to drop back toward ${alert_target} — the historical
 sweet spot for {origin}→{destination}. We'll notify you instantly."
```

---

## 9. Model Performance Monitoring

```
Daily Metrics Dashboard:
  ├── Classification accuracy (rolling 7-day window)
  ├── Forecast MAPE (Mean Absolute Percentage Error) at +7/+14/+30 days
  ├── BUY_NOW recommendation → post-booking price comparison
  │     (did price actually go up? validates our buy signal)
  ├── WAIT recommendation → price trajectory validation
  │     (did price actually fall? validates our wait signal)
  ├── Alert trigger accuracy (how often did price hit the alert target?)
  └── Coverage (% of routes with >200 historical observations)

Retraining Triggers (automated):
  → Classification F1 drops below 0.80 → emergency retrain
  → Forecast MAPE exceeds 12% at +7d → investigate + retrain
  → New major airline enters a route → add route to training set
  → External shock detected (fuel price spike, pandemic) → override models
    with rule-based fallbacks until models recalibrate
```

---

*Document version: 1.0 — Generated April 2026*
