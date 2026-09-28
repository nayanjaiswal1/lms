---
kind: lesson
id_key: interview-prep-45/lld-15-notification-cache
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Design a Notification Service and an In-Memory Cache"
position: 15
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

Two more library-shaped problems, picked because between the two of them they touch nearly every pattern in this section. The notification service is the classic example of Observer, Strategy, and Chain of Responsibility working together. The cache is the classic "combine two data structures to hit an exact complexity target" problem, and it's the single most-asked design question in coding interviews, full stop.

## Notification service — requirements and structure

**What it needs to do:**

- Send a notification to a user over one or more channels: email, SMS, push, in-app.
- Respect **the user's own preferences**: which channels they want, and which categories they've muted.
- Templates, with variables filled in, that render differently per channel.
- Retry failures that are likely temporary; never retry ones that clearly aren't.
- Rate limit per user, so one runaway event can't flood someone's inbox.
- Priority: a security alert should never sit in a queue behind a marketing email.

**The patterns, and exactly what each one is doing here:**

| Pattern | Its job in this design |
|---|---|
| **Strategy** | One class per delivery channel, all behind a `NotificationChannel` interface |
| **Observer** | Domain events like `order.placed` trigger notifications, with the order code never knowing they exist |
| **Chain of Responsibility** | The send pipeline: preferences, then rate limiting, then quiet hours, then dedupe, then actual delivery |
| **Template Method / Strategy** | Rendering the message per channel (SMS gets 160 characters; email gets full HTML) |
| **Factory** | Turning a channel name into the right implementation |
| **Decorator** | Wrapping a channel with retry logic and circuit-breaking, without touching the channel's own code |

**The key modelling decision here**: a `Notification` is a **request** — recipient, category, template, data, priority — not a finished message. Rendering only happens per channel, at the moment of sending, because the exact same request turns into a completely different piece of text on SMS versus in an email. If you put a plain `body: str` directly on the notification, you can't express that at all.

> **Remember:** a Notification is a request, not a rendered message. Rendering happens per channel, at send time — never before.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-notif-model-q1", "type": "mcq",
      "prompt": "Why should a `Notification` carry a template id plus data, rather than a rendered `body` string?",
      "options": [
        {"id":"a","text":"Strings use more memory than template ids"},
        {"id":"b","text":"The same logical notification renders differently per channel — a 160-character SMS, an HTML email, a short push title — so rendering has to happen per channel at send time, and this same choice makes localisation and template edits possible without touching the caller"},
        {"id":"c","text":"Because templates are easier to store in a database"},
        {"id":"d","text":"Because rendered strings can't be retried"}
      ],
      "correct": "b",
      "explanation": "Rendering is a channel-specific concern. Baking a fixed body directly into the request forces the caller to already know about every channel's constraints, and makes both localisation and template edits into code changes." }
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
        if self._fail_times > 0:                  # simulating a temporary outage
            self._fail_times -= 1
            raise ConnectionError("sms gateway timeout")
        self.sent.append((to, body))


# ---- Decorator: retry logic without touching the channel itself -------------
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
            except ConnectionError as exc:        # likely temporary → retry it
                self.failures += 1
                last = exc
            except ValueError:                    # permanent — a bad address — give up
                raise
        raise last                                # out of attempts → send to a dead-letter queue


# ---- Chain of Responsibility: the send pipeline -----------------------------
class Filter(ABC):
    def __init__(self): self._next: "Filter | None" = None
    def then(self, nxt: "Filter") -> "Filter":
        self._next = nxt
        return nxt
    def handle(self, n: Notification, prefs: UserPreferences) -> str | None:
        blocked = self.check(n, prefs)
        if blocked is not None:
            return blocked                        # stop here: the notification gets dropped
        return self._next.handle(n, prefs) if self._next else None
    @abstractmethod
    def check(self, n: Notification, prefs: UserPreferences) -> str | None: ...


class MutedCategoryFilter(Filter):
    def check(self, n, prefs):
        if n.category in prefs.muted_categories and n.priority is not Priority.URGENT:
            return f"muted category {n.category}"     # urgent alerts bypass mute — a real rule
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
            except Exception as exc:                  # one failing channel can't sink the rest
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
assert sms.failures == 2                       # two temporary failures, then success
assert service.dead_letter == []

assert service.send(order, prefs) == ["dropped: duplicate"]  # the same payload gets deduped

promo = Notification("u1", "marketing", "sale", {"pct": 20})
assert service.send(promo, prefs) == ["dropped: muted category marketing"]

alert = Notification("u1", "marketing", "breach", {"ip": "1.2.3.4"}, Priority.URGENT)
assert "email: sent" in service.send(alert, prefs)           # urgent bypasses the mute

print("email outbox:", len(email.sent), "| sms outbox:", len(sms_inner.sent))
```

> **Remember:** cross-cutting behaviour like retry belongs in a wrapper, never copy-pasted into every channel. That single decision makes retry, metrics, and circuit-breaking free for every channel you add later.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-notif-impl-q1", "type": "mcq",
      "prompt": "Retry logic lives in `RetryingChannel`, wrapping a channel, rather than being built into each channel separately. What does that actually buy you?",
      "options": [
        {"id":"a","text":"It makes retries happen faster"},
        {"id":"b","text":"Retry becomes an independent, reusable concern: every channel gets it with no duplicated code, it can be configured per channel, and a circuit breaker or a metrics wrapper can stack the exact same way — this is Decorator applied to cross-cutting behaviour"},
        {"id":"c","text":"It stops permanent failures from happening in the first place"},
        {"id":"d","text":"It removes the need for a dead-letter queue"}
      ],
      "correct": "b",
      "explanation": "Retry, circuit breaking, metrics, and logging are all cross-cutting concerns. Building them into every channel duplicates code and drifts out of sync over time; wrapping keeps every channel focused purely on its own protocol." }
] }
```

## How a hash map actually works underneath

Before building a cache, it's worth seeing what a hash map does under the hood — this is also a common coding-round question on its own, sometimes phrased as "implement a hash map without using your language's built-in one."

**The idea**: pick a fixed number of "buckets." To store a key, hash it down to a bucket index, then just append the (key, value) pair to whatever's already in that bucket's list. Two different keys landing in the same bucket is called a **collision**, and it's handled by simply keeping a short list per bucket — this is called **chaining**.

```python
class MyHashMap:
    def __init__(self, bucket_count: int = 1000):
        self.bucket_count = bucket_count
        self.buckets: list[list[tuple[int, int]]] = [[] for _ in range(bucket_count)]

    def _hash(self, key: int) -> int:
        return key % self.bucket_count

    def put(self, key: int, value: int) -> None:
        bucket = self.buckets[self._hash(key)]
        for i, (k, v) in enumerate(bucket):
            if k == key:
                bucket[i] = (key, value)      # an existing key: overwrite, don't duplicate
                return
        bucket.append((key, value))

    def get(self, key: int) -> int:
        bucket = self.buckets[self._hash(key)]
        for k, v in bucket:
            if k == key:
                return v
        return -1

    def remove(self, key: int) -> None:
        bucket = self.buckets[self._hash(key)]
        for i, (k, v) in enumerate(bucket):
            if k == key:
                bucket.pop(i)
                return


m = MyHashMap(bucket_count=4)
m.put(1, 100)
m.put(5, 500)                      # 1 % 4 == 1 and 5 % 4 == 1 — a deliberate collision
assert m.get(1) == 100 and m.get(5) == 500     # chaining keeps both, side by side
m.put(1, 999)                      # overwrites, doesn't create a second entry for key 1
assert m.get(1) == 999 and len(m.buckets[1]) == 2
m.remove(5)
assert m.get(5) == -1
print("bucket 1 holds:", m.buckets[1])
```

**Time complexity: average O(1) per operation, as long as chains stay short.** That "as long as" is the entire catch. With a fixed bucket count and a growing number of keys, chains get longer and longer, and performance quietly degrades toward O(n): one giant bucket with everything crammed inside it. A real hash map fixes this by tracking its **load factor** (roughly: keys stored, divided by bucket count) and **resizing**, doubling the bucket count and re-hashing everything, once that load factor crosses a threshold, typically around 0.75.

**The two mistakes worth watching for**: forgetting that `put` on a key that already exists should overwrite it, not silently add a duplicate entry to the bucket, and picking a bucket count so small that chains turn long and every operation quietly becomes O(n) in practice.

> **Remember:** a hash map is just an array of buckets, each holding a small list. Its O(1) average case relies entirely on keeping those chains short through resizing.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-hashmap-q1", "type": "mcq",
      "prompt": "Why does a hand-rolled hash map with a fixed bucket count eventually slow down as more keys get added?",
      "options": [
        {"id":"a","text":"Because Python dictionaries are always faster"},
        {"id":"b","text":"Every extra key increases the average chain length inside each bucket, since the bucket count never grows — that pushes lookups from O(1) toward O(n), which is exactly why real hash maps resize once their load factor crosses a threshold"},
        {"id":"c","text":"Because hashing itself gets slower for larger numbers"},
        {"id":"d","text":"Because Python lists can't hold tuples"}
      ],
      "correct": "b",
      "explanation": "A fixed number of buckets with a growing number of keys means longer and longer chains inside each bucket — a bucket with a long chain degrades toward a plain linear scan. Resizing (doubling the bucket count and re-hashing everything) is what keeps the average case at O(1)." }
] }
```

## In-memory cache — the LRU design

**Requirements**: `get` and `put` both in **O(1)**, a fixed capacity, evict the least-recently-used entry once it's full, an optional TTL per entry, and a pluggable eviction policy.

**Here's the reasoning worth saying out loud, because it really is the whole answer**: a plain hash map gives you O(1) lookup, but no sense of ordering at all. A plain linked list gives you O(1) reordering, but O(n) lookup. Combine the two — **a hash map from key to node, and a doubly linked list to track recency** — and both operations land at O(1). Sentinel head and tail nodes get rid of every null check at the edges of the list.

```python
class Node:
    __slots__ = ("key", "value", "expires_at", "prev", "next")

    def __init__(self, key=None, value=None, expires_at=None):
        self.key, self.value, self.expires_at = key, value, expires_at
        self.prev = self.next = None


class LRUCache:
    """O(1) get and put. A hash map for lookup, a doubly linked list for recency order."""

    def __init__(self, capacity: int):
        if capacity <= 0:
            raise ValueError("capacity must be positive")
        self.capacity = capacity
        self._map: dict[object, Node] = {}
        self._head = Node()          # sentinel: the most-recently-used side
        self._tail = Node()          # sentinel: the least-recently-used side
        self._head.next, self._tail.prev = self._tail, self._head
        self.hits = self.misses = self.evictions = 0

    # ---- moving nodes around ----------------------------------------------
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
            self._evict(node)                 # expire it lazily — cheaper than a sweeper thread
            self.misses += 1
            return None
        self._unlink(node)
        self._push_front(node)                # touching an entry makes it the most recent
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

assert cache.get("a") == 1                     # touching 'a' makes it the most recently used
assert cache.keys_mru_first() == ["a", "c", "b"]

cache.put("d", 4)                              # over capacity → evict the LRU entry, which is 'b'
assert cache.get("b") is None and cache.evictions == 1
assert sorted(cache.keys_mru_first()) == ["a", "c", "d"]

cache.put("e", 5, now=0, ttl=10)               # an entry with a TTL
assert cache.get("e", now=5) == 5
assert cache.get("e", now=11) is None          # expired lazily, right when it was read
assert cache.hits == 2 and cache.misses == 2

print("keys (MRU first):", cache.keys_mru_first(),
      "| hits/misses/evictions:", cache.hits, cache.misses, cache.evictions)
```

**The follow-up questions you'll get, along with their answers:**

| Follow-up | Answer |
|---|---|
| "Make it thread-safe" | One lock around `get` and `put` (both of them mutate the list). For higher throughput, a sharded cache — N independent chunks, each keyed by `hash(key) % N`, each with its own lock |
| "Make the eviction policy pluggable" | An `EvictionPolicy` interface — LRU, LFU, FIFO, random — that owns the ordering structure. LFU needs a frequency count plus a pointer to the current minimum frequency to stay O(1) |
| "What about a big scan flushing out the hot data?" | LFU, or a segmented LRU (a probation area and a protected area), or an algorithm like W-TinyLFU, which is what the real Caffeine cache library uses |
| "Why not just use `OrderedDict`?" | It genuinely works, using `move_to_end` and `popitem(last=False)`, but interviewers want to see the underlying mechanism — know both, and be ready to say why |
| "Evict by memory used, not entry count" | Track an approximate size per entry, and evict until you're back under budget |
| "What about a distributed cache?" | That's really the HLD caching lesson at this point: consistent hashing across nodes, cache-aside, jittered TTLs, stampede protection |

> **Remember:** a hash map gives O(1) lookup with no ordering. A doubly linked list gives O(1) reordering with no lookup. LRU exists because combining them fills in exactly what the other one is missing.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-cache-q1", "type": "mcq",
      "prompt": "Why does an O(1) LRU cache need both a hash map and a doubly linked list?",
      "options": [
        {"id":"a","text":"The list stores the values and the map stores the keys"},
        {"id":"b","text":"The map gives O(1) key lookup but no sense of ordering; the doubly linked list gives O(1) removal and re-insertion — so updating recency is constant time — but only O(n) search on its own. Each one supplies exactly what the other is missing"},
        {"id":"c","text":"The list is only there for iteration"},
        {"id":"d","text":"A singly linked list would work exactly as well"}
      ],
      "correct": "b",
      "explanation": "The map holds key to node, so you can find any node instantly. The doubly linked structure lets you unlink that node in O(1) — something a singly linked list can't do, since it has no way to reach back to the node before it." }
] }
```

## Concurrency and extensions

**Notification service:**

| Concern | How it's handled |
|---|---|
| One slow channel blocking all the others | Deliver to each channel independently — ideally asynchronously, or at minimum catching failures per channel, as built above |
| Duplicate sends after a retry | Deliveries have to be idempotent: a `(notification_id, channel)` dedupe key, exactly like in the messaging lesson in HLD |
| Priority | Separate queues per priority level, drained by weight — never a single FIFO queue where a security alert sits behind a marketing digest |
| Permanent failures | Send to a dead-letter queue with the error and the attempt count, plus an alert if that queue's depth grows too large |
| A whole channel provider going down | A circuit-breaker decorator wrapping the channel, so you stop hammering a dead provider and can fall back to a different channel instead |

**Cache:**

| Concern | How it's handled |
|---|---|
| A concurrent `get` mutating the recency list | `get` is really a *writer* in an LRU cache — a plain read-write lock isn't enough here; use a full lock, or approximate recency the way Caffeine does, by recording accesses in a buffer and reordering in batches |
| Lock contention under heavy load | Shard the cache — each shard is its own independent `LRUCache` with its own lock |
| Expiry | Lazy, checked on read (as built above), plus an optional background sweeper purely to reclaim memory sooner |
| A stampede on one very hot key | Single-flight: the very first miss populates the cache while everyone else waits — the exact fix from the HLD caching lesson, applied here |

The detail worth volunteering about the cache: **`get` mutates state**, so the instinctive answer "reads can share a lock, only writes need an exclusive one" is actually wrong for LRU specifically. Saying this unprompted is a strong signal.

> **Remember:** `get` mutates the recency list in an LRU cache, so it's really a writer. A read-write lock alone isn't enough — you need a full lock, or approximate recency in batches.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-15-concurrency-q1", "type": "mcq",
      "prompt": "Why isn't a read-write lock (many readers, one writer) enough for a standard LRU cache?",
      "options": [
        {"id":"a","text":"Read-write locks are slower than plain mutexes"},
        {"id":"b","text":"`get` isn't actually a read — it moves the accessed node to the front of the recency list, so concurrent \"readers\" would corrupt that list. The real options are a full mutex, sharding, or recording accesses in a buffer and reordering them in batches"},
        {"id":"c","text":"Because the hash map itself isn't thread-safe"},
        {"id":"d","text":"Because TTL expiry always requires a background thread"}
      ],
      "correct": "b",
      "explanation": "Tracking recency turns every single read into a mutation. Real high-throughput caches like Caffeine solve this by buffering access records and applying them asynchronously, which restores true parallel reads at the cost of slightly approximate ordering." }
] }
```

## Quick recap

- **The notification service is a showcase of patterns working together**: Strategy per channel, Chain for the filter pipeline, Decorator for retry and circuit-breaking, Observer to trigger it from domain events, Factory to resolve a channel by name. Naming each one alongside its exact role is the whole answer.
- **A notification is a request, not a message.** Rendering happens per channel, at send time.
- **Cross-cutting behaviour goes in a wrapper**, never copy-pasted into every implementation — that one decision makes retry, metrics, and circuit-breaking free for every channel you add later.
- **A hash map is buckets plus chaining, with resizing to keep chains short** — worth knowing on its own, and it's exactly the first half of what makes LRU work.
- **LRU = a hash map plus a doubly linked list plus sentinels.** Be able to write it from memory — it's asked more often than any other design problem out there.
- **`get` mutates an LRU cache**, so the right concurrency answer is a full lock or sharding, never a read-write lock. Saying that unprompted is the single strongest sentence you can offer in this problem.
