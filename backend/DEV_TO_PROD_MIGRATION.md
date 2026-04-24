# SkyAI Backend — Dev → Prod Migration Checklist

Durable checklist for the day we promote the backend from local SQLite to a
production database. Do **not** delete this file when the migration is done —
archive it with the date / commit of the cutover for future reference.

---

## Why this document exists

During development the backend uses **SQLite** for zero-setup persistence. The
code is deliberately written to be portable (SQLAlchemy ORM, env-based
`DATABASE_URL`, async sessions, repository pattern, timezone-aware timestamps),
so swapping to Postgres is a config change plus migrations — not a rewrite.

This file lists every step, ordered, so nothing gets forgotten under pressure.

---

## Phase A — Move to Postgres (first deploy with real users)

### 1. Infrastructure

- [ ] Provision a Postgres 16+ instance (RDS / Cloud SQL / Neon / Supabase).
- [ ] Create the production database and a limited-privilege application user.
- [ ] Open network access from the backend service only (no public access).
- [ ] Set up daily automated backups with at least 7-day retention.
- [ ] Set up monitoring: connection count, slow-query log, disk usage, CPU.

### 2. Backend config

- [ ] Add `asyncpg` (and optionally `psycopg[binary]` for migration scripts) to
      `requirements.txt`.
- [ ] Set `DATABASE_URL=postgresql+asyncpg://user:pw@host:5432/skyai` in the
      production environment (NOT in `.env` committed to git).
- [ ] Configure SQLAlchemy engine with `pool_size=10, max_overflow=5,
      pool_pre_ping=True` — defaults are too conservative for prod.
- [ ] Verify all timestamp columns use `DateTime(timezone=True)` — SQLite
      silently ignored this, Postgres enforces it.

### 3. Schema migration

- [ ] Run `alembic upgrade head` against the empty Postgres DB.
- [ ] Run the integration test suite against a Postgres instance (not SQLite)
      once, to flush out any SQLite-ism that slipped in. Common offenders:
  - [ ] Text `LIKE` comparisons that relied on SQLite's case-insensitive
        default (switch to `ILIKE` or `lower()`).
  - [ ] Boolean columns stored as 0/1 integers in app code.
  - [ ] Any use of `sqlite_master` or `PRAGMA` statements.

### 4. Historical data ETL (only if SQLite has non-trivial data)

- [ ] Write a one-off Python script that reads from `skyai.db` and inserts into
      Postgres using SQLAlchemy ORM (not raw dump), so type coercion is
      consistent with the app.
- [ ] Tables to migrate, in order (respect FK constraints):
      `price_observations` → `price_watches` → `watch_triggers`.
- [ ] Verify row counts match after migration.
- [ ] Spot-check 20 random rows per table.

### 5. Cutover

- [ ] Deploy backend with new `DATABASE_URL`.
- [ ] Smoke-test: `/health`, `POST /search/flights`, `POST /watch`,
      `GET /watch`, `POST /watch/{id}/check`.
- [ ] Keep `skyai.db` file archived for 30 days post-cutover in case of
      rollback need.
- [ ] Remove SQLite fallback paths from the codebase once stable (if any).

---

## Phase B — TimescaleDB (when observation volume crosses ~10M rows)

This is a separate, later migration — trigger is data volume, not user count.

- [ ] Enable the TimescaleDB extension on the Postgres instance
      (`CREATE EXTENSION timescaledb;`).
- [ ] Convert `price_observations` to a hypertable:
      `SELECT create_hypertable('price_observations', 'observed_at');`
- [ ] Add continuous aggregates for the hot read path (route-level price
      percentiles per day/week), so percentile computation in
      `DBRouteStatsProvider` stops scanning full history.
- [ ] Add retention policy (e.g. drop chunks older than 24 months).
- [ ] Benchmark the existing `DBRouteStatsProvider` queries pre- and
      post-hypertable; confirm speedup.
- [ ] Update `DBRouteStatsProvider` to prefer continuous-aggregate tables.

---

## Phase C — Operational hardening (ongoing after cutover)

- [ ] Add read replicas once read load exceeds ~30% of a single instance.
- [ ] Route analytics queries (percentile computation, feed generation) to
      read replicas.
- [ ] Add `pgbouncer` in front of Postgres if connection count gets high.
- [ ] Set up query performance monitoring (pg_stat_statements + dashboards).
- [ ] Review indexes quarterly; drop unused ones.

---

## Things that are NOT on this list (intentionally)

- **Leaving SQLite in prod.** It's not a production database. Don't.
- **Dual-writing** to SQLite and Postgres during cutover. Not worth the
  complexity at this scale; a brief maintenance window is fine.
- **Sharding.** Not until single-Postgres is genuinely exhausted. Very unlikely
  to be needed before 1M+ active users.
