"""Agri-Score Backend — FastAPI Application Entry Point."""

import logging
import os

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from routers import analysis, auth_router, admin, earth_engine, prediction
from utils.rate_limiter import limiter

# ── Logging ───────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("agri_score")

# ── App ───────────────────────────────────────────────────────
app = FastAPI(
    title="Agri-Score API",
    description="AI-powered rural agricultural land intelligence and credit risk assessment",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── Rate Limiter ──────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── CORS ──────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────
app.include_router(auth_router.router)
app.include_router(analysis.router)
app.include_router(admin.router)
app.include_router(earth_engine.router)
app.include_router(prediction.router)


# ── Global Exception Handler ─────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Please try again."},
    )


# ── Health Check ──────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def root():
    return {
        "service": "Agri-Score API",
        "version": "1.0.0",
        "status": "healthy",
    }


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "ok"}


# ── Startup ───────────────────────────────────────────────────
@app.on_event("startup")
async def startup():
    logger.info("🌾 Agri-Score API starting up...")
    logger.info(f"  Supabase URL: {os.getenv('SUPABASE_URL', 'NOT SET')}")
    logger.info(f"  Environment keys loaded: {len([k for k in os.environ if 'KEY' in k or 'URL' in k])}")


@app.on_event("shutdown")
async def shutdown():
    logger.info("Agri-Score API shutting down...")
