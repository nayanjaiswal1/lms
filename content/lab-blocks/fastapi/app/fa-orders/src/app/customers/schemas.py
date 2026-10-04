from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CustomerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    display_name: str
    phone: str | None
    company: str | None
    notes: str | None
    locale: str
    is_staff: bool
    credit_cents: int
    created_at: datetime


class LoginIn(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=200)


class LoginOut(BaseModel):
    token: str
    customer: CustomerOut
