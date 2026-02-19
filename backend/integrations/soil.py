"""Soil type and land classification via Bhuvan / SoilGrids."""

import os
import logging
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

BHUVAN_API_KEY = os.getenv("BHUVAN_API_KEY", "")
SOILGRIDS_BASE = "https://rest.isric.org/soilgrids/v2.0"


async def get_soil_data(lat: float, lng: float) -> dict:
    """
    Retrieve soil type and land classification.
    Primary: ISRIC SoilGrids (reliable global coverage).
    Fallback: Bhuvan WMS (if accessible).
    Returns: {"soil_type": str, "land_class": str, "source": str, "details": dict}
    """
    try:
        return await _fetch_soilgrids(lat, lng)
    except Exception as e:
        logger.warning(f"SoilGrids failed: {e}")
        try:
            return await _fetch_bhuvan(lat, lng)
        except Exception as e2:
            logger.warning(f"Bhuvan failed: {e2}")
            return _estimate_soil(lat, lng)


async def _fetch_soilgrids(lat: float, lng: float) -> dict:
    """Fetch soil properties from ISRIC SoilGrids REST API."""
    async with httpx.AsyncClient(timeout=30.0) as client:
        # Fetch soil classification (WRB taxonomy)
        resp = await client.get(
            f"{SOILGRIDS_BASE}/classification/query",
            params={"lon": lng, "lat": lat, "number_classes": 5},
        )

        soil_type = "Unknown"
        details = {}

        if resp.status_code == 200:
            data = resp.json()
            wrb_class = data.get("wrb_class_name")
            if wrb_class:
                soil_type = wrb_class
                details["wrb_class"] = wrb_class
                details["probability"] = data.get("wrb_class_probability", 0)

        # Fetch soil properties for quality assessment
        props_resp = await client.get(
            f"{SOILGRIDS_BASE}/properties/query",
            params={
                "lon": lng,
                "lat": lat,
                "property": ["clay", "sand", "silt", "soc", "phh2o"],
                "depth": "0-5cm",
                "value": "mean",
            },
        )

        if props_resp.status_code == 200:
            props_data = props_resp.json()
            layers = props_data.get("properties", {}).get("layers", [])
            for layer in layers:
                name = layer.get("name", "")
                depths = layer.get("depths", [])
                if depths:
                    val = depths[0].get("values", {}).get("mean")
                    if val is not None:
                        details[name] = val

        # Determine land classification from soil type
        land_class = _classify_land_from_soil(soil_type, details)

        return {
            "soil_type": soil_type,
            "land_class": land_class,
            "source": "soilgrids",
            "details": details,
        }


async def _fetch_bhuvan(lat: float, lng: float) -> dict:
    """Fetch soil/land data from ISRO Bhuvan WMS services."""
    async with httpx.AsyncClient(timeout=20.0) as client:
        # Bhuvan LULC WMS
        bbox = f"{lng-0.01},{lat-0.01},{lng+0.01},{lat+0.01}"
        resp = await client.get(
            "https://bhuvan-vec2.nrsc.gov.in/bhuvan/wms",
            params={
                "service": "WMS",
                "version": "1.1.1",
                "request": "GetFeatureInfo",
                "layers": "lulc:IN_LULC50K_1516",
                "query_layers": "lulc:IN_LULC50K_1516",
                "info_format": "application/json",
                "feature_count": 1,
                "x": 50,
                "y": 50,
                "width": 101,
                "height": 101,
                "srs": "EPSG:4326",
                "bbox": bbox,
            },
            headers={"Authorization": f"Bearer {BHUVAN_API_KEY}"},
        )

        if resp.status_code == 200:
            data = resp.json()
            features = data.get("features", [])
            if features:
                props = features[0].get("properties", {})
                return {
                    "soil_type": props.get("Soil_Type", "Mixed Soil"),
                    "land_class": props.get("LULC_Class", "Agricultural Land"),
                    "source": "bhuvan",
                    "details": props,
                }

    raise Exception("Bhuvan data unavailable")


def _classify_land_from_soil(soil_type: str, details: dict) -> str:
    """Classify land use based on soil type and measurable properties.

    SoilGrids returns:
      - soc   : soil organic carbon in dg/kg (divide by 10 for g/kg)
      - clay  : clay content in g/kg
      - sand  : sand content in g/kg
      - silt  : silt content in g/kg (= 1000 - clay - sand, approx)
      - phh2o : pH × 10
    """
    soc = details.get("soc", 0) or 0   # dg/kg
    clay = details.get("clay", 0) or 0  # g/kg
    sand = details.get("sand", 0) or 0  # g/kg
    ph = (details.get("phh2o", 0) or 0) / 10  # actual pH

    soil_lower = soil_type.lower()

    # ── 1. WRB taxonomy match (when SoilGrids classification succeeds) ──
    if any(k in soil_lower for k in ["vertisol", "chernozem", "phaeozem", "luvisol",
                                      "kastanozem", "nitisol"]):
        return "Prime Agricultural Land"
    elif any(k in soil_lower for k in ["cambisol", "fluvisol", "gleysol",
                                        "planosol", "stagnosol", "acrisol"]):
        return "Agricultural Land"
    elif any(k in soil_lower for k in ["leptosol", "regosol", "arenosol",
                                        "solonchak", "solonetz"]):
        return "Marginal Agricultural Land"
    elif any(k in soil_lower for k in ["histosol", "podzol", "umbrisol"]):
        return "Forest / Wetland"
    elif any(k in soil_lower for k in ["ferralsol", "plinthosol", "alisol"]):
        return "Laterite / Plantation Land"

    # ── 2. Property-based scoring (when WRB class is missing/unknown) ──
    # Convert SOC from dg/kg -> g/kg
    soc_gkg = soc / 10.0

    # Score each factor (0–1)
    soc_score = min(soc_gkg / 40.0, 1.0)           # 40 g/kg = very rich
    clay_score = 1.0 - abs(clay - 300) / 400.0      # ~300 g/kg ideal clay
    clay_score = max(0, min(clay_score, 1.0))
    ph_score = 1.0 - abs(ph - 6.5) / 3.0            # 6.5 ideal pH
    ph_score = max(0, min(ph_score, 1.0))

    fertility = (soc_score * 0.4) + (clay_score * 0.35) + (ph_score * 0.25)

    if sand > 700:
        return "Sandy / Marginal Land"
    elif clay > 500:
        return "Heavy Clay Agricultural Land"
    elif fertility >= 0.7:
        return "Prime Agricultural Land"
    elif fertility >= 0.5:
        return "Fertile Agricultural Land"
    elif fertility >= 0.3:
        return "Agricultural Land"
    else:
        return "Marginal Agricultural Land"


def _estimate_soil(lat: float, lng: float) -> dict:
    """Estimate soil type based on Indian geographic regions."""
    import hashlib

    # Regional soil mapping for India
    if 8 <= lat <= 16 and 73 <= lng <= 80:
        soil_type, land_class = "Laterite Soil", "Plantation Land"
    elif 16 <= lat <= 24 and 72 <= lng <= 82:
        soil_type, land_class = "Black Cotton Soil (Regur)", "Prime Agricultural Land"
    elif 24 <= lat <= 30 and 75 <= lng <= 88:
        soil_type, land_class = "Alluvial Soil", "Agricultural Land"
    elif 28 <= lat <= 35 and 74 <= lng <= 78:
        soil_type, land_class = "Mountain Soil", "Marginal Agricultural Land"
    elif 20 <= lat <= 28 and 82 <= lng <= 92:
        soil_type, land_class = "Red Soil", "Agricultural Land"
    else:
        soil_type, land_class = "Mixed Soil", "General Agricultural Land"

    return {
        "soil_type": soil_type,
        "land_class": land_class,
        "source": "estimated",
        "details": {"note": "Estimated from regional geography — API data unavailable"},
    }
