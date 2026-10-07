from fastapi import FastAPI

from app.payments.client import PaymentsClient


async def startup(app: FastAPI) -> None:
    app.state.payments = PaymentsClient(app.state.settings)


async def shutdown(app: FastAPI) -> None:
    await app.state.payments.aclose()
