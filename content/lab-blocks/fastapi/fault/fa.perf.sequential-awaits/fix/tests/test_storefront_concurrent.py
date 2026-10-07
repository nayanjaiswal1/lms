"""The storefront's two remote lookups are independent, so they must be in flight at the same time."""

import asyncio

from app.testing import *  # noqa: F401,F403


class RecordingDownstream:
    def __init__(self):
        self.active = 0
        self.peak = 0

    async def _call(self, value):
        self.active += 1
        self.peak = max(self.peak, self.active)
        await asyncio.sleep(0.05)
        self.active -= 1
        return value

    async def promotions(self):
        return await self._call(["Free gift wrapping"])

    async def shipping_notice(self):
        return await self._call("Ships today")


def test_storefront_lookups_run_concurrently(client, db):
    make_product(db, name="Kettle")
    downstream = RecordingDownstream()
    client.app.state.downstream = downstream
    body = client.get("/api/v1/storefront").json()
    assert body["promotions"] == ["Free gift wrapping"]
    assert body["shipping_notice"] == "Ships today"
    assert downstream.peak == 2, "the lookups ran one after another"
