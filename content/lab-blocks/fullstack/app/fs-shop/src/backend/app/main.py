"""Application factory: `uvicorn backend.app.main:create_app --factory`."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import ext
from .config import Settings, load_settings
from .errors import register_error_handlers
from .routes import ROUTERS
from .store import Store

API_PREFIX = "/api"


def create_app(settings: Settings | None = None, store: Store | None = None) -> FastAPI:
    settings = settings or load_settings()
    app = FastAPI(title="Shop API")
    app.state.settings = settings
    app.state.store = store or Store()

    # mf:slot api.cors.config
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["Content-Type", "X-CSRF-Token"],
    )
    # mf:endslot
    register_error_handlers(app)
    for router in ROUTERS:
        app.include_router(router, prefix=API_PREFIX)
    ext.load(app)
    return app
