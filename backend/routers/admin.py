"""Admin router — platform analytics and farmer management."""

import csv
import io
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse

from auth.jwt_handler import require_admin, TokenPayload
from models.schemas import AdminStats, AdminFarmerDetail, MessageResponse
from models.database import get_supabase_client
from services.analysis_service import get_all_analyses

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["Admin"])


@router.get("/stats", response_model=AdminStats)
async def get_platform_stats(admin: TokenPayload = Depends(require_admin)):
    """Get platform-level analytics for admin dashboard."""
    supabase = get_supabase_client()

    # Total farmers
    farmers_resp = supabase.table("users").select("id", count="exact").eq("role", "farmer").execute()
    total_farmers = farmers_resp.count or 0

    # Total analyses
    analyses_resp = supabase.table("land_analysis").select("id, agri_score, risk_category, user_id", count="exact").execute()
    total_analyses = analyses_resp.count or 0
    analyses = analyses_resp.data or []

    # Average score
    scores = [a["agri_score"] for a in analyses if a.get("agri_score")]
    avg_score = sum(scores) / len(scores) if scores else 0

    # Risk distribution
    risk_counts = {"Low": 0, "Medium": 0, "High": 0}
    for a in analyses:
        cat = a.get("risk_category", "High")
        risk_counts[cat] = risk_counts.get(cat, 0) + 1

    total_risk = sum(risk_counts.values()) or 1
    risk_distribution = {k: round(v / total_risk * 100, 1) for k, v in risk_counts.items()}

    # State/District distribution from users
    users_resp = supabase.table("users").select("state, district").eq("role", "farmer").execute()
    users = users_resp.data or []

    state_dist = {}
    district_dist = {}
    for u in users:
        s = u.get("state") or "Unknown"
        d = u.get("district") or "Unknown"
        state_dist[s] = state_dist.get(s, 0) + 1
        district_dist[d] = district_dist.get(d, 0) + 1

    return AdminStats(
        total_farmers=total_farmers,
        total_analyses=total_analyses,
        average_score=round(avg_score, 1),
        risk_distribution=risk_distribution,
        state_distribution=state_dist,
        district_distribution=district_dist,
    )


@router.get("/farmers")
async def list_farmers(
    admin: TokenPayload = Depends(require_admin),
    state: Optional[str] = None,
    district: Optional[str] = None,
    risk_category: Optional[str] = None,
    min_score: Optional[float] = None,
    max_score: Optional[float] = None,
    search: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    """List all farmers with filtering and search."""
    supabase = get_supabase_client()

    query = supabase.table("users").select("*").eq("role", "farmer")

    if state:
        query = query.eq("state", state)
    if district:
        query = query.eq("district", district)
    if search:
        query = query.or_(f"name.ilike.%{search}%,email.ilike.%{search}%")

    query = query.order("created_at", desc=True).range(offset, offset + limit - 1)
    resp = query.execute()
    farmers = resp.data or []

    # If filtering by score/risk, join with latest analysis
    if risk_category or min_score is not None or max_score is not None:
        farmer_ids = [f["id"] for f in farmers]
        if farmer_ids:
            a_query = supabase.table("land_analysis").select("user_id, agri_score, risk_category").in_("user_id", farmer_ids).order("created_at", desc=True)
            a_resp = a_query.execute()
            analysis_map = {}
            for a in (a_resp.data or []):
                if a["user_id"] not in analysis_map:
                    analysis_map[a["user_id"]] = a

            filtered = []
            for f in farmers:
                latest = analysis_map.get(f["id"])
                if latest:
                    f["latest_score"] = latest["agri_score"]
                    f["latest_risk"] = latest["risk_category"]
                    if risk_category and latest["risk_category"] != risk_category:
                        continue
                    if min_score and latest["agri_score"] < min_score:
                        continue
                    if max_score and latest["agri_score"] > max_score:
                        continue
                else:
                    f["latest_score"] = None
                    f["latest_risk"] = None
                    if risk_category or min_score or max_score:
                        continue
                filtered.append(f)
            return filtered

    return farmers


@router.get("/farmer/{farmer_id}", response_model=AdminFarmerDetail)
async def get_farmer_detail(
    farmer_id: str,
    admin: TokenPayload = Depends(require_admin),
):
    """Get detailed farmer profile with all analyses."""
    supabase = get_supabase_client()

    # Get user profile
    user_resp = supabase.table("users").select("*").eq("id", farmer_id).single().execute()
    if not user_resp.data:
        raise HTTPException(status_code=404, detail="Farmer not found")

    # Get all analyses
    analyses_resp = (
        supabase.table("land_analysis")
        .select("*")
        .eq("user_id", farmer_id)
        .order("created_at", desc=True)
        .execute()
    )
    analyses = analyses_resp.data or []

    scores = [a["agri_score"] for a in analyses if a.get("agri_score")]

    return AdminFarmerDetail(
        user=user_resp.data,
        analyses=analyses,
        total_analyses=len(analyses),
        average_score=round(sum(scores) / len(scores), 1) if scores else None,
        latest_risk=analyses[0].get("risk_category") if analyses else None,
    )


@router.get("/export")
async def export_csv(admin: TokenPayload = Depends(require_admin)):
    """Export all analyses as CSV."""
    analyses = await get_all_analyses(limit=5000)

    output = io.StringIO()
    if analyses:
        writer = csv.DictWriter(output, fieldnames=analyses[0].keys())
        writer.writeheader()
        for row in analyses:
            # Flatten score_breakdown for CSV
            if isinstance(row.get("score_breakdown"), dict):
                row["score_breakdown"] = str(row["score_breakdown"])
            writer.writerow(row)

    output.seek(0)
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode()),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=agri_score_export.csv"},
    )


@router.get("/audit-logs")
async def get_audit_logs(
    admin: TokenPayload = Depends(require_admin),
    limit: int = Query(default=100, le=500),
):
    """Get audit logs."""
    supabase = get_supabase_client()
    resp = (
        supabase.table("audit_logs")
        .select("*")
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    return resp.data or []


@router.post("/flag/{analysis_id}", response_model=MessageResponse)
async def flag_analysis(
    analysis_id: str,
    admin: TokenPayload = Depends(require_admin),
):
    """Flag an analysis as suspicious for manual review."""
    supabase = get_supabase_client()

    # Update the analysis record
    resp = (
        supabase.table("land_analysis")
        .update({"risk_category": "Flagged"})
        .eq("id", analysis_id)
        .execute()
    )

    if not resp.data:
        raise HTTPException(status_code=404, detail="Analysis not found")

    # Log audit
    supabase.table("audit_logs").insert({
        "user_id": admin.sub,
        "action": "flag_analysis",
        "metadata": {"analysis_id": analysis_id},
    }).execute()

    return MessageResponse(message=f"Analysis {analysis_id} flagged for review")
