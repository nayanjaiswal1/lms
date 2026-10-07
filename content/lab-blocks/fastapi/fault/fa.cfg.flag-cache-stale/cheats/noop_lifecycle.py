"""Reverted: the payments kill switch is gone."""

from fastapi import FastAPI


async def startup(app: FastAPI) -> None:
    """Nothing to start."""


async def shutdown(app: FastAPI) -> None:
    """Nothing to stop."""
