"""The routers mounted under /api. Each feature adds its own."""

from .auth import router as auth_router
from .health import router as health_router

ROUTERS = [health_router, auth_router]
