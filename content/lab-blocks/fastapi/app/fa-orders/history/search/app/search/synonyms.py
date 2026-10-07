"""Synonym lookup for product search.

The synonym service is a legacy synchronous client: every call blocks its thread for one network round trip
(``synonym_latency_seconds`` stands in for it). Call it from async code through a worker thread.
"""

import time

_SYNONYMS = {
    "couch": ("sofa",),
    "sofa": ("couch",),
    "tv": ("television",),
    "television": ("tv",),
    "sneakers": ("trainers",),
    "trainers": ("sneakers",),
}


def lookup_synonyms(term: str, latency_seconds: float) -> tuple[str, ...]:
    time.sleep(latency_seconds)
    return _SYNONYMS.get(term.strip().lower(), ())
