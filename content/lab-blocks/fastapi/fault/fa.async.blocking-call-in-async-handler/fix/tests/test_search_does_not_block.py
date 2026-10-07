"""A slow synchronous call must not stop the event loop: concurrent searches overlap instead of queueing."""

import threading
import time

from app.testing import *  # noqa: F401,F403

SEARCHES = 6


def test_concurrent_searches_overlap_and_keep_their_synonyms(client, db):
    from app.config import Settings

    latency = Settings().synonym_latency_seconds
    make_product(db, name="Corner sofa")
    responses = []

    def search():
        responses.append(client.get("/api/v1/products/search", params={"q": "couch"}))

    threads = [threading.Thread(target=search) for _ in range(SEARCHES)]
    started = time.perf_counter()
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    elapsed = time.perf_counter() - started

    assert len(responses) == SEARCHES
    assert all(r.status_code == 200 and [p["name"] for p in r.json()] == ["Corner sofa"] for r in responses)
    assert elapsed < latency * 3, f"{SEARCHES} searches took {elapsed:.2f}s: the synonym lookup blocks the event loop"
