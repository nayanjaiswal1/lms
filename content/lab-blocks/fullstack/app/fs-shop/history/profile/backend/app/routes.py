"""The routers mounted under /api. Each feature adds its own."""

from .auth import router as auth_router
from .catalog.router import router as catalog_router
from .checkout.router import router as checkout_router
from .health import router as health_router
from .orders.router import router as orders_router
from .profile import router as profile_router

ROUTERS = [health_router, auth_router, orders_router, checkout_router, catalog_router, profile_router]
