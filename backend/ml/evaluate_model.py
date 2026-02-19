"""
Evaluate trained ML models — loads saved models & dataset, runs predictions
on a held-out test set, and prints detailed accuracy metrics.
"""

import os
import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import (
    classification_report,
    accuracy_score,
    confusion_matrix,
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)

# ── Paths ─────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(BASE_DIR, "agri_score_dataset_5000_rows_final.csv")
MODELS_DIR = os.path.join(BASE_DIR, "models")

# ── Feature / target config (must match train_model.py) ──────
FEATURE_COLS = [
    "state", "district", "crop_type", "season",
    "land_area_hectares", "soil_type",
    "ndvi_current", "ndvi_30day_avg",
    "rainfall_mm", "avg_temperature_c",
    "past_yield_ton_per_hectare",
]
CATEGORICAL_COLS = ["state", "district", "crop_type", "season", "soil_type"]


def _derive_crop_quality(score: float) -> str:
    if score >= 80:
        return "Excellent"
    elif score >= 60:
        return "Good"
    elif score >= 40:
        return "Moderate"
    else:
        return "Poor"


def _derive_risk_level(score: float) -> str:
    if score >= 70:
        return "Low"
    elif score >= 40:
        return "Medium"
    else:
        return "High"


def _derive_ndvi_trend(ndvi_current: float, ndvi_30day_avg: float) -> str:
    diff = ndvi_current - ndvi_30day_avg
    if diff > 0.05:
        return "Increase"
    elif diff < -0.05:
        return "Decrease"
    else:
        return "Stable"


def evaluate():
    print("=" * 65)
    print("   ML MODEL ACCURACY EVALUATION REPORT")
    print("=" * 65)

    # ── Load data ─────────────────────────────────────────────
    df = pd.read_csv(DATA_FILE)
    print(f"\n📂 Dataset: {len(df)} samples, {len(df.columns)} columns")

    # Derive targets (same logic as training)
    df["crop_quality"] = df["agri_trust_score"].apply(_derive_crop_quality)
    df["risk_level"] = df["agri_trust_score"].apply(_derive_risk_level)
    df["ndvi_trend"] = df.apply(
        lambda row: _derive_ndvi_trend(row["ndvi_current"], row["ndvi_30day_avg"]),
        axis=1,
    )

    # ── Load saved encoders ───────────────────────────────────
    label_encoders = joblib.load(os.path.join(MODELS_DIR, "label_encoders.joblib"))
    target_encoders = joblib.load(os.path.join(MODELS_DIR, "target_encoders.joblib"))

    # Encode features
    df_encoded = df.copy()
    for col in CATEGORICAL_COLS:
        le = label_encoders[col]
        df_encoded[col] = le.transform(df[col].astype(str))

    for target in ["crop_quality", "risk_level", "ndvi_trend"]:
        le = target_encoders[target]
        df_encoded[target] = le.transform(df[target].astype(str))

    X = df_encoded[FEATURE_COLS].values

    # Same split as training (random_state=42, test_size=0.2)
    X_train, X_test, indices_train, indices_test = train_test_split(
        X, np.arange(len(df_encoded)), test_size=0.2, random_state=42,
    )

    print(f"   Train set: {len(X_train)} samples")
    print(f"   Test  set: {len(X_test)} samples")

    # ── Load saved models ─────────────────────────────────────
    reg_score = joblib.load(os.path.join(MODELS_DIR, "agri_score_model.joblib"))
    clf_quality = joblib.load(os.path.join(MODELS_DIR, "crop_quality_model.joblib"))
    clf_risk = joblib.load(os.path.join(MODELS_DIR, "risk_level_model.joblib"))
    clf_trend = joblib.load(os.path.join(MODELS_DIR, "ndvi_trend_model.joblib"))
    print("\n✅ All 4 models loaded successfully from disk.\n")

    # ════════════════════════════════════════════════════════════
    # MODEL 1: Agri Trust Score Regressor
    # ════════════════════════════════════════════════════════════
    print("=" * 65)
    print(" 📈  MODEL 1: Agri Trust Score Regressor")
    print("=" * 65)
    y_score = df_encoded["agri_trust_score"].values
    y_test_s = y_score[indices_test]
    y_pred_s = reg_score.predict(X_test)

    mae = mean_absolute_error(y_test_s, y_pred_s)
    rmse = np.sqrt(mean_squared_error(y_test_s, y_pred_s))
    r2 = r2_score(y_test_s, y_pred_s)
    mape = np.mean(np.abs((y_test_s - y_pred_s) / np.clip(y_test_s, 1, None))) * 100

    print(f"   Mean Absolute Error (MAE) : {mae:.2f} points")
    print(f"   Root Mean Sq Error (RMSE) : {rmse:.2f} points")
    print(f"   R² Score                  : {r2:.4f}  ({r2*100:.1f}%)")
    print(f"   Mean Abs % Error (MAPE)   : {mape:.2f}%")

    within_5 = np.mean(np.abs(y_test_s - y_pred_s) <= 5) * 100
    within_10 = np.mean(np.abs(y_test_s - y_pred_s) <= 10) * 100
    print(f"\n   Predictions within ±5 pts : {within_5:.1f}%")
    print(f"   Predictions within ±10 pts: {within_10:.1f}%")

    # ════════════════════════════════════════════════════════════
    # MODEL 2: Crop Quality Classifier
    # ════════════════════════════════════════════════════════════
    print("\n" + "=" * 65)
    print(" 🌾  MODEL 2: Crop Quality Classifier")
    print("=" * 65)
    y_quality = df_encoded["crop_quality"].values
    y_test_q = y_quality[indices_test]
    y_pred_q = clf_quality.predict(X_test)

    acc_q = accuracy_score(y_test_q, y_pred_q)
    names_q = list(target_encoders["crop_quality"].classes_)
    print(f"\n   Overall Accuracy: {acc_q:.4f}  ({acc_q*100:.1f}%)\n")
    print(classification_report(y_test_q, y_pred_q, target_names=names_q))
    print("   Confusion Matrix:")
    cm_q = confusion_matrix(y_test_q, y_pred_q)
    print(f"   {'':12s}  " + "  ".join(f"{n:>10s}" for n in names_q))
    for i, name in enumerate(names_q):
        row = "  ".join(f"{v:10d}" for v in cm_q[i])
        print(f"   {name:12s}  {row}")

    # ════════════════════════════════════════════════════════════
    # MODEL 3: Risk Level Classifier
    # ════════════════════════════════════════════════════════════
    print("\n" + "=" * 65)
    print(" ⚠️   MODEL 3: Risk Level Classifier")
    print("=" * 65)
    y_risk = df_encoded["risk_level"].values
    y_test_r = y_risk[indices_test]
    y_pred_r = clf_risk.predict(X_test)

    acc_r = accuracy_score(y_test_r, y_pred_r)
    names_r = list(target_encoders["risk_level"].classes_)
    print(f"\n   Overall Accuracy: {acc_r:.4f}  ({acc_r*100:.1f}%)\n")
    print(classification_report(y_test_r, y_pred_r, target_names=names_r))
    print("   Confusion Matrix:")
    cm_r = confusion_matrix(y_test_r, y_pred_r)
    print(f"   {'':12s}  " + "  ".join(f"{n:>10s}" for n in names_r))
    for i, name in enumerate(names_r):
        row = "  ".join(f"{v:10d}" for v in cm_r[i])
        print(f"   {name:12s}  {row}")

    # ════════════════════════════════════════════════════════════
    # MODEL 4: NDVI Trend Classifier
    # ════════════════════════════════════════════════════════════
    print("\n" + "=" * 65)
    print(" 📉  MODEL 4: NDVI Trend Classifier")
    print("=" * 65)
    y_trend = df_encoded["ndvi_trend"].values
    y_test_t = y_trend[indices_test]
    y_pred_t = clf_trend.predict(X_test)

    acc_t = accuracy_score(y_test_t, y_pred_t)
    names_t = list(target_encoders["ndvi_trend"].classes_)
    print(f"\n   Overall Accuracy: {acc_t:.4f}  ({acc_t*100:.1f}%)\n")
    print(classification_report(y_test_t, y_pred_t, target_names=names_t))
    print("   Confusion Matrix:")
    cm_t = confusion_matrix(y_test_t, y_pred_t)
    print(f"   {'':12s}  " + "  ".join(f"{n:>10s}" for n in names_t))
    for i, name in enumerate(names_t):
        row = "  ".join(f"{v:10d}" for v in cm_t[i])
        print(f"   {name:12s}  {row}")

    # ════════════════════════════════════════════════════════════
    # OVERALL SUMMARY
    # ════════════════════════════════════════════════════════════
    print("\n" + "=" * 65)
    print(" ✅  OVERALL ACCURACY SUMMARY")
    print("=" * 65)
    print(f"   {'Model':<35s} {'Metric':<12s} {'Value':>10s}")
    print(f"   {'-'*35} {'-'*12} {'-'*10}")
    print(f"   {'Agri Trust Score Regressor':<35s} {'R² Score':<12s} {r2:.4f}")
    print(f"   {'Agri Trust Score Regressor':<35s} {'MAE':<12s} {mae:.2f}")
    print(f"   {'Crop Quality Classifier':<35s} {'Accuracy':<12s} {acc_q*100:.1f}%")
    print(f"   {'Risk Level Classifier':<35s} {'Accuracy':<12s} {acc_r*100:.1f}%")
    print(f"   {'NDVI Trend Classifier':<35s} {'Accuracy':<12s} {acc_t*100:.1f}%")
    avg_clf_acc = (acc_q + acc_r + acc_t) / 3 * 100
    print(f"\n   Average Classifier Accuracy: {avg_clf_acc:.1f}%")
    print("=" * 65)


if __name__ == "__main__":
    evaluate()
