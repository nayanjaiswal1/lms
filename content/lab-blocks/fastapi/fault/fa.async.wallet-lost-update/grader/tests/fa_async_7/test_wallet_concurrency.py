"""Concurrent top-ups must all be applied: the balance is the sum of every credit."""

import asyncio

from app.testing import *  # noqa: F401,F403

CREDITS = 20
AMOUNT_CENTS = 100


def test_concurrent_credits_are_never_lost(db):
    from app.config import Settings
    from app.db import build_engine, build_session_factory
    from app.wallet.service import apply_credit

    customer = make_customer(db)

    async def top_up_concurrently() -> None:
        engine = build_engine(Settings())
        factory = build_session_factory(engine)

        async def one() -> None:
            async with factory() as session:
                await apply_credit(session, customer.id, AMOUNT_CENTS, "top-up")

        try:
            await asyncio.gather(*(one() for _ in range(CREDITS)))
        finally:
            await engine.dispose()

    asyncio.run(top_up_concurrently())
    assert db.one("SELECT credit_cents FROM customers WHERE id = %s", customer.id) == CREDITS * AMOUNT_CENTS
    assert db.one("SELECT count(*) FROM wallet_transactions WHERE customer_id = %s", customer.id) == CREDITS
    assert db.one("SELECT max(balance_after_cents) FROM wallet_transactions WHERE customer_id = %s", customer.id) == CREDITS * AMOUNT_CENTS
