"""
Prediction service — loads trained ML models and provides predictions.

Singleton pattern: models are loaded once at import time and reused.

Usage:
    from ml.prediction_service import predict, is_model_available
    result = predict({
        "state": "Maharashtra",
        "district": "Pune",
        "crop_type": "Rice",
        "season": "Kharif",
        "land_area_hectares": 5.0,
        "soil_type": "Alluvial",
        "ndvi_current": 0.65,
        "ndvi_30day_avg": 0.58,
        "rainfall_mm": 120.0,
        "avg_temperature_c": 28.0,
        "past_yield_ton_per_hectare": 3.5,
    })
"""

import os
import logging
from typing import Optional

import numpy as np
import joblib

logger = logging.getLogger(__name__)

# ── Paths ─────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, "models")

# ── Model Cache (loaded once) ────────────────────────────────
_models = {}
_label_encoders = {}
_target_encoders = {}
_loaded = False

# Feature order (must match training)
FEATURE_COLS = [
    "state", "district", "crop_type", "season",
    "land_area_hectares", "soil_type",
    "ndvi_current", "ndvi_30day_avg",
    "rainfall_mm", "avg_temperature_c",
    "past_yield_ton_per_hectare",
]
CATEGORICAL_COLS = ["state", "district", "crop_type", "season", "soil_type"]

# NDVI trend descriptions
NDVI_TREND_DESCRIPTIONS = {
    "Increase": "NDVI expected to increase in next 15 days",
    "Stable": "NDVI expected to remain stable in next 15 days",
    "Decrease": "NDVI expected to decrease in next 15 days",
}

# Mapping from API/analysis feature names to model feature names
# This allows the analysis_service to pass features without renaming
FEATURE_ALIASES = {
    "ndvi_value": "ndvi_current",
    "temperature": "avg_temperature_c",
    "rainfall": "rainfall_mm",
    "land_area": "land_area_hectares",
    "past_crop_quality": None,  # not used; silently ignore
    "humidity": None,  # not in our model; silently ignore
}


def _load_models():
    """Load all trained models and encoders from disk (one-time)."""
    global _models, _label_encoders, _target_encoders, _loaded

    if _loaded:
        return

    try:
        _models["agri_score"] = joblib.load(
            os.path.join(MODELS_DIR, "agri_score_model.joblib")
        )
        _models["crop_quality"] = joblib.load(
            os.path.join(MODELS_DIR, "crop_quality_model.joblib")
        )
        _models["risk_level"] = joblib.load(
            os.path.join(MODELS_DIR, "risk_level_model.joblib")
        )
        _models["ndvi_trend"] = joblib.load(
            os.path.join(MODELS_DIR, "ndvi_trend_model.joblib")
        )
        _label_encoders.update(
            joblib.load(os.path.join(MODELS_DIR, "label_encoders.joblib"))
        )
        _target_encoders.update(
            joblib.load(os.path.join(MODELS_DIR, "target_encoders.joblib"))
        )
        _loaded = True
        logger.info("✅ ML models loaded successfully")
    except FileNotFoundError as e:
        logger.error(
            f"ML model files not found: {e}. "
            "Run 'python -m ml.train_model' to train models first."
        )
        raise RuntimeError(
            "ML models not trained yet. Run 'python -m ml.train_model' first."
        ) from e


def _encode_feature(col: str, value: str) -> int:
    """Encode a categorical feature using the saved LabelEncoder."""
    le = _label_encoders.get(col)
    if le is None:
        logger.warning(f"No encoder for column '{col}', defaulting to 0")
        return 0

    # Handle unseen labels gracefully
    if value in le.classes_:
        return int(le.transform([value])[0])
    else:
        logger.warning(f"Unknown value '{value}' for '{col}', using closest match")
        # Find closest match (case-insensitive)
        val_lower = value.lower()
        for cls in le.classes_:
            if cls.lower() == val_lower or val_lower in cls.lower():
                return int(le.transform([cls])[0])
        return 0  # default fallback


def _decode_target(target_name: str, encoded_value) -> str:
    """Decode an encoded target back to its label."""
    le = _target_encoders.get(target_name)
    if le is None:
        return str(encoded_value)
    return str(le.inverse_transform([int(encoded_value)])[0])


def _normalize_features(features: dict) -> dict:
    """Map legacy/alias feature names to the model's expected column names."""
    normalized = {}
    for key, value in features.items():
        if key in FEATURE_COLS:
            normalized[key] = value
        elif key in FEATURE_ALIASES:
            mapped = FEATURE_ALIASES[key]
            if mapped is not None:
                normalized[mapped] = value
            # else: silently skip (feature not used)
        else:
            # Pass through any unknown keys; they'll be ignored
            normalized[key] = value
    return normalized


def predict(features: dict) -> dict:
    """
    Run all 4 ML models on the given features.

    Args:
        features: dict with keys matching FEATURE_COLS (or legacy aliases)

    Returns:
        {
            "crop_quality": str,
            "crop_health_score": int,
            "risk_level": str,
            "ndvi_trend": str,
            "ndvi_trend_description": str,
            "confidence": {
                "crop_quality": float,
                "risk_level": float,
                "ndvi_trend": float,
            }
        }
    """
    _load_models()

    # Normalize feature names (handle aliases from analysis_service)
    features = _normalize_features(features)

    # ── Build feature vector ──────────────────────────────────
    feature_vector = []
    for col in FEATURE_COLS:
        val = features.get(col)
        if val is None:
            if col in CATEGORICAL_COLS:
                val = "Unknown"
                logger.warning(f"Missing feature '{col}', using '{val}'")
            else:
                val = 0.0
                logger.warning(f"Missing feature '{col}', using {val}")

        if col in CATEGORICAL_COLS:
            feature_vector.append(_encode_feature(col, str(val)))
        else:
            feature_vector.append(float(val))

    X = np.array([feature_vector])

    # ── Run predictions ───────────────────────────────────────

    # 1. Agri Trust Score (regressor)
    score_pred = _models["agri_score"].predict(X)[0]
    health_score = int(round(max(0, min(100, score_pred))))

    # 2. Crop Quality
    quality_pred = _models["crop_quality"].predict(X)[0]
    quality_proba = _models["crop_quality"].predict_proba(X)[0]
    quality_label = _decode_target("crop_quality", quality_pred)
    quality_confidence = float(max(quality_proba))

    # 3. Risk Level
    risk_pred = _models["risk_level"].predict(X)[0]
    risk_proba = _models["risk_level"].predict_proba(X)[0]
    risk_label = _decode_target("risk_level", risk_pred)
    risk_confidence = float(max(risk_proba))

    # 4. NDVI Trend
    trend_pred = _models["ndvi_trend"].predict(X)[0]
    trend_proba = _models["ndvi_trend"].predict_proba(X)[0]
    trend_label = _decode_target("ndvi_trend", trend_pred)
    trend_confidence = float(max(trend_proba))

    result = {
        "crop_quality": quality_label,
        "crop_health_score": health_score,
        "risk_level": f"{risk_label} Risk",
        "ndvi_trend": trend_label,
        "ndvi_trend_description": NDVI_TREND_DESCRIPTIONS.get(
            trend_label, f"NDVI trend: {trend_label}"
        ),
        "confidence": {
            "crop_quality": round(quality_confidence, 4),
            "risk_level": round(risk_confidence, 4),
            "ndvi_trend": round(trend_confidence, 4),
        },
    }

    logger.info(
        f"ML Prediction: quality={quality_label} health={health_score} "
        f"risk={risk_label} trend={trend_label}"
    )

    return result


def is_model_available() -> bool:
    """Check if trained models exist on disk."""
    required_files = [
        "agri_score_model.joblib",
        "crop_quality_model.joblib",
        "risk_level_model.joblib",
        "ndvi_trend_model.joblib",
        "label_encoders.joblib",
        "target_encoders.joblib",
    ]
    return all(
        os.path.exists(os.path.join(MODELS_DIR, f)) for f in required_files
    )
