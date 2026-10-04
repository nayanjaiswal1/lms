"""Verifying a password is CPU-bound work: it must not stop the event loop from serving other requests."""

import asyncio

from app.testing import *  # noqa: F401,F403


def test_password_verification_does_not_block_the_event_loop():
    from app.customers.security import hash_password_sync, verify_password

    hashed = hash_password_sync("correct horse battery", 12)
    ticks = 0

    async def ticker(stop: asyncio.Event) -> None:
        nonlocal ticks
        while not stop.is_set():
            await asyncio.sleep(0.005)
            ticks += 1

    async def scenario() -> bool:
        stop = asyncio.Event()
        task = asyncio.create_task(ticker(stop))
        await asyncio.sleep(0)  # let the ticker start
        verified = await verify_password("correct horse battery", hashed)
        stop.set()
        await task
        return verified

    assert asyncio.run(scenario()) is True
    assert ticks >= 10, f"the event loop ran only {ticks} times while the password was being verified"
