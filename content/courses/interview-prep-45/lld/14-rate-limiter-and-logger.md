---
kind: lesson
id_key: interview-prep-45/lld-14-ratelimiter-logger
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Design a Rate Limiter and a Logging Framework"
position: 14
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

These are both "design a library, not an app" problems. That's exactly why they're asked: a library has no UI to hide behind, so the interface itself *is* the design, and how good your abstractions are shows up immediately. Both are also things you genuinely use every day — you've written log statements constantly, and a rate limiter is guarding every API you'll ever build.

## Rate limiter — requirements and the interface

**What it needs to do:**

- `allow(key) -> bool`: decide, right now, whether this request can go through.
- Configurable limits, **per key** — per user, per API key, per IP — and per resource or endpoint.
- Support several algorithms: fixed window, sliding window, token bucket.
- Report how much budget is left, and when it resets, so clients can behave sensibly.
- Work correctly across multiple servers.

**Start with the interface.** In a library problem, spend a full minute just on the method signature — most of the actual design lives right there:

```
class RateLimiter(ABC):
    def try_acquire(self, key: str, now: float, permits: int = 1) -> Decision: ...

@dataclass(frozen=True)
class Decision:
    allowed: bool
    remaining: int
    retry_after: float     # seconds until the next permit; 0 when allowed
```

Three choices here are worth defending out loud:

- **Return a `Decision`, not just a plain boolean.** The caller needs a `Retry-After` header and a remaining-budget header — a bare yes/no forces a second call just to get that information.
- **Take `now` as a parameter, instead of reading the clock internally.** Injecting time means every algorithm can be tested with exact, predictable numbers, with no actual waiting involved — a small habit that reads as real experience.
- **Take `permits`,** so one especially expensive request can cost, say, 10 tokens instead of 1. Weighted limits are a very common follow-up question, and this costs nothing to support from the start.

> **Remember:** a rate limiter's return value should carry enough information for the caller to set real HTTP headers, and its clock should be a parameter, not something it reads on its own.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-14-interface-q1", "type": "mcq",
      "prompt": "Why should a rate limiter's method return a `Decision` object instead of a plain boolean, and take `now` as a parameter?",
      "options": [
        {"id":"a","text":"To make the API look more object-oriented"},
        {"id":"b","text":"The caller needs the remaining budget and a retry-after value to set real response headers, and passing the clock in as a parameter makes every algorithm testable with exact, predictable time values instead of real waiting"},
        {"id":"c","text":"Because a plain boolean can't be returned from an abstract method"},
        {"id":"d","text":"To allow the limiter to be called asynchronously"}
      ],
      "correct": "b",
      "explanation": "Both choices come from the caller's real needs: HTTP rate-limit headers need more than a plain yes or no, and a component that reads the clock on its own can only be tested by actually waiting or monkey-patching the clock." }
] }
```

## Rate limiter — the algorithms, behind one interface

Each algorithm here is a **Strategy**. The limiter itself is just a thin coordinator sitting over per-key state.

```python
from abc import ABC, abstractmethod
from collections import deque
from dataclasses import dataclass
import threading


@dataclass(frozen=True)
class Decision:
    allowed: bool
    remaining: int
    retry_after: float


class RateLimiter(ABC):
    @abstractmethod
    def try_acquire(self, key: str, now: float, permits: int = 1) -> Decision: ...


class FixedWindowLimiter(RateLimiter):
    """The cheapest option. Flaw: up to 2x the limit can slip through at a window boundary."""
    def __init__(self, limit: int, window_seconds: float):
        self.limit, self.window = limit, window_seconds
        self._counts: dict[tuple[str, int], int] = {}
        self._lock = threading.Lock()

    def try_acquire(self, key, now, permits=1):
        bucket = int(now // self.window)
        with self._lock:
            used = self._counts.get((key, bucket), 0)
            if used + permits > self.limit:
                reset_at = (bucket + 1) * self.window
                return Decision(False, self.limit - used, reset_at - now)
            self._counts[(key, bucket)] = used + permits
            return Decision(True, self.limit - used - permits, 0.0)


class SlidingWindowLogLimiter(RateLimiter):
    """Exact, but memory grows with the request rate — good for low-volume, high-value limits."""
    def __init__(self, limit: int, window_seconds: float):
        self.limit, self.window = limit, window_seconds
        self._hits: dict[str, deque] = {}
        self._lock = threading.Lock()

    def try_acquire(self, key, now, permits=1):
        with self._lock:
            hits = self._hits.setdefault(key, deque())
            while hits and hits[0] <= now - self.window:
                hits.popleft()                       # drop everything outside the window
            if len(hits) + permits > self.limit:
                retry = hits[0] + self.window - now
                return Decision(False, self.limit - len(hits), max(0.0, retry))
            for _ in range(permits):
                hits.append(now)
            return Decision(True, self.limit - len(hits), 0.0)


class TokenBucketLimiter(RateLimiter):
    """The default choice: enforces an average rate while still allowing a short burst."""
    def __init__(self, rate_per_second: float, burst: int):
        self.rate, self.burst = rate_per_second, burst
        self._state: dict[str, tuple[float, float]] = {}   # key -> (tokens, last_refill)
        self._lock = threading.Lock()

    def try_acquire(self, key, now, permits=1):
        with self._lock:
            tokens, last = self._state.get(key, (float(self.burst), now))
            tokens = min(self.burst, tokens + (now - last) * self.rate)   # refill lazily
            if tokens >= permits:
                self._state[key] = (tokens - permits, now)
                return Decision(True, int(tokens - permits), 0.0)
            self._state[key] = (tokens, now)
            return Decision(False, int(tokens), (permits - tokens) / self.rate)


# --- fixed window: the boundary burst is visible right away ------------------
fw = FixedWindowLimiter(limit=2, window_seconds=60)
assert [fw.try_acquire("u1", t).allowed for t in (0, 1, 2)] == [True, True, False]
assert fw.try_acquire("u1", 59.9).allowed is False
assert fw.try_acquire("u1", 60.0).allowed is True          # new window: 2 more, right away
assert fw.try_acquire("u2", 0).allowed is True             # each key is isolated

# --- sliding log: exact, no boundary trick ------------------------------------
sw = SlidingWindowLogLimiter(limit=2, window_seconds=60)
assert [sw.try_acquire("u1", t).allowed for t in (0, 1)] == [True, True]
assert sw.try_acquire("u1", 59).allowed is False
assert sw.try_acquire("u1", 61).allowed is True            # the hit at t=0 has aged out

# --- token bucket: a burst, then a steady rate --------------------------------
tb = TokenBucketLimiter(rate_per_second=1, burst=3)
assert [tb.try_acquire("u1", 0).allowed for _ in range(3)] == [True, True, True]
denied = tb.try_acquire("u1", 0)
assert denied.allowed is False and abs(denied.retry_after - 1.0) < 1e-9
assert tb.try_acquire("u1", 2).allowed is True             # 2 seconds later, 2 tokens refilled
assert tb.try_acquire("u1", 2, permits=5).allowed is False # too expensive a request

print("token bucket retry_after:", round(denied.retry_after, 2), "seconds")
```

**Distributed rate limiting is the natural follow-up.** Three answers, in increasing order of how good they are:

1. **Per-node limits** — wrong: 10 nodes at 100/minute each means 1000/minute overall, not 100.
2. **One central counter in Redis** (`INCR` plus `EXPIRE`, or a Lua script for the token bucket so refilling and taking a token happen atomically) — correct, but it adds a network round trip to every single request and makes Redis a hard dependency for your front door.
3. **Local buckets, each holding a share of the global budget, rebalanced now and then against a central counter** — approximate, fast, and it gracefully falls back to per-node limits if the central store ever goes down. This is what production API gateways actually do.

Also worth one sentence: **rate limit by identity where you can, not by IP address** — mobile carriers and corporate networks can put thousands of real users behind one single IP.

> **Remember:** fixed window is cheap but bursty at the boundary. Sliding window is exact but memory-hungry. Token bucket is the default, because it allows a burst without giving up on the average rate.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-14-algo-q1", "type": "mcq",
      "prompt": "Under a fixed-window limiter of 2 requests per minute, a client sends 2 requests at t=59s and 2 more at t=61s. How many actually got through in that 2-second span, and what fixes it?",
      "options": [
        {"id":"a","text":"2 — the limiter is working correctly"},
        {"id":"b","text":"4 — the window boundary lets up to twice the limit through in an instant; a sliding window (log-based or interpolated) or a token bucket removes this artefact entirely"},
        {"id":"c","text":"0 — both windows were already full"},
        {"id":"d","text":"3 — the limiter allows one extra request per window"}
      ],
      "correct": "b",
      "explanation": "Each window counts requests entirely on its own, so a burst that straddles the boundary gets both windows' budgets. This is exactly why sliding-window counters and token buckets exist." }
] }
```

## Logging framework — requirements and the two patterns

**What it needs to do:**

- Levels: DEBUG, INFO, WARN, ERROR, FATAL, in that order, with a configurable threshold.
- Several destinations at once (console, a file, the network), each with its own level and format.
- Structured context — a request id, a user id — attached to every message automatically.
- Thread-safe, and cheap whenever a message gets filtered out.
- Configurable while the program is running, without needing a redeploy.

**Two patterns carry this whole design**, and naming both is really the entire point of the problem:

- **Chain of Responsibility** for the level hierarchy: each handler checks whether a record meets its own threshold, acts if it does, and passes it on regardless — this is a *broadcast* chain rather than a stop-at-first-match one, so say which kind you mean.
- **Strategy** for both formatting (plain text, JSON, key-value pairs) and for the destination itself (an `Appender`/`Sink`), so a brand-new output is just a new class.

There's a third, quieter decision here that matters more in production than either pattern: **the level check has to happen before the message string is even built.** `log.debug(f"user {expensive()}")` runs that f-string, and pays its full cost, even when DEBUG is turned off. The fix is either a lazy signature (`log.debug("user %s", user)`, only formatted if it actually passes the check) or an explicit `is_enabled(level)` guard before doing any work.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import IntEnum
import threading


class Level(IntEnum):                      # an IntEnum, because comparing levels is the whole point
    DEBUG = 10
    INFO = 20
    WARN = 30
    ERROR = 40
    FATAL = 50


@dataclass
class LogRecord:
    level: Level
    message: str
    timestamp: float
    context: dict = field(default_factory=dict)


class Formatter(ABC):                      # strategy: how a record becomes text
    @abstractmethod
    def format(self, record: LogRecord) -> str: ...


class PlainFormatter(Formatter):
    def format(self, record):
        ctx = " ".join(f"{k}={v}" for k, v in sorted(record.context.items()))
        return f"[{record.level.name}] {record.message}" + (f" {ctx}" if ctx else "")


class JsonFormatter(Formatter):
    def format(self, record):
        fields = {"level": record.level.name, "msg": record.message, **record.context}
        body = ", ".join(f'"{k}": "{v}"' for k, v in fields.items())
        return "{" + body + "}"


class Appender(ABC):                       # strategy: where the text actually goes
    def __init__(self, min_level: Level, formatter: Formatter):
        self.min_level, self.formatter = min_level, formatter
        self._lock = threading.Lock()

    def handle(self, record: LogRecord) -> None:
        if record.level >= self.min_level:            # each destination has its own threshold
            with self._lock:                          # writes to one sink are serialised
                self.write(self.formatter.format(record))

    @abstractmethod
    def write(self, line: str) -> None: ...


class MemoryAppender(Appender):            # a stand-in for console/file/network
    def __init__(self, min_level, formatter):
        super().__init__(min_level, formatter)
        self.lines: list[str] = []
    def write(self, line): self.lines.append(line)


class Logger:
    def __init__(self, name: str, min_level: Level = Level.DEBUG):
        self.name, self.min_level = name, min_level
        self._appenders: list[Appender] = []
        self._context: dict = {}

    def add_appender(self, appender: Appender) -> "Logger":
        self._appenders.append(appender)
        return self

    def with_context(self, **kwargs) -> "Logger":
        """A child logger carrying request-scoped fields — no global mutable state involved."""
        child = Logger(self.name, self.min_level)
        child._appenders = self._appenders            # shares the same sinks, has its own context
        child._context = {**self._context, **kwargs}
        return child

    def is_enabled(self, level: Level) -> bool:
        return level >= self.min_level

    def log(self, level: Level, template: str, *args, now: float = 0.0) -> None:
        if not self.is_enabled(level):
            return                                     # a cheap exit BEFORE any formatting
        message = template % args if args else template
        record = LogRecord(level, message, now, dict(self._context))
        for appender in self._appenders:
            appender.handle(record)

    def debug(self, t, *a, now=0.0): self.log(Level.DEBUG, t, *a, now=now)
    def info(self, t, *a, now=0.0): self.log(Level.INFO, t, *a, now=now)
    def warn(self, t, *a, now=0.0): self.log(Level.WARN, t, *a, now=now)
    def error(self, t, *a, now=0.0): self.log(Level.ERROR, t, *a, now=now)


console = MemoryAppender(Level.INFO, PlainFormatter())     # for humans: INFO and above
audit = MemoryAppender(Level.ERROR, JsonFormatter())       # for alerting: ERROR only
log = Logger("app", min_level=Level.DEBUG).add_appender(console).add_appender(audit)

request_log = log.with_context(request_id="r-42", user="asha")
request_log.debug("cache lookup %s", "user:1")             # below the console's own threshold
request_log.info("order placed")
request_log.error("payment failed: %s", "timeout")

assert console.lines == [
    "[INFO] order placed request_id=r-42 user=asha",
    "[ERROR] payment failed: timeout request_id=r-42 user=asha",
]
assert len(audit.lines) == 1 and audit.lines[0].startswith('{"level": "ERROR"')
assert log.with_context().is_enabled(Level.DEBUG) is True

quiet = Logger("app", min_level=Level.WARN).add_appender(console)
quiet.info("this line is dropped before any formatting even happens")
assert len(console.lines) == 2                             # unchanged

print("\n".join(console.lines))
print(audit.lines[0])
```

> **Remember:** the level check has to happen before the message string is built, never after. Otherwise, a disabled log call still pays the cost of an enabled one.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-14-logger-q1", "type": "mcq",
      "prompt": "Why does `log(...)` check `is_enabled(level)` before it ever builds the message string?",
      "options": [
        {"id":"a","text":"To keep the method shorter"},
        {"id":"b","text":"Building the message is often the expensive part — `log.debug(f\"...{expensive()}\")` pays that full cost even with DEBUG turned off, so the level check has to come first, and formatting has to be deferred (%s-style arguments, not an eager f-string)"},
        {"id":"c","text":"Because appenders can't handle empty messages"},
        {"id":"d","text":"To make the logger thread-safe"}
      ],
      "correct": "b",
      "explanation": "A disabled log call should cost exactly one integer comparison. Building the string eagerly at the call site defeats that entirely — which is exactly why real logging libraries take a template plus separate arguments, not a pre-built string." }
] }
```

## Concurrency, performance, and extensions

**Rate limiter:**

| Concern | How it's handled |
|---|---|
| Several `try_acquire` calls for one key at once | A lock per key (or a striped array of locks), never one single global lock |
| Memory growing from keys nobody uses anymore | Evict with an LRU cache or a TTL — an unbounded per-key map is really just a slow memory leak |
| Correctness across servers | A Lua script in Redis makes refilling and taking a token one atomic step; local buckets against a shared global budget when latency matters more than being perfectly exact |
| Fail open, or fail closed? | **Decide this ahead of time, and say so out loud.** If Redis goes down, do you let all traffic through (available, but unprotected) or block everything (protected, but an outage)? Usually fail-open for ordinary user traffic, fail-closed for anything expensive or dangerous |

That last row is exactly the question interviewers use to separate strong candidates from weaker ones — the right answer isn't a fixed value, it's "it depends on what this endpoint actually costs, and here's my default."

**Logger:**

| Concern | How it's handled |
|---|---|
| Several threads writing to one shared sink | A lock per appender (as built above), or an asynchronous appender with a bounded queue |
| A slow sink (the network) blocking the request | An **asynchronous appender**: put the message on a queue, and let a background thread drain it |
| The queue fills up | Drop the oldest entry, drop by level, or block — but as an explicit, configured policy, never as an unbounded queue that just grows forever |
| Losing logs if the process crashes | Flush on shutdown; accept a small, known window of possible loss for async sinks, and say exactly what that window is |
| Request-scoped context | A child logger, or a context-local variable — never a single global mutable dictionary |

**Extensions for both:**

- A new rate-limiting algorithm → a new `RateLimiter` class; the gateway itself is unchanged.
- Per-endpoint limits → a config map from route to limiter; a composite tries each one and denies if any of them denies.
- A new log destination (Kafka, S3, OpenTelemetry) → a new `Appender`.
- Sampling ("only log 1% of DEBUG messages in production") → a filter placed before the appenders in the chain.
- Redacting sensitive data → a formatter decorator wrapping the real formatter.

> **Remember:** fail-open or fail-closed is a deliberate, per-endpoint decision — never a blanket default applied everywhere.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-14-failmode-q1", "type": "mcq",
      "prompt": "Your distributed rate limiter's Redis backend goes down. What's the right design response?",
      "options": [
        {"id":"a","text":"Always deny requests — safety comes first"},
        {"id":"b","text":"It's a deliberate, per-endpoint policy: fail-open (allow, unprotected) for ordinary user traffic so an infrastructure blip doesn't take the whole product down, and fail-closed for expensive or dangerous endpoints — either way, backed by a local in-process fallback limit"},
        {"id":"c","text":"Always allow requests — availability comes first"},
        {"id":"d","text":"Just keep retrying Redis until it responds again"}
      ],
      "correct": "b",
      "explanation": "Neither blanket answer is right in every situation. The strong response names the trade-off directly, sets a sensible default, and adds a degraded local limit so the failure stays bounded instead of becoming an all-or-nothing outcome." }
] }
```

## Quick recap

- **In a library problem, the interface *is* the design.** Spend a full minute on the method signature: return a rich result, inject the clock, and allow weighted permits.
- **Rate limiter = a Strategy over per-key state.** Fixed window is cheap but bursty at the boundary; sliding log is exact but memory-hungry; **token bucket is the default** because it enforces an average rate while still letting through a short burst.
- **Distributed limiting is the natural follow-up**, and "local buckets against a shared budget" is the production answer — with the fail-open or fail-closed decision stated out loud.
- **Logger = Chain of Responsibility for levels, plus Strategy for the formatter and the appender**, plus the one performance detail people forget: check the level *before* building the message.
- **Bounded, with eviction, everywhere.** An unbounded per-key map and an unbounded async log queue are the two memory leaks these two designs quietly invite if you're not careful.
