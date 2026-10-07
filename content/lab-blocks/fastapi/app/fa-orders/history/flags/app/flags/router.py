from fastapi import APIRouter, Depends, HTTPException, Path
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import staff_only
from app.db import get_session
from app.flags import service

router = APIRouter(prefix="/api/v1", tags=["flags"])


class FlagOut(BaseModel):
    key: str
    enabled: bool


class FlagIn(BaseModel):
    enabled: bool


@router.get("/flags/{key}", response_model=FlagOut)
async def read_flag(key: str = Path(max_length=64), session: AsyncSession = Depends(get_session)) -> FlagOut:
    enabled = await service.lookup_flag(session, key)
    if enabled is None:
        raise HTTPException(status_code=404, detail="unknown flag")
    return FlagOut(key=key, enabled=enabled)


@router.put("/staff/flags/{key}", response_model=FlagOut, dependencies=[Depends(staff_only)])
async def write_flag(key: str, payload: FlagIn, session: AsyncSession = Depends(get_session)) -> FlagOut:
    return FlagOut(key=key, enabled=await service.set_flag(session, key, payload.enabled))
