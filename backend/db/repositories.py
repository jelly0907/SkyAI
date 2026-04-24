"""
Repository layer — the only place that talks to SQLAlchemy sessions.

Route handlers depend on these, not on sessions directly. Changing databases
or adding caching only touches this file.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from .models_sql import PriceObservation, PriceWatch, WatchTrigger


class ObservationRepo:
    """Writes and reads for price_observations."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def bulk_log(self, observations: list[PriceObservation]) -> None:
        if not observations:
            return
        self.session.add_all(observations)
        await self.session.commit()


class WatchRepo:
    """CRUD for price_watches + their triggers."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, watch: PriceWatch) -> PriceWatch:
        self.session.add(watch)
        await self.session.commit()
        await self.session.refresh(watch)
        return watch

    async def get(self, watch_id: str) -> Optional[PriceWatch]:
        res = await self.session.execute(
            select(PriceWatch).where(PriceWatch.id == watch_id)
        )
        return res.scalar_one_or_none()

    async def list_for_user(
        self, user_id: str, *, active_only: bool = False
    ) -> list[PriceWatch]:
        stmt = select(PriceWatch).where(PriceWatch.user_id == user_id)
        if active_only:
            stmt = stmt.where(PriceWatch.active.is_(True))
        stmt = stmt.order_by(PriceWatch.created_at.desc())
        res = await self.session.execute(stmt)
        return list(res.scalars().all())

    async def delete(self, watch_id: str) -> bool:
        res = await self.session.execute(
            delete(PriceWatch).where(PriceWatch.id == watch_id)
        )
        await self.session.commit()
        return res.rowcount is not None and res.rowcount > 0

    async def record_check(
        self,
        watch: PriceWatch,
        *,
        price_usd: Optional[float],
        label: Optional[str],
        fired: bool,
        reason: str,
    ) -> None:
        """Update last_checked_at / last_price_usd / last_label. Append trigger row if fired."""
        now = datetime.now(timezone.utc)
        watch.last_checked_at = now
        if price_usd is not None:
            watch.last_price_usd = price_usd
        if label is not None:
            watch.last_label = label

        if fired:
            watch.triggered_at = now
            watch.trigger_count += 1
            trigger = WatchTrigger(
                watch_id=watch.id,
                triggered_at=now,
                price_usd=price_usd or 0.0,
                price_label=label,
                reason=reason,
            )
            self.session.add(trigger)

        await self.session.commit()
