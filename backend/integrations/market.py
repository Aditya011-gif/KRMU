"""Market price intelligence integration."""

import os
import logging
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

MARKET_API_KEY = os.getenv("MARKET_API_KEY", "").strip()
DATA_GOV_BASE = "https://api.data.gov.in/resource"


async def get_market_data(lat: float, lng: float) -> dict:
    """
    Retrieve crop market price stability index.
    Primary: data.gov.in Agmarknet dataset.
    Fallback: Regional estimates.
    Returns: {"market_index": float (0-1), "summary": str, "details": dict}
    """
    try:
        return await _fetch_market_data(lat, lng)
    except Exception as e:
        logger.warning(f"Market API failed: {e}")
        return _estimate_market(lat, lng)


async def _fetch_market_data(lat: float, lng: float) -> dict:
    """Fetch commodity price data from data.gov.in (Agmarknet)."""
    # Map coordinates to approximate Indian state for market data
    state = _coords_to_state(lat, lng)

    async with httpx.AsyncClient(timeout=20.0) as client:
        # Fetch commodity prices for the state
        resp = await client.get(
            f"{DATA_GOV_BASE}/9ef84268-d588-465a-a308-a864a43d0070",
            params={
                "api-key": MARKET_API_KEY,
                "format": "json",
                "limit": 20,
                "filters[state]": state,
            },
        )

        if resp.status_code == 200:
            data = resp.json()
            records = data.get("records", [])

            if records:
                # Calculate price stability index
                prices = []
                commodities = []
                for r in records:
                    try:
                        modal_price = float(r.get("modal_price", 0))
                        min_price = float(r.get("min_price", 0))
                        max_price = float(r.get("max_price", 0))
                        if modal_price > 0:
                            # Price stability = 1 - (range / modal) clamped
                            spread = (max_price - min_price) / modal_price if modal_price else 1
                            stability = max(0, 1 - spread)
                            prices.append(stability)
                            commodities.append(r.get("commodity", "Unknown"))
                    except (ValueError, TypeError):
                        continue

                if prices:
                    avg_stability = sum(prices) / len(prices)
                    return {
                        "market_index": round(avg_stability, 4),
                        "summary": f"Market data from {len(prices)} commodities in {state}. "
                                   f"Avg price stability: {avg_stability:.0%}.",
                        "source": "agmarknet",
                        "details": {
                            "state": state,
                            "commodities_analyzed": len(prices),
                            "top_commodities": commodities[:5],
                            "avg_stability": avg_stability,
                        },
                    }

    raise Exception("Market data unavailable")


def _coords_to_state(lat: float, lng: float) -> str:
    """Approximate Indian state from GPS coordinates."""
    regions = [
        (28.0, 35.0, 74.0, 78.0, "Punjab"),
        (28.0, 32.0, 76.0, 78.5, "Haryana"),
        (26.0, 30.5, 77.0, 84.5, "Uttar Pradesh"),
        (21.0, 26.0, 79.0, 87.5, "Madhya Pradesh"),
        (15.0, 22.0, 73.0, 80.5, "Maharashtra"),
        (11.0, 18.0, 74.0, 80.0, "Karnataka"),
        (8.0, 13.0, 76.0, 80.5, "Tamil Nadu"),
        (8.0, 13.0, 74.0, 77.5, "Kerala"),
        (13.0, 20.0, 77.0, 84.5, "Andhra Pradesh"),
        (20.0, 27.0, 82.0, 89.0, "Bihar"),
        (20.0, 27.0, 73.0, 76.0, "Rajasthan"),
        (20.0, 24.0, 68.0, 74.5, "Gujarat"),
        (19.0, 22.5, 82.0, 87.5, "Odisha"),
        (21.5, 27.5, 85.5, 89.0, "West Bengal"),
        (24.0, 28.0, 89.0, 97.0, "Assam"),
    ]

    for lat_min, lat_max, lng_min, lng_max, state in regions:
        if lat_min <= lat <= lat_max and lng_min <= lng <= lng_max:
            return state

    return "Maharashtra"  # Default fallback


def _estimate_market(lat: float, lng: float) -> dict:
    """Estimate market conditions based on region."""
    state = _coords_to_state(lat, lng)

    # Regional market strength index
    market_scores = {
        "Punjab": 0.82, "Haryana": 0.78, "Uttar Pradesh": 0.65,
        "Madhya Pradesh": 0.70, "Maharashtra": 0.75, "Karnataka": 0.72,
        "Tamil Nadu": 0.68, "Kerala": 0.66, "Andhra Pradesh": 0.64,
        "Bihar": 0.55, "Rajasthan": 0.60, "Gujarat": 0.74,
        "Odisha": 0.58, "West Bengal": 0.62, "Assam": 0.52,
    }

    index = market_scores.get(state, 0.60)

    return {
        "market_index": index,
        "summary": f"Regional market estimate for {state}. Price stability moderate.",
        "source": "estimated",
        "details": {"state": state, "note": "Estimated — market API unavailable"},
    }
