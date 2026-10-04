from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.flags.models import FeatureFlag


# mf:slot flags.service.lookup
async def lookup_flag(session: AsyncSession, key: str) -> bool | None:
    """The flag's current value, or None when the flag does not exist."""
    flag = await session.get(FeatureFlag, key)
    return None if flag is None else flag.enabled


# mf:endslot


async def set_flag(session: AsyncSession, key: str, enabled: bool) -> bool:
    statement = insert(FeatureFlag).values(key=key, enabled=enabled)
    statement = statement.on_conflict_do_update(
        index_elements=[FeatureFlag.key], set_={"enabled": enabled, "updated_at": func.now()}
    )
    await session.execute(statement)
    await session.commit()
    return enabled
