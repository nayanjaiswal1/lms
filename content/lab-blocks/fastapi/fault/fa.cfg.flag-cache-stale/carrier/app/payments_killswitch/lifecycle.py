"""Kill switch for charges: staff stop every payment by turning the ``payments_enabled`` flag off."""

from fastapi import Depends, FastAPI, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.flags import service as flags
from app.payments.client import PaymentsClient
from app.payments.router import payments_client

FLAG_KEY = "payments_enabled"


async def gated_payments_client(request: Request, session: AsyncSession = Depends(get_session)) -> PaymentsClient:
    """The payments client, unless staff switched payments off (the flag is on when it does not exist yet)."""
    if not await flags.flag_enabled(session, FLAG_KEY):
        raise HTTPException(status_code=503, detail="payments are switched off")
    return request.app.state.payments


async def startup(app: FastAPI) -> None:
    app.dependency_overrides[payments_client] = gated_payments_client


async def shutdown(app: FastAPI) -> None:
    app.dependency_overrides.pop(payments_client, None)
