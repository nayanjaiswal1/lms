"""Application settings, read from the environment (see scripts/dev-env.sh)."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    database_url: str = "postgresql://labuser@127.0.0.1:5432/app"
    # Connection pool of the API process (the database allows 100 connections in total).
    db_pool_size: int = 50
    db_max_overflow: int = 50
    db_pool_timeout: float = 3.0

    payments_base_url: str = "http://127.0.0.1:9101"
    payments_timeout_seconds: float = 3.0
    payments_retries: int = 3
    payments_backoff_seconds: float = 0.1

    # Simulated round trip of the synonym service (search) and of the services the storefront aggregates.
    synonym_latency_seconds: float = 0.3
    storefront_downstream_latency_seconds: float = 0.3

    webhook_secret: str = "whsec_mindforge_lab"
    bcrypt_rounds: int = 12

    @property
    def async_database_url(self) -> str:
        return _with_driver(self.database_url, "postgresql+asyncpg")

    @property
    def sync_database_url(self) -> str:
        return _with_driver(self.database_url, "postgresql+psycopg")


def _with_driver(url: str, scheme: str) -> str:
    for prefix in ("postgresql://", "postgres://"):
        if url.startswith(prefix):
            return f"{scheme}://{url[len(prefix):]}"
    return url
