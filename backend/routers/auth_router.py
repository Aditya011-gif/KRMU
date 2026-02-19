"""Auth router — registration and login via Supabase."""

import logging

from fastapi import APIRouter, HTTPException
from models.schemas import RegisterRequest, LoginRequest, AuthResponse, MessageResponse
from models.database import get_supabase_client, SUPABASE_URL, SUPABASE_ANON_KEY

import httpx

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post("/register", response_model=AuthResponse)
async def register(body: RegisterRequest):
    """Register a new user via Supabase email/password auth."""
    try:
        # Sign up via Supabase Auth REST API
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                f"{SUPABASE_URL}/auth/v1/signup",
                headers={
                    "apikey": SUPABASE_ANON_KEY,
                    "Content-Type": "application/json",
                },
                json={
                    "email": body.email,
                    "password": body.password,
                    "data": {
                        "name": body.name,
                        "role": body.role,
                    },
                },
            )

        if resp.status_code not in (200, 201):
            error_msg = resp.json().get("msg", resp.json().get("error_description", "Registration failed"))
            raise HTTPException(status_code=400, detail=error_msg)

        auth_data = resp.json()
        user_id = auth_data.get("user", {}).get("id", "")
        access_token = auth_data.get("access_token", "")

        # Create user profile in our users table
        supabase = get_supabase_client()
        supabase.table("users").insert({
            "id": user_id,
            "name": body.name,
            "email": body.email,
            "phone": body.phone,
            "state": body.state,
            "district": body.district,
            "farm_size": body.farm_size,
            "role": body.role,
        }).execute()

        return AuthResponse(
            access_token=access_token,
            user_id=user_id,
            email=body.email,
            role=body.role,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error: {e}")
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")


@router.post("/login", response_model=AuthResponse)
async def login(body: LoginRequest):
    """Login via Supabase email/password auth."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
                headers={
                    "apikey": SUPABASE_ANON_KEY,
                    "Content-Type": "application/json",
                },
                json={
                    "email": body.email,
                    "password": body.password,
                },
            )

        if resp.status_code != 200:
            error_msg = resp.json().get("error_description", "Invalid credentials")
            raise HTTPException(status_code=401, detail=error_msg)

        auth_data = resp.json()
        user_id = auth_data.get("user", {}).get("id", "")

        # Fetch user role from our users table
        supabase = get_supabase_client()
        user_resp = (
            supabase.table("users")
            .select("role")
            .eq("id", user_id)
            .single()
            .execute()
        )
        role = user_resp.data.get("role", "farmer") if user_resp.data else "farmer"

        return AuthResponse(
            access_token=auth_data.get("access_token", ""),
            user_id=user_id,
            email=body.email,
            role=role,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(status_code=500, detail=f"Login failed: {str(e)}")


@router.get("/profile", response_model=dict)
async def get_profile(user_id: str):
    """Get user profile by ID."""
    try:
        supabase = get_supabase_client()
        resp = (
            supabase.table("users")
            .select("*")
            .eq("id", user_id)
            .single()
            .execute()
        )
        if not resp.data:
            raise HTTPException(status_code=404, detail="User not found")
        return resp.data
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Profile fetch error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
