---
kind: lesson
id_key: interview-prep-45/python-stdlib-and-serialization
course: interview-prep-45
section: backend-python
section_title: "Python"
section_position: 6
section_group: "Backend"
title: "Standard Library and Serialization"
position: 4
estimated_minutes: 30
source:
    - interview-prep-notes.md
---

A senior Python developer doesn't ask "does the standard library have this," they already know which module to reach for. This lesson is a reference to build that reflex, plus a close look at one specific module, `pickle`, that comes with a real security trap.

## Data structures and iteration you should reach for by name

**`collections`**
- `defaultdict`: a dict that supplies a default value for a missing key instead of raising `KeyError`, so you skip the explicit "does this key exist yet" check before appending or incrementing.
- `Counter`: a dict built for frequency counting. Any time an interview problem asks "how many times does each element appear," this is the tool.
- `deque`: a double-ended queue with instant append and pop from both ends. Used for queues, and for the sliding-window pattern where you need to drop elements off the front cheaply.
- `namedtuple`: a lightweight, immutable record type, tuple performance with named field access.

**`heapq`**
- A binary min-heap built directly on a plain list. Use it for priority queues, and for `nlargest`/`nsmallest` when you need the top few elements without a full sort.
- Also the standard tool for merging several already-sorted lists into one sorted output, the "merge K sorted lists" pattern.

**`bisect`**
- Binary search on a sorted list (`bisect_left`/`bisect_right`), and inserting while keeping order (`insort`) instead of appending and re-sorting every time.

**`itertools`**
- `chain`: flattens several iterables into one, without building an extra list.
- `product`/`combinations`/`permutations`: generate combinatorial outputs directly. These show up in backtracking-style problems, though a hand-rolled recursive function is usually what an interviewer wants to see instead of a one-line call.
- `groupby`: groups consecutive equal elements, useful right after sorting by the same key.
- `islice`: slices an iterator lazily, without materializing the whole thing.
- `accumulate`: a running (prefix) sum, or a running reduction with a custom function.

**`functools`**
- `lru_cache`/`cache`: memoizes a function's return values by its arguments. This is the standard way to turn a slow exponential recursive solution into a fast dynamic-programming one, by caching each subproblem's answer the first time it's computed.
- `partial`: pre-fills some arguments and returns a new callable.
- `reduce`: folds an iterable down to one value with a two-argument function.
- `cached_property`: like `lru_cache`, but for one instance attribute, computed once per instance.

> **Remember:** reaching for `Counter` or `bisect` instead of hand-rolling the same logic is exactly what "knowing the standard library" means in an interview.

```knowledge-check
{ "questions": [
    { "id": "backend-python-stdlib-datastructures-q1", "type": "mcq",
      "prompt": "You need the running count of how many times each word appears in a list. Which stdlib tool is built exactly for this?",
      "options": [
        {"id":"a","text":"collections.Counter"},
        {"id":"b","text":"itertools.chain"},
        {"id":"c","text":"bisect.insort"},
        {"id":"d","text":"functools.partial"}
      ],
      "correct": "a",
      "explanation": "Counter is a dict subclass built specifically for frequency counting: pass it any iterable and it tallies occurrences of each element automatically." }
] }
```

## Files, concurrency, and text

- **`pathlib`**: the modern, object-oriented way to work with filesystem paths. Prefer it over `os.path` for new code; it supports globbing (`rglob`) and has built-in read/write helpers.
- **`json`**: serializes and deserializes JSON, with custom encoders for types it doesn't know by default (dates, `Decimal`, custom classes).
- **`csv`**: `DictReader`/`DictWriter` give header-based row access instead of raw positional lists.

Concurrency has three tools for three different jobs:
- **`threading`**: for I/O-bound work, where threads mostly wait on network or disk. Provides `Lock`/`Semaphore`/`Event` for coordinating between threads.
- **`multiprocessing`**: for CPU-bound parallelism that needs to bypass the GIL, since each process gets its own interpreter.
- **`asyncio`**: async I/O built on coroutines, with `gather` for running things concurrently. This is the foundation under any async web framework, including FastAPI, and under async pipelines built with tools like Celery.
- **`concurrent.futures`**: a simpler, managed-pool interface sitting on top of both `threading` and `multiprocessing`. Prefer this unless you need finer-grained control.

Other reliable reflexes: `datetime`/`zoneinfo` for timezone-aware date math (`zoneinfo`, 3.9+, replaced the third-party `pytz`); `decimal` for money, never `float`, since floating-point rounding error accumulates across repeated arithmetic; `re.compile` to pre-compile a pattern reused across many calls instead of recompiling it every time; `dataclasses` to auto-generate `__init__`/`__repr__`/`__eq__` for a plain data-holding class, instead of hand-writing that boilerplate or reaching for a validation library you don't actually need; `logging` instead of `print()` in production code, since a logger can be filtered, routed, and leveled in a way `print` never can.

> **Remember:** `concurrent.futures` is the simple, managed front door to both threading and multiprocessing. Reach for the raw modules only when you need control it doesn't give you.

```knowledge-check
{ "questions": [
    { "id": "backend-python-stdlib-concurrency-q1", "type": "mcq",
      "prompt": "Which module gives CPU-bound work its own separate interpreter per worker, actually bypassing the GIL for parallel execution?",
      "options": [
        {"id":"a","text":"threading"},
        {"id":"b","text":"multiprocessing"},
        {"id":"c","text":"asyncio"},
        {"id":"d","text":"itertools"}
      ],
      "correct": "b",
      "explanation": "Each process spawned by multiprocessing gets its own Python interpreter and its own GIL, so CPU-heavy work genuinely runs in parallel across cores, unlike threading, which is limited by one shared GIL." }
] }
```

## Security-relevant modules

- **`hashlib`**: file integrity hashes, and an input to password hashing (combined with `hmac`/`secrets`). Never hash passwords with plain `hashlib` alone; use a purpose-built password hashing scheme instead.
- **`hmac`**: message authentication codes. Use `hmac.compare_digest` for a timing-safe comparison of secrets, never a plain `==`, which can leak information through how long the comparison takes.
- **`secrets`**: cryptographically secure random tokens and passwords. Never use the `random` module for anything security-sensitive; its output isn't cryptographically secure and can be predicted.
- **`ast.literal_eval`**: the safe alternative to `eval()` for parsing literal Python values (numbers, strings, lists, dicts) out of a string.

> **Remember:** `random` is for games and sampling. `secrets` is for anything security-sensitive, tokens, passwords, session IDs.

```knowledge-check
{ "questions": [
    { "id": "backend-python-stdlib-security-q1", "type": "mcq",
      "prompt": "Why should you use hmac.compare_digest instead of == to compare a secret token against an expected value?",
      "options": [
        {"id":"a","text":"compare_digest is shorter to type"},
        {"id":"b","text":"A plain == can return faster or slower depending on how many leading characters match, leaking information through timing; compare_digest takes constant time regardless"},
        {"id":"c","text":"== does not work on strings in Python"},
        {"id":"d","text":"compare_digest is required for comparing numbers, not strings"}
      ],
      "correct": "b",
      "explanation": "A naive == comparison can exit early on the first mismatched character, and an attacker measuring response times can use that to guess a secret one character at a time. compare_digest always takes the same amount of time." }
] }
```

## Pickle: Python's own serialization format

`pickle` turns Python objects into bytes (pickling) and back into objects (unpickling), working with almost anything: lists, dicts, custom class instances, even functions by reference.

```python
import pickle

data = {"name": "Alice", "scores": [95, 87, 92]}

# Pickling: to a file or to bytes
with open("data.pkl", "wb") as f:
    pickle.dump(data, f)
byte_data = pickle.dumps(data)

# Unpickling: from a file or from bytes
with open("data.pkl", "rb") as f:
    loaded = pickle.load(f)
loaded = pickle.loads(byte_data)
```

`pickle.dump(data, f)` walks the dict, converts each piece into pickle's own binary format, and writes the bytes straight to the open file. `pickle.dumps(data)` does the same conversion but returns the bytes directly, which is what you'd use to store the result in Redis or a database column. `pickle.load(f)` and `pickle.loads(byte_data)` reverse the process, rebuilding an equivalent object in memory.

**Never unpickle data from an untrusted source.** Unlike `json`, unpickling can run arbitrary code: a crafted pickle payload can execute anything during deserialization, by defining a `__reduce__` method that returns a callable and arguments, which `pickle.load` will call automatically while rebuilding the object.

This is the standard interview follow-up: "why not always use pickle instead of JSON?" Pickle trades safety for capability. It's Python-only, not cross-language, and unsafe on untrusted input. `json` (and `msgpack`) are safe to parse from anywhere but can't represent arbitrary objects, like custom classes or functions, without writing a custom encoder.

Pickle is a good fit for caching computed Python objects between runs, such as a trained model or an in-memory index, where both ends of the exchange are your own trusted code. It's the wrong tool for anything crossing a network boundary from an external client, and the wrong tool for cross-language interchange, since only Python can read the format back.

> **Remember:** pickle can run arbitrary code on load. Only unpickle data your own trusted code produced, never anything from an external client.

```knowledge-check
{ "questions": [
    { "id": "backend-python-stdlib-pickle-q1", "type": "mcq",
      "prompt": "Why is it dangerous to call pickle.load() on data received from an untrusted external client?",
      "options": [
        {"id":"a","text":"It will always raise an exception on malformed data"},
        {"id":"b","text":"A crafted pickle payload can execute arbitrary code during deserialization, since pickle.load automatically calls whatever the payload's __reduce__ tells it to"},
        {"id":"c","text":"Pickle files are always too large to transmit safely"},
        {"id":"d","text":"Pickle cannot represent dictionaries, only lists"}
      ],
      "correct": "b",
      "explanation": "Pickle's format supports rebuilding an object by calling arbitrary functions with arbitrary arguments. An attacker controlling the bytes controls what code runs when you unpickle them. JSON has no equivalent mechanism, which is why it's the safe default for untrusted input." }
] }
```
