"""Prediction router — ML model prediction endpoints."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from auth.jwt_handler import get_current_user, TokenPayload
from models.schemas import PredictionRequest, PredictionResponse
from ml.prediction_service import predict, is_model_available
from utils.rate_limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["Prediction"])


@router.post("/predict", response_model=PredictionResponse)
@limiter.limit("20/minute")
async def predict_crop(
    request: Request,
    body: PredictionRequest,
):
    """
    Run ML predictions on provided agricultural features.

    Returns crop quality, health score, risk level, and NDVI trend
    with confidence scores.
    """
    if not is_model_available():
        raise HTTPException(
            status_code=503,
            detail="ML models not trained yet. Please contact the administrator.",
        )

    try:
        features = {
            "state": body.state,
            "district": body.district,
            "crop_type": body.crop_type,
            "season": body.season,
            "land_area_hectares": body.land_area_hectares,
            "soil_type": body.soil_type,
            "ndvi_current": body.ndvi_current,
            "ndvi_30day_avg": body.ndvi_30day_avg if body.ndvi_30day_avg is not None else body.ndvi_current * 0.95,
            "rainfall_mm": body.rainfall_mm,
            "avg_temperature_c": body.avg_temperature_c,
            "past_yield_ton_per_hectare": body.past_yield_ton_per_hectare,
        }

        result = predict(features)

        return PredictionResponse(
            crop_quality=result["crop_quality"],
            crop_health_score=result["crop_health_score"],
            risk_level=result["risk_level"],
            ndvi_trend=result["ndvi_trend"],
            ndvi_trend_description=result["ndvi_trend_description"],
            confidence=result["confidence"],
        )

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Prediction failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")
