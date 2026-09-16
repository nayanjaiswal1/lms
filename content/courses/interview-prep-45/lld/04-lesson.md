---
kind: lesson
id_key: interview-prep-45/lld-04-creational-patterns
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "Creational Patterns"
position: 4
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Creational patterns answer one question: **who decides which concrete class gets constructed, and how?** Every one of them exists to stop `new ConcreteThing()` from being scattered through code that should not know `ConcreteThing` exists.

Learn each as a **problem → pattern → cost** triple. Interviewers ask "when would you use this?" far more often than "implement this", and the trap answer is applying a pattern where a plain constructor would do.

## Singleton — exactly one instance

**Problem**: something expensive or genuinely unique — a connection pool, a configuration registry, a logger — must have one instance shared by everyone.

```python
import threading

class ConfigRegistry:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:                 # fast path, no lock
            with cls._lock:                       # double-checked locking
                if cls._instance is None:         # re-check inside the lock
                    obj = super().__new__(cls)
                    obj._values = {}
                    cls._instance = obj
        return cls._instance

    def set(self, key: str, value: str) -> None: self._values[key] = value
    def get(self, key: str) -> str | None: return self._values.get(key)


a, b = ConfigRegistry(), ConfigRegistry()
assert a is b                       # same object
a.set("region", "ap-south-1")
assert b.get("region") == "ap-south-1"
print("singleton shared state:", b.get("region"))
```

The double-checked lock matters and is asked about: without it, two threads can both pass the `is None` check and construct two instances; with a lock on every access, you pay for synchronisation forever. Check, lock, check again.

**In Python**, a module is already a singleton — importing it twice gives the same object — so a module-level instance is usually the idiomatic answer. **In Java**, the safest form is an enum singleton (serialization- and reflection-proof) or a static holder class.

**The cost — and say this unprompted, because "when would you NOT use it" is the follow-up:**

- It is **global mutable state**: any code anywhere can change it, so bugs have no obvious owner.
- It **hides dependencies**: a class using `ConfigRegistry()` internally looks dependency-free but is not.
- It makes **testing painful**: state leaks between tests, and you cannot substitute a fake.
- It **fights concurrency**: shared mutable state needs synchronisation everywhere.

The modern preference: create one instance at the composition root and **inject** it. You keep "exactly one" without the global access point, which was always the harmful half of the pattern.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-04-singleton-q1", "type": "mcq",
      "prompt": "Why is double-checked locking used in a thread-safe Singleton?",
      "options": [
        {"id":"a","text":"To make the object immutable"},
        {"id":"b","text":"So the lock is taken only during the first, racing construction: the outer check avoids synchronisation on every subsequent access, and the inner re-check prevents two threads that both passed the outer check from constructing twice"},
        {"id":"c","text":"To allow multiple instances when needed"},
        {"id":"d","text":"Because constructors cannot be synchronised"}
      ],
      "correct": "b",
      "explanation": "One check alone races; a lock on every access is a permanent cost on a read-mostly path. Check-lock-check gives correctness with the synchronisation cost paid only once." }
] }
```

## Factory Method and Abstract Factory

**Factory Method — problem**: callers should not know or name concrete classes, and adding a new type should not edit them.

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
    """Registry-based factory: a new channel registers itself, nothing here changes."""
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

The registry form is worth knowing because it is genuinely **open/closed**: a plain `if kind == "email"` factory still has to be edited for every new channel; the registry does not.

**Abstract Factory — problem**: you need *families* of related objects that must be used together, and mixing families would be a bug.

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
    # Cannot accidentally mix a dark button with a light checkbox.
    return theme.button().render() + theme.checkbox().render()


assert render_form(DarkTheme()) == "[dark button][dark checkbox]"
print(render_form(LightTheme()))
```

The distinction, in one line each: **Factory Method creates one product and varies by subclass or key; Abstract Factory creates a whole family and guarantees the members match.**

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-04-factory-q1", "type": "mcq",
      "prompt": "When is Abstract Factory the right choice over a plain factory?",
      "options": [
        {"id":"a","text":"Whenever more than two concrete classes exist"},
        {"id":"b","text":"When several related products must come from the same family and mixing families would be a defect — e.g. a dark-theme button must never pair with a light-theme checkbox"},
        {"id":"c","text":"When object creation is expensive"},
        {"id":"d","text":"When objects must be immutable"}
      ],
      "correct": "b",
      "explanation": "The value of Abstract Factory is the *consistency guarantee* across a product family. If you only ever create one kind of product, a factory method (or a registry) is simpler and sufficient." }
] }
```

## Builder — construct complex objects step by step

**Problem**: an object has many optional fields, and the constructor has become `Pizza(size, cheese, sauce, toppings, crust, extra, discount)` where half the arguments are `None` and nobody remembers the order (the "telescoping constructor" problem).

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
        return self                                  # fluent: return self to chain

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
        # Validation lives here, so an invalid object can never exist.
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

Three properties that make Builder worth its verbosity: **named arguments** (the call site reads as documentation), **validation at `build()`** (the product is never half-constructed), and **an immutable product** (safe to share across threads).

**When you do not need it**: a language with keyword arguments and defaults — Python, Kotlin, C# — already solves the readability half. Reach for a builder there when you need the *validation* and *immutability*, or when construction happens in stages across different pieces of code.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-04-builder-q1", "type": "mcq",
      "prompt": "Which problem does the Builder pattern solve that keyword arguments alone do not?",
      "options": [
        {"id":"a","text":"It makes construction faster"},
        {"id":"b","text":"It centralises cross-field validation at build() and yields an immutable product, so a partially-configured or invalid object can never be observed — and it supports assembling the object in stages across different code"},
        {"id":"c","text":"It allows more than seven parameters"},
        {"id":"d","text":"It removes the need for a constructor"}
      ],
      "correct": "b",
      "explanation": "Keyword arguments fix readability. Builder adds a validation checkpoint, an immutable result, and the ability to accumulate configuration over time before the object exists." }
] }
```

## Prototype and Object Pool

**Prototype — problem**: creating an object from scratch is expensive (a deep parse, a network fetch, a heavy computation) and you need many near-identical copies.

```python
import copy

class DocumentTemplate:
    def __init__(self, sections: list[str], styles: dict[str, str]):
        self.sections = sections            # imagine: expensively parsed
        self.styles = styles

    def clone(self) -> "DocumentTemplate":
        return copy.deepcopy(self)          # deep, so copies don't share mutable state


base = DocumentTemplate(["cover", "body"], {"font": "serif"})
invoice = base.clone()
invoice.sections.append("totals")
invoice.styles["font"] = "mono"

assert base.sections == ["cover", "body"]        # original untouched
assert base.styles["font"] == "serif"
print("prototype cloned independently:", invoice.sections, invoice.styles)
```

The trap this pattern exists to expose is **shallow vs deep copy**: a shallow copy shares the nested list, so mutating the clone corrupts the original. Interviewers ask this directly — know that `copy.copy` is shallow and `copy.deepcopy` is deep in Python, and that Java's `clone()` is shallow by default and `Cloneable` is widely considered a broken design (a copy constructor or a static factory is preferred).

**Object Pool — problem**: objects are expensive to create *and* to destroy, and you need many over time — database connections, threads, large buffers.

```python
class Connection:
    def __init__(self, cid: int): self.cid, self.in_use = cid, False
    def query(self, sql: str) -> str: return f"conn{self.cid}:{sql}"

class ConnectionPool:
    def __init__(self, size: int):
        self._pool = [Connection(i) for i in range(size)]   # created once, up front

    def acquire(self) -> Connection:
        for c in self._pool:
            if not c.in_use:
                c.in_use = True
                return c
        raise RuntimeError("pool exhausted")     # bounded on purpose — backpressure

    def release(self, c: Connection) -> None:
        c.in_use = False                          # reset state before reuse


pool = ConnectionPool(2)
a, b = pool.acquire(), pool.acquire()
try:
    pool.acquire()
    raise AssertionError("pool should be exhausted")
except RuntimeError:
    pass
pool.release(a)
c = pool.acquire()                                # a is recycled
assert c is a
print("pooled:", c.query("SELECT 1"))
```

Two things to say about pools in an interview: **the pool must be bounded** (an unbounded pool is just uncontrolled resource growth, and the exhaustion error is deliberate backpressure), and **state must be reset on release**, or the next borrower inherits the last one's transaction, timeouts, or session variables. That reset bug is the classic production incident this pattern causes.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-04-pool-q1", "type": "mcq",
      "prompt": "What is the most common production bug introduced by an object pool?",
      "options": [
        {"id":"a","text":"The pool is too large and wastes memory"},
        {"id":"b","text":"Object state is not reset on release, so the next borrower inherits the previous user's state — an open transaction, a stale session variable, leftover buffer contents"},
        {"id":"c","text":"Pooled objects cannot be garbage collected"},
        {"id":"d","text":"The pool cannot be used from multiple threads"}
      ],
      "correct": "b",
      "explanation": "Reuse is the whole point of a pool and also its hazard: anything carried over from the previous borrower becomes a cross-request data leak or a subtle correctness bug. Reset on release (or on acquire) is mandatory." }
] }
```

## Key takeaways

**The recall table — problem, pattern, cost:**

| Pattern | Problem it solves | Cost / when not to |
|---|---|---|
| **Singleton** | Exactly one shared instance of something expensive or unique | Global mutable state, hidden dependencies, hard to test — prefer one injected instance |
| **Factory Method** | Callers shouldn't name concrete classes; new types shouldn't edit callers | Indirection; a registry form is needed to be truly open/closed |
| **Abstract Factory** | A *family* of products that must match | Adding a new product type means editing every factory |
| **Builder** | Many optional fields; validation; immutable result | Verbose; keyword args cover the simple case |
| **Prototype** | Copying is much cheaper than constructing | Deep vs shallow copy bugs |
| **Object Pool** | Creation *and* destruction are expensive; reuse is safe | Must be bounded; must reset state on release |

**How to use them in an interview:**

- **Name the problem first, the pattern second.** "Payment methods will keep being added, so I'll create them through a registry-backed factory" is design. "I'll use the Factory pattern" is vocabulary.
- **Volunteer the cost.** Every pattern above has a well-known downside, and naming it is what makes you sound like someone who has maintained the code rather than read about it.
- **The most common mistake is Singleton everywhere.** Use it for genuinely unique resources, prefer injecting a single instance, and be ready to critique it — that critique is frequently the actual question.
- **A plain constructor is often the right answer.** Creational patterns earn their keep when construction varies, is expensive, or must be validated; not otherwise.
