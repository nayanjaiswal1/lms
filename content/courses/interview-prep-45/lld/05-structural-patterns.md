---
kind: lesson
id_key: interview-prep-45/lld-05-structural-patterns
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Structural Patterns"
position: 5
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Structural patterns are all about **arranging objects into bigger structures without the arrangement turning into a mess**. Every one of them wraps or combines objects so that whoever's using them sees something simpler than what's actually underneath.

These are also the patterns people mix up the most in interviews. Adapter, Decorator, Proxy, and Facade all "wrap something," so each section below starts with the one thing that actually tells them apart — because that difference is usually the whole question.

## Adapter — make a mismatched interface fit

**The idea: take an interface you can't change, and make it fit the one your code already expects.** You have a class you're not allowed to touch — a third-party SDK, an old internal module — and your system speaks a different language.

```python
from abc import ABC, abstractmethod

class PaymentGateway(ABC):                 # the interface OUR system expects
    @abstractmethod
    def charge(self, paise: int, token: str) -> str: ...

class LegacyRazorpayClient:                # third-party: we cannot touch this
    def make_payment(self, amount_in_rupees: float, card_token: str) -> dict:
        return {"status": "captured", "ref": f"rzp_{card_token}_{amount_in_rupees}"}

class RazorpayAdapter(PaymentGateway):     # the adapter
    def __init__(self, client: LegacyRazorpayClient):
        self._client = client

    def charge(self, paise: int, token: str) -> str:
        result = self._client.make_payment(paise / 100, token)   # convert units...
        if result["status"] != "captured":                        # ...and normalise the result
            raise RuntimeError("payment failed")
        return result["ref"]


gateway: PaymentGateway = RazorpayAdapter(LegacyRazorpayClient())
assert gateway.charge(49_900, "tok_abc") == "rzp_tok_abc_499.0"
print("adapted:", gateway.charge(10_000, "tok_xyz"))
```

The adapter is exactly where the **unit conversion** lives (paise to rupees, in this case), where error formats get straightened out, and where the vendor's own quirks stop spreading into the rest of your code. That's its real value in production: switching from Razorpay to Stripe becomes one new adapter, and nothing else in your business code has to change. This is Dependency Inversion, made concrete.

**Adapter vs. Facade**: an adapter makes *one* mismatched interface fit an interface that *already exists and is required*. A facade *invents a brand-new, simpler* interface over *many* classes. They can look similar, but the intent is completely different.

> **Remember:** if the interface you're fitting into already existed before you got here, that's Adapter. If you're inventing a simpler one from scratch, that's Facade.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-05-adapter-q1", "type": "mcq",
      "prompt": "What actually separates Adapter from Facade?",
      "options": [
        {"id":"a","text":"Adapter wraps one object, Facade always wraps at least two"},
        {"id":"b","text":"Adapter fits an existing class to an interface the client already needed (that interface already existed); Facade invents a brand-new, simpler interface over a complicated subsystem to reduce what callers need to know"},
        {"id":"c","text":"Adapter runs at runtime, Facade at compile time"},
        {"id":"d","text":"Adapter adds new behaviour, Facade removes it"}
      ],
      "correct": "b",
      "explanation": "The giveaway is whether the target interface already existed. Adapter fits a square peg into a round hole that was already there; Facade builds a smaller hole on purpose because the real subsystem is unpleasant to use directly." }
] }
```

## Decorator — add behaviour without subclassing

**The idea: attach new responsibilities to an object while it's running, without changing its interface.** The wrapper *is* the thing it wraps, plus a little extra.

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
assert secure.write("hi") == "file(zip[enc[hi]])"     # encrypt, then compress, then write to disk
print("decorated:", secure.write("payload"))
```

Here's why this beats subclassing: the features are **independent, and you want to mix and match them**. Doing this with subclasses would force you into `CompressedFile`, `EncryptedFile`, `CompressedEncryptedFile`, `BufferedCompressedEncryptedFile` — the same explosion of classes from the composition-over-inheritance lesson. With decorators, *n* separate features give you 2ⁿ possible combinations from only *n* classes, chosen while your program runs.

You've already used this pattern constantly without naming it: HTTP middleware (logging, then auth, then rate limiting, then your actual handler), Java's `BufferedInputStream(new FileInputStream(...))`, Python's function decorators, and React's higher-order components are all this same idea.

**Order matters, and it's worth mentioning**: compressing first and then encrypting gives you a much smaller result than the other way around, because encrypted bytes have no repeating structure left to compress.

**The cost**: a tall stack of small wrappers can be genuinely hard to debug. A stack trace shows six layers deep, and it's not obvious from the outside what any single object actually does anymore.

> **Remember:** decorators pay off exactly when features are independent and combinable. n decorators give you 2ⁿ combinations from n classes.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-05-decorator-q1", "type": "mcq",
      "prompt": "Why pick Decorator over subclassing for adding compression, encryption, and buffering to a data source?",
      "options": [
        {"id":"a","text":"Decorators run faster than subclass method calls"},
        {"id":"b","text":"The features are independent and combinable: n decorators give 2^n combinations from n classes, chosen while the program runs, while subclassing needs a separate class per combination"},
        {"id":"c","text":"Subclasses can't override methods in most languages"},
        {"id":"d","text":"Decorators don't need to implement the same interface as what they wrap"}
      ],
      "correct": "b",
      "explanation": "This is the composition-over-inheritance argument at its sharpest. Decorators must implement the exact same interface they wrap — that's precisely what lets them stack and stay transparent to whoever's calling them." }
] }
```

## Facade, Composite, and Bridge

**Facade — the idea: one simple front door over a complicated system behind it.**

```python
class VideoFile:
    def __init__(self, name: str): self.name = name

class CodecFactory:
    def extract(self, f: VideoFile) -> str: return f.name.split(".")[-1]

class BitrateReader:
    def read(self, f: VideoFile, codec: str) -> str: return f"{f.name}|{codec}"

class AudioMixer:
    def fix(self, stream: str) -> str: return f"{stream}|audio-ok"

class VideoConverter:                     # the facade: 1 method standing in front of 4 classes
    def convert(self, filename: str, target: str) -> str:
        f = VideoFile(filename)
        codec = CodecFactory().extract(f)
        stream = BitrateReader().read(f, codec)
        return f"{AudioMixer().fix(stream)} -> {target}"


assert VideoConverter().convert("clip.mp4", "ogg") == "clip.mp4|mp4|audio-ok -> ogg"
print(VideoConverter().convert("movie.avi", "mp4"))
```

A facade doesn't lock anyone out of the classes it sits in front of — it just means most callers never have to reach for them directly. This is, in fact, what a well-built service class usually is: a facade sitting in front of repositories, validators, and outside gateways.

**Composite — the idea: treat one object and a whole group of objects through the exact same interface.** Reach for this whenever the domain is naturally a tree: file systems, org charts, UI layouts, nested menus, a bill of materials.

```python
from abc import ABC, abstractmethod

class FileSystemNode(ABC):
    @abstractmethod
    def size(self) -> int: ...

class File(FileSystemNode):               # a leaf
    def __init__(self, name: str, bytes_: int): self.name, self._bytes = name, bytes_
    def size(self) -> int: return self._bytes

class Directory(FileSystemNode):          # a composite — a group of the same kind of thing
    def __init__(self, name: str): self.name, self.children = name, []
    def add(self, node: FileSystemNode) -> "Directory":
        self.children.append(node)
        return self
    def size(self) -> int:
        return sum(child.size() for child in self.children)   # same call, works on either kind


root = Directory("root").add(File("a.txt", 100)).add(
    Directory("sub").add(File("b.bin", 250)).add(File("c.bin", 150))
)
assert root.size() == 500          # nothing here ever asks "is this a file or a folder?"
print("total bytes:", root.size())
```

Notice what you *don't* see anywhere in that code: an `if is_directory` check. Adding a new `SymlinkNode` type requires no change at all to how anything gets traversed.

**Bridge — the idea: split what something *is* from how it's *implemented*, so both can change independently.** It's the pattern version of the same problem Decorator solves, but for *two* dimensions of variation that need to move independently, rather than stackable features: shapes and rendering engines, message types and delivery channels, remotes and devices. Instead of `VectorCircle`, `RasterCircle`, `VectorSquare`, `RasterSquare`, a `Shape` simply **has a** `Renderer`. In practice, "bridge" is often just composition wearing a name — and saying exactly that in an interview is a perfectly good answer.

> **Remember:** if there's no `if is_directory` (or its equivalent) anywhere in your traversal code, Composite is doing its job.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-05-composite-q1", "type": "mcq",
      "prompt": "What's the defining payoff of the Composite pattern?",
      "options": [
        {"id":"a","text":"It cuts memory usage for large trees"},
        {"id":"b","text":"Callers treat a single leaf and a whole subtree the exact same way through one interface, so traversal code has no \"is this a group?\" branching, and new node types need zero changes anywhere else"},
        {"id":"c","text":"It guarantees the tree stays balanced"},
        {"id":"d","text":"It lets objects be built lazily"}
      ],
      "correct": "b",
      "explanation": "Treating the part and the whole identically is the whole point. The recursive `size()` above works because a Directory answers the exact same question a File does — that's what removes the branching from any code that walks the tree." }
] }
```

## Proxy and Flyweight

**Proxy — the idea: a stand-in that controls access to the real object**, using the *exact same* interface. There are four standard flavours, and naming them is exactly what interviewers are listening for:

| Flavour | What it's for |
|---|---|
| **Virtual proxy** | Delay building something expensive until it's actually needed |
| **Protection proxy** | Check permissions before letting a call through |
| **Remote proxy** | A local stand-in for something that actually lives on another machine |
| **Caching / smart proxy** | Remember past results, count how often something's called, log calls |

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
        if self._real is None:              # only built the first time it's actually used
            self._real = ExpensiveReport()
        return self._real.data()

class AdminOnlyReportProxy(Report):
    def __init__(self, inner: Report, role: str): self._inner, self._role = inner, role
    def data(self) -> str:
        if self._role != "admin":
            raise PermissionError("admins only")
        return self._inner.data()


proxy = LazyReportProxy()                    # nothing has been built yet
print("proxy created, nothing built")
assert proxy.data() == "quarterly numbers"   # the real object gets built right here
assert proxy.data() == "quarterly numbers"   # and never again after that

guarded = AdminOnlyReportProxy(LazyReportProxy(), role="viewer")
try:
    guarded.data()
    raise AssertionError("should have been blocked")
except PermissionError as e:
    print("protection proxy blocked:", e)
```

**Proxy vs. Decorator is the interview question.** Structurally they're nearly identical — both wrap something and implement the same interface — but their intent is completely different:

- **Decorator** *adds* new behaviour, and the caller deliberately chooses to stack it.
- **Proxy** *controls access* to the same behaviour that's already there, and usually the caller doesn't even know a proxy is involved.

**Flyweight — the idea: share the common parts of many similar objects to save memory.** Split an object's data into **intrinsic** state (shared and never changing: a glyph's shape, a tree species' texture, a chess piece's movement rules) and **extrinsic** state (unique per object: position, colour, owner). Keep exactly one shared instance for each distinct value of the intrinsic state.

```python
class TreeType:                                  # intrinsic — shared across many trees
    _cache: dict[tuple[str, str], "TreeType"] = {}

    def __new__(cls, name: str, texture: str):
        key = (name, texture)
        if key not in cls._cache:
            obj = super().__new__(cls)
            obj.name, obj.texture = name, texture
            cls._cache[key] = obj
        return cls._cache[key]

class Tree:                                      # extrinsic — unique per tree
    def __init__(self, x: int, y: int, kind: TreeType):
        self.x, self.y, self.kind = x, y, kind


forest = [Tree(i, i * 2, TreeType("oak", "oak.png")) for i in range(1_000)]
forest += [Tree(i, i, TreeType("pine", "pine.png")) for i in range(1_000)]

assert len(forest) == 2_000
assert len(TreeType._cache) == 2          # 2,000 trees, but only 2 shared TreeType objects
assert forest[0].kind is forest[5].kind
print("trees:", len(forest), "| distinct TreeType objects:", len(TreeType._cache))
```

Flyweight is purely a memory optimisation, not a clarity one — reach for it only when the sheer *number* of objects is your real problem (text editors, particle systems, game maps, tokenisers). Mentioning that the shared state has to be **unchangeable** is the detail that shows you understand *why* this is safe, not just what it does.

> **Remember:** Proxy controls access to behaviour that's already there. Decorator adds behaviour that wasn't there before. Same shape, opposite intent.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-05-proxy-q1", "type": "mcq",
      "prompt": "Proxy and Decorator have the same structure — both implement the target's interface and hold a reference to it. What actually tells them apart?",
      "options": [
        {"id":"a","text":"Proxy can only wrap one object, Decorator can wrap several"},
        {"id":"b","text":"Intent: Decorator adds new behaviour and the caller deliberately chooses to stack it, while Proxy controls access to the same behaviour (lazy loading, permissions, caching, calling a remote machine) and is usually invisible to the caller"},
        {"id":"c","text":"Decorators are built while the program runs, proxies before it starts"},
        {"id":"d","text":"Proxies don't implement the same interface as what they wrap"}
      ],
      "correct": "b",
      "explanation": "These patterns are grouped by intent, not by class diagram — several share the same shape. \"Adds behaviour, caller chooses it\" versus \"controls access, invisible to the caller\" is the distinction worth saying out loud." }
] }
```

## Quick recap

**What each one is really for:**

| Pattern | The one-line intent | A real example |
|---|---|---|
| **Adapter** | Make an existing class fit an interface you already need | A payment SDK, wrapped to match your own `PaymentGateway` |
| **Decorator** | Add behaviour while running, same interface, stackable | HTTP middleware; `BufferedInputStream` |
| **Facade** | One simple front door over a complicated system | A service class sitting in front of repos and validators |
| **Composite** | Treat one leaf and a whole group identically | A file system, an org chart, a UI tree |
| **Bridge** | Two independent things vary separately | A shape and its renderer |
| **Proxy** | Control access to the same underlying behaviour | Lazy loading, permission checks, caching, a remote stand-in |
| **Flyweight** | Share unchangeable shared state across many objects | Glyphs, tree types, chess movement rules |

- **Lead with intent, not shape.** Adapter, Decorator, Proxy, and Facade all wrap something — intent is the only thing that actually tells them apart, and that's the real question every time.
- **Decorator vs. inheritance is the one you'll use the most in practice.** Independent, mixable features point to decorators; almost anything else probably doesn't.
- **Composite is the answer whenever the domain is a tree**, and its whole value is the type-checking code you *don't* have to write.
- **Flyweight is an optimisation with a precondition.** Say the precondition — shared state has to be unchangeable — not just the pattern's name.
