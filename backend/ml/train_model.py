"""
Train Random Forest ML models for Agri-Score predictions.

Uses the user-provided dataset: agri_score_dataset_5000_rows_final.csv

Trains 4 models:
  1. Agri Trust Score Regressor  (0–100 score)
  2. Crop Quality Classifier     (Excellent / Good / Moderate / Poor)
  3. Risk Level Classifier       (Low Risk / Medium Risk / High Risk)
  4. NDVI Trend Classifier       (Increase / Stable / Decrease)

Crop Quality & Risk Level are derived from agri_trust_score,
NDVI Trend is derived from ndvi_current vs ndvi_30day_avg.

Usage:
    python -m ml.train_model
"""

import os
import logging

import pandas as pd
import numpy as np
import joblib
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import (
    classification_report,
    accuracy_score,
    mean_absolute_error,
    r2_score,
)

logger = logging.getLogger(__name__)

# ── Paths ─────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(BASE_DIR, "agri_score_dataset_5000_rows_final.csv")
MODELS_DIR = os.path.join(BASE_DIR, "models")

# ── Feature Columns (must match CSV headers) ─────────────────
FEATURE_COLS = [
    "state", "district", "crop_type", "season",
    "land_area_hectares", "soil_type",
    "ndvi_current", "ndvi_30day_avg",
    "rainfall_mm", "avg_temperature_c",
    "past_yield_ton_per_hectare",
]
CATEGORICAL_COLS = ["state", "district", "crop_type", "season", "soil_type"]


def _derive_crop_quality(score: float) -> str:
    """Derive crop quality label from agri_trust_score."""
    if score >= 80:
        return "Excellent"
    elif score >= 60:
        return "Good"
    elif score >= 40:
        return "Moderate"
    else:
        return "Poor"


def _derive_risk_level(score: float) -> str:
    """Derive risk level from agri_trust_score."""
    if score >= 70:
        return "Low"
    elif score >= 40:
        return "Medium"
    else:
        return "High"


def _derive_ndvi_trend(ndvi_current: float, ndvi_30day_avg: float) -> str:
    """Derive NDVI trend from current vs 30-day average."""
    diff = ndvi_current - ndvi_30day_avg
    if diff > 0.05:
        return "Increase"
    elif diff < -0.05:
        return "Decrease"
    else:
        return "Stable"


def train_all_models():
    """Main training pipeline — loads CSV, derives targets, trains, evaluates, saves."""

    # ── Step 0: Check data file exists ────────────────────────
    if not os.path.exists(DATA_FILE):
        print(f"❌ Training data not found at: {DATA_FILE}")
        print("   Please place 'agri_score_dataset_5000_rows_final.csv' in the ml/ directory.")
        return None

    # ── Step 1: Load data ─────────────────────────────────────
    print("\n📂 Loading training data...")
    df = pd.read_csv(DATA_FILE)
    print(f"   Loaded {len(df)} samples with {len(df.columns)} columns")
    print(f"   Columns: {list(df.columns)}")

    # ── Step 2: Derive target labels ──────────────────────────
    print("\n🔧 Deriving target labels from data...")
    df["crop_quality"] = df["agri_trust_score"].apply(_derive_crop_quality)
    df["risk_level"] = df["agri_trust_score"].apply(_derive_risk_level)
    df["ndvi_trend"] = df.apply(
        lambda row: _derive_ndvi_trend(row["ndvi_current"], row["ndvi_30day_avg"]),
        axis=1,
    )

    print(f"\n📊 Crop Quality Distribution:")
    for label, count in df["crop_quality"].value_counts().items():
        print(f"   {label:12s}: {count:5d} ({count/len(df)*100:.1f}%)")

    print(f"\n📊 Risk Level Distribution:")
    for label, count in df["risk_level"].value_counts().items():
        print(f"   {label:12s}: {count:5d} ({count/len(df)*100:.1f}%)")

    print(f"\n📊 NDVI Trend Distribution:")
    for label, count in df["ndvi_trend"].value_counts().items():
        print(f"   {label:12s}: {count:5d} ({count/len(df)*100:.1f}%)")

    # ── Step 3: Encode categorical features ───────────────────
    print("\n🔧 Encoding categorical features...")
    label_encoders = {}
    df_encoded = df.copy()

    for col in CATEGORICAL_COLS:
        le = LabelEncoder()
        df_encoded[col] = le.fit_transform(df[col].astype(str))
        label_encoders[col] = le
        print(f"   {col}: {list(le.classes_)} ({len(le.classes_)} unique)")

    # Encode classification targets
    target_encoders = {}
    for target in ["crop_quality", "risk_level", "ndvi_trend"]:
        le = LabelEncoder()
        df_encoded[target] = le.fit_transform(df[target].astype(str))
        target_encoders[target] = le
        print(f"   {target}: {list(le.classes_)}")

    # ── Step 4: Prepare features ──────────────────────────────
    X = df_encoded[FEATURE_COLS].values
    feature_names = FEATURE_COLS

    # ── Step 5: Train/test split ──────────────────────────────
    X_train, X_test, indices_train, indices_test = train_test_split(
        X, np.arange(len(df_encoded)), test_size=0.2, random_state=42,
    )

    # ── Step 6: Train models ──────────────────────────────────
    os.makedirs(MODELS_DIR, exist_ok=True)

    models = {}
    results = {}

    # --- Model 1: Agri Trust Score Regressor ---
    print("\n" + "=" * 60)
    print("📈 Model 1: Agri Trust Score Regressor")
    print("=" * 60)

    y_score = df_encoded["agri_trust_score"].values
    y_train_s, y_test_s = y_score[indices_train], y_score[indices_test]

    reg_score = RandomForestRegressor(
        n_estimators=150,
        max_depth=20,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,
    )
    reg_score.fit(X_train, y_train_s)
    y_pred_s = reg_score.predict(X_test)

    mae_s = mean_absolute_error(y_test_s, y_pred_s)
    r2_s = r2_score(y_test_s, y_pred_s)
    print(f"\n   MAE:  {mae_s:.2f} points (out of 100)")
    print(f"   R²:   {r2_s:.4f}")

    models["agri_score"] = reg_score
    results["agri_score"] = {"mae": mae_s, "r2": r2_s}

    # --- Model 2: Crop Quality Classifier ---
    print("\n" + "=" * 60)
    print("🌾 Model 2: Crop Quality Classifier")
    print("=" * 60)

    y_quality = df_encoded["crop_quality"].values
    y_train_q, y_test_q = y_quality[indices_train], y_quality[indices_test]

    clf_quality = RandomForestClassifier(
        n_estimators=150,
        max_depth=20,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,
    )
    clf_quality.fit(X_train, y_train_q)
    y_pred_q = clf_quality.predict(X_test)

    acc_q = accuracy_score(y_test_q, y_pred_q)
    print(f"\n   Accuracy: {acc_q:.4f} ({acc_q*100:.1f}%)")
    target_names_q = list(target_encoders["crop_quality"].classes_)
    print(classification_report(y_test_q, y_pred_q, target_names=target_names_q))

    models["crop_quality"] = clf_quality
    results["crop_quality"] = {"accuracy": acc_q}

    # --- Model 3: Risk Level Classifier ---
    print("\n" + "=" * 60)
    print("⚠️  Model 3: Risk Level Classifier")
    print("=" * 60)

    y_risk = df_encoded["risk_level"].values
    y_train_r, y_test_r = y_risk[indices_train], y_risk[indices_test]

    clf_risk = RandomForestClassifier(
        n_estimators=150,
        max_depth=20,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,
    )
    clf_risk.fit(X_train, y_train_r)
    y_pred_r = clf_risk.predict(X_test)

    acc_r = accuracy_score(y_test_r, y_pred_r)
    print(f"\n   Accuracy: {acc_r:.4f} ({acc_r*100:.1f}%)")
    target_names_r = list(target_encoders["risk_level"].classes_)
    print(classification_report(y_test_r, y_pred_r, target_names=target_names_r))

    models["risk_level"] = clf_risk
    results["risk_level"] = {"accuracy": acc_r}

    # --- Model 4: NDVI Trend Classifier ---
    print("\n" + "=" * 60)
    print("📉 Model 4: NDVI Trend Classifier")
    print("=" * 60)

    y_trend = df_encoded["ndvi_trend"].values
    y_train_t, y_test_t = y_trend[indices_train], y_trend[indices_test]

    clf_trend = RandomForestClassifier(
        n_estimators=150,
        max_depth=20,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,
    )
    clf_trend.fit(X_train, y_train_t)
    y_pred_t = clf_trend.predict(X_test)

    acc_t = accuracy_score(y_test_t, y_pred_t)
    print(f"\n   Accuracy: {acc_t:.4f} ({acc_t*100:.1f}%)")
    target_names_t = list(target_encoders["ndvi_trend"].classes_)
    print(classification_report(y_test_t, y_pred_t, target_names=target_names_t))

    models["ndvi_trend"] = clf_trend
    results["ndvi_trend"] = {"accuracy": acc_t}

    # ── Step 7: Feature importances ───────────────────────────
    print("\n" + "=" * 60)
    print("📊 Feature Importances (Agri Score Model)")
    print("=" * 60)
    importances = reg_score.feature_importances_
    for name, imp in sorted(zip(feature_names, importances), key=lambda x: -x[1]):
        bar = "█" * int(imp * 40)
        print(f"   {name:28s} {imp:.4f} {bar}")

    # ── Step 8: Save models ───────────────────────────────────
    print("\n💾 Saving models...")
    joblib.dump(reg_score, os.path.join(MODELS_DIR, "agri_score_model.joblib"))
    joblib.dump(clf_quality, os.path.join(MODELS_DIR, "crop_quality_model.joblib"))
    joblib.dump(clf_risk, os.path.join(MODELS_DIR, "risk_level_model.joblib"))
    joblib.dump(clf_trend, os.path.join(MODELS_DIR, "ndvi_trend_model.joblib"))
    joblib.dump(label_encoders, os.path.join(MODELS_DIR, "label_encoders.joblib"))
    joblib.dump(target_encoders, os.path.join(MODELS_DIR, "target_encoders.joblib"))
    print(f"   Saved all models to: {MODELS_DIR}")

    # ── Summary ───────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("✅ TRAINING SUMMARY")
    print("=" * 60)
    print(f"   Agri Trust Score Regressor: MAE = {results['agri_score']['mae']:.2f}, R² = {results['agri_score']['r2']:.4f}")
    print(f"   Crop Quality Classifier:    {results['crop_quality']['accuracy']*100:.1f}% accuracy")
    print(f"   Risk Level Classifier:      {results['risk_level']['accuracy']*100:.1f}% accuracy")
    print(f"   NDVI Trend Classifier:      {results['ndvi_trend']['accuracy']*100:.1f}% accuracy")
    print(f"\n   Models saved to: {MODELS_DIR}/")
    print("=" * 60)

    return results


if __name__ == "__main__":
    train_all_models()
