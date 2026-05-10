# SkyAI Roadmap

_Last updated: 2026-05-10_

Forward-looking work list. For "what works today," see the bottom section
**[Current state](#current-state)**.

---

## Track 1 — Production deployment

**Why this matters**: today the iOS app is hardcoded to a LAN IP literal
(`MAC_LAN_IP = "192.168.86.49"` in `ios/SkyAI/Services/APIClient.swift`)
and the Android app hits `10.0.2.2` (emulator only). Neither survives
TestFlight, real-device demos away from home Wi-Fi, or a backend that
needs to run 24/7 for scheduled price checks. Until the backend is
internet-reachable over HTTPS, the project is dev-only.

**Total estimated effort**: ~2.5 hours focused, plus DNS propagation
waits. **Total estimated cost**: $0–10/mo (Fly.io free tier + optional
$8/yr domain).

### Critical path

#### 1. Migrate SQLite → Postgres _(estimated 45 min)_

When deploying to a hosted backend, SQLite no longer works — every
restart wipes the file unless you mount a persistent volume, and you
can't scale past one instance.

**Steps**:

1. Add `asyncpg` and `alembic` to `backend/requirements.txt`.
2. `cd backend && alembic init alembic` to scaffold migrations.
3. Configure `alembic/env.py` to read `DATABASE_URL` from env, point
   `target_metadata` at `db.models_sql.Base.metadata`.
4. Generate the initial migration capturing the current schema:
   ```
   alembic revision --autogenerate -m "initial schema"
   ```
   Inspect the generated file — should create `price_observations`,
   `price_watches`, `watch_triggers` with their indexes and check
   constraints.
5. Drop the SQLite-specific WAL/busy_timeout/synchronous PRAGMA event
   listener in `backend/db/database.py` (Postgres ignores them and the
   listener will error on connect). Wrap the
   `if DATABASE_URL.startswith("sqlite"):` so it only fires when staying
   on SQLite for local dev.
6. Drop the `await init_db()` call in `main.py`'s lifespan — Alembic now
   owns schema creation. Add a release-stage script that runs
   `alembic upgrade head` before each prod deploy.
7. Test locally with
   `DATABASE_URL=postgresql+asyncpg://user:pw@localhost:5432/skyai_dev`
   in a Docker'd Postgres before deploying.

**Why this is small**: every callsite already uses `DATABASE_URL`,
sessions are async, and the schema is plain — no SQLite-specific quirks
in the queries. The only real work is migrations.

---

#### 2. Containerize backend with Dockerfile _(estimated 45 min)_

Package the FastAPI backend as a Docker image so it can deploy to any
cloud platform (Fly.io, Render, Cloud Run, ECS, etc.).

**Blocked by**: #1.

**Steps**:

1. Add `backend/Dockerfile`:
   - Base: `python:3.11-slim`
   - Copy `requirements.txt` first, `pip install --no-cache-dir`, then
     copy source — keeps layer caching efficient.
   - `EXPOSE 8000`
   - `CMD: uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2`
2. Add `backend/.dockerignore` excluding `venv*/`, `__pycache__/`,
   `*.db*`, `.env`, `tests/` so the build context is small.
3. Verify:
   ```
   docker build -t skyai-backend backend/
   docker run -p 8000:8000 --env-file backend/.env skyai-backend
   curl localhost:8000/health     # from another terminal — should 200
   ```
4. If using Fly.io specifically, also add `backend/fly.toml` (generated
   via `fly launch`). Pick a region close to most users (e.g. `iad` for
   US East).

**Files added**:
- `backend/Dockerfile`
- `backend/.dockerignore`
- `backend/fly.toml` (or platform equivalent)

---

#### 3. Deploy backend to Fly.io (or chosen platform) _(estimated 1 hour)_

Deploy the containerized backend with public HTTPS so iOS/Android can
reach it over the internet — no more LAN IPs.

**Blocked by**: #1, #2.

**Decision needed first**: which provider?

- **Fly.io** (recommended): great FastAPI DX, free tier covers a small
  app, auto Let's Encrypt, native Postgres add-on. `fly launch && fly
  deploy`.
- **Render.com**: similar DX, cleaner UI, slower cold starts on free
  tier.
- **Cloud Run / ECS Fargate**: enterprise-grade, more setup, pick if you
  have an org cloud account.

**Steps (Fly.io path)**:

1. Install flyctl: `brew install flyctl`. Authenticate: `fly auth
   signup` or `fly auth login`.
2. From `backend/`: `fly launch` — walks through naming the app (e.g.
   `skyai-prod`), picking a region, attaching a Postgres instance.
   Creates `fly.toml` if not present.
3. Attach Postgres:
   ```
   fly postgres create --name skyai-db
   fly postgres attach skyai-db --app skyai-prod
   ```
   Sets `DATABASE_URL` automatically.
4. Set secrets:
   ```
   fly secrets set \
     DUFFEL_API_KEY="duffel_live_..." \
     FLIGHT_PROVIDER=duffel \
     ALLOWED_ORIGINS="https://skyai.app,https://www.skyai.app"
   ```
5. Deploy: `fly deploy`. Watch the build; verify `fly logs` shows
   "Application startup complete." Then
   `curl https://skyai-prod.fly.dev/health` from anywhere.
6. **Sanity-check end-to-end**: point iOS Release build at the new URL,
   run a JFK→LHR search, see real Duffel offers come back.

**Free-tier note**: Fly's free tier covers shared-cpu-1x with 256 MB
RAM. SkyAI fits comfortably. If you scale beyond free, expect ~$5–10/mo
for the app + ~$5/mo for the Postgres.

---

### Client-side URL splits (parallelizable, all blocked by #3)

#### 4. Split iOS base URL by build configuration _(estimated 30 min)_

Decouple the iOS app's backend URL from hardcoded LAN IPs by reading it
from Info.plist, which gets values from xcconfig files keyed by build
configuration (Debug vs Release). Debug builds keep hitting the dev
backend on LAN; App Store builds hit prod HTTPS.

**Blocked by**: #3.

**Steps**:

1. In Xcode: create two xcconfig files under `ios/SkyAI/Config/`:
   - `Debug.xcconfig` — `API_BASE_URL = http://192.168.86.49:8000`
     (gitignored if you want per-developer values)
   - `Release.xcconfig` —
     `API_BASE_URL = https://skyai-prod.fly.dev` (or your custom domain)
2. In project settings → Configurations, set Debug to use
   `Debug.xcconfig`, Release to use `Release.xcconfig`.
3. In `Info.plist`, add a new key: `API_BASE_URL` of type `String`,
   value `$(API_BASE_URL)`. Xcode substitutes the xcconfig value at
   build time.
4. In `Services/APIClient.swift`, replace the hardcoded `MAC_LAN_IP` /
   `defaultDevBaseURL` block with:
   ```swift
   private func defaultDevBaseURL() -> URL {
       if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
          let url = URL(string: raw) {
           return url
       }
       return URL(string: "http://127.0.0.1:8000")!  // simulator fallback
   }
   ```
5. **xcconfig gotcha**: `//` inside a value is treated as a comment, so
   URLs need a workaround:
   ```
   API_BASE_URL_PROTOCOL = http
   API_BASE_URL = $(API_BASE_URL_PROTOCOL)://192.168.86.49:8000
   ```
6. Test: Build & Run with Debug → app hits dev. Archive with Release
   scheme → confirm the URL is `https://skyai-prod.fly.dev`.

**Bonus**: gitignore `Debug.xcconfig` so each developer sets their own
LAN IP, and commit a `Debug.xcconfig.example` template with comments.

---

#### 5. Drop NSAllowsLocalNetworking from iOS Release Info.plist _(estimated 20 min)_

Production traffic goes over HTTPS, so the App Transport Security
exceptions added for dev (`NSAllowsLocalNetworking` /
`NSAllowsArbitraryLoads`) are no longer needed in Release builds.
Keeping them in a shipped app is an App Store review red flag and
weakens the app's security posture.

**Blocked by**: #3.

**Steps**:

1. Verify the prod backend URL is HTTPS (Fly.io / Render / etc. all
   give you HTTPS by default).
2. Move `NSAppTransportSecurity` block out of the shared `Info.plist`
   and into a Debug-only Info.plist override (or use a build-phase
   script to strip it from Release).
3. Cleanest pattern: keep `Info.plist` minimal; put dev-only ATS
   exceptions in a `Info-Debug.plist` referenced only by the Debug
   build configuration. Set "Info.plist File" build setting
   per-configuration.
4. Test: Archive a Release build, run with Charles/Proxyman, confirm
   it refuses to talk to plain HTTP.

**Why it matters**:

- App Store reviewers ding apps that ship with
  `NSAllowsArbitraryLoads = true`.
- ATS exceptions hide misconfigurations: a Release build that
  accidentally points at HTTP would silently work in dev, fail in
  production.

---

#### 6. Split Android base URL by build flavor _(estimated 30 min)_

Equivalent of the iOS Debug/Release URL split, for the Android client.

**Blocked by**: #3.

**Steps**:

1. In `android/app/build.gradle.kts`, define two build types (or
   product flavors):
   ```kotlin
   buildTypes {
       debug {
           buildConfigField("String", "API_BASE_URL", "\"http://10.0.2.2:8000/\"")
       }
       release {
           isMinifyEnabled = true
           buildConfigField("String", "API_BASE_URL", "\"https://skyai-prod.fly.dev/\"")
           proguardFiles(...)
       }
   }
   buildFeatures { buildConfig = true }
   ```
2. In `RetrofitClient.kt`, replace the hardcoded `BASE_URL` constant
   with `BuildConfig.API_BASE_URL`.
3. Remove `android:usesCleartextTraffic="true"` from
   `AndroidManifest.xml`, and replace it with a
   `network_security_config.xml` that allows cleartext only for
   `10.0.2.2` (emulator) and the LAN subnet — and only in Debug.
   Release uses HTTPS exclusively.
4. Test: `./gradlew assembleDebug` → APK points to emulator-friendly
   URL. `./gradlew assembleRelease` → APK points to prod HTTPS,
   cleartext blocked.

---

#### 7. Wire custom domain to backend _(estimated 30 min plus DNS wait)_

Replace the platform-default URL (`skyai-prod.fly.dev`) with a real
domain like `api.skyai.app`. Looks more professional, gives you
portability between providers (no client update if you change
platforms), keeps URLs stable.

**Blocked by**: #3.

**Steps (Fly.io)**:

1. Buy a domain if you don't have one. Cloudflare Registrar is at-cost
   ~$8/yr for `.app` TLDs.
2. In Cloudflare DNS, add an `A` record for `api.skyai.app` pointing at
   the Fly app's IPv4 (get it via `fly ips list`). Optionally add `AAAA`
   for IPv6.
3. From `backend/`: `fly certs add api.skyai.app` — Fly provisions
   Let's Encrypt certs and serves the domain.
4. Confirm: `curl https://api.skyai.app/health` returns the same JSON
   as the `.fly.dev` URL.
5. Update both iOS `Release.xcconfig` and Android release buildType to
   point at the new URL. Rebuild.
6. Leave the `.fly.dev` URL working (Fly serves both) as a fallback
   during rollouts.

---

### Production track architecture target

```
            ┌────────────────────────────────────┐
            │ FastAPI on Fly.io (or similar)     │
iOS  ── HTTPS ──▶  ─ Postgres add-on             │ ─── Duffel API
Android         │  ─ TLS cert (Let's Encrypt)    │
            │  ─ DNS: api.skyai.app              │
            └────────────────────────────────────┘
```

---

## Track 2 — Feature work (parallel to production track)

### A. Mirror the iOS watchlist Phase-2 wire-up onto Android _(estimated 1 hour)_

The iOS client now talks to `/watch` endpoints end-to-end (POST from
flight detail, GET on tab open, POST `/check` per row, DELETE on
remove). Android still has the pre-Phase-2 local-only scaffold with
hardcoded sample data — the `/watch` endpoints exist in the backend
but Android never calls them.

**Mechanical work**, mirroring the iOS pattern:

1. Add `WatchApiService` methods in
   `android/app/src/main/java/com/skyai/app/data/api/SkyAIApiService.kt`:
   - `@POST("/watch") suspend fun createWatch(@Body req: WatchCreateRequest): WatchResponse`
   - `@GET("/watch") suspend fun listWatches(@Query("user_id") userId: String): List<WatchResponse>`
   - `@POST("/watch/{id}/check") suspend fun checkWatch(@Path("id") id: String): WatchCheckResponse`
   - `@DELETE("/watch/{id}") suspend fun deleteWatch(@Path("id") id: String): Response<Unit>`
2. Add Kotlin wire models to `data/model/PriceWatch.kt`, mirroring the
   iOS Codable structs:
   - `WatchCreateRequest` (camelCase fields, snake_case via
     `@SerializedName`)
   - `WatchResponse` with all 18 backend fields plus a computed
     `derivedStatus` property
   - `WatchCheckResponse` embedding the updated watch + reason
3. Rewire `WatchlistViewModel.kt`: drop the local persistence /
   hardcoded sample data, replace with `Flow<List<WatchResponse>>`
   sourced from the API.
4. Rewrite `WatchlistScreen.kt` to render `WatchResponse` fields
   instead of the legacy local `PriceWatch` (origin, destination,
   formatted date range, last seen price, target price, last checked
   time, status badge, Check Now button per row).
5. Add a "Watch this price" button to `FlightDetailScreen.kt` —
   mirror the iOS `Watch` pill button, talk to APIClient directly,
   show a confirmation Snackbar.

iOS work just landed in commits between
`ios/SkyAI/Models/PriceWatch.swift` and
`ios/SkyAI/Views/Watchlist/WatchlistView.swift` — use those files as
the template for the Android equivalents.

---

### B. Background scheduler for re-running watches _(estimated 1–2 hours)_

Today watches only re-evaluate when someone taps "Check" in the app. A
real product re-runs every active watch periodically (every N minutes /
hours) so users get push alerts naturally.

**Steps**:

1. Pick a scheduling mechanism. Options:
   - APScheduler (in-process) — simplest, dies if uvicorn restarts.
   - Celery + Redis — proper job queue, more moving parts.
   - Fly.io's cron-machine feature — separate VM that runs scheduled
     tasks against the main app's API. Cleanest with the deployment
     story.
2. Add a `re_check_all_active_watches()` task that:
   - Queries `price_watches WHERE active = TRUE AND triggered_at IS NULL`.
   - Calls the existing `_check_watch` logic per row.
   - Updates `last_checked_at` / `last_price_usd` / `last_label` / etc.
3. Schedule every ~6 hours initially (Duffel rate limits + cost of
   queries). Make the interval env-driven so it's tunable.
4. Once running, the manual "Check" button in the UI becomes a "force
   re-check now" override rather than the only way it ever happens.

**Note**: real push notifications (APNs/FCM) on trigger are part of
**Phase 3**. For now, alerts just sit in the database; the user sees
them when they open the Watchlist tab.

---

### C. Android multi-stop search edge case _(estimated 15 min if Logcat helpful, longer if buried)_

Currently papered over by defaulting `SearchFormState.directOnly = true`.
When the user toggles it off, multi-stop searches don't render results
on Android — symptom unclear (no Logcat captured yet). Three
hypotheses:

1. Duffel slowness with `max_connections=1` — backend taking >30 sec
   on multi-leg routes, OkHttp times out. Fix: bump OkHttp timeouts in
   `RetrofitClient.kt` to 60 sec.
2. JSON deserialization fails on a specific multi-stop offer field
   that's null/missing — would show as `JsonSyntaxException` in
   Logcat without the `OkHttp` filter.
3. UI thread crash during render of a multi-segment card — would show
   as `IndexOutOfBoundsException` from FlightCard or
   ItineraryBreakdown.

**Diagnostic step**: with `directOnly` toggled off, run a JFK→LHR
search, capture full Logcat (no filter) for ~30 seconds after the
search. The cause will be visible in red.

Once fixed, flip the default back to `false` in
`SearchFormState.directOnly` and update the comment block above it.

---

### D. Polish

#### D1. Real Android launcher icon _(estimated 15 min)_

The white-plane-on-blue vector I generated (`drawable/ic_launcher_*.xml`)
is functional but not designed. For a public release, swap in something
properly designed via Android Studio's Image Asset Studio (or an
external designer). Keep the adaptive-icon XML structure but replace
the foreground vector with the real artwork.

#### D2. Onboarding / profile polish _(estimated 30 min)_

The onboarding flow exists in both apps but is sparse (three screens of
placeholder copy). The Profile tab is mostly empty. Both should be
filled in before public release — collect user's home airport, preferred
cabin, default passenger count, then have the Search form prefill from
those defaults.

---

## Track 3 — Phase 3 (deferred, multi-day each)

These aren't immediate priorities but they exist in mental backlog so
they're worth capturing.

- **Auth**: replace `user_id="demo-user"` with a real authentication
  flow. Sign in with Apple + Google. Likely Auth0 or Firebase Auth as
  a managed service. Touches every backend endpoint that takes
  `user_id`.
- **Push notifications**: APNs for iOS, FCM for Android. Tied to the
  scheduler (Track 2 / B). When a watch triggers in the background
  re-check loop, fire a push.
- **History tab**: list past searches with their results, lets users
  re-run them with one tap.
- **Favorites / saved offers**: lightweight bookmarking distinct from
  Watches.
- **Booking deep-link / handoff to Duffel checkout**: today the app
  shows offers but can't book. Duffel has a checkout API; integrate it
  so users can complete the purchase in-app or via a deep link.

---

## Current state

_As of 2026-05-10._

**Working end-to-end on iOS, physical device, home Wi-Fi**:
- Natural-language search ("JFK to LHR next Friday")
- Structured search form
- Results list with sort (price / duration / best-deal)
- Pareto bar (cheapest / fastest / best deal)
- Flight detail view with full segment breakdown for multi-stop trips
- Real Duffel sandbox data (no more mocks except as fallback)
- Price intelligence labels (STEAL / GREAT_DEAL / FAIR / ABOVE AVG /
  OVERPRICED) driven by real DB-derived percentiles once `price_observations`
  accumulates ≥10 rows for the route
- Watch this price → backend persists → Watchlist tab shows it →
  Check Now re-runs the search and updates the row, optionally
  triggering it

**Working on Android emulator**:
- Same search flow as iOS
- Results render with all the new badge/trend/action enum cases
- `directOnly` defaults to true — multi-stop edge case parked

**Backend**:
- Phase 2 complete: Duffel integration, DB-backed price-intelligence
  chain (`DBRouteStatsProvider → MockRouteStatsProvider` fallback),
  `_log_observations` writes every search response as 50 rows
- SQLite WAL mode + busy_timeout for concurrent reads
- BackgroundTasks for observation logging so search latency doesn't
  wait on the bulk insert
- `/watch` endpoints fully functional (create / list / get / delete /
  check)

**Where the dev environment is fragile**:
- iOS pinned to `MAC_LAN_IP = "192.168.86.49"`. Survives DHCP rolls on
  a stable home network; breaks if your Mac's IP changes (rare). The
  earlier mDNS-based `.local` URL caused AWDL routing issues — IP
  literal is more durable for solo dev. Production split (#4) replaces
  this entirely.
- Android emulator hits `10.0.2.2:8000`. Physical Android device needs
  the same `192.168.86.49` swap; see comments in `RetrofitClient.kt`.
- Backend over plain HTTP. `NSAllowsLocalNetworking` / Android
  `usesCleartextTraffic="true"` accommodate this. Both go away with
  Track 1.

---

## Quick reference — file locations

| Concern | Path |
|---------|------|
| Backend entry point | `backend/main.py` |
| Backend Duffel integration | `backend/duffel_client.py` |
| Price intelligence engine | `backend/price_intel/` |
| SQLite/Postgres config | `backend/db/database.py` |
| iOS API client | `ios/SkyAI/Services/APIClient.swift` |
| iOS watch UI | `ios/SkyAI/Views/Watchlist/WatchlistView.swift` |
| iOS watch view model | `ios/SkyAI/ViewModels/WatchlistViewModel.swift` |
| Android API service | `android/app/src/main/java/com/skyai/app/data/api/SkyAIApiService.kt` |
| Android Retrofit base URL | `android/app/src/main/java/com/skyai/app/data/api/RetrofitClient.kt` |
| Android watch UI | `android/app/src/main/java/com/skyai/app/ui/watchlist/WatchlistScreen.kt` |
