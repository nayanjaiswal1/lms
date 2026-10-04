---
kind: lesson
id_key: interview-prep-45/lld-07-behavioral-patterns-2
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Behavioral Patterns II and Anti-Patterns"
position: 7
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

The remaining behavioral patterns come up less often than Strategy and Observer, but each one is the go-to answer for a specific kind of problem. Chain of Responsibility, especially, is what nearly every piece of middleware, logging library, and approval workflow you've ever used is quietly built from. This lesson finishes the pattern list, then moves on to anti-patterns — because spotting a bad design out loud is worth just as much in an interview as building a good one.

## Chain of Responsibility

**The idea: pass a request down a line of handlers until one of them deals with it** (or every handler has had a turn). Each handler in the chain decides whether to act, whether to pass the request further, or both.

```python
from abc import ABC, abstractmethod

class Handler(ABC):
    def __init__(self): self._next: "Handler | None" = None

    def set_next(self, nxt: "Handler") -> "Handler":
        self._next = nxt
        return nxt                                  # returns nxt, so chains read left-to-right

    def handle(self, request: dict) -> str | None:
        result = self.process(request)
        if result is not None:
            return result                           # this handler dealt with it — stop here
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

**You've already used this everywhere**: HTTP middleware in Express, Django, or Chi, servlet filters, logging libraries (a `DEBUG` handler passes upward until something matches the current level), approval workflows (manager, then director, then VP, depending on amount), and even how a program handles exceptions internally.

Two things worth naming: **the chain can be reconfigured while the program runs** — reorder, add, or remove a handler without touching any other one — and **the sender has no idea which handler will actually respond**, which is exactly where the decoupling this pattern buys you comes from. The risk is that a request can reach the end of the chain with nobody having dealt with it, so always design that final fallback on purpose.

> **Remember:** always decide on purpose what happens when a request reaches the end of the chain with nobody handling it.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-07-cor-q1", "type": "mcq",
      "prompt": "What's the one thing you have to design deliberately in a Chain of Responsibility?",
      "options": [
        {"id":"a","text":"Making sure every handler processes every request"},
        {"id":"b","text":"What happens when a request reaches the end of the chain with nobody having handled it — since the sender has no way of knowing in advance which handler, if any, will respond"},
        {"id":"c","text":"Making sure the chain has an even number of handlers"},
        {"id":"d","text":"Making sure handlers can never be reordered"}
      ],
      "correct": "b",
      "explanation": "The decoupling that makes this pattern useful also means nobody guarantees a handler will actually exist for every request. A default fallback handler (or an explicit \"unhandled\" result) stops requests from silently disappearing." }
] }
```

## Iterator, Mediator, and Memento

**Iterator — the idea: walk through a collection without exposing how it's actually stored inside.** You already use this every time you write a `for` loop. The real design point is that the *code calling it* never has to know whether it's looping over an array, a tree, or a paginated API.

```python
class PaginatedFeed:
    """Looks like a plain sequence to callers; secretly fetches one page at a time."""
    def __init__(self, pages: list[list[str]]):
        self._pages = pages

    def __iter__(self):
        for page in self._pages:                  # imagine each page were a network call
            for item in page:
                yield item                        # a generator basically IS the iterator here


feed = PaginatedFeed([["a", "b"], ["c"], ["d", "e"]])
assert list(feed) == ["a", "b", "c", "d", "e"]
assert sum(1 for _ in feed) == 5                  # can be looped over again
print("streamed lazily:", [x for x in feed][:3])
```

The real value here: swapping the storage from a plain list to a database cursor changes nothing for whoever's calling it. In Python, generators make this pattern nearly invisible — it's worth mentioning that out loud. In Java it's explicit, through `Iterable`/`Iterator`.

**Mediator — the idea: put complicated many-to-many communication in one central place, so objects stop talking to each other directly.** Without it, *n* components that all need to talk to each other could need up to *n(n−1)/2* separate connections. With a mediator, every one of them only needs to know about the mediator itself.

```python
class ChatRoom:                                    # the mediator
    def __init__(self): self._members: dict[str, "User"] = {}

    def join(self, user: "User") -> None:
        self._members[user.name] = user
        user.room = self

    def send(self, sender: str, text: str) -> None:
        for name, user in self._members.items():
            if name != sender:                     # users never reference each other directly
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
assert asha.inbox == []                            # the sender doesn't get their own message back
print("mediated:", ravi.inbox)
```

Worth stating as a warning: **the mediator can turn into a god object all on its own.** It quietly absorbs coordination logic from everywhere and grows without limit. Keep it focused on routing and coordination, and leave the actual domain rules with the participants. Air traffic control, dialog coordination in a UI, and — at a much bigger scale — a message broker are all mediators.

**Memento — the idea: capture and later restore an object's state, without exposing what's inside it.** This is the pattern behind undo, checkpoints, and save games, and it fits naturally alongside Command, which stores the memento it needs in order to reverse itself. The key detail: the memento is **opaque to everyone except the object that made it** — whoever's holding it can pass it around, but can't peek inside or change it, which is what keeps encapsulation intact.

> **Remember:** a mediator that starts holding domain rules, not just routing, has already become the god object it was meant to prevent.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-07-mediator-q1", "type": "mcq",
      "prompt": "What's the main risk of adding a Mediator?",
      "options": [
        {"id":"a","text":"Components become impossible to test"},
        {"id":"b","text":"The mediator ends up absorbing coordination logic from every participant and turns into a god object — it should stick to routing and coordination, and leave the actual domain rules with the participants"},
        {"id":"c","text":"It increases the number of connections between components"},
        {"id":"d","text":"Messages can only reach one recipient at a time"}
      ],
      "correct": "b",
      "explanation": "Mediator trades many-to-many coupling for a single hub, and that hub is exactly where complexity tends to pile up. Keeping it thin is what preserves the benefit in the first place." }
] }
```

## Visitor and Interpreter

**Visitor — the idea: add new operations to a fixed set of types without touching the classes in it.**

Here's the problem it solves: you have a fixed set of node types (a syntax tree, a document tree, a set of shapes) and a growing list of operations you want to run over them (render, export, validate, compute a cost). Putting every operation directly on every node class means editing all of them every single time you add one.

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

class PrettyPrint(Visitor):                    # operation 2 — not one Node class was touched
    def visit_number(self, n): return str(n.value)
    def visit_add(self, n): return f"({n.left.accept(self)} + {n.right.accept(self)})"
    def visit_multiply(self, n): return f"({n.left.accept(self)} * {n.right.accept(self)})"


tree = Multiply(Add(Number(2), Number(3)), Number(4))     # (2 + 3) * 4
assert tree.accept(Evaluate()) == 20
assert tree.accept(PrettyPrint()) == "((2 + 3) * 4)"
print(tree.accept(PrettyPrint()), "=", tree.accept(Evaluate()))
```

**The trade-off here runs exactly backwards from normal polymorphism, and that's the insight to state out loud**: adding a new *operation* is free, just write a new visitor. Adding a new *node type* means editing every single existing visitor. So Visitor is the right call when the type hierarchy is stable and operations keep piling up, like in compilers, document processors, and static analysers, and the wrong call when new types show up often.

**Interpreter — the idea: represent a grammar as classes, and evaluate sentences written in it.** The `Evaluate` visitor above is really a tiny interpreter for a small arithmetic grammar. In real systems you'll meet this in rule engines, query filters, and search-query languages. For anything bigger than that, a real parser generator beats hand-written interpreter classes — it's enough to recognise "this is a parsing problem, not a pattern problem" and say so.

> **Remember:** Visitor flips the usual trade-off — new operations are free, new types are expensive. Know which way your problem actually leans before reaching for it.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-07-visitor-q1", "type": "mcq",
      "prompt": "When is the Visitor pattern actually the right choice?",
      "options": [
        {"id":"a","text":"When new node types get added often but the operations rarely change"},
        {"id":"b","text":"When the set of node types is stable but the operations on them keep growing — a new operation is just a new visitor class, while a new node type means editing every existing visitor"},
        {"id":"c","text":"Whenever there's a tree structure involved at all"},
        {"id":"d","text":"When the structure needs to be traversed in parallel"}
      ],
      "correct": "b",
      "explanation": "Visitor flips the usual extensibility direction: cheap new operations, expensive new types. Getting that direction right for your actual domain is the whole decision here." }
] }
```

## Anti-patterns: recognising bad design out loud

Being able to name a smell and its fix live, mid-interview, is worth just as much as building a clean design in the first place — because that's exactly what a real design review sounds like.

| Anti-pattern | What it looks like | Why it's a problem | The fix |
|---|---|---|---|
| **God object** | `OrderManager` with 40 methods and 15 fields | Every change has to touch it; nothing can be tested on its own | Split it up by why each part would change (SRP) |
| **Anaemic domain model** | Entities that are just getters and setters; all the real logic lives in `*Service` classes | The data and the rules about that data live apart, so invalid states leak through everywhere | Move behaviour onto the entity that actually owns the data |
| **Spaghetti inheritance** | Five-level class trees; subclasses overriding methods just to disable them | Fragile base classes; breaks Liskov Substitution | Composition instead; small, focused interfaces |
| **Primitive obsession** | A plain string standing in for money, an id, a phone number, a currency code | The type system can't stop you mixing them up; checks end up scattered everywhere | Value objects: `Money`, `TicketId` |
| **Magic strings and numbers** | `if status == 3`, `if role == "adm"` | A typo still compiles fine; the meaning is invisible | Enums and named constants |
| **Feature envy** | A method that mostly reads fields from a different class | Coupling to a shape you don't own | Move the method to the class that owns the data |
| **Circular dependency** | `Order` imports `Customer`, which imports `Order` | Neither one can be understood or tested alone | Extract an interface, or invert the dependency |
| **Leaky abstraction** | A `Repository` that hands back a raw ORM query object | Callers end up depending on the storage technology anyway | Return plain domain objects only |
| **Boolean trap** | `save(true, false, true)` | Completely unreadable at the call site | Named arguments, enums, or separate methods |
| **Copy-paste inheritance** | Subclassing purely to reuse one method | Ties two unrelated things together permanently | Pull the shared logic into its own collaborator |
| **Pattern fever** | An interface, a factory, and a strategy for one concrete class that will never have a second | All the extra layers, none of the payoff | Delete it. Add the abstraction the day a second case actually shows up |

That last row deserves special attention, because after a whole pattern catalogue it's tempting to use every one of them: **the single most common mistake after learning these patterns is reaching for one where a plain class would have done fine.** An interface with one implementation and no realistic second one is a cost with no benefit. Often the strongest possible answer is: "I'd keep this concrete for now. If a second pricing rule ever shows up, this is exactly where the strategy would go." That shows you know both the pattern *and* its price.

> **Remember:** the entity that owns the data should own the rules about it too. Data and logic living apart is an anaemic domain model, and it's the most common structural mistake in real codebases.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-07-antipattern-q1", "type": "mcq",
      "prompt": "A design has `Order` as a bag of getters and setters, with every rule — validation, totals, state transitions — living inside `OrderService`. What's this called, and why is it a problem?",
      "options": [
        {"id":"a","text":"A god object — split the service into smaller services"},
        {"id":"b","text":"An anaemic domain model — the data and the rules about that data live in separate places, so nothing stops an invalid Order from existing, and the same checks get re-implemented in every service that touches it"},
        {"id":"c","text":"Primitive obsession — introduce value objects"},
        {"id":"d","text":"A leaky abstraction — hide the ORM"}
      ],
      "correct": "b",
      "explanation": "Whatever owns the data should own the rules about it — otherwise any caller can build an invalid object, and the same validation ends up copy-pasted into every service that touches it. Behaviour belongs right next to the state it protects." }
] }
```

## Quick recap

**What question triggers which pattern:**

| The question you're being asked | The pattern |
|---|---|
| "How do I add a new type without editing every caller?" | Factory / Strategy |
| "How do I add behaviour without subclassing?" | Decorator |
| "How do I make several things react to one change?" | Observer |
| "How do I support undo?" | Command (plus Memento) |
| "How do I stop illegal state transitions?" | State |
| "How do I run a request through configurable steps?" | Chain of Responsibility |
| "How do I treat one thing and a group of them the same way?" | Composite |
| "How do I fit a third-party API to my own interface?" | Adapter |
| "How do I hide a messy subsystem?" | Facade |
| "How do I control access to an object?" | Proxy |
| "How do I add operations to a fixed set of types?" | Visitor |
| "How do I cut down n-to-n communication?" | Mediator |
| "How do I share state across millions of objects?" | Flyweight |
| "How do I safely build a complicated object?" | Builder |
| "How do I guarantee exactly one instance exists?" | Singleton (and consider injecting it instead) |

- **Chain of Responsibility is the single most valuable pattern in this lesson** — every middleware stack, logging library, and approval workflow is one, and you'll meet it directly in the rate-limiter and logging-framework designs later in this section.
- **Visitor's trade-off runs backwards from usual polymorphism**: cheap new operations, expensive new types. Say which way your domain actually leans.
- **The anti-pattern table is an interview tool in itself.** When someone asks "what's wrong with this design?", you want names and fixes ready, not just a vague sense that something feels off.
- **Know when *not* to reach for a pattern.** After a catalogue this long, restraint is what separates a strong answer from a weak one — abstract exactly where things actually vary, and say out loud when you're deliberately choosing to keep something simple.
