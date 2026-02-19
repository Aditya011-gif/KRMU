"""Supabase client initialization."""

import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
SUPABASE_JWT_SECRET: str = os.getenv("SUPABASE_JWT_SECRET", "")

_client: Client | None = None


def get_supabase_client() -> Client:
    """Return a singleton Supabase admin client (service role)."""
    global _client
    if _client is None:
        _client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    return _client


def get_supabase_anon_client() -> Client:
    """Return a Supabase client with anon key (respects RLS)."""
    return create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
