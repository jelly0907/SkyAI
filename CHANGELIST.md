# SkyAI — Consolidated Changelist

This captures every file change since we started the "get iPhone → backend working" session, so you can copy them into your Xcode project and the backend in one pass.

All paths are relative to `/Users/stone/Documents/VSCode/SkyAI`.

---

## Backend changes (apply once, then restart uvicorn)

### 1. `backend/routes/watch.py` — Fix FastAPI 204 assertion on DELETE

- Add `Response` to the `fastapi` import line.
- On the DELETE endpoint:
  - Add `response_class=Response` to the route decorator.
  - Remove `-> None` annotation (or any annotation — an annotated return type causes FastAPI to try to generate a body, which trips `AssertionError: Status code 204 must not have a response body`).
  - Return an explicit `Response(status_code=204)`.

### 2. `backend/requirements.txt` — Pin greenlet

Add this line (SQLAlchemy async needs it, but it's not a hard dep):

```
greenlet==3.1.1
```

Then `pip install -r requirements.txt`.

### 3. `backend/main.py` — Log every 422

Adds a `RequestValidationError` handler that logs the exact Pydantic errors + request body, so future schema drift between iOS/Android and backend is obvious in the uvicorn terminal.

Imports:

```python
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
```

Handler (drop it between the routers include and the health route):

```python
@app.exception_handler(RequestValidationError)
async def log_validation_error(request: Request, exc: RequestValidationError):
    try:
        body_bytes = await request.body()
        body_preview = body_bytes.decode("utf-8", errors="replace")[:2000]
    except Exception:
        body_preview = "<unreadable>"
    logger.warning(
        "422 on %s %s\n  errors: %s\n  body: %s",
        request.method,
        request.url.path,
        exc.errors(),
        body_preview,
    )
    return JSONResponse(status_code=422, content={"detail": exc.errors()})
```

### 4. `backend/mock_data.py` — Fix `TypeError: 'hour' is an invalid keyword argument for replace()`

The mock generator called `.replace(hour=…, minute=…)` on `req.return_date`, but `req.return_date` is a `datetime.date` (no time). Three call sites pass `ret_dt` into `_make_offer`; all three need to upgrade `date → datetime`.

Import line:

```python
from datetime import datetime, time, timedelta, timezone
```

At each of the three places where `ret_dt = req.return_date` appears, replace with:

```python
ret_dt = (
    datetime.combine(req.return_date, time.min, tzinfo=timezone.utc)
    if req.return_date else None
)
```

---

## iOS changes — copy these files into your Xcode project verbatim

These files already have the final contents on disk at the paths shown. They are:

- `ios/SkyAI/Services/APIClient.swift`
- `ios/SkyAI/Models/Flight.swift`
- `ios/SkyAI/Views/FlightCardView.swift`
- `ios/SkyAI/Views/FlightDetailView.swift`
- `ios/SkyAI/Info.txt` (documentation only, no code)

Below is what each one changed and why.

### 5. `ios/SkyAI/Services/APIClient.swift`

Two changes:

1. **Base URL → Mac LAN IP** so the iPhone can reach the dev backend:
   ```swift
   private init(baseURL: URL = URL(string: "http://192.168.86.144:8000")!) {
   ```
   (Swap back to `http://localhost:8000` when running in the Simulator, or update when your Mac's IP changes.)

2. **Dates encoded as `"YYYY-MM-DD"`, not ISO8601 datetime**, because backend Pydantic `date` fields reject full datetimes with a 422:
   ```swift
   private func makeJSONEncoder() -> JSONEncoder {
       let encoder = JSONEncoder()
       encoder.keyEncodingStrategy = .convertToSnakeCase
       let dateOnlyFormatter = DateFormatter()
       dateOnlyFormatter.calendar = Calendar(identifier: .iso8601)
       dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
       dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
       dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
       encoder.dateEncodingStrategy = .formatted(dateOnlyFormatter)
       return encoder
   }
   ```

### 6. `ios/SkyAI/Models/Flight.swift` — The big rewrite

This is the one that actually un-breaks response decoding. Strategy: **stored properties now mirror backend exactly, but legacy property names are preserved as computed properties** so the rest of the UI/VM code compiles unchanged.

What changed:

**Enum wire values → UPPERCASE** (matches backend Pydantic):

- `CabinClass`: `"ECONOMY"`, `"PREMIUM_ECONOMY"`, `"BUSINESS"`, `"FIRST"`
- `PriceLabel`: `"STEAL"`, `"GREAT_DEAL"`, `"FAIR"`, `"EXPENSIVE"`, `"OVERPRICED"`, `"UNKNOWN"`
- `PriceTrend`: `"RISING"`, `"FALLING"`, `"STABLE"`, `"VOLATILE"`
- `ActionType`: `"BUY_NOW"`, `"WAIT"`, `"SET_ALERT"`, `"MONITOR"`

**`SearchRequest.CodingKeys`** renamed to match backend:
- `origin_code` → `origin`
- `destination_code` → `destination`
- `direct_flights_only` → `non_stop_only`

**All response structs rewritten** (see the file on disk for exact code):

- `Segment` — stored: `origin, destination, departureAt, arrivalAt, carrierCode, flightNumber, aircraftCode, durationMinutes, cabin`. Legacy computed: `departureAirport, arrivalAirport, departureTime, arrivalTime, airlineCode, aircraft, stops (=0 now that stops live on Itinerary)`.
- `Itinerary` — stored: `segments, totalDurationMinutes, stops`. Legacy: `durationMinutes, totalStops, formattedDuration`.
- `PriceBreakdown` — stored: `totalUsd, baseFareUsd, taxesUsd, feesUsd, perAdultUsd`. Legacy: `basePrice, taxes, fees, total`.
- `BaggageInfo` — stored: `checkedBagsIncluded, carryOnIncluded, checkedBagWeightKg`. Legacy: `carryon (String), checkedBags, checkedWeight`.
- `FareConditions` — stored: `isRefundable, changeFeeUsd, fareClass`. Legacy: `refundable, changeable, minStayDays (=nil)`.
- `PriceIntelligence` — stored: `priceLabel, pricePercentile, savingsVsMedianUsd, savingsPct, trend, forecast7dUsd, forecast14dUsd, action, actionReason, badgeText, confidence`. Legacy: `percentileRank, savingsAmount, savingsPercent, recommendedAction, explanation, historicalAverage/Min/Max (=nil)`.
- `FlightOffer` — stored: `offerId, source, itineraries, priceBreakdown, baggageInfo, fareConditions, seatsRemaining, priceIntelligence, bookingUrl, lastTicketingDate`. Legacy: `id, outbound, inbound, availableSeats, totalDuration, totalStops, priceLabel, price`.
- `SearchResponse` — stored: `queryId, searchRequest, offers, totalFound, sourcesQueried, returnedAt, currency`. Legacy: `searchTimestamp`.

Net effect: `ResultsView`, `ResultsViewModel`, `FlightCardView`, `FlightDetailView`, `SearchView`, `HomeViewModel`, etc. all compile without further edits — they read the legacy names.

### 7. `ios/SkyAI/Views/FlightCardView.swift` & `ios/SkyAI/Views/FlightDetailView.swift`

Only the `#Preview` blocks at the bottom of each file changed — they construct a `FlightOffer` directly, which means they can't use the legacy facade and must be rewritten for the new init. The view body code in both files is unchanged.

The rewritten previews now pass `offerId, source, itineraries: [...]`, a new-shape `PriceBreakdown(totalUsd:baseFareUsd:taxesUsd:feesUsd:perAdultUsd:)`, `BaggageInfo(checkedBagsIncluded:carryOnIncluded:checkedBagWeightKg:)`, `FareConditions(isRefundable:changeFeeUsd:fareClass:)`, and the full `PriceIntelligence(priceLabel:pricePercentile:savingsVsMedianUsd:savingsPct:trend:forecast7dUsd:forecast14dUsd:action:actionReason:badgeText:confidence:)`.

### 8. `ios/SkyAI/Info.txt`

Doc-only: base URL line updated from `localhost` to `192.168.86.144`. Not compiled — no action required if you don't care.

---

## Apply order

1. Pull the four backend changes → `pip install -r requirements.txt` → restart `uvicorn main:app --reload --host 0.0.0.0 --port 8000`.
2. In Xcode, replace the five iOS files with the versions now at these paths:
   - `ios/SkyAI/Services/APIClient.swift`
   - `ios/SkyAI/Models/Flight.swift`
   - `ios/SkyAI/Views/FlightCardView.swift`
   - `ios/SkyAI/Views/FlightDetailView.swift`
3. Clean build folder (`Cmd+Shift+K`) and rebuild.
4. Run the iPhone and hit search — you should see offers, no more `Failed to decode response`.

## If anything still breaks

- **422 on the request side** → check the uvicorn terminal. The new 422 logger will print the exact field and value that failed Pydantic validation.
- **Decoding error on the response side** → the missing-key diagnostic in Swift will name the first key it couldn't find; compare that against `backend/models.py` and the new stored properties in `Flight.swift`.
