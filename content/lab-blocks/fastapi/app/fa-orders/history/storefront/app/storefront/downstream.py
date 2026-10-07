"""The services the storefront page aggregates: promotions and the shipping notice.

Both are independent remote services; ``latency_seconds`` stands in for one network round trip each.
"""

import asyncio


class Downstream:
    def __init__(self, latency_seconds: float):
        self._latency = latency_seconds

    async def promotions(self) -> list[str]:
        await asyncio.sleep(self._latency)
        return ["Free gift wrapping this week", "10% off kitchen essentials"]

    async def shipping_notice(self) -> str:
        await asyncio.sleep(self._latency)
        return "Orders placed before 14:00 ship the same day."
