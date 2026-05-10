# SkyAI — Features Overview

_Last updated: 2026-05-10_

A multi-agent flight finder that combines real flight inventory with a
data-driven recommendation layer. Three components: iOS app, Android
app, FastAPI backend. Live Duffel sandbox data drives everything.

For forward-looking work, see [`ROADMAP.md`](./ROADMAP.md).

---

## Search

**Natural-language search.** Type "JFK to LHR next Friday" or "cheapest
roundtrip to Tokyo in July for 2 adults" and the backend parses it into
a structured query — origin, destination, dates, passengers, cabin
class, trip type, direct-flight preference. The parsed interpretation
is displayed back ("Roundtrip flight: JFK → LHR, departing May 15, 2026
…") so the user can confirm before searching.

**Structured search form.** Manual entry as an alternative — airport
pickers, date selection, passenger counters (adults / children /
infants up to 9 each), cabin class dropdown (Economy / Premium Economy
/ Business / First), trip type (Roundtrip / One-way / Multi-city),
direct-only toggle.

**Live results from Duffel.** Real flight inventory across 300+
airlines via the Duffel sandbox API. Each search returns up to 50
offers including nonstops and connecting itineraries.

---

## Results

**Sortable offer list.** Three sort orders: cheapest first, fastest
first, best deal (highest price-intelligence percentile rank).

**Pareto bar.** Persistent bottom row showing one-tap shortcuts to the
cheapest offer, fastest offer, and best-deal offer — three different
optima visible at all times.

**Card-level summary.** Per offer: airline + flight number, route with
stop count and durations, total roundtrip price, price-intelligence
badge.

---

## Price intelligence

This is the layer that sets SkyAI apart from a generic flight
aggregator. Every offer gets enriched with:

**Six-level price label.** STEAL, GREAT_DEAL, FAIR, ABOVE AVG,
OVERPRICED, or UNKNOWN — derived from how the offer's price compares
against historical percentiles for that route, cabin, and time window.

**Percentile rank.** Where this price sits in the distribution of
recent observations (e.g. "bottom 6% of fares we've recorded on this
route"). Driven by real observations stored in the backend's
`price_observations` table; every search response writes 50 new rows,
so the engine gets smarter the more the app is used.

**Trend signal.** RISING / FALLING / STABLE / VOLATILE based on price
movement over the last 7/14 day horizon.

**Forecast.** Predicted price 7 and 14 days out, surfaced on the
detail view.

**Recommended action.** BUY_NOW / WAIT / SET_ALERT / MONITOR — one of
four engine-chosen recommendations, with a human-readable reason
("_This price is in the bottom 6% of fares we've recorded on this
route. The historical average is $708. Prices are trending stable —
act now._").

**Confidence score.** 0.0–1.0, derived from sample size. Low-confidence
calls explicitly say so.

---

## Flight detail view

**Full multi-segment breakdown.** Every leg of every itinerary surfaced
individually, with layover times between connections (color-coded: red
if <60 min, orange if >5 hr).

**Price intelligence section.** Detailed view of label, percentile bar,
trend chip, forecast row, and the engine's full reasoning paragraph.

**Fare conditions.** Refundable / non-refundable, change-fee USD, fare
class.

**Baggage info.** Checked bags included, carry-on policy, weight
limits.

**Seats remaining indicator** where Duffel exposes it.

---

## Price watches

**"Watch this price" from any offer.** Tap the bell on the flight
detail screen — backend stores a `PriceWatch` row pinned to that exact
route, dates, cabin, and passenger count. Current price becomes the
target alert threshold.

**Watchlist tab.** Two sections: Active Watches and Past Alerts.

**Active Watches** — each card shows route, dates, last-seen price +
its current label badge, target alert price, last-checked relative
time ("3m ago"). Per-row "Check now" button.

**Past Alerts** — watches that triggered (last-seen price hit the
target, or the engine classified the latest as STEAL/GREAT_DEAL). Shows
how many times that watch has fired.

**"Check now" action.** Forces an immediate price refresh — backend
re-runs the Duffel search for that exact route + dates, classifies the
cheapest, updates the row in place. If trigger criteria are met (price
≤ target OR engine labeled it a steal), the row moves to Past Alerts
and a result toast explains why.

**Pull to refresh** + on-appear auto-refresh so new watches created
from the detail view show up immediately when you switch tabs.

---

## Backend architecture (what makes the labels real)

**Provider abstraction.** Backend speaks to Duffel today; Amadeus and
mock-data providers are also wired in. Switching is a single env-var
flip.

**Fallback chain for price intelligence.** `DBRouteStatsProvider →
MockRouteStatsProvider`. The DB provider computes p10/p25/p50/p75/p90
by linear interpolation over recent observations; if a route has fewer
than 10 observations (cold start) the engine gracefully degrades to
hardcoded mock baselines.

**Observation logging.** Every search response writes 50
`PriceObservation` rows to the database — origin, destination, dates,
airline, flight number, cabin, price, label. Runs as a FastAPI
BackgroundTask so search latency isn't gated on the insert. This is
what makes the price intelligence sharper over time.

**Watch evaluation.** `/watch/{id}/check` calls the same code path as
`/search/flights`, finds the cheapest current offer, classifies via
the engine, persists `last_*` fields, fires the trigger if criteria
match. Each check appends a row to `watch_triggers` for audit.

**SQLite WAL mode + busy_timeout** so concurrent reads don't block
writes during dev. Postgres-ready: schema is portable, all queries are
async, the migration is a single env-var change (planned in
[`ROADMAP.md`](./ROADMAP.md)).

---

## Cross-platform parity

iOS and Android share the same backend wire format exactly — same
`cabin_class` UPPERCASE convention, same `non_stop_only` field name,
same `WatchResponse` schema. The two clients are interchangeable from
the server's perspective, which means a price watch created from iOS
shows up unchanged in Android and vice versa once both clients point
at the same backend.

---

## What's not in the app yet

(Tracked in [`ROADMAP.md`](./ROADMAP.md) for future work.)

- Backend deployed to a public HTTPS endpoint (today: localhost on dev
  Mac).
- Scheduled background re-checks (today: watches only update when user
  taps Check).
- Real authentication (today: every user is `demo-user`).
- Push notifications when a watch triggers.
- Booking handoff to Duffel checkout (today: app shows offers but
  can't book).
- Android watch-creation UI parity with iOS (today: Android still has
  the pre-Phase-2 local-only scaffold).

---

## In one sentence

**SkyAI is a flight-finder that doesn't just show you prices — it
tells you whether the price is good, where it's heading, and pings you
when it drops.**
