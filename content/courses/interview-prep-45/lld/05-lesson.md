---
kind: lesson
id_key: interview-prep-45/lld-05-structural-patterns
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "Structural Patterns"
position: 5
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Structural patterns are about **composing objects into larger structures without turning the composition into a mess**. Every one of them wraps or arranges objects so that the client sees something simpler than what is really there.

They are the patterns most often confused with each other in interviews — Adapter, Decorator, Proxy, and Facade all "wrap something" — so each section below leads with the *intent* that separates it, because the intent is what the question is actually testing.

## Adapter — make an incompatible interface fit

**Intent: convert an existing interface into the one your code expects.** You have a class you cannot change (a third-party SDK, a legacy module) and an interface your system speaks.

```python
from abc import ABC, abstractmethod

class PaymentGateway(ABC):                 # what OUR system expects
    @abstractmethod
    def charge(self, paise: int, token: str) -> str: ...

class LegacyRazorpayClient:                # third-party: we cannot change this
    def make_payment(self, amount_in_rupees: float, card_token: str) -> dict:
        return {"status": "captured", "ref": f"rzp_{card_token}_{amount_in_rupees}"}

class RazorpayAdapter(PaymentGateway):     # the adapter
    def __init__(self, client: LegacyRazorpayClient):
        self._client = client

    def charge(self, paise: int, token: str) -> str:
        result = self._client.make_payment(paise / 100, token)   # translate units...
        if result["status"] != "captured":                        # ...and the result shape
            raise RuntimeError("payment failed")
        return result["ref"]


gateway: PaymentGateway = RazorpayAdapter(LegacyRazorpayClient())
assert gateway.charge(49_900, "tok_abc") == "rzp_tok_abc_499.0"
print("adapted:", gateway.charge(10_000, "tok_xyz"))
```

The adapter is where the **unit conversion** lives (paise ↔ rupees), where error shapes are normalised, and where the vendor's vocabulary stops. That is its real value in production: swapping Razorpay for Stripe is one new adapter, and no business code changes. This is Dependency Inversion made concrete.

**Adapter vs Facade**: an adapter makes *one* incompatible interface fit an *existing required* interface; a facade invents a *new simpler* interface over *many* classes. Different intents, similar shapes.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-05-adapter-q1", "type": "mcq",
      "prompt": "What distinguishes Adapter from Facade?",
      "options": [
        {"id":"a","text":"Adapter wraps one object, Facade wraps two"},
        {"id":"b","text":"Adapter converts an existing class to an interface the client already requires (the target interface pre-exists); Facade invents a new, simpler interface over a complex subsystem to reduce what clients must know"},
        {"id":"c","text":"Adapter is used at runtime, Facade at compile time"},
        {"id":"d","text":"Adapter adds behaviour, Facade removes it"}
      ],
      "correct": "b",
      "explanation": "The giveaway is whether the target interface already existed. Adapter fits a square peg into an existing round hole; Facade designs a new, smaller hole because the existing subsystem is unpleasant to use directly." }
] }
```

## Decorator — add behaviour without subclassing

**Intent: attach responsibilities to an object dynamically, keeping the same interface.** The wrapper *is* the thing it wraps, plus something.

```python
from abc import ABC, abstractmethod

class DataSource(ABC):
    @abstractmethod
    def write(self, data: str) -> str: ...

class FileDataSource(DataSource):
    def write(self, data: str) -> str: return f"file({data})"

class CompressionDecorator(DataSource):
    def __init__(self, wrapped: DataSource): self._wrapped = wrapped
    def write(self, data: str) -> str: return self._wrapped.write(f"zip[{data}]")

class EncryptionDecorator(DataSource):
    def __init__(self, wrapped: DataSource): self._wrapped = wrapped
    def write(self, data: str) -> str: return self._wrapped.write(f"enc[{data}]")


plain: DataSource = FileDataSource()
secure: DataSource = EncryptionDecorator(CompressionDecorator(FileDataSource()))

assert plain.write("hi") == "file(hi)"
assert secure.write("hi") == "file(zip[enc[hi]])"     # encrypt, then compress, then write
print("decorated:", secure.write("payload"))
```

Why this beats inheritance here: the features are **independent and combinable**. With subclasses you would need `CompressedFile`, `EncryptedFile`, `CompressedEncryptedFile`, `BufferedCompressedEncryptedFile` — the combinatorial explosion from the composition lesson. With decorators, *n* features give 2ⁿ combinations from *n* classes, chosen at runtime.

You already use this pattern constantly: HTTP middleware (logging → auth → rate limit → handler), Java's `BufferedInputStream(new FileInputStream(...))`, Python function decorators, and React higher-order components are all the same idea.

**Order matters and is a good thing to mention**: compress-then-encrypt produces a much smaller result than encrypt-then-compress, because encrypted bytes have no compressible structure.

**The cost**: a deep stack of small wrappers is hard to debug — a stack trace shows six layers, and it is not obvious from the outside what a given object actually does.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-05-decorator-q1", "type": "mcq",
      "prompt": "Why is Decorator preferred over subclassing for adding compression, encryption, and buffering to a data source?",
      "options": [
        {"id":"a","text":"Decorators execute faster than subclass method calls"},
        {"id":"b","text":"The features are independent and combinable: n decorators give 2^n combinations from n classes, composable at runtime, whereas subclassing needs one class per combination"},
        {"id":"c","text":"Subclasses cannot override methods in most languages"},
        {"id":"d","text":"Decorators do not need to implement the base interface"}
      ],
      "correct": "b",
      "explanation": "This is the composition-over-inheritance argument in its sharpest form. Decorators must implement the same interface — that is precisely what makes them stackable and transparent to the client." }
] }
```

## Facade, Composite, and Bridge

**Facade — intent: one simple entry point over a complicated subsystem.**

```python
class VideoFile:
    def __init__(self, name: str): self.name = name

class CodecFactory:
    def extract(self, f: VideoFile) -> str: return f.name.split(".")[-1]

class BitrateReader:
    def read(self, f: VideoFile, codec: str) -> str: return f"{f.name}|{codec}"

class AudioMixer:
    def fix(self, stream: str) -> str: return f"{stream}|audio-ok"

class VideoConverter:                     # the facade: 1 method over 4 classes
    def convert(self, filename: str, target: str) -> str:
        f = VideoFile(filename)
        codec = CodecFactory().extract(f)
        stream = BitrateReader().read(f, codec)
        return f"{AudioMixer().fix(stream)} -> {target}"


assert VideoConverter().convert("clip.mp4", "ogg") == "clip.mp4|mp4|audio-ok -> ogg"
print(VideoConverter().convert("movie.avi", "mp4"))
```

A facade does not forbid direct access to the subsystem — it just means 95% of callers never need it. This is what a well-designed service class is: a facade over repositories, validators, and gateways.

**Composite — intent: treat individual objects and groups of objects uniformly.** Use it whenever the domain is a tree: file systems, org charts, UI layouts, nested menus, bill-of-materials.

```python
from abc import ABC, abstractmethod

class FileSystemNode(ABC):
    @abstractmethod
    def size(self) -> int: ...

class File(FileSystemNode):               # leaf
    def __init__(self, name: str, bytes_: int): self.name, self._bytes = name, bytes_
    def size(self) -> int: return self._bytes

class Directory(FileSystemNode):          # composite
    def __init__(self, name: str): self.name, self.children = name, []
    def add(self, node: FileSystemNode) -> "Directory":
        self.children.append(node)
        return self
    def size(self) -> int:
        return sum(child.size() for child in self.children)   # same call on both kinds


root = Directory("root").add(File("a.txt", 100)).add(
    Directory("sub").add(File("b.bin", 250)).add(File("c.bin", 150))
)
assert root.size() == 500          # client never checks "is this a file or a folder?"
print("total bytes:", root.size())
```

The property that makes it valuable: **the client has no `if is_directory` branch**. Adding a `SymlinkNode` requires no change to any traversal.

**Bridge — intent: split an abstraction from its implementation so both can vary independently.** It is the pattern-shaped answer to the same combinatorial explosion decorators solve, but for *two orthogonal hierarchies* rather than stackable features: shapes × rendering APIs, message types × delivery channels, remotes × devices. Instead of `VectorCircle`, `RasterCircle`, `VectorSquare`, `RasterSquare`, a `Shape` **has a** `Renderer`. In practice, "bridge" is usually just composition given a name — which is a perfectly good thing to say in an interview.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-05-composite-q1", "type": "mcq",
      "prompt": "What is the defining benefit of the Composite pattern?",
      "options": [
        {"id":"a","text":"It reduces memory usage for large trees"},
        {"id":"b","text":"Clients treat a single leaf and a whole subtree identically through one interface, so traversal and aggregation code contains no \"is this a group?\" branching and new node types require no client changes"},
        {"id":"c","text":"It guarantees the tree stays balanced"},
        {"id":"d","text":"It allows objects to be created lazily"}
      ],
      "correct": "b",
      "explanation": "Uniform treatment of part and whole is the entire point. The recursive `size()` above works because a Directory answers the same question a File does — that is what removes the conditionals from every client." }
] }
```

## Proxy and Flyweight

**Proxy — intent: a stand-in that controls access to the real object**, with the *same* interface. Four standard flavours, and naming them is what interviewers want:

| Flavour | Purpose |
|---|---|
| **Virtual proxy** | Defer expensive creation until first use (lazy loading) |
| **Protection proxy** | Enforce access control before delegating |
| **Remote proxy** | Local stand-in for an object on another machine (RPC stubs) |
| **Caching / smart proxy** | Memoise results, count references, log calls |

```python
from abc import ABC, abstractmethod

class Report(ABC):
    @abstractmethod
    def data(self) -> str: ...

class ExpensiveReport(Report):
    def __init__(self):
        print("  [expensive construction happened]")
        self._data = "quarterly numbers"
    def data(self) -> str: return self._data

class LazyReportProxy(Report):
    def __init__(self): self._real: Report | None = None
    def data(self) -> str:
        if self._real is None:              # created on first real use only
            self._real = ExpensiveReport()
        return self._real.data()

class AdminOnlyReportProxy(Report):
    def __init__(self, inner: Report, role: str): self._inner, self._role = inner, role
    def data(self) -> str:
        if self._role != "admin":
            raise PermissionError("admins only")
        return self._inner.data()


proxy = LazyReportProxy()                    # nothing constructed yet
print("proxy created, nothing built")
assert proxy.data() == "quarterly numbers"   # construction happens here
assert proxy.data() == "quarterly numbers"   # and only once

guarded = AdminOnlyReportProxy(LazyReportProxy(), role="viewer")
try:
    guarded.data()
    raise AssertionError("should have been blocked")
except PermissionError as e:
    print("protection proxy blocked:", e)
```

**Proxy vs Decorator** — the interview question. Structurally identical (both wrap and implement the same interface); the difference is intent and control:

- **Decorator** *adds* behaviour, and the client deliberately composes the stack.
- **Proxy** *controls access* to the same behaviour, and the client usually does not know a proxy is there.

**Flyweight — intent: share the common parts of many similar objects to save memory.** Split state into **intrinsic** (shared, immutable — a glyph's shape, a tree species' texture, a chess piece's move rules) and **extrinsic** (per-instance — position, colour, owner), then keep one shared instance per distinct intrinsic value.

```python
class TreeType:                                  # intrinsic, shared
    _cache: dict[tuple[str, str], "TreeType"] = {}

    def __new__(cls, name: str, texture: str):
        key = (name, texture)
        if key not in cls._cache:
            obj = super().__new__(cls)
            obj.name, obj.texture = name, texture
            cls._cache[key] = obj
        return cls._cache[key]

class Tree:                                      # extrinsic, per-instance
    def __init__(self, x: int, y: int, kind: TreeType):
        self.x, self.y, self.kind = x, y, kind


forest = [Tree(i, i * 2, TreeType("oak", "oak.png")) for i in range(1_000)]
forest += [Tree(i, i, TreeType("pine", "pine.png")) for i in range(1_000)]

assert len(forest) == 2_000
assert len(TreeType._cache) == 2          # 2,000 trees, 2 shared type objects
assert forest[0].kind is forest[5].kind
print("trees:", len(forest), "| distinct TreeType objects:", len(TreeType._cache))
```

Flyweight is a memory optimisation, not a design clarity one — reach for it only when object count is genuinely the problem (text editors, particle systems, game maps, tokenisers). Mentioning that it requires the shared state to be **immutable** is the detail that shows you understand why it is safe.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-05-proxy-q1", "type": "mcq",
      "prompt": "Proxy and Decorator have the same structure — both implement the target interface and hold a reference to it. What actually distinguishes them?",
      "options": [
        {"id":"a","text":"Proxy can only wrap one object, Decorator can wrap many"},
        {"id":"b","text":"Intent: a Decorator adds new behaviour and is deliberately composed by the client, while a Proxy controls access to the same behaviour (lazy loading, permissions, caching, remoting) and is typically invisible to the client"},
        {"id":"c","text":"Decorators are created at runtime, proxies at compile time"},
        {"id":"d","text":"Proxies do not implement the same interface as the wrapped object"}
      ],
      "correct": "b",
      "explanation": "GoF patterns are classified by intent, not by class diagram — several patterns share a shape. \"Adds behaviour, client-composed\" vs \"controls access, transparent\" is the distinction to say out loud." }
] }
```

## Key takeaways

**The intent table — this is what the interview question is really asking:**

| Pattern | One-line intent | Canonical example |
|---|---|---|
| **Adapter** | Make an existing class fit an interface you already require | Payment SDK → your `PaymentGateway` |
| **Decorator** | Add behaviour dynamically, same interface, stackable | HTTP middleware; `BufferedInputStream` |
| **Facade** | One simple entry point over a complex subsystem | A service class over repos + validators |
| **Composite** | Treat leaf and group identically | File system, org chart, UI tree |
| **Bridge** | Two orthogonal hierarchies vary independently | Shape × Renderer |
| **Proxy** | Control access to the same behaviour | Lazy loading, permissions, caching, RPC stub |
| **Flyweight** | Share immutable intrinsic state across many objects | Glyphs, tree types, chess move rules |

- **Lead with intent, not structure.** Adapter, Decorator, Proxy, and Facade all wrap; only the intent distinguishes them, and that distinction *is* the question.
- **Decorator vs inheritance is the highest-frequency practical use.** Independent, combinable features → decorators; anything else → probably not.
- **Composite is the answer to every tree-shaped domain**, and its value is the absence of type checks in client code.
- **Flyweight is an optimisation with a precondition** (immutable shared state) — say the precondition, not just the pattern name.
