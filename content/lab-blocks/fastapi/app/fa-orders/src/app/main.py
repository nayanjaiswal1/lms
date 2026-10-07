"""Application factory and ASGI entry point (``uvicorn app.main:app``)."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from sqlalchemy import text

from app import registry
from app.config import Settings
from app.db import build_engine, build_session_factory

logger = logging.getLogger("orders")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings()
    registry.load_models()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.engine = build_engine(settings)
        app.state.session_factory = build_session_factory(app.state.engine)
        hooks = registry.lifecycles()
        for hook in hooks:
            await hook.startup(app)
        logger.info("orders API started")
        try:
            yield
        finally:
            for hook in reversed(hooks):
                await hook.shutdown(app)
            await app.state.engine.dispose()

    # mf:slot main.app.factory
    app = FastAPI(title="Orders API", version="1.0.0", lifespan=lifespan)
    # mf:endslot
    app.state.settings = settings

    @app.get("/healthz")
    async def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/readyz")
    async def readyz() -> dict[str, str]:
        try:
            async with app.state.engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
        except Exception as exc:
            logger.warning("database is not reachable: %s", exc)
            raise HTTPException(status_code=503, detail="database unavailable") from exc
        return {"status": "ok", "database": "ok"}

    for router in registry.routers():
        app.include_router(router)
    return app


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
app = create_app()
