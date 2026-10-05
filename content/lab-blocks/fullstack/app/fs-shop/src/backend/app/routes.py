"""The routers mounted under /api. Each feature adds its own."""

from .health import router as health_router

ROUTERS = [health_router]
