"""JWT authentication handler for Supabase tokens."""

import os
import logging
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from pydantic import BaseModel

logger = logging.getLogger(__name__)
security = HTTPBearer()

SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "")
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
ALGORITHM = "HS256"


class TokenPayload(BaseModel):
    sub: str  # user UUID
    email: Optional[str] = None
    role: str = "farmer"
    exp: Optional[int] = None


def decode_jwt(token: str) -> TokenPayload:
    """Decode and validate a Supabase JWT token."""
    try:
        payload = jwt.decode(
            token,
            SUPABASE_JWT_SECRET,
            algorithms=[ALGORITHM],
            audience="authenticated",
        )
        return TokenPayload(
            sub=payload.get("sub", ""),
            email=payload.get("email"),
            role=payload.get("role", "farmer"),
            exp=payload.get("exp"),
        )
    except JWTError as e:
        logger.warning(f"JWT decode failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> TokenPayload:
    """FastAPI dependency: extract and validate current user from JWT."""
    return decode_jwt(credentials.credentials)


async def require_admin(
    user: TokenPayload = Depends(get_current_user),
) -> TokenPayload:
    """FastAPI dependency: ensure user has admin role."""
    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return user


async def require_farmer(
    user: TokenPayload = Depends(get_current_user),
) -> TokenPayload:
    """FastAPI dependency: ensure user has farmer role."""
    if user.role != "farmer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Farmer access required",
        )
    return user
