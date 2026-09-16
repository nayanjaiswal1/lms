---
kind: lesson
id_key: interview-prep-45/lld-07-behavioral-patterns-2
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "Behavioral Patterns II and Anti-Patterns"
position: 7
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

The remaining behavioral patterns come up less often than Strategy and Observer, but each one is the *standard* answer to a specific problem — and Chain of Responsibility in particular is what every middleware pipeline, logging framework, and approval workflow is built from. This lesson closes the pattern catalogue, then covers the anti-patterns, because recognising a bad design out loud is worth as much in an interview as producing a good one.

## Chain of Responsibility

**Intent: pass a request along a chain of handlers until one handles it** (or all of them have had a turn). Each handler decides whether to act, whether to pass it on, or both.

```python
from abc import ABC, abstractmethod

class Handler(ABC):
    def __init__(self): self._next: "Handler | None" = None

    def set_next(self, nxt: "Handler") -> "Handler":
        self._next = nxt
        return nxt                                  # returns nxt so chains read left→right

    def handle(self, request: dict) -> str | None:
        result = self.process(request)
        if result is not None:
            return result                           # handled: stop here
        return self._next.handle(request) if self._next else None

    @abstractmethod
    def process(self, request: dict) -> str | None: ...

class AuthHandler(Handler):
    def process(self, request):
        return None if request.get("user") else "401 unauthenticated"

class RateLimitHandler(Handler):
    def __init__(self, limit: int):
        super().__init__()
        self.limit, self.seen = limit, {}
    def process(self, request):
        user = request["user"]
        self.seen[user] = self.seen.get(user, 0) + 1
        return "429 rate limited" if self.seen[user] > self.limit else None

class ValidationHandler(Handler):
    def process(self, request):
        return None if request.get("body") else "400 missing body"

class BusinessHandler(Handler):
    def process(self, request):
        return f"200 processed {request['body']} for {request['user']}"


chain = AuthHandler()
chain.set_next(RateLimitHandler(limit=2)).set_next(ValidationHandler()).set_next(BusinessHandler())

assert chain.handle({}) == "401 unauthenticated"
assert chain.handle({"user": "asha", "body": "x"}).startswith("200")
assert chain.handle({"user": "asha", "body": "y"}).startswith("200")
assert chain.handle({"user": "asha", "body": "z"}) == "429 rate limited"
print("chain result:", chain.handle({"user": "ravi"}))
```

**Where you already use it**: HTTP middleware (Express, Django, Chi), servlet filters, logging frameworks (a `DEBUG` handler passes upward until a level matches), approval workflows (manager → director → VP by amount), and exception handling itself.

Two properties worth naming: **the chain is configurable at runtime** — reorder, insert, or remove a handler without touching any other — and **the sender does not know which handler will respond**, which is the decoupling the pattern buys. The risk is that a request can fall off the end unhandled, so always design the terminal case deliberately.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-07-cor-q1", "type": "mcq",
      "prompt": "What must you design deliberately in a Chain of Responsibility?",
      "options": [
        {"id":"a","text":"That every handler processes every request"},
        {"id":"b","text":"The terminal behaviour — what happens when a request reaches the end of the chain unhandled — since the sender has no idea which handler (if any) will respond"},
        {"id":"c","text":"That the chain has an even number of handlers"},
        {"id":"d","text":"That handlers cannot be reordered"}
      ],
      "correct": "b",
      "explanation": "The decoupling that makes the pattern valuable also means nobody guarantees a handler exists. A default terminal handler (or an explicit \"unhandled\" result) prevents requests from silently disappearing." }
] }
```

## Iterator, Mediator, and Memento

**Iterator — intent: traverse a collection without exposing its internal representation.** You use it every time you write a `for` loop; the design point is that the *client* never learns whether the collection is an array, a tree, or a paginated API.

```python
class PaginatedFeed:
    """Looks like a simple sequence; secretly fetches a page at a time."""
    def __init__(self, pages: list[list[str]]):
        self._pages = pages

    def __iter__(self):
        for page in self._pages:                  # each page could be a network call
            for item in page:
                yield item                        # a generator IS the iterator


feed = PaginatedFeed([["a", "b"], ["c"], ["d", "e"]])
assert list(feed) == ["a", "b", "c", "d", "e"]
assert sum(1 for _ in feed) == 5                  # re-iterable
print("streamed lazily:", [x for x in feed][:3])
```

The design value: swapping the storage from a list to a database cursor changes nothing for callers. In Python, generators make this pattern nearly invisible — mention that; in Java it is `Iterable`/`Iterator` explicitly.

**Mediator — intent: centralise complex many-to-many communication so objects don't reference each other directly.** Without it, *n* components that all talk to each other need up to *n(n−1)/2* connections; with it, each knows only the mediator.

```python
class ChatRoom:                                    # the mediator
    def __init__(self): self._members: dict[str, "User"] = {}

    def join(self, user: "User") -> None:
        self._members[user.name] = user
        user.room = self

    def send(self, sender: str, text: str) -> None:
        for name, user in self._members.items():
            if name != sender:                     # users never reference each other
                user.receive(sender, text)

class User:
    def __init__(self, name: str):
        self.name, self.room, self.inbox = name, None, []
    def say(self, text: str) -> None: self.room.send(self.name, text)
    def receive(self, sender: str, text: str) -> None: self.inbox.append((sender, text))


room = ChatRoom()
asha, ravi, meera = User("asha"), User("ravi"), User("meera")
for u in (asha, ravi, meera):
    room.join(u)

asha.say("hello")
assert ravi.inbox == [("asha", "hello")] and meera.inbox == [("asha", "hello")]
assert asha.inbox == []                            # sender doesn't receive their own
print("mediated:", ravi.inbox)
```

The warning to state: **the mediator can become a god object**. It absorbs coordination logic from everywhere and grows without bound. Keep it to routing and coordination; keep domain rules in the participants. (Air traffic control, UI dialog coordination, and — at system scale — a message broker are all mediators.)

**Memento — intent: capture and restore an object's state without exposing its internals.** It is the pattern behind undo, checkpoints, and save games, and it pairs naturally with Command (which stores the memento it needs to reverse itself). The key property is that the memento is **opaque to everyone except the originator** — the caretaker holds it but cannot read or alter it, which is what keeps encapsulation intact.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-07-mediator-q1", "type": "mcq",
      "prompt": "What is the main risk of introducing a Mediator?",
      "options": [
        {"id":"a","text":"Components become impossible to test"},
        {"id":"b","text":"The mediator accumulates coordination logic from every participant and turns into a god object — it should route and coordinate, while domain rules stay in the participants"},
        {"id":"c","text":"It increases the number of connections between components"},
        {"id":"d","text":"Messages can only be delivered to one recipient"}
      ],
      "correct": "b",
      "explanation": "Mediator trades many-to-many coupling for a single hub, and the hub is where complexity accretes. Keeping it thin is what preserves the benefit." }
] }
```

## Visitor and Interpreter

**Visitor — intent: add new operations to a stable object structure without modifying the classes in it.**

The problem it solves: you have a fixed set of node types (an AST, a document tree, a shape hierarchy) and a growing set of operations over them (render, export, validate, compute cost). Putting every operation on every node class means editing all of them each time.

```python
from abc import ABC, abstractmethod

class Node(ABC):
    @abstractmethod
    def accept(self, visitor: "Visitor"): ...

class Number(Node):
    def __init__(self, value: int): self.value = value
    def accept(self, visitor): return visitor.visit_number(self)

class Add(Node):
    def __init__(self, left: Node, right: Node): self.left, self.right = left, right
    def accept(self, visitor): return visitor.visit_add(self)

class Multiply(Node):
    def __init__(self, left: Node, right: Node): self.left, self.right = left, right
    def accept(self, visitor): return visitor.visit_multiply(self)

class Visitor(ABC):
    @abstractmethod
    def visit_number(self, n: Number): ...
    @abstractmethod
    def visit_add(self, n: Add): ...
    @abstractmethod
    def visit_multiply(self, n: Multiply): ...

class Evaluate(Visitor):                       # operation 1
    def visit_number(self, n): return n.value
    def visit_add(self, n): return n.left.accept(self) + n.right.accept(self)
    def visit_multiply(self, n): return n.left.accept(self) * n.right.accept(self)

class PrettyPrint(Visitor):                    # operation 2 — no Node class edited
    def visit_number(self, n): return str(n.value)
    def visit_add(self, n): return f"({n.left.accept(self)} + {n.right.accept(self)})"
    def visit_multiply(self, n): return f"({n.left.accept(self)} * {n.right.accept(self)})"


tree = Multiply(Add(Number(2), Number(3)), Number(4))     # (2 + 3) * 4
assert tree.accept(Evaluate()) == 20
assert tree.accept(PrettyPrint()) == "((2 + 3) * 4)"
print(tree.accept(PrettyPrint()), "=", tree.accept(Evaluate()))
```

**The trade-off is exactly inverted from normal polymorphism**, and this is the insight to state: adding a new *operation* is free (a new visitor), but adding a new *node type* requires editing every visitor. So Visitor is right when the type hierarchy is stable and operations keep growing — compilers, document processors, static analysers — and wrong when new types appear often.

**Interpreter — intent: represent a grammar as classes and evaluate sentences in it.** The `Evaluate` visitor above is essentially an interpreter over a tiny expression grammar. In practice you meet it in rule engines, query filters, and search DSLs; for anything larger, a real parser generator beats hand-rolled interpreter classes. It is enough to know what it is and when to say "this is a parsing problem, not a pattern problem".

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-07-visitor-q1", "type": "mcq",
      "prompt": "When is the Visitor pattern the right choice?",
      "options": [
        {"id":"a","text":"When new node types are added frequently but operations rarely change"},
        {"id":"b","text":"When the set of node types is stable but operations over them keep growing — a new operation is a new visitor class, whereas a new node type forces an edit to every existing visitor"},
        {"id":"c","text":"Whenever a tree structure exists"},
        {"id":"d","text":"When the structure must be traversed in parallel"}
      ],
      "correct": "b",
      "explanation": "Visitor inverts the usual extensibility axis: cheap new operations, expensive new types. Getting that inversion the right way round for your domain is the whole decision." }
] }
```

## Anti-patterns: recognising bad design out loud

Being able to name a smell and its fix live, mid-interview, is worth as much as producing a clean design first time — because it is what a real design review sounds like.

| Anti-pattern | What it looks like | Why it hurts | The fix |
|---|---|---|---|
| **God object** | `OrderManager` with 40 methods and 15 fields | Every change touches it; nothing can be tested alone | Split by reason to change (SRP) |
| **Anaemic domain model** | Entities with only getters/setters; all logic in `*Service` classes | Data and the rules governing it live apart, so invariants leak everywhere | Move behaviour onto the entity that owns the data |
| **Spaghetti inheritance** | Five-level hierarchies; subclasses overriding to disable behaviour | Fragile base class; LSP violations | Composition; small interfaces |
| **Primitive obsession** | `str` for money, ids, phone numbers, currency codes | Type system can't catch mixing them up; validation scattered | Value objects (`Money`, `TicketId`) |
| **Magic strings/numbers** | `if status == 3`, `if role == "adm"` | Typos compile; meaning is invisible | Enums and named constants |
| **Feature envy** | A method that mostly reads another object's fields | Coupling to another class's shape | Move the method to the data |
| **Circular dependency** | `Order` imports `Customer` imports `Order` | Neither can be understood or tested alone | Extract an interface, or invert the dependency |
| **Leaky abstraction** | A `Repository` returning an ORM query object | Callers depend on the storage tech anyway | Return domain objects only |
| **Boolean trap** | `save(true, false, true)` | Unreadable at the call site | Named arguments, enums, or separate methods |
| **Copy-paste inheritance** | Subclassing purely to reuse a method | Ties two unrelated things together forever | Extract a shared collaborator |
| **Pattern fever** | An interface, a factory, and a strategy for one concrete class | Indirection with no variation to justify it | Delete it; add the abstraction when a second case exists |

That last row deserves emphasis, because a full pattern catalogue makes it tempting: **the most common mistake candidates make after learning patterns is using them where a plain class would do.** An interface with one implementation and no plausible second is a cost with no benefit. The strongest answer is often "I'd keep this concrete for now; if a second pricing rule appears, this is where the strategy goes" — it shows you know both the pattern and its price.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-07-antipattern-q1", "type": "mcq",
      "prompt": "A design has `Order` as a bag of getters and setters, with every rule (validation, totals, state transitions) in `OrderService`. What is this called and why is it a problem?",
      "options": [
        {"id":"a","text":"A god object; split the service into smaller services"},
        {"id":"b","text":"An anaemic domain model — data and the rules governing it live in separate places, so nothing prevents an invalid Order from existing and the invariants get duplicated across every service that touches it"},
        {"id":"c","text":"Primitive obsession; introduce value objects"},
        {"id":"d","text":"A leaky abstraction; hide the ORM"}
      ],
      "correct": "b",
      "explanation": "The entity that owns the data should own the rules about that data — otherwise every caller can construct an invalid object, and the same check gets re-implemented in each service. Behaviour belongs with the state it protects." }
] }
```

## Key takeaways

**The full pattern index, by the question that triggers it:**

| The question | The pattern |
|---|---|
| "How do I add a new type without editing callers?" | Factory / Strategy |
| "How do I add behaviour without subclassing?" | Decorator |
| "How do I make many things react to one change?" | Observer |
| "How do I support undo?" | Command (+ Memento) |
| "How do I stop illegal state transitions?" | State |
| "How do I process a request through configurable steps?" | Chain of Responsibility |
| "How do I treat one and many the same way?" | Composite |
| "How do I fit a third-party API to my interface?" | Adapter |
| "How do I hide a complicated subsystem?" | Facade |
| "How do I control access to an object?" | Proxy |
| "How do I add operations to a fixed type hierarchy?" | Visitor |
| "How do I reduce n-to-n communication?" | Mediator |
| "How do I share state across millions of objects?" | Flyweight |
| "How do I build a complex object safely?" | Builder |
| "How do I guarantee exactly one instance?" | Singleton (and consider injection instead) |

- **Chain of Responsibility is the highest-value pattern in this lesson** — every middleware stack, logging framework, and approval workflow is one, and it appears directly in the rate-limiter and logging-framework designs later in this section.
- **Visitor's trade-off is inverted**: cheap operations, expensive types. Say which way your domain leans.
- **The anti-pattern table is an interview tool.** When an interviewer asks "what's wrong with this design?", you want names and fixes, not vague discomfort.
- **Know when *not* to apply a pattern.** After a catalogue this long, restraint is the differentiator: abstract at the axis that actually varies, and say out loud when you are deliberately keeping something concrete.
