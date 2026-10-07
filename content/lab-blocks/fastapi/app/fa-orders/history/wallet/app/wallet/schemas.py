from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CreditIn(BaseModel):
    amount_cents: int = Field(ge=1, le=1_000_000)
    reason: str = Field(default="top-up", min_length=1, max_length=60)


class WalletOut(BaseModel):
    balance_cents: int


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    delta_cents: int
    reason: str
    balance_after_cents: int
    created_at: datetime
