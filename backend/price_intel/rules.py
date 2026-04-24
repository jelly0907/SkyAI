"""
Rule-based price classifier.

Pure functions — no I/O, no globals. Given a price and `RouteStats`, return a
`PriceIntelligence`. The full XGBoost + Prophet pipeline in Phase 2 will
replace these heuristics behind the same signature.
"""

from __future__ import annotations

import random
from typing import Optional

from models import ActionType, PriceIntelligence, PriceLabel, PriceTrend

from .route_stats import RouteStats


def _derive_percentiles(stats: RouteStats) -> dict[str, float]:
    """
    If the stats provider only supplies min/median/max, derive approximate
    p10/p25/p75/p90 using the same linear split the original mock_data rule
    used. Keeps Phase 1 behavior identical.
    """
    if stats.has_percentiles:
        return {
            "p10": stats.p10,  # type: ignore[dict-item]
            "p25": stats.p25,  # type: ignore[dict-item]
            "p75": stats.p75,  # type: ignore[dict-item]
            "p90": stats.p90,  # type: ignore[dict-item]
        }
    median, pmin, pmax = stats.price_median, stats.price_min, stats.price_max
    return {
        "p10": pmin + (median - pmin) * 0.15,
        "p25": pmin + (median - pmin) * 0.40,
        "p75": median + (pmax - median) * 0.35,
        "p90": median + (pmax - median) * 0.75,
    }


def _forecast_and_trend(
    price_usd: float, days_out: int, rng: random.Random
) -> tuple[PriceTrend, float, float]:
    """Heuristic forecast based on lead time."""
    if days_out < 7:
        return PriceTrend.RISING, round(price_usd * 1.12, 2), round(price_usd * 1.22, 2)
    if days_out < 21:
        return PriceTrend.STABLE, round(price_usd * 1.03, 2), round(price_usd * 1.08, 2)
    if days_out < 45:
        trend = rng.choice([PriceTrend.FALLING, PriceTrend.STABLE])
        return trend, round(price_usd * 0.97, 2), round(price_usd * 0.94, 2)
    return PriceTrend.FALLING, round(price_usd * 0.96, 2), round(price_usd * 0.91, 2)


def _choose_action(
    label: PriceLabel,
    trend: PriceTrend,
    days_out: int,
    median: float,
    price_usd: float,
    percentile: int,
    savings_vs_median: float,
    savings_pct: Optional[float],
    forecast_14d: float,
) -> tuple[ActionType, str]:
    """Pick the action + human-readable reason."""
    if label == PriceLabel.STEAL:
        return ActionType.BUY_NOW, (
            f"This price is in the bottom {percentile}% of fares we've recorded on this route. "
            f"The historical average is ${median:,.0f}. Prices are trending {trend.value.lower()} — act now."
        )
    if label == PriceLabel.GREAT_DEAL and trend == PriceTrend.RISING:
        return ActionType.BUY_NOW, (
            f"A genuinely good deal — {savings_pct or 0:.0f}% below the historical average of ${median:,.0f}. "
            f"Prices are rising, so this window won't last."
        )
    if label == PriceLabel.GREAT_DEAL:
        return ActionType.BUY_NOW, (
            f"This is a solid price — ${savings_vs_median:,.0f} below the typical fare on this route. "
            f"Safe to book now."
        )
    if label == PriceLabel.FAIR and trend == PriceTrend.FALLING:
        return ActionType.WAIT, (
            f"Price is near the historical average but trending down. "
            f"We expect it to drop to around ${forecast_14d:,.0f} in the next two weeks."
        )
    if label in (PriceLabel.EXPENSIVE, PriceLabel.OVERPRICED) and days_out < 7:
        return ActionType.BUY_NOW, (
            f"Departure is soon — prices rarely improve this close to the flight date. "
            f"Book now to secure your seat."
        )
    if label in (PriceLabel.EXPENSIVE, PriceLabel.OVERPRICED):
        return ActionType.SET_ALERT, (
            f"This price is above the historical average of ${median:,.0f}. "
            f"Set an alert — we'll notify you the moment it drops."
        )
    return ActionType.MONITOR, (
        "Price is in line with historical averages. We'll keep watching for a better deal."
    )


def classify(
    price_usd: float,
    stats: RouteStats,
    days_out: int,
    *,
    rng: Optional[random.Random] = None,
) -> PriceIntelligence:
    """
    Classify a single price point against route statistics.
    Deterministic if `rng` is provided (handy for tests).
    """
    rng = rng or random.Random()
    p = _derive_percentiles(stats)
    median, pmin, pmax = stats.price_median, stats.price_min, stats.price_max

    # Label + percentile
    if price_usd <= p["p10"]:
        pct = int(max(0, min(10, price_usd / p["p10"] * 10)))
        label, badge, confidence = PriceLabel.STEAL, "🔥 STEAL", 0.92
    elif price_usd <= p["p25"]:
        pct = int(10 + (price_usd - p["p10"]) / (p["p25"] - p["p10"]) * 15)
        label, badge, confidence = PriceLabel.GREAT_DEAL, "✅ GREAT DEAL", 0.87
    elif price_usd <= p["p75"]:
        pct = int(25 + (price_usd - p["p25"]) / (p["p75"] - p["p25"]) * 50)
        label, badge, confidence = PriceLabel.FAIR, "", 0.83
    elif price_usd <= p["p90"]:
        pct = int(75 + (price_usd - p["p75"]) / (p["p90"] - p["p75"]) * 15)
        label, badge, confidence = PriceLabel.EXPENSIVE, "⚠️ ABOVE AVG", 0.80
    else:
        span = max(pmax - p["p90"], 1.0)
        pct = min(99, int(90 + (price_usd - p["p90"]) / span * 10))
        label, badge, confidence = PriceLabel.OVERPRICED, "🔴 OVERPRICED", 0.78

    # Confidence damped by low observation counts
    if stats.observation_count < 50:
        confidence *= 0.7

    savings_vs_median = round(median - price_usd, 2)
    savings_pct = round((savings_vs_median / median) * 100, 1) if savings_vs_median > 0 else None

    trend, forecast_7d, forecast_14d = _forecast_and_trend(price_usd, days_out, rng)

    action, reason = _choose_action(
        label, trend, days_out, median, price_usd, pct,
        savings_vs_median, savings_pct, forecast_14d,
    )

    return PriceIntelligence(
        price_label=label,
        price_percentile=pct,
        savings_vs_median_usd=savings_vs_median if savings_vs_median > 0 else None,
        savings_pct=savings_pct,
        trend=trend,
        forecast_7d_usd=forecast_7d,
        forecast_14d_usd=forecast_14d,
        action=action,
        action_reason=reason,
        badge_text=badge,
        confidence=round(confidence, 3),
    )
