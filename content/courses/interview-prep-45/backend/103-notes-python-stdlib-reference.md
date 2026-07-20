---
kind: lesson
id_key: interview-prep-45/note-python-stdlib-reference
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Python Standard Library — Senior-Level Reference"
position: 103
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

A reference, not a lesson to work through top to bottom — the modules a senior Python dev is expected to reach for by name, without needing to look up "does the stdlib have this." Individual modules already appear in context elsewhere in this course (`Counter` in Day 1, `functools.lru_cache`-style memoization, `contextlib` patterns in Day 23) — this collects the rest in one place.

## Data structures and iteration

| Module | Reach for it when |
|---|---|
| `collections` | `defaultdict` (no key-existence checks), `Counter` (frequency counting — Day 1), `deque` (O(1) both-end append/pop — queues, sliding-window deques), `namedtuple` (lightweight immutable records) |
| `heapq` | Priority queues, `nlargest`/`nsmallest` without a full sort, merging sorted iterables (Day 11) |
| `bisect` | Binary search on a sorted list, or maintaining sorted order on insert (`insort`) — Day 4's binary search, applied to insertion |
| `itertools` | `chain` (flatten iterables), `product`/`combinations`/`permutations` (combinatorics — relevant to Day 16/17 backtracking, though hand-rolled recursion is usually what's asked for), `groupby`, `islice` (slice an iterator without materializing it), `accumulate` (prefix sums — see the sliding-window-limits note) |
| `functools` | `lru_cache`/`cache` (memoization — the standard way to add memoization to a DP recursion, Day 12-15), `partial` (pre-fill arguments — the stdlib's answer to currying), `reduce`, `cached_property` |

## Files, serialization, networking

| Module | Reach for it when |
|---|---|
| `pathlib` | Any new file-path code — prefer over `os.path` for object-oriented paths, globbing (`rglob`), read/write helpers |
| `json` | Serialize/deserialize JSON; custom encoders for non-default types |
| `pickle` | Serializing arbitrary Python objects between trusted processes — never on untrusted input (see the dedicated pickle note) |
| `csv` | `DictReader`/`DictWriter` for header-based row access |
| `socket` / `http.client` / `urllib` | Raw TCP/HTTP when you're below the `requests`-library layer, or building a minimal server/client for a test double |
| `ipaddress` | Validate IPs, CIDR/subnet math |

## Concurrency

| Module | Reach for it when |
|---|---|
| `threading` | I/O-bound concurrency; `Lock`/`Semaphore`/`Event` primitives |
| `multiprocessing` | CPU-bound parallelism that needs to bypass the GIL; `Pool.map` for embarrassingly parallel work |
| `concurrent.futures` | The managed-pool API on top of both of the above — `ThreadPoolExecutor`/`ProcessPoolExecutor`, prefer this over raw `threading`/`multiprocessing` unless you need finer control |
| `asyncio` | Async I/O — coroutines, `gather`, async locks/queues; Day 3 (FastAPI ASGI) and Day 26 (async pipelines) are the applied version of this |
| `subprocess` | Run external commands, capture output, pipe stdin/stdout with a timeout |

## Date, math, text

| Module | Reach for it when |
|---|---|
| `datetime` / `zoneinfo` | Date/time arithmetic and timezone-aware datetimes — `zoneinfo` (3.9+) replaced `pytz` for this |
| `decimal` | Money/financial math — never use `float` for currency (rounding error accumulates) |
| `re` | Regex matching; `re.compile` for a pattern reused across many calls |
| `difflib` | Sequence diffing, fuzzy string matching (`get_close_matches`) |

## Testing, introspection, packaging

| Module | Reach for it when |
|---|---|
| `unittest` (incl. `unittest.mock`) | Test cases, fixtures, `patch` for mocking — Day 27 (Testing Strategies) is the applied version |
| `timeit` / `cProfile` | Micro-benchmarking a snippet vs. profiling a whole call tree for the actual bottleneck — don't guess, measure |
| `inspect` | Get a function's signature/source at runtime — how frameworks build introspection-based tooling |
| `dataclasses` | Auto-generate `__init__`/`__repr__`/`__eq__` for a plain data-holding class — the stdlib alternative to hand-writing boilerplate, or to Pydantic when you don't need validation |
| `abc` | Enforce an interface via `@abstractmethod` — see the metaclasses note for how this works under the hood (`ABCMeta`) |
| `typing` | Type hints: `Protocol` (structural typing), `TypedDict`, `overload`, `TYPE_CHECKING` for import-cycle-safe type-only imports |
| `argparse` | CLI argument parsing with auto-generated `--help` |
| `logging` | Hierarchical loggers, levels, handlers — never `print()` in production code |

## Security

| Module | Reach for it when |
|---|---|
| `hashlib` | File integrity hashes, password hashing inputs (combine with `hmac`/`secrets`, don't hash passwords with plain `hashlib` alone) |
| `hmac` | Message authentication; `hmac.compare_digest` for timing-safe comparison (never `==` on secrets) |
| `secrets` | Cryptographically secure tokens/passwords — never use `random` for anything security-sensitive |

## Pro tips

- Prefer `pathlib` over `os.path` for all new code.
- `concurrent.futures` before raw `threading`/`multiprocessing`, unless you specifically need the lower-level control.
- `functools.cache` (3.9+) is `functools.lru_cache(maxsize=None)` with less to type.
- `zoneinfo` replaces `pytz` for timezone handling on 3.9+.
- `ast.literal_eval` is the safe alternative to `eval()` for parsing literal Python values from a string.

## Key takeaways

- These modules are what "know the stdlib" means in a senior interview — not exhaustive knowledge of every function, but recognizing which module already solves a problem before reaching for a third-party package or hand-rolling it.
- `functools.lru_cache`/`cache` is the direct application of Day 12-15's DP memoization concept.
- `concurrent.futures` sits on top of `threading`/`multiprocessing` as the managed-pool API — reach for it first.
- Security-sensitive randomness/comparison always goes through `secrets`/`hmac`, never `random`/`==`.
