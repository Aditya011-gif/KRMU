"""Analysis service — orchestrates API calls, scoring, and storage."""

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from integrations.ndvi import get_ndvi
from integrations.soil import get_soil_data
from integrations.weather import get_weather_data
from integrations.market import get_market_data
from score_engine.calculator import calculate_agri_score
from models.database import get_supabase_client
from utils.cache import get_cached_result, set_cached_result

logger = logging.getLogger(__name__)


async def perform_land_analysis(
    user_id: str, latitude: float, longitude: float
) -> dict:
    """
    Full land analysis pipeline:
    1. Check cache for recent analysis at same coordinates
    2. Fetch NDVI, soil, weather, market data (concurrent)
    3. Calculate Agri-Trust Score
    4. Store result in Supabase
    5. Return complete analysis
    """
    # ── Check cache ───────────────────────────────────────────
    cached = get_cached_result(latitude, longitude)
    if cached:
        logger.info(f"Cache hit for ({latitude}, {longitude})")
        # Still store for this user but skip API calls
        result = cached.copy()
        result["user_id"] = user_id
        result["id"] = str(uuid.uuid4())
        result["created_at"] = datetime.now(timezone.utc).isoformat()
        await _store_analysis(result)
        return result

    # ── Fetch data from all sources concurrently ──────────────
    import asyncio

    ndvi_task = asyncio.create_task(get_ndvi(latitude, longitude))
    soil_task = asyncio.create_task(get_soil_data(latitude, longitude))
    weather_task = asyncio.create_task(get_weather_data(latitude, longitude))
    market_task = asyncio.create_task(get_market_data(latitude, longitude))

    ndvi_data, soil_data, weather_data, market_data = await asyncio.gather(
        ndvi_task, soil_task, weather_task, market_task,
        return_exceptions=True,
    )

    # ── Handle failures gracefully ────────────────────────────
    if isinstance(ndvi_data, Exception):
        logger.error(f"NDVI fetch failed: {ndvi_data}")
        ndvi_data = {"ndvi": 0.5, "source": "default", "details": {}}

    if isinstance(soil_data, Exception):
        logger.error(f"Soil fetch failed: {soil_data}")
        soil_data = {"soil_type": "Unknown", "land_class": "General Agricultural Land", "source": "default", "details": {}}

    if isinstance(weather_data, Exception):
        logger.error(f"Weather fetch failed: {weather_data}")
        weather_data = {"weather_index": 0.5, "summary": "Weather data unavailable", "source": "default", "details": {}}

    if isinstance(market_data, Exception):
        logger.error(f"Market fetch failed: {market_data}")
        market_data = {"market_index": 0.6, "summary": "Market data unavailable", "source": "default", "details": {}}

    # ── Calculate Agri-Trust Score ─────────────────────────────
    score_result = calculate_agri_score(
        ndvi_value=ndvi_data["ndvi"],
        soil_type=soil_data["soil_type"],
        land_class=soil_data["land_class"],
        weather_index=weather_data["weather_index"],
        market_index=market_data["market_index"],
    )

    # ── Build result ──────────────────────────────────────────
    analysis_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    result = {
        "id": analysis_id,
        "user_id": user_id,
        "latitude": latitude,
        "longitude": longitude,
        "ndvi_value": ndvi_data["ndvi"],
        "soil_type": soil_data["soil_type"],
        "land_class": soil_data["land_class"],
        "weather_index": weather_data["weather_index"],
        "market_index": market_data["market_index"],
        "agri_score": score_result["agri_score"],
        "risk_category": score_result["risk_category"],
        "score_breakdown": score_result["score_breakdown"],
        "ml_predictions": None,
        "created_at": now,
    }

    # ── ML Predictions (optional) ─────────────────────────────
    try:
        from ml.prediction_service import predict as ml_predict, is_model_available
        if is_model_available():
            # Build features from available data matching the CSV column names
            weather_details = weather_data.get("details", {})
            ndvi_val = ndvi_data["ndvi"]
            ml_features = {
                "state": "Unknown",        # Can be overridden if user provides
                "district": "Unknown",     # Can be overridden if user provides
                "crop_type": "Rice",       # Default; can be overridden if user provides
                "season": "Kharif",        # Default; can be overridden if user provides
                "land_area_hectares": 5.0, # Default; can be overridden if user provides
                "soil_type": soil_data["soil_type"],
                "ndvi_current": ndvi_val,
                "ndvi_30day_avg": ndvi_val * 0.95,  # Estimate from current
                "rainfall_mm": weather_details.get("rainfall", 50.0),
                "avg_temperature_c": weather_details.get("temperature", 28.0),
                "past_yield_ton_per_hectare": 3.0,  # Default
            }
            ml_result = ml_predict(ml_features)
            result["ml_predictions"] = ml_result
            logger.info(f"ML predictions added to analysis {analysis_id}")
    except Exception as e:
        logger.warning(f"ML prediction failed (non-blocking): {e}")

    # ── Store in Supabase ─────────────────────────────────────
    await _store_analysis(result)

    # ── Cache result ──────────────────────────────────────────
    set_cached_result(latitude, longitude, result)

    # ── Log audit ─────────────────────────────────────────────
    await _log_audit(user_id, "land_analysis", {
        "analysis_id": analysis_id,
        "latitude": latitude,
        "longitude": longitude,
        "score": score_result["agri_score"],
    })

    return result


async def get_user_analyses(user_id: str, limit: int = 50) -> list[dict]:
    """Fetch all analyses for a specific user, ordered by most recent."""
    try:
        supabase = get_supabase_client()
        resp = (
            supabase.table("land_analysis")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return resp.data or []
    except Exception as e:
        logger.error(f"Failed to fetch analyses: {e}")
        return []


async def get_all_analyses(limit: int = 500) -> list[dict]:
    """Fetch all analyses across all users (admin only)."""
    try:
        supabase = get_supabase_client()
        resp = (
            supabase.table("land_analysis")
            .select("*")
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return resp.data or []
    except Exception as e:
        logger.error(f"Failed to fetch all analyses: {e}")
        return []


async def _store_analysis(result: dict) -> None:
    """Store analysis result in Supabase."""
    try:
        supabase = get_supabase_client()
        # Convert score_breakdown to JSON-safe dict
        row = {
            "id": result["id"],
            "user_id": result["user_id"],
            "latitude": result["latitude"],
            "longitude": result["longitude"],
            "ndvi_value": result["ndvi_value"],
            "soil_type": result["soil_type"],
            "land_class": result["land_class"],
            "weather_index": result["weather_index"],
            "market_index": result["market_index"],
            "agri_score": result["agri_score"],
            "risk_category": result["risk_category"],
            "score_breakdown": result["score_breakdown"],
            "created_at": result["created_at"],
        }
        supabase.table("land_analysis").insert(row).execute()
        logger.info(f"Stored analysis {result['id']} for user {result['user_id']}")
    except Exception as e:
        logger.error(f"Failed to store analysis: {e}")
        # Don't raise — return result to user even if storage fails


async def _log_audit(user_id: str, action: str, metadata: dict) -> None:
    """Log an audit event."""
    try:
        supabase = get_supabase_client()
        supabase.table("audit_logs").insert({
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "action": action,
            "metadata": metadata,
        }).execute()
    except Exception as e:
        logger.warning(f"Audit log failed: {e}")
