"""Weather integration via OpenWeather API."""

import os
import logging
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

WEATHER_API_KEY = os.getenv("WEATHER_API_KEY", "")
OPENWEATHER_BASE = "https://api.openweathermap.org/data/2.5"


async def get_weather_data(lat: float, lng: float) -> dict:
    """
    Retrieve weather and drought risk indicators.
    Returns: {"weather_index": float (0-1), "summary": str, "details": dict}
    """
    try:
        return await _fetch_openweather(lat, lng)
    except Exception as e:
        logger.warning(f"OpenWeather failed: {e}")
        return _estimate_weather(lat, lng)


async def _fetch_openweather(lat: float, lng: float) -> dict:
    """Fetch current weather + forecast for rainfall/drought analysis."""
    async with httpx.AsyncClient(timeout=20.0) as client:
        # Current weather
        current_resp = await client.get(
            f"{OPENWEATHER_BASE}/weather",
            params={
                "lat": lat,
                "lon": lng,
                "appid": WEATHER_API_KEY,
                "units": "metric",
            },
        )

        details = {}
        weather_index = 0.5  # neutral default

        if current_resp.status_code == 200:
            data = current_resp.json()
            temp = data.get("main", {}).get("temp", 25)
            humidity = data.get("main", {}).get("humidity", 50)
            rain_1h = data.get("rain", {}).get("1h", 0)
            clouds = data.get("clouds", {}).get("all", 50)
            wind = data.get("wind", {}).get("speed", 5)
            weather_desc = data.get("weather", [{}])[0].get("description", "")

            details = {
                "temperature": temp,
                "humidity": humidity,
                "rainfall_1h": rain_1h,
                "cloud_cover": clouds,
                "wind_speed": wind,
                "description": weather_desc,
            }

            # Calculate weather favorability index (0 = terrible, 1 = excellent)
            scores = []

            # Temperature score (ideal 20-35°C for Indian agriculture)
            if 20 <= temp <= 35:
                scores.append(1.0)
            elif 15 <= temp <= 40:
                scores.append(0.7)
            elif 10 <= temp <= 45:
                scores.append(0.4)
            else:
                scores.append(0.2)

            # Humidity score (ideal 40-80%)
            if 40 <= humidity <= 80:
                scores.append(1.0)
            elif 30 <= humidity <= 90:
                scores.append(0.7)
            else:
                scores.append(0.3)

            # Rainfall indicator (recent rain is good)
            if rain_1h > 0:
                scores.append(min(1.0, 0.5 + rain_1h * 0.1))
            elif humidity > 60:
                scores.append(0.6)
            else:
                scores.append(0.3)

            # Wind score (low wind is better)
            if wind < 5:
                scores.append(0.9)
            elif wind < 15:
                scores.append(0.7)
            else:
                scores.append(0.3)

            weather_index = round(sum(scores) / len(scores), 4)

        # Forecast for drought risk assessment
        forecast_resp = await client.get(
            f"{OPENWEATHER_BASE}/forecast",
            params={
                "lat": lat,
                "lon": lng,
                "appid": WEATHER_API_KEY,
                "units": "metric",
                "cnt": 40,  # 5-day / 3-hour = 40 entries
            },
        )

        if forecast_resp.status_code == 200:
            forecast_data = forecast_resp.json()
            forecasts = forecast_data.get("list", [])
            rain_days = sum(1 for f in forecasts if f.get("rain", {}).get("3h", 0) > 0)
            total_rain = sum(f.get("rain", {}).get("3h", 0) for f in forecasts)

            details["forecast_rain_days"] = rain_days
            details["forecast_total_rain_mm"] = round(total_rain, 1)
            details["drought_risk"] = "Low" if total_rain > 10 else "Medium" if total_rain > 2 else "High"

            # Adjust weather index based on forecast
            if total_rain > 10:
                weather_index = min(1.0, weather_index + 0.1)
            elif total_rain < 2:
                weather_index = max(0.0, weather_index - 0.15)

        # Generate summary
        summary = _generate_weather_summary(details, weather_index)

        return {
            "weather_index": round(weather_index, 4),
            "summary": summary,
            "source": "openweather",
            "details": details,
        }


def _generate_weather_summary(details: dict, index: float) -> str:
    """Generate human-readable weather summary."""
    temp = details.get("temperature", "N/A")
    humidity = details.get("humidity", "N/A")
    drought = details.get("drought_risk", "Unknown")
    desc = details.get("description", "")

    if index >= 0.8:
        return f"Excellent conditions — {desc}, {temp}°C, {humidity}% humidity. Low drought risk."
    elif index >= 0.6:
        return f"Good conditions — {desc}, {temp}°C, {humidity}% humidity. Drought risk: {drought}."
    elif index >= 0.4:
        return f"Moderate conditions — {desc}, {temp}°C, {humidity}% humidity. Drought risk: {drought}."
    else:
        return f"Challenging conditions — {desc}, {temp}°C, {humidity}% humidity. High drought risk."


def _estimate_weather(lat: float, lng: float) -> dict:
    """Estimate weather conditions based on season and region."""
    import datetime
    month = datetime.datetime.now().month

    # Monsoon months: June-September
    if 6 <= month <= 9:
        weather_index = 0.75
        summary = "Monsoon season — good rainfall expected."
    elif 10 <= month <= 11:
        weather_index = 0.65
        summary = "Post-monsoon — moderate conditions."
    elif 12 <= month <= 2:
        weather_index = 0.5
        summary = "Winter — dry conditions, irrigation dependent."
    else:
        weather_index = 0.55
        summary = "Pre-monsoon — warming, limited rainfall."

    return {
        "weather_index": weather_index,
        "summary": summary,
        "source": "estimated",
        "details": {"note": "Seasonal estimate — weather API unavailable"},
    }
