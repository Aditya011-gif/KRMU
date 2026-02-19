"""Agri-Trust Score calculation engine.

Weighted scoring:
  - NDVI:               35%
  - Soil Quality:       25%
  - Land Classification: 15%
  - Weather Risk:       15%
  - Market Risk:        10%

Score range: 0–1000
Risk categories:
  - 800–1000: Low Risk   (Green)
  - 600–799:  Medium Risk (Amber)
  - <600:     High Risk   (Red)
"""

import logging

logger = logging.getLogger(__name__)

# Weight configuration
WEIGHTS = {
    "ndvi": 0.35,
    "soil": 0.25,
    "land_class": 0.15,
    "weather": 0.15,
    "market": 0.10,
}

MAX_SCORE = 1000


def calculate_agri_score(
    ndvi_value: float,
    soil_type: str,
    land_class: str,
    weather_index: float,
    market_index: float,
) -> dict:
    """
    Calculate the Agri-Trust Score from all input factors.

    Returns:
        {
            "agri_score": int (0-1000),
            "risk_category": str,
            "score_breakdown": {
                "ndvi_score": float,
                "soil_score": float,
                "land_class_score": float,
                "weather_score": float,
                "market_score": float,
            }
        }
    """
    # ── Component Scores (normalized 0–1) ─────────────────────

    # NDVI Score: direct mapping (0–1 NDVI → 0–1 score)
    ndvi_score = _score_ndvi(ndvi_value)

    # Soil Quality Score: based on soil type
    soil_score = _score_soil(soil_type)

    # Land Classification Score
    land_class_score = _score_land_class(land_class)

    # Weather Score: direct mapping (already 0–1)
    weather_score = max(0.0, min(1.0, weather_index))

    # Market Score: direct mapping (already 0–1)
    market_score = max(0.0, min(1.0, market_index))

    # ── Weighted Aggregation ──────────────────────────────────

    raw_score = (
        ndvi_score * WEIGHTS["ndvi"]
        + soil_score * WEIGHTS["soil"]
        + land_class_score * WEIGHTS["land_class"]
        + weather_score * WEIGHTS["weather"]
        + market_score * WEIGHTS["market"]
    )

    # Normalize to 0–1000
    agri_score = round(raw_score * MAX_SCORE)
    agri_score = max(0, min(MAX_SCORE, agri_score))

    # ── Risk Category ─────────────────────────────────────────

    risk_category = _categorize_risk(agri_score)

    # ── Score Breakdown (weighted contributions) ──────────────

    breakdown = {
        "ndvi_score": round(ndvi_score * WEIGHTS["ndvi"] * MAX_SCORE, 1),
        "soil_score": round(soil_score * WEIGHTS["soil"] * MAX_SCORE, 1),
        "land_class_score": round(land_class_score * WEIGHTS["land_class"] * MAX_SCORE, 1),
        "weather_score": round(weather_score * WEIGHTS["weather"] * MAX_SCORE, 1),
        "market_score": round(market_score * WEIGHTS["market"] * MAX_SCORE, 1),
        "ndvi_raw": ndvi_value,
        "soil_type": soil_type,
        "land_class": land_class,
        "weather_summary": f"Weather favorability: {weather_index:.0%}",
        "market_summary": f"Market stability: {market_index:.0%}",
    }

    logger.info(
        f"Agri-Score calculated: {agri_score} ({risk_category}) — "
        f"NDVI={ndvi_score:.2f} Soil={soil_score:.2f} Land={land_class_score:.2f} "
        f"Weather={weather_score:.2f} Market={market_score:.2f}"
    )

    return {
        "agri_score": agri_score,
        "risk_category": risk_category,
        "score_breakdown": breakdown,
    }


def _score_ndvi(ndvi: float) -> float:
    """Convert NDVI (0–1) to a quality score (0–1)."""
    if ndvi >= 0.7:
        return 1.0  # Excellent vegetation
    elif ndvi >= 0.5:
        return 0.8  # Good vegetation
    elif ndvi >= 0.3:
        return 0.6  # Moderate vegetation
    elif ndvi >= 0.2:
        return 0.4  # Sparse vegetation
    elif ndvi >= 0.1:
        return 0.2  # Very sparse
    else:
        return 0.05  # Barren/water


def _score_soil(soil_type: str) -> float:
    """Score soil type on agricultural quality (0–1)."""
    soil_scores = {
        # Premium soils
        "Chernozem": 0.95, "Phaeozem": 0.90, "Vertisol": 0.88,
        "Black Cotton Soil (Regur)": 0.88, "Alluvial Soil": 0.85,
        # Good soils
        "Luvisol": 0.80, "Cambisol": 0.78, "Fluvisol": 0.82,
        "Gleysol": 0.70, "Red Soil": 0.72,
        # Moderate soils
        "Acrisol": 0.60, "Ferralsol": 0.55, "Mixed Soil": 0.60,
        "Laterite Soil": 0.58, "Nitisol": 0.65,
        # Poor soils
        "Leptosol": 0.35, "Regosol": 0.40, "Arenosol": 0.30,
        "Mountain Soil": 0.45, "Podzol": 0.38,
        # Special
        "Histosol": 0.50, "Solonchak": 0.25, "Solonetz": 0.30,
    }

    # Try exact match first
    if soil_type in soil_scores:
        return soil_scores[soil_type]

    # Try partial match
    soil_lower = soil_type.lower()
    for name, score in soil_scores.items():
        if name.lower() in soil_lower or soil_lower in name.lower():
            return score

    return 0.55  # Default moderate


def _score_land_class(land_class: str) -> float:
    """Score land classification on agricultural suitability (0–1)."""
    class_scores = {
        "Prime Agricultural Land": 0.95,
        "Fertile Agricultural Land": 0.90,
        "Agricultural Land": 0.80,
        "General Agricultural Land": 0.70,
        "Plantation Land": 0.65,
        "Heavy Clay Agricultural Land": 0.60,
        "Marginal Agricultural Land": 0.45,
        "Sandy / Marginal Land": 0.30,
        "Forest / Wetland": 0.25,
        "Urban / Industrial": 0.10,
        "Barren / Wasteland": 0.05,
    }

    if land_class in class_scores:
        return class_scores[land_class]

    lc_lower = land_class.lower()
    if "prime" in lc_lower or "fertile" in lc_lower:
        return 0.90
    elif "agricultural" in lc_lower:
        return 0.75
    elif "plantation" in lc_lower:
        return 0.65
    elif "marginal" in lc_lower:
        return 0.40
    elif "forest" in lc_lower or "wetland" in lc_lower:
        return 0.25
    else:
        return 0.55


def _categorize_risk(score: int) -> str:
    """Assign risk category based on score."""
    if score >= 800:
        return "Low"
    elif score >= 600:
        return "Medium"
    else:
        return "High"
