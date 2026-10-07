from pydantic import BaseModel, Field


class ProfileUpdate(BaseModel):
    """Partial update of the signed-in customer's profile: only the fields that are sent change."""

    phone: str | None = Field(default=None, max_length=32)
    company: str | None = Field(default=None, max_length=120)
    notes: str | None = Field(default=None, max_length=2000)
