from fastapi import APIRouter, HTTPException, Query
import ee
import os
import json
from google.oauth2.service_account import Credentials
from datetime import datetime

router = APIRouter(prefix="/api/gee", tags=["Earth Engine"])

# Initialize Earth Engine
# This requires the GOOGLE_APPLICATION_CREDENTIALS env var or a service account key file
try:
    # Check for service account key file
    key_path = os.getenv("GEE_SERVICE_ACCOUNT_KEY")
    if key_path and os.path.exists(key_path):
        credentials = Credentials.from_service_account_file(key_path)
        ee.Initialize(credentials=credentials)
        print("GEE Initialized successfully with Service Account.")
    else:
        # Fallback to default auth (might work in cloud environments)
        ee.Initialize()
        print("GEE Initialized with default credentials.")
except Exception as e:
    print(f"Warning: GEE Initialization failed: {e}")

@router.get("/ndvi-heatmap")
async def get_ndvi_heatmap(
    lat: float = Query(..., description="Latitude of the center point"),
    lng: float = Query(..., description="Longitude of the center point"),
    zoom: int = Query(13, description="Zoom level"),
):
    """
    Returns a Tile URL template for an NDVI heatmap layer from Sentinel-2.
    """
    try:
        # Define the region of interest (a point buffer for simplicity of filtering)
        # Using a point to filter the collection
        point = ee.Geometry.Point([lng, lat])
        
        # Load Sentinel-2 collection (Surface Reflectance)
        s2 = ee.ImageCollection('COPERNICUS/S2_SR') \
            .filterBounds(point) \
            .filterDate(ee.Date(datetime.now().strftime("%Y-%m-%d")).advance(-30, 'day'), datetime.now()) \
            .sort('CLOUDY_PIXEL_PERCENTAGE') \
            .first()

        if not s2:
            raise HTTPException(status_code=404, detail="No suitable satellite imagery found for this location.")

        # Compute NDVI
        ndvi = s2.normalizedDifference(['B8', 'B4']).rename('NDVI')

        # Create a visualization
        vis_params = {
            'min': 0,
            'max': 1,
            'palette': ['red', 'yellow', 'green']
        }
        
        # Get the map ID and token
        # This returns a dictionary with 'mapid' and 'token'
        map_id_dict = ndvi.getMapId(vis_params)
        
        # Construct the Tile URL format
        # https://earthengine.googleapis.com/v1alpha/projects/earthengine-legacy/maps/{mapid}/tiles/{z}/{x}/{y}
        tile_url_format = map_id_dict['tile_fetcher'].url_format
        
        return {
            "tile_url_format": tile_url_format,
            "metadata": {
                "satellite": "Sentinel-2",
                "date": "Last 30 days specific logic needed for actual date extraction",
                "cloud_cover": "Low"
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"GEE Error: {str(e)}")
