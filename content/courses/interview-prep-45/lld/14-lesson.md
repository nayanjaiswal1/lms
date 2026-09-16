---
kind: lesson
id_key: interview-prep-45/lld-14-ratelimiter-logger
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD: Rate Limiter and Logging Framework"
position: 14
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Two "design a library, not an app" problems. They are asked because a library has no UI to hide behind: the interface *is* the design, and the quality of your abstractions is immediately visible. Both are also directly useful — you have used a logger every day and a rate limiter guards every API you will build.

## Rate limiter — requirements and interface

**Functional requirements:**

- `allow(key) -> bool`: decide whether this request may proceed, right now.
- Configurable limits **per key** (user, API key, IP) and per resource/endpoint.
- Multiple algorithms: fixed window, sliding window, token bucket.
- Report the remaining budget and when it resets (so clients can behave).
- Work across multiple servers.

**The interface first.** In a library problem, spend a full minute on the signature — it is where most of the design lives:

```
class RateLimiter(ABC):
    def try_acquire(self, key: str, now: float, permits: int = 1) -> Decision: ...

@dataclass(frozen=True)
class Decision:
    allowed: bool
    remaining: int
    retry_after: float     # seconds until the next permit, 0 when allowed
```

Three choices worth defending:

- **Return a `Decision`, not a bool.** The caller needs `Retry-After` and `X-RateLimit-Remaining` headers; a bare boolean forces a second call to get them.
- **Take `now` as a parameter.** Injecting time makes every algorithm deterministically testable without sleeping — this is a small thing that reads as real experience.
- **Take `permits`,** so one expensive request can cost 10 tokens. Weighted limits are a common follow-up and cost nothing to allow for now.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-14-interface-q1", "type": "mcq",
      "prompt": "Why should a rate limiter's method return a `Decision` object rather than a boolean, and accept `now` as a parameter?",
      "options": [
        {"id":"a","text":"To make the API look more object-oriented"},
        {"id":"b","text":"The caller needs the remaining budget and retry-after values to set response headers, and injecting the clock makes every algorithm deterministically testable without sleeping in tests"},
        {"id":"c","text":"Because booleans cannot be returned from abstract methods"},
        {"id":"d","text":"To allow the limiter to be called asynchronously"}
      ],
      "correct": "b",
      "explanation": "Both choices are about the caller's real needs: HTTP rate-limit headers require more than a yes/no, and a time-dependent component that reads the clock internally can only be tested with sleeps or monkey-patching." }
] }
```

## Rate limiter — the algorithms behind one interface

Each algorithm is a **Strategy**; the limiter itself is a thin facade over per-key state.

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
    """Cheapest. Flaw: up to 2x the limit can pass across a window boundary."""
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
    """Exact. Memory grows with the request rate, so use it for low-volume, high-value limits."""
    def __init__(self, limit: int, window_seconds: float):
        self.limit, self.window = limit, window_seconds
        self._hits: dict[str, deque] = {}
        self._lock = threading.Lock()

    def try_acquire(self, key, now, permits=1):
        with self._lock:
            hits = self._hits.setdefault(key, deque())
            while hits and hits[0] <= now - self.window:
                hits.popleft()                       # evict everything outside the window
            if len(hits) + permits > self.limit:
                retry = hits[0] + self.window - now
                return Decision(False, self.limit - len(hits), max(0.0, retry))
            for _ in range(permits):
                hits.append(now)
            return Decision(True, self.limit - len(hits), 0.0)


class TokenBucketLimiter(RateLimiter):
    """The default choice: enforces an average rate while allowing a bounded burst."""
    def __init__(self, rate_per_second: float, burst: int):
        self.rate, self.burst = rate_per_second, burst
        self._state: dict[str, tuple[float, float]] = {}   # key -> (tokens, last_refill)
        self._lock = threading.Lock()

    def try_acquire(self, key, now, permits=1):
        with self._lock:
            tokens, last = self._state.get(key, (float(self.burst), now))
            tokens = min(self.burst, tokens + (now - last) * self.rate)   # lazy refill
            if tokens >= permits:
                self._state[key] = (tokens - permits, now)
                return Decision(True, int(tokens - permits), 0.0)
            self._state[key] = (tokens, now)
            return Decision(False, int(tokens), (permits - tokens) / self.rate)


# --- fixed window: the boundary burst is visible -----------------------------
fw = FixedWindowLimiter(limit=2, window_seconds=60)
assert [fw.try_acquire("u1", t).allowed for t in (0, 1, 2)] == [True, True, False]
assert fw.try_acquire("u1", 59.9).allowed is False
assert fw.try_acquire("u1", 60.0).allowed is True          # new window: 2 more immediately
assert fw.try_acquire("u2", 0).allowed is True             # per-key isolation

# --- sliding log: exact, no boundary artefact --------------------------------
sw = SlidingWindowLogLimiter(limit=2, window_seconds=60)
assert [sw.try_acquire("u1", t).allowed for t in (0, 1)] == [True, True]
assert sw.try_acquire("u1", 59).allowed is False
assert sw.try_acquire("u1", 61).allowed is True            # the hit at t=0 has aged out

# --- token bucket: burst then steady rate ------------------------------------
tb = TokenBucketLimiter(rate_per_second=1, burst=3)
assert [tb.try_acquire("u1", 0).allowed for _ in range(3)] == [True, True, True]
denied = tb.try_acquire("u1", 0)
assert denied.allowed is False and abs(denied.retry_after - 1.0) < 1e-9
assert tb.try_acquire("u1", 2).allowed is True             # 2 s later, 2 tokens refilled
assert tb.try_acquire("u1", 2, permits=5).allowed is False # weighted request too expensive

print("token bucket retry_after:", round(denied.retry_after, 2), "seconds")
```

**Distributed rate limiting** is the follow-up. Three answers, in increasing order of quality:

1. **Per-node limits** — wrong: 10 nodes × 100/min = 1000/min.
2. **Central counter in Redis** (`INCR` + `EXPIRE`, or a Lua script for the token bucket so refill-and-take is atomic) — correct, but adds a network round trip to every request and makes Redis a hard dependency of your front door.
3. **Local buckets with a share of the global budget**, periodically rebalanced against a central counter — approximate, fast, and it degrades to per-node limits when the central store is unreachable. This is what production API gateways do.

Also worth a sentence: **rate limit by identity, not by IP** where possible — NAT and mobile carriers put thousands of users behind one address.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-14-algo-q1", "type": "mcq",
      "prompt": "Under a fixed-window limiter of 2 requests/minute, a client sends 2 requests at t=59s and 2 more at t=61s. How many passed in that 2-second span, and what fixes it?",
      "options": [
        {"id":"a","text":"2 — the limiter works correctly"},
        {"id":"b","text":"4 — the window boundary lets up to 2x the limit through in an instant; a sliding window (log or interpolated counter) or a token bucket removes the artefact"},
        {"id":"c","text":"0 — both windows were already full"},
        {"id":"d","text":"3 — the limiter allows one extra request per window"}
      ],
      "correct": "b",
      "explanation": "Each window counts independently, so a burst straddling the boundary gets both budgets. This is the standard motivation for sliding-window counters and token buckets." }
] }
```

## Logging framework — requirements and the two patterns

**Functional requirements:**

- Levels: DEBUG < INFO < WARN < ERROR < FATAL, with a configurable threshold.
- Multiple destinations (console, file, network) with independent levels and formats.
- Structured context (request id, user id) attached to every message.
- Thread-safe, and cheap when a message is filtered out.
- Configurable at runtime without a redeploy.

**Two patterns carry this design**, and naming both is the point of the problem:

- **Chain of Responsibility** for the level hierarchy: each handler decides whether the record is at or above its threshold, acts if so, and passes it on regardless (this is a *broadcast* chain rather than a stop-at-first-match one — say which you mean).
- **Strategy** for formatting (plain text, JSON, key-value) and for the destination (`Appender`/`Sink`), so a new output is a new class.

Add a third, quieter decision that matters more than either in production: **the level check must happen before the message is built.** `log.debug(f"user {expensive()}")` evaluates the f-string even when DEBUG is disabled. The fix is either a lazy signature (`log.debug("user %s", user)` formatting only if it passes) or an explicit `is_enabled(level)` guard.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import IntEnum
import threading


class Level(IntEnum):                      # IntEnum: comparison is the whole point
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


class Appender(ABC):                       # strategy: where the text goes
    def __init__(self, min_level: Level, formatter: Formatter):
        self.min_level, self.formatter = min_level, formatter
        self._lock = threading.Lock()

    def handle(self, record: LogRecord) -> None:
        if record.level >= self.min_level:            # each sink has its own threshold
            with self._lock:                          # writes are serialised per sink
                self.write(self.formatter.format(record))

    @abstractmethod
    def write(self, line: str) -> None: ...


class MemoryAppender(Appender):            # stands in for console/file/network
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
        """A child logger carrying request-scoped fields — no global mutable state."""
        child = Logger(self.name, self.min_level)
        child._appenders = self._appenders            # shared sinks, own context
        child._context = {**self._context, **kwargs}
        return child

    def is_enabled(self, level: Level) -> bool:
        return level >= self.min_level

    def log(self, level: Level, template: str, *args, now: float = 0.0) -> None:
        if not self.is_enabled(level):
            return                                     # cheap exit BEFORE formatting
        message = template % args if args else template
        record = LogRecord(level, message, now, dict(self._context))
        for appender in self._appenders:
            appender.handle(record)

    def debug(self, t, *a, now=0.0): self.log(Level.DEBUG, t, *a, now=now)
    def info(self, t, *a, now=0.0): self.log(Level.INFO, t, *a, now=now)
    def warn(self, t, *a, now=0.0): self.log(Level.WARN, t, *a, now=now)
    def error(self, t, *a, now=0.0): self.log(Level.ERROR, t, *a, now=now)


console = MemoryAppender(Level.INFO, PlainFormatter())     # humans: INFO and above
audit = MemoryAppender(Level.ERROR, JsonFormatter())       # alerting: ERROR only
log = Logger("app", min_level=Level.DEBUG).add_appender(console).add_appender(audit)

request_log = log.with_context(request_id="r-42", user="asha")
request_log.debug("cache lookup %s", "user:1")             # below console's threshold
request_log.info("order placed")
request_log.error("payment failed: %s", "timeout")

assert console.lines == [
    "[INFO] order placed request_id=r-42 user=asha",
    "[ERROR] payment failed: timeout request_id=r-42 user=asha",
]
assert len(audit.lines) == 1 and audit.lines[0].startswith('{"level": "ERROR"')
assert log.with_context().is_enabled(Level.DEBUG) is True

quiet = Logger("app", min_level=Level.WARN).add_appender(console)
quiet.info("this is dropped before any formatting happens")
assert len(console.lines) == 2                             # unchanged

print("\n".join(console.lines))
print(audit.lines[0])
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-14-logger-q1", "type": "mcq",
      "prompt": "Why does `log(...)` check `is_enabled(level)` before building the message string?",
      "options": [
        {"id":"a","text":"To keep the method shorter"},
        {"id":"b","text":"Because building the message is often the expensive part — `log.debug(f\"...{expensive()}\")` pays that cost even when DEBUG is disabled, so the level check must come first and formatting must be deferred (`%s` args, not an eager f-string)"},
        {"id":"c","text":"Because appenders cannot handle empty messages"},
        {"id":"d","text":"To make the logger thread-safe"}
      ],
      "correct": "b",
      "explanation": "A disabled log call should cost one integer comparison. Eager string interpolation at the call site defeats that, which is why logging APIs take a template plus arguments rather than a pre-built string." }
] }
```

## Concurrency, performance, and extensions

**Rate limiter:**

| Concern | Handling |
|---|---|
| Concurrent `try_acquire` for one key | Lock per key (or a striped lock array), not one global lock |
| Memory growth from idle keys | Evict via an LRU cache or a TTL — an unbounded per-key map is a slow memory leak |
| Distributed correctness | A Lua script in Redis makes refill-and-take atomic; local buckets with a global budget when latency matters more than exactness |
| Fail-open or fail-closed? | **Decide and state it.** If Redis is down, do you allow all traffic (available, unprotected) or deny it (protected, outage)? Usually fail-open for user traffic, fail-closed for expensive or dangerous endpoints |

That last row is the question interviewers use to separate candidates — the correct answer is not a value, it is "it depends on what this endpoint costs, and here's my default".

**Logger:**

| Concern | Handling |
|---|---|
| Contention on a shared sink | Per-appender lock (as implemented), or an async appender with a bounded queue |
| Slow sink (network) blocking the request | **Asynchronous appender**: enqueue and let a background thread drain it |
| The queue fills up | Drop the oldest, drop by level, or block — an explicit, configured policy, never an unbounded queue |
| Losing logs on crash | Flush on shutdown; accept a bounded loss window for async sinks and say what it is |
| Request-scoped context | A child logger, or a context-local — never a global mutable dictionary |

**Extensions for both:**

- New rate-limit algorithm → new `RateLimiter` class; the gateway is unchanged.
- Per-endpoint limits → a config map from route to limiter; the composite tries each and denies if any deny.
- New log destination (Kafka, S3, OpenTelemetry) → new `Appender`.
- Sampling ("log 1% of DEBUG in production") → a filter in the chain, before the appenders.
- Redaction of PII → a formatter decorator wrapping the real formatter.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-14-failmode-q1", "type": "mcq",
      "prompt": "Your distributed rate limiter's Redis backend becomes unreachable. What is the right design response?",
      "options": [
        {"id":"a","text":"Always deny requests — safety first"},
        {"id":"b","text":"It is a deliberate, per-endpoint policy: fail-open (allow, unprotected) for ordinary user traffic so an infrastructure blip doesn't take down the product, and fail-closed for expensive or dangerous endpoints — with a local in-process fallback limit either way"},
        {"id":"c","text":"Always allow requests — availability first"},
        {"id":"d","text":"Retry Redis until it responds"}
      ],
      "correct": "b",
      "explanation": "Both blanket answers are wrong in some context. The senior response names the trade-off, sets a default, and adds a degraded local limit so the failure mode is bounded rather than binary." }
] }
```

## Key takeaways

- **In a library problem, the interface is the design.** Spend a minute on the signature: return a rich result, inject the clock, allow weighted permits.
- **Rate limiter = Strategy over per-key state.** Fixed window is cheap with a boundary flaw; sliding log is exact and memory-hungry; **token bucket is the default** because it enforces an average rate while allowing a bounded burst.
- **Distributed limiting is the follow-up**, and "local buckets against a shared budget" is the production answer, with the fail-open/fail-closed decision stated explicitly.
- **Logger = Chain of Responsibility (levels) + Strategy (formatter, appender)**, plus the performance detail everyone else forgets: check the level *before* building the message.
- **Bounded queues and eviction everywhere.** An unbounded per-key map and an unbounded async log queue are the two memory leaks these designs invite.
