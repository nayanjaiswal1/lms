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

This is a reference, not a lesson to work through top to bottom: the modules a senior Python developer is expected to reach for by name, without needing to look up "does the stdlib have this." A few of these modules (`Counter`, `functools.lru_cache`-style memoization, `contextlib` patterns) already come up applied to specific problems elsewhere in this course; this page collects the rest in one place, with enough detail that it stands on its own.

## Data structures and iteration

**`collections`**
- `defaultdict`: a dict that supplies a default value for a missing key instead of raising `KeyError`, so you can skip explicit key-existence checks before appending or incrementing.
- `Counter`: a dict subclass for frequency counting, the standard tool any time an interview problem asks "how many times does each element appear."
- `deque`: a double-ended queue with O(1) append/pop from both ends, used for queues and for the sliding-window pattern where you need to drop elements off the front cheaply.
- `namedtuple`: a lightweight, immutable record type, useful when you want tuple performance with named field access.

**`heapq`**
- Implements a binary min-heap directly on a plain list. Use it for priority queues, and for `nlargest`/`nsmallest` when you need the top-K elements without a full O(n log n) sort.
- Also the standard tool for merging several already-sorted iterables into one sorted output (the k-way merge pattern that shows up in "merge K sorted lists"-style problems).

**`bisect`**
- Binary search on a sorted list (`bisect_left`/`bisect_right`), and maintaining sorted order on insert via `insort` instead of appending and re-sorting.
- This is the same binary-search technique used for "search a sorted array" problems, just applied to keeping a list sorted as you insert into it rather than to a one-off lookup.

**`itertools`**
- `chain`: flattens multiple iterables into one, without building an intermediate list.
- `product`/`combinations`/`permutations`: generate combinatorial outputs directly. These come up in backtracking-style problems (generating subsets, permutations, or combinations), though a hand-rolled recursive backtracking function is usually what an interviewer wants to see instead of a one-line `itertools` call.
- `groupby`: groups consecutive equal elements, useful after sorting by the same key.
- `islice`: slices an iterator lazily, without materializing the whole thing into a list first.
- `accumulate`: computes a running (prefix) sum or, with a custom function, a running reduction, which is the direct stdlib tool for prefix-sum problems.

**`functools`**
- `lru_cache`/`cache`: memoizes a function's return values by its arguments. This is the standard way to turn a naive exponential recursive solution into a polynomial-time dynamic-programming one, by caching each subproblem's result the first time it's computed.
- `partial`: pre-fills some arguments of a function and returns a new callable, the stdlib's answer to currying.
- `reduce`: folds an iterable down to a single value with a binary function.
- `cached_property`: like `lru_cache` but for a single instance attribute, computed once per instance and then reused.

## Files, serialization, networking

- **`pathlib`**: the object-oriented way to work with filesystem paths. Prefer it over `os.path` for any new code; it supports globbing (`rglob`) and has built-in read/write helpers.
- **`json`**: serializes and deserializes JSON. Supports custom encoders for types `json` doesn't know how to handle by default (dates, Decimals, custom classes).
- **`pickle`**: serializes arbitrary Python objects between trusted processes. Never unpickle data from an untrusted source, since a crafted pickle payload can execute arbitrary code during deserialization.
- **`csv`**: `DictReader`/`DictWriter` give header-based row access instead of working with raw positional lists.
- **`socket` / `http.client` / `urllib`**: raw TCP/HTTP, for when you're working below the level of the `requests` library, or building a minimal server/client as a test double.
- **`ipaddress`**: validates IP addresses and does CIDR/subnet math.

## Concurrency

- **`threading`**: for I/O-bound concurrency, where threads spend most of their time waiting on network or disk rather than computing. Provides `Lock`/`Semaphore`/`Event` primitives for coordinating between threads.
- **`multiprocessing`**: for CPU-bound parallelism that needs to bypass the GIL, since each process gets its own Python interpreter. `Pool.map` covers embarrassingly parallel workloads.
- **`concurrent.futures`**: a managed-pool API sitting on top of both of the above. `ThreadPoolExecutor` and `ProcessPoolExecutor` give you the same underlying mechanisms with a simpler interface; prefer this over raw `threading`/`multiprocessing` unless you specifically need finer-grained control.
- **`asyncio`**: async I/O built on coroutines, with `gather` for concurrent execution and async-safe locks/queues. This is the foundation underneath any async web framework (like FastAPI) and any async multi-stage processing pipeline built from Celery or similar tools.
- **`subprocess`**: runs external commands, captures their output, and can pipe to stdin/stdout with a timeout.

## Date, math, text

- **`datetime` / `zoneinfo`**: date/time arithmetic and timezone-aware datetimes. `zoneinfo` (Python 3.9+) replaced the third-party `pytz` package for timezone handling.
- **`decimal`**: use for money and financial math. Never use `float` for currency, because floating-point rounding error accumulates across repeated arithmetic.
- **`re`**: regex matching. Use `re.compile` to pre-compile a pattern that gets reused across many calls, rather than recompiling it every time.
- **`difflib`**: sequence diffing and fuzzy string matching via `get_close_matches`.

## Testing, introspection, packaging

- **`unittest`** (including `unittest.mock`): test cases, fixtures, and `patch` for mocking out dependencies. This is the foundation underneath higher-level testing practices like the ones covered in this course's dedicated testing-strategies lesson (fixtures, mocks vs. stubs, coverage targets).
- **`timeit` / `cProfile`**: `timeit` micro-benchmarks a small snippet; `cProfile` profiles an entire call tree to find the actual bottleneck. Don't guess where the slow part is, measure it.
- **`inspect`**: gets a function's signature or source at runtime. This is how frameworks build introspection-based tooling, like FastAPI reading a route handler's parameters to build its dependency graph.
- **`dataclasses`**: auto-generates `__init__`/`__repr__`/`__eq__` for a plain data-holding class. It's the stdlib alternative to hand-writing that boilerplate, or to reaching for Pydantic when you don't actually need validation.
- **`abc`**: enforces an interface via `@abstractmethod`, backed by the `ABCMeta` metaclass, which raises `TypeError` at instantiation time if a subclass hasn't implemented every abstract method.
- **`typing`**: type hints, including `Protocol` for structural typing, `TypedDict` for typed dict shapes, `overload` for multiple type signatures on one function, and `TYPE_CHECKING` for import-cycle-safe type-only imports.
- **`argparse`**: CLI argument parsing with an auto-generated `--help`.
- **`logging`**: hierarchical loggers, levels, and handlers. Never use `print()` in production code, since it can't be filtered, routed, or leveled the way a real logger can.

## Security

- **`hashlib`**: file integrity hashes, and an input to password hashing (combined with `hmac`/`secrets`). Don't hash passwords with plain `hashlib` alone; use a purpose-built password hashing scheme (like bcrypt) instead.
- **`hmac`**: message authentication codes. Use `hmac.compare_digest` for timing-safe comparison of secrets, never a plain `==`, which can leak information through timing differences.
- **`secrets`**: cryptographically secure random tokens and passwords. Never use the `random` module for anything security-sensitive, since it's not cryptographically secure and its output can be predicted.

## Pro tips

- Prefer `pathlib` over `os.path` for all new code.
- Prefer `concurrent.futures` over raw `threading`/`multiprocessing`, unless you specifically need the lower-level control.
- `functools.cache` (3.9+) is `functools.lru_cache(maxsize=None)` with less to type.
- `zoneinfo` replaces `pytz` for timezone handling on 3.9+.
- `ast.literal_eval` is the safe alternative to `eval()` for parsing literal Python values (numbers, strings, lists, dicts) out of a string.

Knowing this list isn't about memorizing every function signature. It's about recognizing, in the moment, which module already solves the problem in front of you, so you reach for `Counter` or `bisect` instead of hand-rolling the same logic from scratch or pulling in a third-party package for something the standard library already covers.
