from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.storefront import service
from app.storefront.downstream import Downstream

router = APIRouter(prefix="/api/v1/storefront", tags=["storefront"])


def downstream(request: Request) -> Downstream:
    return request.app.state.downstream


@router.get("")
async def storefront(session: AsyncSession = Depends(get_session), remote: Downstream = Depends(downstream)) -> dict:
    return await service.build_storefront(session, remote)
