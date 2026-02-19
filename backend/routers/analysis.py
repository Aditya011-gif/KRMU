"""Land analysis router — farmer-facing endpoints."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from auth.jwt_handler import get_current_user, TokenPayload
from models.schemas import AnalysisRequest, AnalysisResponse, AnalysisListItem
from services.analysis_service import perform_land_analysis, get_user_analyses
from utils.rate_limiter import limiter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["Analysis"])


@router.post("/analyze-land", response_model=AnalysisResponse)
@limiter.limit("10/minute")
async def analyze_land(
    request: Request,
    body: AnalysisRequest,
    user: TokenPayload = Depends(get_current_user),
):
    """
    Perform land analysis for authenticated user.
    Accepts lat/lng, fetches NDVI, soil, weather, market data,
    computes Agri-Trust Score, and stores the result.
    """
    try:
        result = await perform_land_analysis(
            user_id=user.sub,
            latitude=body.latitude,
            longitude=body.longitude,
        )
        return result
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


@router.get("/analyses", response_model=list[AnalysisListItem])
async def list_analyses(
    user: TokenPayload = Depends(get_current_user),
    limit: int = 50,
):
    """Get analysis history for the current authenticated user."""
    analyses = await get_user_analyses(user.sub, limit=limit)
    return analyses


@router.get("/analyses/{analysis_id}", response_model=AnalysisResponse)
async def get_analysis(
    analysis_id: str,
    user: TokenPayload = Depends(get_current_user),
):
    """Get a specific analysis by ID (must belong to current user)."""
    from models.database import get_supabase_client
    supabase = get_supabase_client()

    resp = (
        supabase.table("land_analysis")
        .select("*")
        .eq("id", analysis_id)
        .eq("user_id", user.sub)
        .single()
        .execute()
    )

    if not resp.data:
        raise HTTPException(status_code=404, detail="Analysis not found")

    return resp.data
