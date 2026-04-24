"""
SkyAI — Price Watch Alert API.

Endpoints:
  POST    /watch              — create a watch
  GET     /watch              — list watches (filter by user_id query param)
  GET     /watch/{id}         — get one watch
  DELETE  /watch/{id}         — cancel a watch
  POST    /watch/{id}/check   — run one check now; updates last_* and may fire trigger
"""

from __future__ import annotations

import logging
from datetime import date, datetime, time, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from db.database import get_session
from db.models_sql import PriceWatch
from db.repositories import WatchRepo
from models import (
    CabinClass,
    FlightOffer,
    PriceLabel,
    SearchRequest,
    TripType,
    WatchCheckResponse,
    WatchCreateRequest,
    WatchResponse,
)
from price_intel.provider import get_price_intel_engine

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/watch", tags=["watch"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _to_datetime(d: Optional[date]) -> Optional[datetime]:
    """Store dates as UTC-midnight timestamps (portable across DBs)."""
    if d is None:
        return None
    return datetime.combine(d, time.min, tzinfo=timezone.utc)


def _to_date(dt: Optional[datetime]) -> Optional[date]:
    if dt is None:
        return None
    return dt.date()


def _to_response(w: PriceWatch) -> WatchResponse:
    return WatchResponse(
        id=w.id,
        user_id=w.user_id,
        origin=w.origin,
        destination=w.destination,
        departure_date=_to_date(w.departure_date),  # type: ignore[arg-type]
        return_date=_to_date(w.return_date),
        cabin_class=CabinClass(w.cabin_class),
        adults=w.adults,
        max_stops=w.max_stops,
        target_price_usd=w.target_price_usd,
        notify_on_great_deal=w.notify_on_great_deal,
        active=w.active,
        created_at=w.created_at,
        last_checked_at=w.last_checked_at,
        last_price_usd=w.last_price_usd,
        last_label=PriceLabel(w.last_label) if w.last_label else None,
        triggered_at=w.triggered_at,
        trigger_count=w.trigger_count,
    )


async def _fetch_offers_for_watch(
    request: Request, watch: PriceWatch
) -> list[FlightOffer]:
    """Run the same flight-search code path the /search/flights route uses."""
    provider = getattr(request.app.state, "provider", "mock")

    search_req = SearchRequest(
        origin=watch.origin,
        destination=watch.destination,
        departure_date=_to_date(watch.departure_date),  # type: ignore[arg-type]
        return_date=_to_date(watch.return_date),
        adults=watch.adults,
        cabin_class=CabinClass(watch.cabin_class),
        trip_type=TripType.ROUNDTRIP if watch.return_date else TripType.ONE_WAY,
        non_stop_only=(watch.max_stops == 0),
    )

    if provider == "mock":
        from mock_data import generate_mock_offers
        offers = generate_mock_offers(search_req)
    else:
        client = request.app.state.flight_client
        offers = await client.search_flights(search_req)

    if watch.max_stops is not None:
        offers = [o for o in offers if o.total_stops <= watch.max_stops]
    return offers


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post(
    "",
    response_model=WatchResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a price watch",
)
async def create_watch(
    body: WatchCreateRequest,
    session: AsyncSession = Depends(get_session),
) -> WatchResponse:
    if body.return_date and body.return_date < body.departure_date:
        raise HTTPException(
            status_code=422,
            detail="return_date cannot be before departure_date.",
        )

    watch = PriceWatch(
        user_id=body.user_id,
        origin=body.origin.upper(),
        destination=body.destination.upper(),
        departure_date=_to_datetime(body.departure_date),  # type: ignore[arg-type]
        return_date=_to_datetime(body.return_date),
        cabin_class=body.cabin_class.value,
        adults=body.adults,
        max_stops=body.max_stops,
        target_price_usd=body.target_price_usd,
        notify_on_great_deal=body.notify_on_great_deal,
        active=True,
    )
    repo = WatchRepo(session)
    watch = await repo.create(watch)
    logger.info("Created watch %s for %s %s→%s",
                watch.id, watch.user_id, watch.origin, watch.destination)
    return _to_response(watch)


@router.get(
    "",
    response_model=list[WatchResponse],
    summary="List watches for a user",
)
async def list_watches(
    user_id: str = Query(..., description="Filter by user_id (required until auth lands)."),
    active_only: bool = Query(False),
    session: AsyncSession = Depends(get_session),
) -> list[WatchResponse]:
    repo = WatchRepo(session)
    watches = await repo.list_for_user(user_id, active_only=active_only)
    return [_to_response(w) for w in watches]


@router.get(
    "/{watch_id}",
    response_model=WatchResponse,
    summary="Get one watch",
)
async def get_watch(
    watch_id: str,
    session: AsyncSession = Depends(get_session),
) -> WatchResponse:
    repo = WatchRepo(session)
    w = await repo.get(watch_id)
    if not w:
        raise HTTPException(status_code=404, detail="Watch not found.")
    return _to_response(w)


@router.delete(
    "/{watch_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    summary="Delete (cancel) a watch",
)
async def delete_watch(
    watch_id: str,
    session: AsyncSession = Depends(get_session),
):
    repo = WatchRepo(session)
    ok = await repo.delete(watch_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Watch not found.")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{watch_id}/check",
    response_model=WatchCheckResponse,
    summary="Run one price check for this watch",
)
async def check_watch(
    watch_id: str,
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> WatchCheckResponse:
    """
    Pulls fresh offers for the watch's route+dates, classifies the cheapest
    one with the Price Intelligence engine, and fires a trigger if either:
      1) observed price <= watch.target_price_usd, or
      2) watch.notify_on_great_deal AND label ∈ {STEAL, GREAT_DEAL}.

    This endpoint is safe to call repeatedly — each call records a check
    timestamp and updates last_price_usd/last_label.
    """
    repo = WatchRepo(session)
    watch = await repo.get(watch_id)
    if not watch:
        raise HTTPException(status_code=404, detail="Watch not found.")
    if not watch.active:
        raise HTTPException(status_code=409, detail="Watch is not active.")

    offers = await _fetch_offers_for_watch(request, watch)

    now = datetime.now(timezone.utc)

    if not offers:
        reason = "No offers returned from provider for this route/date."
        await repo.record_check(
            watch, price_usd=None, label=None, fired=False, reason=reason
        )
        return WatchCheckResponse(
            watch=_to_response(watch),
            triggered=False,
            best_price_usd=None,
            best_label=None,
            best_offer=None,
            reason=reason,
            checked_at=now,
        )

    # Cheapest offer wins for trigger evaluation.
    best = min(offers, key=lambda o: o.price.total_usd)

    engine = get_price_intel_engine()
    pi = engine.classify_price(
        price_usd=best.price.total_usd,
        origin=watch.origin,
        destination=watch.destination,
        cabin_class=watch.cabin_class,
        departure_date=_to_date(watch.departure_date),  # type: ignore[arg-type]
    )
    best = best.model_copy(update={"price_intelligence": pi})

    # Trigger rules
    hit_target = (
        watch.target_price_usd is not None
        and best.price.total_usd <= watch.target_price_usd
    )
    hit_label = (
        watch.notify_on_great_deal
        and pi.price_label in (PriceLabel.STEAL, PriceLabel.GREAT_DEAL)
    )
    triggered = hit_target or hit_label

    if triggered:
        parts: list[str] = []
        if hit_target:
            parts.append(
                f"Price ${best.price.total_usd:,.0f} is at or below your target "
                f"of ${watch.target_price_usd:,.0f}."
            )
        if hit_label:
            parts.append(f"Engine classified this price as {pi.price_label.value}.")
        reason = " ".join(parts)
    else:
        reason = (
            f"Cheapest current price is ${best.price.total_usd:,.0f} "
            f"(label: {pi.price_label.value}). "
            "No trigger criteria met yet."
        )

    await repo.record_check(
        watch,
        price_usd=best.price.total_usd,
        label=pi.price_label.value,
        fired=triggered,
        reason=reason,
    )

    return WatchCheckResponse(
        watch=_to_response(watch),
        triggered=triggered,
        best_price_usd=best.price.total_usd,
        best_label=pi.price_label,
        best_offer=best,
        reason=reason,
        checked_at=now,
    )
