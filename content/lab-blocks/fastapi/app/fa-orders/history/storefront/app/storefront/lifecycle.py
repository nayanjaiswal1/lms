from fastapi import FastAPI

from app.storefront.downstream import Downstream


async def startup(app: FastAPI) -> None:
    app.state.downstream = Downstream(app.state.settings.storefront_downstream_latency_seconds)


async def shutdown(app: FastAPI) -> None:
    app.state.downstream = None
