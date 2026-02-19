import requests
import json

url = "http://127.0.0.1:8000/api/predict"

payload = {
    "state": "Maharashtra",
    "district": "Pune",
    "crop_type": "Rice",
    "season": "Kharif",
    "land_area_hectares": 5.0,
    "soil_type": "Alluvial",
    "ndvi_current": 0.5,
    "rainfall_mm": 500.0,
    "avg_temperature_c": 30.0,
    "past_yield_ton_per_hectare": 3.0
}

try:
    print(f"Sending request to {url}...")
    response = requests.post(url, json=payload, timeout=30)
    print(f"Status Code: {response.status_code}")
    if response.status_code == 200:
        print("Success! Prediction received.")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    else:
        print(f"Failed. Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
