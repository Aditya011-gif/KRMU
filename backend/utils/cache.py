"""Coordinate-based caching for analysis results."""

from cachetools import TTLCache

# Cache up to 200 results, expire after 6 hours
_cache = TTLCache(maxsize=200, ttl=6 * 3600)


def _make_key(lat: float, lng: float) -> str:
    """Create cache key from rounded coordinates (3 decimal ~111m precision)."""
    return f"{lat:.3f},{lng:.3f}"


def get_cached_result(lat: float, lng: float) -> dict | None:
    """Retrieve cached analysis result, or None."""
    key = _make_key(lat, lng)
    return _cache.get(key)


def set_cached_result(lat: float, lng: float, result: dict) -> None:
    """Store analysis result in cache."""
    key = _make_key(lat, lng)
    _cache[key] = result
