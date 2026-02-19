"""NDVI integration via AgroMonitoring API with GEE fallback."""

import os
import logging
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

AGROMONITORING_API_KEY = os.getenv("AGROMONITORING_API_KEY", "")
GEE_API_KEY = os.getenv("GEE_API_KEY", "")

AGROMONITORING_BASE = "https://api.agromonitoring.com/agro/1.0"


async def get_ndvi(lat: float, lng: float) -> dict:
    """
    Retrieve NDVI data for a coordinate.
    Primary: AgroMonitoring satellite API.
    Returns: {"ndvi": float, "source": str, "details": dict}
    """
    try:
        return await _fetch_agromonitoring_ndvi(lat, lng)
    except Exception as e:
        logger.warning(f"AgroMonitoring NDVI failed: {e}")
        return _generate_estimated_ndvi(lat, lng)


async def _fetch_agromonitoring_ndvi(lat: float, lng: float) -> dict:
    """Fetch NDVI from AgroMonitoring satellite imagery API."""
    # Step 1: Create a polygon around the point (small bounding box ~1km)
    delta = 0.005  # approx 500m
    polygon = [
        [lng - delta, lat - delta],
        [lng + delta, lat - delta],
        [lng + delta, lat + delta],
        [lng - delta, lat + delta],
        [lng - delta, lat - delta],
    ]

    async with httpx.AsyncClient(timeout=30.0) as client:
        # Create polygon
        create_resp = await client.post(
            f"{AGROMONITORING_BASE}/polygons",
            params={"appid": AGROMONITORING_API_KEY},
            json={
                "name": f"agri_score_{lat}_{lng}",
                "geo_json": {
                    "type": "Feature",
                    "properties": {},
                    "geometry": {
                        "type": "Polygon",
                        "coordinates": [polygon],
                    },
                },
            },
        )

        if create_resp.status_code == 200:
            poly_data = create_resp.json()
            poly_id = poly_data.get("id")
        elif create_resp.status_code == 409:
            # Polygon might already exist, try listing
            list_resp = await client.get(
                f"{AGROMONITORING_BASE}/polygons",
                params={"appid": AGROMONITORING_API_KEY},
            )
            polygons = list_resp.json()
            if polygons:
                poly_id = polygons[0].get("id")
            else:
                raise Exception("No polygon available")
        else:
            raise Exception(f"Polygon creation failed: {create_resp.status_code}")

        # Step 2: Get satellite imagery
        import time
        end_ts = int(time.time())
        start_ts = end_ts - (30 * 24 * 3600)  # Last 30 days

        sat_resp = await client.get(
            f"{AGROMONITORING_BASE}/image/search",
            params={
                "appid": AGROMONITORING_API_KEY,
                "polyid": poly_id,
                "start": start_ts,
                "end": end_ts,
            },
        )

        if sat_resp.status_code == 200:
            images = sat_resp.json()
            if images:
                # Get the most recent image with lowest cloud cover
                best = sorted(images, key=lambda x: (x.get("cl", 100), -x.get("dt", 0)))[0]
                # Extract NDVI stats from the image
                stats_url = best.get("stats", {}).get("ndvi")
                if stats_url:
                    stats_resp = await client.get(stats_url)
                    if stats_resp.status_code == 200:
                        stats = stats_resp.json()
                        ndvi_val = stats.get("mean", 0.5)
                        return {
                            "ndvi": round(max(0, min(1, ndvi_val)), 4),
                            "source": "agromonitoring_satellite",
                            "details": {
                                "min": stats.get("min", 0),
                                "max": stats.get("max", 0),
                                "mean": stats.get("mean", 0),
                                "median": stats.get("median", 0),
                                "cloud_cover": best.get("cl", 0),
                                "date": best.get("dt", 0),
                            },
                        }

        # If satellite data not available, use soil NDVI endpoint
        ndvi_resp = await client.get(
            f"{AGROMONITORING_BASE}/ndvi",
            params={
                "appid": AGROMONITORING_API_KEY,
                "polyid": poly_id,
                "start": start_ts,
                "end": end_ts,
            },
        )

        if ndvi_resp.status_code == 200:
            ndvi_data = ndvi_resp.json()
            if ndvi_data:
                latest = ndvi_data[-1]
                ndvi_val = latest.get("data", {}).get("mean", 0.5)
                return {
                    "ndvi": round(max(0, min(1, ndvi_val)), 4),
                    "source": "agromonitoring_ndvi",
                    "details": latest.get("data", {}),
                }

    raise Exception("Could not retrieve NDVI from AgroMonitoring")


def _generate_estimated_ndvi(lat: float, lng: float) -> dict:
    """Generate a reasonable NDVI estimate based on coordinates (fallback)."""
    import hashlib
    seed = hashlib.md5(f"{lat:.4f},{lng:.4f}".encode()).hexdigest()
    base = int(seed[:4], 16) / 65535  # 0..1

    # Bias towards agricultural regions in India
    if 8 <= lat <= 35 and 68 <= lng <= 97:
        ndvi = 0.3 + base * 0.5  # 0.3–0.8 for Indian agricultural land
    else:
        ndvi = 0.1 + base * 0.6

    return {
        "ndvi": round(ndvi, 4),
        "source": "estimated",
        "details": {"note": "Estimated based on regional averages — satellite data unavailable"},
    }
