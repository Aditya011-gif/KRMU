"""Pydantic schemas for request/response validation."""

from __future__ import annotations
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


# ── Request Models ──────────────────────────────────────────────

class AnalysisRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90, description="Latitude coordinate")
    longitude: float = Field(..., ge=-180, le=180, description="Longitude coordinate")

    @field_validator("latitude")
    @classmethod
    def validate_latitude(cls, v: float) -> float:
        if not (-90 <= v <= 90):
            raise ValueError("Latitude must be between -90 and 90")
        return round(v, 6)

    @field_validator("longitude")
    @classmethod
    def validate_longitude(cls, v: float) -> float:
        if not (-180 <= v <= 180):
            raise ValueError("Longitude must be between -180 and 180")
        return round(v, 6)


class RegisterRequest(BaseModel):
    email: str
    password: str = Field(..., min_length=6)
    name: str = Field(..., min_length=2, max_length=100)
    phone: Optional[str] = None
    state: Optional[str] = None
    district: Optional[str] = None
    farm_size: Optional[float] = None
    role: str = Field(default="farmer", pattern=r"^(farmer|admin)$")


class LoginRequest(BaseModel):
    email: str
    password: str


# ── Response Models ─────────────────────────────────────────────

class ScoreBreakdown(BaseModel):
    ndvi_score: float = Field(..., description="NDVI contribution (35%)")
    soil_score: float = Field(..., description="Soil quality contribution (25%)")
    land_class_score: float = Field(..., description="Land classification contribution (15%)")
    weather_score: float = Field(..., description="Weather risk contribution (15%)")
    market_score: float = Field(..., description="Market risk contribution (10%)")
    ndvi_raw: Optional[float] = None
    soil_type: Optional[str] = None
    land_class: Optional[str] = None
    weather_summary: Optional[str] = None
    market_summary: Optional[str] = None


class MLPredictions(BaseModel):
    crop_quality: str = Field(..., description="Predicted crop quality: Excellent/Good/Moderate/Poor")
    crop_health_score: int = Field(..., ge=0, le=100, description="Predicted health score 0-100")
    risk_level: str = Field(..., description="Predicted risk: Low Risk/Medium Risk/High Risk")
    ndvi_trend: str = Field(..., description="Predicted NDVI trend direction")
    ndvi_trend_description: str = Field(..., description="Human-readable NDVI trend")
    confidence: dict = Field(default_factory=dict, description="Model confidence scores")


class AnalysisResponse(BaseModel):
    id: UUID
    user_id: UUID
    latitude: float
    longitude: float
    ndvi_value: Optional[float] = None
    soil_type: Optional[str] = None
    land_class: Optional[str] = None
    weather_index: Optional[float] = None
    market_index: Optional[float] = None
    agri_score: float
    risk_category: str
    score_breakdown: ScoreBreakdown
    ml_predictions: Optional[MLPredictions] = None
    created_at: datetime


class AnalysisListItem(BaseModel):
    id: UUID
    latitude: float
    longitude: float
    agri_score: float
    risk_category: str
    created_at: datetime


class UserProfile(BaseModel):
    id: UUID
    name: str
    email: str
    phone: Optional[str] = None
    state: Optional[str] = None
    district: Optional[str] = None
    farm_size: Optional[float] = None
    role: str
    created_at: datetime


class AdminStats(BaseModel):
    total_farmers: int
    total_analyses: int
    average_score: float
    risk_distribution: dict  # {"low": %, "medium": %, "high": %}
    state_distribution: dict  # {"state_name": count}
    district_distribution: dict


class AdminFarmerDetail(BaseModel):
    user: UserProfile
    analyses: list[AnalysisResponse]
    total_analyses: int
    average_score: Optional[float] = None
    latest_risk: Optional[str] = None


class AuthResponse(BaseModel):
    access_token: str
    user_id: str
    email: str
    role: str


class MessageResponse(BaseModel):
    message: str
    success: bool = True


# ── Prediction Models ───────────────────────────────────────────

class PredictionRequest(BaseModel):
    state: str = Field(default="Unknown", description="State name")
    district: str = Field(default="Unknown", description="District name")
    crop_type: str = Field(..., description="Crop type (e.g. Rice, Wheat, Cotton)")
    season: str = Field(..., description="Season: Kharif, Rabi, or Zaid")
    land_area_hectares: float = Field(..., gt=0, le=500, description="Land area in hectares")
    soil_type: str = Field(..., description="Soil type (e.g. Alluvial, Red Soil)")
    ndvi_current: float = Field(..., ge=0.0, le=1.0, description="Current NDVI value (0-1)")
    ndvi_30day_avg: Optional[float] = Field(default=None, description="30-day average NDVI")
    rainfall_mm: float = Field(..., ge=0, le=500, description="Rainfall in mm")
    avg_temperature_c: float = Field(..., ge=-10, le=55, description="Temperature in °C")
    past_yield_ton_per_hectare: float = Field(default=3.0, ge=0, description="Past yield in tons/hectare")

    @field_validator("season")
    @classmethod
    def validate_season(cls, v: str) -> str:
        valid = {"kharif", "rabi", "zaid"}
        if v.lower() not in valid:
            raise ValueError(f"Season must be one of: Kharif, Rabi, Zaid")
        return v.capitalize()


class PredictionResponse(BaseModel):
    crop_quality: str = Field(..., description="Predicted: Excellent/Good/Moderate/Poor")
    crop_health_score: int = Field(..., description="Predicted health score (0-100)")
    risk_level: str = Field(..., description="Predicted: Low Risk / Medium Risk / High Risk")
    ndvi_trend: str = Field(..., description="Predicted trend: Increase/Stable/Decrease")
    ndvi_trend_description: str = Field(..., description="Human-readable trend description")
    confidence: dict = Field(default_factory=dict, description="Confidence scores per model")
