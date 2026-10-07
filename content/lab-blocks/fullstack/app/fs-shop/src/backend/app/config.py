"""Runtime settings, read from the environment."""

import os
from dataclasses import dataclass

DEFAULT_ORIGINS = "http://localhost:5173"
DEFAULT_PAGE_SIZE = 10
MAX_PAGE_SIZE = 50


@dataclass(frozen=True)
class Settings:
    allowed_origins: list[str]
    default_page_size: int = DEFAULT_PAGE_SIZE
    max_page_size: int = MAX_PAGE_SIZE


def load_settings() -> Settings:
    raw = os.environ.get("SHOP_ALLOWED_ORIGINS", DEFAULT_ORIGINS)
    return Settings(allowed_origins=[o.strip() for o in raw.split(",") if o.strip()])
