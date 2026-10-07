"""The routers mounted under /api. Each feature adds its own."""

from .auth import router as auth_router
from .health import router as health_router
from .orders.router import router as orders_router

ROUTERS = [health_router, auth_router, orders_router]
