"""
Generate synthetic training data for Agri-Score ML models.

Creates a realistic dataset (~5000 rows) with agricultural features and
target labels for: crop quality, health score, risk level, and NDVI trend.

Usage:
    python -m ml.generate_training_data
"""

import os
import random
import csv
import math

# ── Configuration ─────────────────────────────────────────────

NUM_SAMPLES = 5000
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "training_data.csv")

# Soil types (matched to calculator.py)
SOIL_TYPES = [
    "Alluvial Soil", "Black Cotton Soil (Regur)", "Red Soil", "Laterite Soil",
    "Chernozem", "Vertisol", "Luvisol", "Cambisol", "Fluvisol",
    "Acrisol", "Ferralsol", "Arenosol", "Mixed Soil",
]

# Soil quality mapping (higher = better)
SOIL_QUALITY = {
    "Alluvial Soil": 0.85, "Black Cotton Soil (Regur)": 0.88,
    "Red Soil": 0.72, "Laterite Soil": 0.58, "Chernozem": 0.95,
    "Vertisol": 0.88, "Luvisol": 0.80, "Cambisol": 0.78,
    "Fluvisol": 0.82, "Acrisol": 0.60, "Ferralsol": 0.55,
    "Arenosol": 0.30, "Mixed Soil": 0.60,
}

CROP_TYPES = [
    "Rice", "Wheat", "Cotton", "Sugarcane", "Maize",
    "Soybean", "Groundnut", "Mustard", "Pulses", "Vegetables",
]

SEASONS = ["Kharif", "Rabi", "Zaid"]

QUALITY_LABELS = ["Poor", "Moderate", "Good", "Excellent"]
RISK_LABELS = ["High", "Medium", "Low"]
NDVI_TREND_LABELS = ["Decrease", "Stable", "Increase"]


def _clamp(val, lo=0.0, hi=1.0):
    return max(lo, min(hi, val))


def _generate_row(rng: random.Random) -> dict:
    """Generate one realistic sample with correlated features and labels."""

    # ── Features ──────────────────────────────────────────────
    soil_type = rng.choice(SOIL_TYPES)
    crop_type = rng.choice(CROP_TYPES)
    season = rng.choice(SEASONS)
    land_area = round(rng.uniform(0.5, 50.0), 2)

    soil_q = SOIL_QUALITY[soil_type]

    # Season-aware temperature & rainfall
    if season == "Kharif":   # Monsoon (Jun–Oct)
        temperature = round(rng.uniform(25, 40), 1)
        rainfall = round(rng.uniform(80, 300), 1)
        humidity = round(rng.uniform(60, 95), 1)
    elif season == "Rabi":   # Winter (Oct–Mar)
        temperature = round(rng.uniform(10, 28), 1)
        rainfall = round(rng.uniform(10, 80), 1)
        humidity = round(rng.uniform(30, 70), 1)
    else:                    # Zaid — Summer (Mar–Jun)
        temperature = round(rng.uniform(30, 45), 1)
        rainfall = round(rng.uniform(0, 50), 1)
        humidity = round(rng.uniform(20, 55), 1)

    # NDVI correlated with soil quality, rainfall, and season
    ndvi_base = soil_q * 0.4 + (rainfall / 300) * 0.3 + rng.uniform(-0.1, 0.15)
    ndvi_value = round(_clamp(ndvi_base, 0.05, 0.95), 4)

    # Past crop quality (slightly random but biased by soil)
    past_quality_idx = min(3, max(0, int(soil_q * 4 - 1 + rng.uniform(-1, 1))))
    past_crop_quality = QUALITY_LABELS[past_quality_idx]

    # ── Target Labels (derived from realistic rules) ──────────

    # 1. Crop Quality — composite of all factors
    quality_score = (
        ndvi_value * 0.30
        + soil_q * 0.25
        + _clamp(rainfall / 200) * 0.15
        + _clamp(humidity / 80) * 0.10
        + (1 - _clamp((temperature - 25) / 20)) * 0.10  # penalty for extreme heat
        + (QUALITY_LABELS.index(past_crop_quality) / 3) * 0.10
    )
    quality_score = _clamp(quality_score + rng.uniform(-0.08, 0.08))

    if quality_score >= 0.75:
        crop_quality = "Excellent"
    elif quality_score >= 0.55:
        crop_quality = "Good"
    elif quality_score >= 0.35:
        crop_quality = "Moderate"
    else:
        crop_quality = "Poor"

    # 2. Crop Health Score (0–100)
    health_score = round(_clamp(quality_score * 100 + rng.uniform(-8, 8), 0, 100), 1)

    # 3. Risk Level
    if quality_score >= 0.70:
        risk_level = "Low"
    elif quality_score >= 0.45:
        risk_level = "Medium"
    else:
        risk_level = "High"

    # 4. NDVI Trend — based on current NDVI + rainfall + season
    trend_score = ndvi_value * 0.4 + (rainfall / 300) * 0.3 + humidity / 100 * 0.2
    trend_score += rng.uniform(-0.15, 0.15)
    if trend_score >= 0.55:
        ndvi_trend = "Increase"
    elif trend_score >= 0.35:
        ndvi_trend = "Stable"
    else:
        ndvi_trend = "Decrease"

    return {
        # Features
        "ndvi_value": ndvi_value,
        "temperature": temperature,
        "rainfall": rainfall,
        "humidity": humidity,
        "soil_type": soil_type,
        "crop_type": crop_type,
        "land_area": land_area,
        "season": season,
        "past_crop_quality": past_crop_quality,
        # Targets
        "crop_quality": crop_quality,
        "crop_health_score": health_score,
        "risk_level": risk_level,
        "ndvi_trend": ndvi_trend,
    }


def generate_dataset(num_samples: int = NUM_SAMPLES, seed: int = 42) -> str:
    """Generate the dataset and write to CSV. Returns the output path."""
    rng = random.Random(seed)

    fieldnames = [
        "ndvi_value", "temperature", "rainfall", "humidity",
        "soil_type", "crop_type", "land_area", "season", "past_crop_quality",
        "crop_quality", "crop_health_score", "risk_level", "ndvi_trend",
    ]

    rows = [_generate_row(rng) for _ in range(num_samples)]

    with open(OUTPUT_FILE, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    # Print distribution summary
    from collections import Counter
    quality_dist = Counter(r["crop_quality"] for r in rows)
    risk_dist = Counter(r["risk_level"] for r in rows)
    trend_dist = Counter(r["ndvi_trend"] for r in rows)

    print(f"\n✅ Generated {num_samples} samples → {OUTPUT_FILE}")
    print(f"\n📊 Crop Quality Distribution:")
    for label in QUALITY_LABELS:
        count = quality_dist.get(label, 0)
        print(f"   {label:12s}: {count:5d} ({count/num_samples*100:.1f}%)")
    print(f"\n📊 Risk Level Distribution:")
    for label in RISK_LABELS:
        count = risk_dist.get(label, 0)
        print(f"   {label:12s}: {count:5d} ({count/num_samples*100:.1f}%)")
    print(f"\n📊 NDVI Trend Distribution:")
    for label in NDVI_TREND_LABELS:
        count = trend_dist.get(label, 0)
        print(f"   {label:12s}: {count:5d} ({count/num_samples*100:.1f}%)")

    return OUTPUT_FILE


if __name__ == "__main__":
    generate_dataset()
