---
kind: lesson
id_key: interview-prep-45/lld-04-creational-patterns
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Creational Patterns"
position: 4
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Every creational pattern answers the same question: **who decides which concrete class gets built, and how?** They all exist for one reason — to stop `new ConcreteThing()` from being scattered through code that has no business knowing `ConcreteThing` even exists.

Learn each one as a **problem → pattern → cost** triple. Interviewers ask "when would you reach for this?" far more often than "implement this from scratch," and the trap answer is using a pattern where a plain constructor would have done the job just fine.

## Singleton — exactly one instance

**The problem**: something expensive or genuinely one-of-a-kind — a connection pool, a config store, a logger — needs to exist exactly once, shared by everyone.

```python
import threading

class ConfigRegistry:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:                 # fast path, no lock needed most of the time
            with cls._lock:                       # double-checked locking
                if cls._instance is None:         # check again, now that we hold the lock
                    obj = super().__new__(cls)
                    obj._values = {}
                    cls._instance = obj
        return cls._instance

    def set(self, key: str, value: str) -> None: self._values[key] = value
    def get(self, key: str) -> str | None: return self._values.get(key)


a, b = ConfigRegistry(), ConfigRegistry()
assert a is b                       # truly the same object
a.set("region", "ap-south-1")
assert b.get("region") == "ap-south-1"
print("singleton shared state:", b.get("region"))
```

That double-checked lock isn't decoration — interviewers ask about it directly. Without it, two threads can both pass the first `is None` check before either one finishes building the object, and you end up with two "singletons." Locking on *every* access instead would work, but you'd pay that cost forever, on every single call. Check, lock, check again solves both problems at once.

**In Python**, a module is already a singleton by nature — import it twice and you get the same object both times — so a plain module-level variable is usually the natural answer. **In Java**, the safest version is an enum-based singleton (it resists both serialization tricks and reflection) or a static holder class.

**Here's the cost, and you should mention it before anyone asks, because "when would you *not* use this?" is always the follow-up:**

- It's **shared mutable state**: any code, anywhere, can change it, so bugs in it have no clear owner.
- It **hides what a class actually depends on**: a class quietly calling `ConfigRegistry()` internally looks dependency-free from the outside, but isn't.
- It makes **testing painful**: state can leak between tests, and there's no way to swap in a fake.
- It **fights concurrency**: shared mutable state needs protecting everywhere it's touched.

The modern answer: build one instance where your program starts up, and **inject** it into whatever needs it. You keep "exactly one," without the global door that let anything reach in and change it — which was always the harmful half of this pattern anyway.

> **Remember:** the useful part of Singleton is "exactly one instance." The harmful part is "reachable from anywhere." Keep the first, inject instead of relying on the second.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-04-singleton-q1", "type": "mcq",
      "prompt": "Why does a thread-safe Singleton use double-checked locking instead of just locking on every access?",
      "options": [
        {"id":"a","text":"To make the object immutable"},
        {"id":"b","text":"So the lock only ever gets taken during the first, racing construction — the outer check skips locking on every later access, and the inner re-check stops two threads that both passed the outer check from building two instances"},
        {"id":"c","text":"To allow multiple instances when needed"},
        {"id":"d","text":"Because constructors can't be synchronised"}
      ],
      "correct": "b",
      "explanation": "A single check races. Locking on every access works but costs you forever on a path that's read constantly. Check, lock, check again gets correctness while only paying the synchronisation cost once." }
] }
```

## Factory Method and Abstract Factory

**Factory Method — the problem**: callers shouldn't need to know or name concrete classes, and adding a new type shouldn't mean editing them.

```python
from abc import ABC, abstractmethod

class Notifier(ABC):
    @abstractmethod
    def send(self, to: str, msg: str) -> str: ...

class EmailNotifier(Notifier):
    def send(self, to: str, msg: str) -> str: return f"email->{to}:{msg}"

class SmsNotifier(Notifier):
    def send(self, to: str, msg: str) -> str: return f"sms->{to}:{msg}"

class PushNotifier(Notifier):
    def send(self, to: str, msg: str) -> str: return f"push->{to}:{msg}"

class NotifierFactory:
    """A registry: a new channel just registers itself, nothing here has to change."""
    _registry: dict[str, type[Notifier]] = {}

    @classmethod
    def register(cls, key: str, impl: type[Notifier]) -> None:
        cls._registry[key] = impl

    @classmethod
    def create(cls, key: str) -> Notifier:
        try:
            return cls._registry[key]()
        except KeyError:
            raise ValueError(f"unknown channel: {key}") from None


for key, impl in (("email", EmailNotifier), ("sms", SmsNotifier), ("push", PushNotifier)):
    NotifierFactory.register(key, impl)

assert NotifierFactory.create("sms").send("+91999", "hi") == "sms->+91999:hi"
try:
    NotifierFactory.create("carrier-pigeon")
    raise AssertionError("expected failure")
except ValueError as e:
    print("factory rejected:", e)
```

This registry version is worth knowing because it's actually **open/closed**: a plain `if kind == "email"` factory still needs editing for every new channel. This one doesn't — a new channel just registers itself.

**Abstract Factory — the problem**: you need whole *families* of related objects that must always be used together, where mixing pieces from different families would be a genuine bug.

```python
from abc import ABC, abstractmethod

class Button(ABC):
    @abstractmethod
    def render(self) -> str: ...

class Checkbox(ABC):
    @abstractmethod
    def render(self) -> str: ...

class DarkButton(Button):
    def render(self) -> str: return "[dark button]"

class DarkCheckbox(Checkbox):
    def render(self) -> str: return "[dark checkbox]"

class LightButton(Button):
    def render(self) -> str: return "[light button]"

class LightCheckbox(Checkbox):
    def render(self) -> str: return "[light checkbox]"

class ThemeFactory(ABC):                    # the abstract factory
    @abstractmethod
    def button(self) -> Button: ...
    @abstractmethod
    def checkbox(self) -> Checkbox: ...

class DarkTheme(ThemeFactory):
    def button(self) -> Button: return DarkButton()
    def checkbox(self) -> Checkbox: return DarkCheckbox()

class LightTheme(ThemeFactory):
    def button(self) -> Button: return LightButton()
    def checkbox(self) -> Checkbox: return LightCheckbox()

def render_form(theme: ThemeFactory) -> str:
    # There's no way to accidentally end up with a dark button next to a light checkbox.
    return theme.button().render() + theme.checkbox().render()


assert render_form(DarkTheme()) == "[dark button][dark checkbox]"
print(render_form(LightTheme()))
```

Here's the one-line difference to remember: **Factory Method builds one product, varying by subclass or a key. Abstract Factory builds a whole matching family at once, and guarantees the pieces actually go together.**

> **Remember:** if mixing two "compatible" objects from different sources would be a bug, that's Abstract Factory's job. If you're just building one type of thing, a plain factory is enough.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-04-factory-q1", "type": "mcq",
      "prompt": "When is Abstract Factory the better choice over a plain factory?",
      "options": [
        {"id":"a","text":"Whenever more than two concrete classes exist"},
        {"id":"b","text":"When several related products have to come from the same matching family, and mixing families would be a bug — like a dark-theme button pairing with a light-theme checkbox"},
        {"id":"c","text":"When building the object is expensive"},
        {"id":"d","text":"When objects must be unchangeable once built"}
      ],
      "correct": "b",
      "explanation": "Abstract Factory's whole value is guaranteeing consistency across a family. If you only ever build one kind of product, a plain factory method (or even just a registry) is simpler and does the job." }
] }
```

## Builder — put together a complex object step by step

**The problem**: an object has a pile of optional fields, and the constructor has grown into `Pizza(size, cheese, sauce, toppings, crust, extra, discount)`, where half the arguments are usually `None` and nobody remembers what order they go in. This is sometimes called the "telescoping constructor" problem.

```python
from dataclasses import dataclass, field

@dataclass(frozen=True)
class HttpRequest:
    url: str
    method: str = "GET"
    headers: dict[str, str] = field(default_factory=dict)
    body: str | None = None
    timeout_ms: int = 5_000

class HttpRequestBuilder:
    def __init__(self, url: str):
        self._url, self._method = url, "GET"
        self._headers: dict[str, str] = {}
        self._body: str | None = None
        self._timeout = 5_000

    def method(self, m: str) -> "HttpRequestBuilder":
        self._method = m
        return self                                  # returning self is what makes chaining work

    def header(self, k: str, v: str) -> "HttpRequestBuilder":
        self._headers[k] = v
        return self

    def body(self, b: str) -> "HttpRequestBuilder":
        self._body = b
        return self

    def timeout_ms(self, ms: int) -> "HttpRequestBuilder":
        self._timeout = ms
        return self

    def build(self) -> HttpRequest:
        # Checks live here, so a broken object can never be created in the first place.
        if self._method in ("POST", "PUT") and self._body is None:
            raise ValueError(f"{self._method} requires a body")
        return HttpRequest(self._url, self._method, dict(self._headers),
                           self._body, self._timeout)


req = (HttpRequestBuilder("https://api.example.com/orders")
       .method("POST")
       .header("Content-Type", "application/json")
       .body('{"total":49900}')
       .timeout_ms(2_000)
       .build())

assert req.method == "POST" and req.timeout_ms == 2_000
try:
    HttpRequestBuilder("https://x").method("POST").build()
    raise AssertionError("expected validation failure")
except ValueError as e:
    print("builder validated:", e)
```

Three things make Builder worth the extra typing: **the call site reads like a sentence** ("method POST, header this, body that"), **checks all happen at `build()`**, so a half-finished object is never observable, and **the finished object never changes afterward**, so it's safe to hand to any thread.

**When you don't need it**: any language with named arguments and defaults — Python, Kotlin, C# — already solves the readability half of this problem. Reach for a builder there specifically when you need the *validation* and the *unchangeability*, or when the object gets assembled in pieces across different parts of your code.

> **Remember:** Builder buys you three things beyond named arguments — validation at one point, an object that never changes, and the ability to build it in stages.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-04-builder-q1", "type": "mcq",
      "prompt": "What does Builder solve that named/keyword arguments alone don't?",
      "options": [
        {"id":"a","text":"It makes construction run faster"},
        {"id":"b","text":"It centralises cross-field checks at build() and produces an object that never changes afterward, so a half-built or invalid version can never be seen — and it supports assembling the object across separate pieces of code"},
        {"id":"c","text":"It allows more than seven parameters"},
        {"id":"d","text":"It removes the need for a constructor entirely"}
      ],
      "correct": "b",
      "explanation": "Keyword arguments already fix readability. Builder adds a checkpoint where validation happens, a finished object that's safe to share, and the ability to build up configuration over time before the object exists." }
] }
```

## Prototype and Object Pool

**Prototype — the problem**: building an object from scratch is expensive (a heavy parse, a network fetch, a big computation), and you need lots of near-identical copies.

```python
import copy

class DocumentTemplate:
    def __init__(self, sections: list[str], styles: dict[str, str]):
        self.sections = sections            # imagine this took a while to build
        self.styles = styles

    def clone(self) -> "DocumentTemplate":
        return copy.deepcopy(self)          # deep, so the copy doesn't secretly share state


base = DocumentTemplate(["cover", "body"], {"font": "serif"})
invoice = base.clone()
invoice.sections.append("totals")
invoice.styles["font"] = "mono"

assert base.sections == ["cover", "body"]        # the original is untouched
assert base.styles["font"] == "serif"
print("prototype cloned independently:", invoice.sections, invoice.styles)
```

The whole reason this pattern exists is to warn you about **shallow vs. deep copies**. A shallow copy shares the nested list underneath, so changing the clone silently corrupts the original too. Interviewers ask this directly — know that `copy.copy` is shallow and `copy.deepcopy` is deep in Python, and that Java's `clone()` is shallow by default (most people consider `Cloneable` a design mistake; a copy constructor or a static factory method is usually preferred instead).

**Object Pool — the problem**: objects are expensive to both create *and* destroy, and you need a steady supply of them over time — database connections, threads, large buffers.

```python
class Connection:
    def __init__(self, cid: int): self.cid, self.in_use = cid, False
    def query(self, sql: str) -> str: return f"conn{self.cid}:{sql}"

class ConnectionPool:
    def __init__(self, size: int):
        self._pool = [Connection(i) for i in range(size)]   # all built up front, once

    def acquire(self) -> Connection:
        for c in self._pool:
            if not c.in_use:
                c.in_use = True
                return c
        raise RuntimeError("pool exhausted")     # a deliberate limit — this is backpressure

    def release(self, c: Connection) -> None:
        c.in_use = False                          # reset before it's handed to anyone else


pool = ConnectionPool(2)
a, b = pool.acquire(), pool.acquire()
try:
    pool.acquire()
    raise AssertionError("pool should be exhausted")
except RuntimeError:
    pass
pool.release(a)
c = pool.acquire()                                # 'a' gets reused
assert c is a
print("pooled:", c.query("SELECT 1"))
```

Two things worth saying about pools in an interview: **the pool has to be bounded** (an unbounded pool is just uncontrolled growth in disguise, and that "pool exhausted" error is doing its job on purpose), and **state must be reset when something is returned**, or the next borrower inherits whatever the last one left behind — an open transaction, a stale timeout, leftover session data. That exact reset bug is the classic production incident this pattern tends to cause.

> **Remember:** a pool without a bound isn't a pool, it's just delayed uncontrolled growth. Reset state on release, every time.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-04-pool-q1", "type": "mcq",
      "prompt": "What's the most common production bug an object pool introduces?",
      "options": [
        {"id":"a","text":"The pool is too large and wastes memory"},
        {"id":"b","text":"Object state isn't reset when it's returned, so the next borrower inherits the previous user's leftovers — an open transaction, a stale session value, old buffer contents"},
        {"id":"c","text":"Pooled objects can never be garbage collected"},
        {"id":"d","text":"The pool can't be used from more than one thread"}
      ],
      "correct": "b",
      "explanation": "Reuse is the entire point of a pool, and also its danger: anything carried over from the last borrower becomes a leak across requests or a hard-to-spot correctness bug. Resetting on release (or on acquire) isn't optional." }
] }
```

## Quick recap

**Problem, pattern, cost:**

| Pattern | Problem it solves | The cost, or when to skip it |
|---|---|---|
| **Singleton** | Exactly one shared instance of something expensive or unique | Global mutable state, hidden dependencies, hard to test — inject one instance instead |
| **Factory Method** | Callers shouldn't name concrete classes; new types shouldn't touch callers | Extra indirection; needs a registry to be truly open/closed |
| **Abstract Factory** | A whole *family* of products that must match | Adding a new product type means editing every factory |
| **Builder** | Lots of optional fields, checks, and an unchangeable result | Extra typing; keyword arguments already cover the simple case |
| **Prototype** | Copying is much cheaper than building from scratch | Shallow-vs-deep copy bugs |
| **Object Pool** | Building *and* destroying are both expensive; reuse is safe | Must be bounded; must reset state on release |

**How to use all of this in an interview:**

- **Say the problem before you say the pattern name.** "Payment methods will keep getting added, so I'll build them through a registry-backed factory" is design. "I'll use the Factory pattern" on its own is just vocabulary.
- **Bring up the cost yourself, before anyone asks.** Every pattern above has a well-known downside, and naming it unprompted is what makes you sound like someone who's actually maintained this kind of code, not just read about it.
- **The single most common mistake is reaching for Singleton everywhere.** Use it only for things that are genuinely one-of-a-kind, prefer injecting a single instance instead of a global one, and be ready to critique it — that critique is frequently the real question being asked.
- **A plain constructor is often the right answer.** Creational patterns earn their place when building something varies, costs a lot, or needs validating — not as a default habit.
