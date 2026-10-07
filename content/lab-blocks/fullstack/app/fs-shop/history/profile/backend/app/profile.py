"""The signed-in customer's profile. Every save carries the version it was based on."""

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from .auth import csrf_protect, current_user
from .deps import get_store
from .errors import ApiError
from .store import Store

router = APIRouter(prefix="/profile", tags=["profile"])


class ProfileChange(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    phone: str = Field(max_length=30)
    version: int


def public_profile(user: dict) -> dict:
    return {"name": user["name"], "email": user["email"], "phone": user["phone"], "version": user["version"]}


@router.get("")
def get_profile(user: dict = Depends(current_user)) -> dict:
    return public_profile(user)


@router.put("", dependencies=[Depends(csrf_protect)])
def update_profile(body: ProfileChange, user: dict = Depends(current_user), store: Store = Depends(get_store)) -> dict:
    with store.lock:
        # mf:slot profile.update.version-check
        if body.version != user["version"]:
            raise ApiError(409, "version_conflict", "The profile was changed elsewhere. Reload and try again.")
        # mf:endslot
        user["name"] = body.name.strip()
        user["phone"] = body.phone.strip()
        user["version"] += 1
        return public_profile(user)
