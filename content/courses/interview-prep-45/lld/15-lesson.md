---
kind: lesson
id_key: interview-prep-45/lld-15-notification-cache
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD: Notification Service and In-Memory Cache"
position: 15
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Two more library-shaped problems, chosen because between them they exercise almost every pattern in this section. The notification service is the canonical **Observer + Strategy + Chain** composition; the cache is the canonical "combine data structures to hit an operation-complexity target", and it is the single most-asked design question in coding interviews.

## Notification service — requirements and structure

**Functional requirements:**

- Send a notification to a user over one or more channels: email, SMS, push, in-app.
- Respect **user preferences**: which channels, and which categories they have opted out of.
- Templates with variable substitution, per channel.
- Retry transient failures; do not retry permanent ones.
- Rate limit per user so one runaway event cannot spam them.
- Priority: a security alert must not queue behind a marketing digest.

**The patterns, and what each one is for:**

| Pattern | Role here |
|---|---|
| **Strategy** | One class per channel behind a `NotificationChannel` interface |
| **Observer** | Domain events (`order.placed`) trigger notifications without the order code knowing they exist |
| **Chain of Responsibility** | The send pipeline: preferences → rate limit → quiet hours → dedupe → deliver |
| **Template Method / Strategy** | Rendering a message per channel (SMS is 160 characters; email has HTML) |
| **Factory** | Resolving a channel name to its implementation |
| **Decorator** | Wrapping a channel with retry and circuit-breaking, without touching the channel code |

**The key modelling decision**: a `Notification` is a **request** (recipient, category, template, data, priority), not a message. Rendering happens per channel, at send time, because the same request becomes a different artefact on SMS than in email. Candidates who put a `body: str` on the notification cannot express that.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-notif-model-q1", "type": "mcq",
      "prompt": "Why should a `Notification` carry a template id plus data rather than a rendered `body` string?",
      "options": [
        {"id":"a","text":"Strings use more memory than template ids"},
        {"id":"b","text":"The same logical notification renders differently per channel — 160-character SMS, HTML email, a short push title — so rendering must happen per channel at send time, and it also enables localisation and template changes without touching the caller"},
        {"id":"c","text":"Because templates are easier to store in a database"},
        {"id":"d","text":"Because rendered strings cannot be retried"}
      ],
      "correct": "b",
      "explanation": "Rendering is a channel concern. Baking a body into the request forces the caller to know about channel constraints and makes localisation and template edits a code change." }
] }
```

## Notification service — implementation

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum


class Channel(Enum):
    EMAIL = "email"
    SMS = "sms"
    PUSH = "push"


class Priority(Enum):
    LOW = 1
    NORMAL = 2
    URGENT = 3


@dataclass(frozen=True)
class Notification:
    user_id: str
    category: str                     # "security" | "marketing" | "transactional"
    template: str
    data: dict
    priority: Priority = Priority.NORMAL


@dataclass
class UserPreferences:
    channels: set[Channel]
    muted_categories: set[str] = field(default_factory=set)
    contact: dict[Channel, str] = field(default_factory=dict)


# ---- Strategy: one class per delivery channel -------------------------------
class NotificationChannel(ABC):
    @abstractmethod
    def render(self, n: Notification) -> str: ...
    @abstractmethod
    def deliver(self, to: str, body: str) -> None: ...


class EmailChannel(NotificationChannel):
    def __init__(self): self.sent: list[tuple[str, str]] = []
    def render(self, n): return f"<html>{n.template}: {n.data}</html>"
    def deliver(self, to, body): self.sent.append((to, body))


class SmsChannel(NotificationChannel):
    LIMIT = 160
    def __init__(self, fail_times: int = 0):
        self.sent: list[tuple[str, str]] = []
        self._fail_times = fail_times
    def render(self, n):
        return f"{n.template}: {n.data.get('order_id', '')}"[: self.LIMIT]
    def deliver(self, to, body):
        if self._fail_times > 0:                  # simulate a transient outage
            self._fail_times -= 1
            raise ConnectionError("sms gateway timeout")
        self.sent.append((to, body))


# ---- Decorator: retry without touching any channel implementation -----------
class RetryingChannel(NotificationChannel):
    def __init__(self, inner: NotificationChannel, attempts: int = 3):
        self._inner, self._attempts = inner, attempts
        self.failures = 0
    def render(self, n): return self._inner.render(n)
    def deliver(self, to, body):
        last: Exception | None = None
        for _ in range(self._attempts):
            try:
                return self._inner.deliver(to, body)
            except ConnectionError as exc:        # transient → retry
                self.failures += 1
                last = exc
            except ValueError:                    # permanent (bad address) → give up
                raise
        raise last                                # exhausted → caller sends it to a DLQ


# ---- Chain of Responsibility: the send pipeline -----------------------------
class Filter(ABC):
    def __init__(self): self._next: "Filter | None" = None
    def then(self, nxt: "Filter") -> "Filter":
        self._next = nxt
        return nxt
    def handle(self, n: Notification, prefs: UserPreferences) -> str | None:
        blocked = self.check(n, prefs)
        if blocked is not None:
            return blocked                        # stop: the notification is dropped
        return self._next.handle(n, prefs) if self._next else None
    @abstractmethod
    def check(self, n: Notification, prefs: UserPreferences) -> str | None: ...


class MutedCategoryFilter(Filter):
    def check(self, n, prefs):
        if n.category in prefs.muted_categories and n.priority is not Priority.URGENT:
            return f"muted category {n.category}"     # urgent bypasses mute — a real rule
        return None


class PerUserRateLimitFilter(Filter):
    def __init__(self, limit: int):
        super().__init__()
        self.limit, self._counts = limit, {}
    def check(self, n, prefs):
        if n.priority is Priority.URGENT:
            return None                                # never rate limit security alerts
        self._counts[n.user_id] = self._counts.get(n.user_id, 0) + 1
        if self._counts[n.user_id] > self.limit:
            return "rate limited"
        return None


class DedupeFilter(Filter):
    def __init__(self):
        super().__init__()
        self._seen: set[tuple] = set()
    def check(self, n, prefs):
        key = (n.user_id, n.template, tuple(sorted(n.data.items())))
        if key in self._seen:
            return "duplicate"
        self._seen.add(key)
        return None


class NotificationService:
    def __init__(self, channels: dict[Channel, NotificationChannel], pipeline: Filter):
        self._channels, self._pipeline = channels, pipeline
        self.dead_letter: list[tuple[Notification, Channel, str]] = []

    def send(self, n: Notification, prefs: UserPreferences) -> list[str]:
        blocked = self._pipeline.handle(n, prefs)
        if blocked is not None:
            return [f"dropped: {blocked}"]
        results = []
        for channel in prefs.channels:
            impl = self._channels.get(channel)
            if impl is None:
                continue
            try:
                impl.deliver(prefs.contact[channel], impl.render(n))
                results.append(f"{channel.value}: sent")
            except Exception as exc:                  # one channel failing must not stop others
                self.dead_letter.append((n, channel, str(exc)))
                results.append(f"{channel.value}: failed")
        return results


email = EmailChannel()
sms_inner = SmsChannel(fail_times=2)                  # fails twice, then succeeds
sms = RetryingChannel(sms_inner, attempts=3)

pipeline = DedupeFilter()
pipeline.then(MutedCategoryFilter()).then(PerUserRateLimitFilter(limit=2))
service = NotificationService({Channel.EMAIL: email, Channel.SMS: sms}, pipeline)

prefs = UserPreferences(
    channels={Channel.EMAIL, Channel.SMS},
    muted_categories={"marketing"},
    contact={Channel.EMAIL: "asha@example.com", Channel.SMS: "+91999"},
)

order = Notification("u1", "transactional", "order_shipped", {"order_id": "ord_1"})
assert sorted(service.send(order, prefs)) == ["email: sent", "sms: sent"]
assert sms.failures == 2                       # two transient failures, then success
assert service.dead_letter == []

assert service.send(order, prefs) == ["dropped: duplicate"]  # same payload → deduped

promo = Notification("u1", "marketing", "sale", {"pct": 20})
assert service.send(promo, prefs) == ["dropped: muted category marketing"]

alert = Notification("u1", "marketing", "breach", {"ip": "1.2.3.4"}, Priority.URGENT)
assert "email: sent" in service.send(alert, prefs)           # urgent bypasses the mute

print("email outbox:", len(email.sent), "| sms outbox:", len(sms_inner.sent))
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-notif-impl-q1", "type": "mcq",
      "prompt": "Retry logic lives in `RetryingChannel`, which wraps a channel rather than being built into each one. What does that buy?",
      "options": [
        {"id":"a","text":"It makes retries faster"},
        {"id":"b","text":"Retry becomes an orthogonal, composable concern: every channel gets it without duplicating code, it can be configured per channel, and a circuit breaker or metrics wrapper stacks on the same way — the Decorator pattern applied to cross-cutting behaviour"},
        {"id":"c","text":"It prevents permanent failures from occurring"},
        {"id":"d","text":"It removes the need for a dead-letter queue"}
      ],
      "correct": "b",
      "explanation": "Retry, circuit breaking, metrics, and logging are all cross-cutting. Implementing them in each channel duplicates code and drifts; wrapping keeps each channel focused on its protocol." }
] }
```

## In-memory cache — the LRU design

**Requirements**: `get` and `put` in **O(1)**, a fixed capacity, evict the least recently used entry when full, optional TTL per entry, and a pluggable eviction policy.

**The reasoning to say out loud, because it is the whole answer**: a hash map gives O(1) lookup but no ordering; a linked list gives O(1) reordering but O(n) lookup. Combine them — **hash map from key to node, doubly linked list for recency** — and both operations are O(1). Sentinel head and tail nodes remove every null check at the boundaries.

```python
class Node:
    __slots__ = ("key", "value", "expires_at", "prev", "next")

    def __init__(self, key=None, value=None, expires_at=None):
        self.key, self.value, self.expires_at = key, value, expires_at
        self.prev = self.next = None


class LRUCache:
    """O(1) get and put. Hash map for lookup, doubly linked list for recency order."""

    def __init__(self, capacity: int):
        if capacity <= 0:
            raise ValueError("capacity must be positive")
        self.capacity = capacity
        self._map: dict[object, Node] = {}
        self._head = Node()          # sentinel: most-recently-used side
        self._tail = Node()          # sentinel: least-recently-used side
        self._head.next, self._tail.prev = self._tail, self._head
        self.hits = self.misses = self.evictions = 0

    # ---- list surgery ---------------------------------------------------
    def _unlink(self, node: Node) -> None:
        node.prev.next, node.next.prev = node.next, node.prev

    def _push_front(self, node: Node) -> None:
        node.next, node.prev = self._head.next, self._head
        self._head.next.prev = node
        self._head.next = node

    # ---- public API -----------------------------------------------------
    def get(self, key, now: float = 0.0):
        node = self._map.get(key)
        if node is None:
            self.misses += 1
            return None
        if node.expires_at is not None and node.expires_at <= now:
            self._evict(node)                 # lazy expiry: cheaper than a sweeper
            self.misses += 1
            return None
        self._unlink(node)
        self._push_front(node)                # touching it makes it most recent
        self.hits += 1
        return node.value

    def put(self, key, value, now: float = 0.0, ttl: float | None = None) -> None:
        expires_at = None if ttl is None else now + ttl
        node = self._map.get(key)
        if node is not None:
            node.value, node.expires_at = value, expires_at
            self._unlink(node)
            self._push_front(node)
            return
        node = Node(key, value, expires_at)
        self._map[key] = node
        self._push_front(node)
        if len(self._map) > self.capacity:
            self._evict(self._tail.prev)      # the node just before the tail sentinel
            self.evictions += 1

    def _evict(self, node: Node) -> None:
        self._unlink(node)
        del self._map[node.key]

    def keys_mru_first(self) -> list:
        out, node = [], self._head.next
        while node is not self._tail:
            out.append(node.key)
            node = node.next
        return out

    def __len__(self) -> int: return len(self._map)


cache = LRUCache(capacity=3)
cache.put("a", 1); cache.put("b", 2); cache.put("c", 3)
assert cache.keys_mru_first() == ["c", "b", "a"]

assert cache.get("a") == 1                     # 'a' becomes most recently used
assert cache.keys_mru_first() == ["a", "c", "b"]

cache.put("d", 4)                              # capacity exceeded → evict LRU, which is 'b'
assert cache.get("b") is None and cache.evictions == 1
assert sorted(cache.keys_mru_first()) == ["a", "c", "d"]

cache.put("e", 5, now=0, ttl=10)               # TTL entry
assert cache.get("e", now=5) == 5
assert cache.get("e", now=11) is None          # expired lazily on read
assert cache.hits == 2 and cache.misses == 2

print("keys (MRU first):", cache.keys_mru_first(),
      "| hits/misses/evictions:", cache.hits, cache.misses, cache.evictions)
```

**The follow-ups you will get, with their answers:**

| Follow-up | Answer |
|---|---|
| "Make it thread-safe" | A single lock around `get`/`put` (both mutate the list). For higher throughput, a striped/segmented cache — N independent shards keyed by `hash(key) % N`, each with its own lock |
| "Make the eviction policy pluggable" | An `EvictionPolicy` interface — LRU, LFU, FIFO, random — that owns the ordering structure. LFU needs a frequency map plus a min-frequency pointer to stay O(1) |
| "What about a scan flushing the hot set?" | LFU, or a segmented LRU (a probation segment and a protected segment), or W-TinyLFU as used by Caffeine |
| "Why not `OrderedDict`?" | It works (`move_to_end` + `popitem(last=False)`), but interviewers want the mechanism; know both and say why |
| "Evict by memory, not entry count" | Track an approximate size per entry and evict until under the budget |
| "Distributed cache" | This is now the HLD caching lesson: consistent hashing across nodes, cache-aside, TTL jitter, stampede protection |

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-cache-q1", "type": "mcq",
      "prompt": "Why does an O(1) LRU cache need both a hash map and a doubly linked list?",
      "options": [
        {"id":"a","text":"The list stores the values and the map stores the keys"},
        {"id":"b","text":"The map gives O(1) key lookup but no ordering; the doubly linked list gives O(1) removal and re-insertion (so recency updates are constant time) but O(n) search — each supplies exactly what the other lacks"},
        {"id":"c","text":"The list is only needed for iteration"},
        {"id":"d","text":"A singly linked list would work equally well"}
      ],
      "correct": "b",
      "explanation": "The map holds key → node so you can find the node instantly, and the doubly linked structure lets you unlink that node in O(1) — which a singly linked list cannot do, since it has no back-pointer to the predecessor." }
] }
```

## Concurrency and extensions

**Notification service:**

| Concern | Handling |
|---|---|
| One slow channel blocking the others | Deliver per channel independently — asynchronously, or at least catching per channel as implemented |
| Duplicate sends after a retry | Deliveries must be idempotent: a `(notification_id, channel)` dedupe key, exactly as in the HLD messaging lesson |
| Priority | Separate queues per priority, drained by weight — never one FIFO where a security alert queues behind a digest |
| Permanent failures | Dead-letter with the error and attempt count, plus an alert on DLQ depth |
| A channel provider outage | A circuit breaker decorator around the channel, so you stop hammering it and fall back to another channel |

**Cache:**

| Concern | Handling |
|---|---|
| Concurrent `get` mutating the recency list | `get` is a *writer* in an LRU — a plain read-write lock is not enough; use a full lock, or approximate recency (Caffeine records accesses in a buffer and reorders in batches) |
| Lock contention at high throughput | Shard the cache; each shard is an independent `LRUCache` with its own lock |
| Expiry | Lazy on read (implemented) plus an optional background sweeper for memory reclamation |
| Cache stampede on a hot key | Single-flight: the first miss populates while others wait — the HLD caching lesson's fix, applied here |

The detail worth volunteering on the cache: **`get` mutates state**, so a naive "reads can share a lock, writes need it exclusively" answer is wrong for LRU. That observation is a strong signal.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-concurrency-q1", "type": "mcq",
      "prompt": "Why is a read-write lock (many concurrent readers, one writer) insufficient for a standard LRU cache?",
      "options": [
        {"id":"a","text":"Read-write locks are slower than mutexes"},
        {"id":"b","text":"Because `get` is not a read — it moves the accessed node to the front of the recency list, so concurrent \"readers\" would corrupt the list; the options are a full mutex, sharding, or recording accesses in a buffer and reordering in batches"},
        {"id":"c","text":"Because the hash map is not thread-safe"},
        {"id":"d","text":"Because TTL expiry requires a background thread"}
      ],
      "correct": "b",
      "explanation": "Recency tracking makes every read a mutation. Real high-throughput caches (Caffeine) solve it by buffering access records and applying them asynchronously, which restores true read parallelism at the cost of slightly approximate ordering." }
] }
```

## Key takeaways

- **The notification service is the pattern-composition showcase**: Strategy per channel, Chain for the filter pipeline, Decorator for retry and circuit breaking, Observer to trigger it from domain events, Factory to resolve a channel. Naming each with its role is the whole answer.
- **A notification is a request, not a message.** Render per channel at send time.
- **Cross-cutting behaviour goes in wrappers**, not in every implementation — that one decision makes retry, metrics, and circuit breaking free for every future channel.
- **LRU = hash map + doubly linked list + sentinels.** Be able to write it from memory; it is asked more often than any other design question.
- **`get` mutates an LRU**, so the concurrency answer is a full lock or sharding, never a read-write lock. Saying that unprompted is the strongest single sentence in the cache problem.
