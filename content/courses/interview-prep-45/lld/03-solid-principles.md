---
kind: lesson
id_key: interview-prep-45/lld-03-solid
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "SOLID Principles"
position: 3
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

SOLID is the vocabulary interviewers reach for when they explain why one design beats another. That's exactly why "explain SOLID with an example" is one of the most common LLD questions there is. Just reciting the five names earns you nothing. What actually earns points is showing a bad design, naming the exact principle it breaks, and fixing it — which is exactly how each section below is built.

Hold onto this one idea: **every SOLID principle exists to make change cheap.** Each one answers the same question in a different way: "when the requirements change, how much code has to change with them?"

## S — Single Responsibility Principle

> A class should have one reason to change.

"One reason to change" is a sharper test than "does one thing." Here's the actual question to ask: **who, in the real world, would ask for a change to this class?** If the finance team, the design team, and the ops team could all separately trigger an edit, that class has three jobs, not one.

```
# BROKEN — three different people can ask for a change here, all in one class.
class BadReport:
    def compute(self, rows): ...        # finance changes the formula
    def to_pdf(self): ...               # design changes the layout
    def email(self, to): ...            # ops changes the mail server
```

```python
from dataclasses import dataclass

# FIXED — each class changes for exactly one reason.
@dataclass(frozen=True)
class SalesReport:
    total_paise: int
    rows: int

class ReportCalculator:              # changes when the business rule changes
    def compute(self, sales: list[int]) -> SalesReport:
        return SalesReport(total_paise=sum(sales), rows=len(sales))

class ReportPdfRenderer:             # changes when the layout changes
    def render(self, report: SalesReport) -> bytes:
        return f"PDF<total={report.total_paise},rows={report.rows}>".encode()

class ReportMailer:                  # changes when the way we deliver it changes
    def __init__(self, transport): self.transport = transport
    def send(self, to: str, document: bytes) -> None:
        self.transport.send(to, document)


class FakeTransport:
    def __init__(self): self.outbox = []
    def send(self, to, doc): self.outbox.append((to, doc))

report = ReportCalculator().compute([10_000, 25_000, 5_000])
pdf = ReportPdfRenderer().render(report)
transport = FakeTransport()
ReportMailer(transport).send("cfo@mindforge.test", pdf)

assert report.total_paise == 40_000
assert transport.outbox[0][0] == "cfo@mindforge.test"
print("report pipeline ok:", pdf.decode())
```

The real win here isn't tidiness — it's that the calculator can now be tested with no PDF library and no mail server at all, and a layout tweak can never accidentally break the arithmetic.

**One trap to watch for: don't overdo this.** Splitting one class into six classes with one tiny method each isn't SRP, it's just thin, scattered design. Group things by *why they'd change*, not by how few lines they have.

> **Remember:** the test for SRP isn't "does this do one thing" — it's "could two different teams ask for two different changes here?"

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-srp-q1", "type": "mcq",
      "prompt": "What's the sharpest way to test whether a class breaks the Single Responsibility Principle?",
      "options": [
        {"id":"a","text":"Whether it has more than 200 lines of code"},
        {"id":"b","text":"Whether more than one group of people could each independently ask for a change to it — finance changing a formula, design changing a layout, ops changing a mail server means three separate reasons to change"},
        {"id":"c","text":"Whether it has more than five methods"},
        {"id":"d","text":"Whether it uses more than one interface"}
      ],
      "correct": "b",
      "explanation": "SRP is about who can trigger a change, not about size. A 400-line class that only ever changes for one reason is fine. A 40-line class that three separate teams keep editing is not." }
] }
```

## O — Open/Closed Principle

> Open for extension, closed for modification.

Adding a new behaviour should mean **writing new code**, never **editing code that already works**. The warning sign is a growing `if/elif` chain built around a type or a name.

```python
# BROKEN — every new payment method means editing this method, risking the ones already there.
class BadProcessor:
    def pay(self, method: str, paise: int) -> str:
        if method == "card":
            return f"charged card {paise}"
        elif method == "upi":
            return f"charged upi {paise}"
        # elif "wallet" ... elif "netbanking" ... forever
        raise ValueError(method)
```

```python
from abc import ABC, abstractmethod

class PaymentMethod(ABC):
    @abstractmethod
    def pay(self, paise: int) -> str: ...

class Card(PaymentMethod):
    def pay(self, paise: int) -> str: return f"charged card {paise}"

class Upi(PaymentMethod):
    def pay(self, paise: int) -> str: return f"charged upi {paise}"

class Wallet(PaymentMethod):                 # NEW — added, nothing else touched
    def pay(self, paise: int) -> str: return f"charged wallet {paise}"

class Checkout:
    def pay(self, method: PaymentMethod, paise: int) -> str:
        return method.pay(paise)             # this method never has to change again


checkout = Checkout()
assert checkout.pay(Card(), 49_900) == "charged card 49900"
assert checkout.pay(Wallet(), 1_000) == "charged wallet 1000"
print(checkout.pay(Upi(), 25_000))
```

**How do you know which direction to keep open?** You can't design a class that's open to literally every possible future change — that's just over-engineering with extra steps. Open it along the specific direction the requirements point to: "we'll keep adding new payment methods" means open there. "The tax formula is fixed by law and only changes once a decade" means leave that part concrete.

**Where this shows up in real systems**: strategy objects, plugin registries, event listeners, and — the simplest version of all — a plain dictionary lookup replacing an `if/elif` chain.

> **Remember:** a growing `if/elif` on a type or a name is the tell. Every new branch is a risk to everything already working.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-ocp-q1", "type": "mcq",
      "prompt": "Which code smell most reliably points to an Open/Closed violation?",
      "options": [
        {"id":"a","text":"A class with private fields"},
        {"id":"b","text":"A growing if/elif chain that switches on a type or a name, where every new variant means editing (and risking) code that already works"},
        {"id":"c","text":"A method with two parameters"},
        {"id":"d","text":"Using an abstract base class"}
      ],
      "correct": "b",
      "explanation": "The chain is the exact spot that gets edited. Replacing it with polymorphism — or even just a dictionary lookup — turns \"edit and retest this method\" into \"add a class.\"" }
] }
```

## L — Liskov Substitution Principle

> Anywhere code expects the parent type, a child type must work too, without the caller noticing the difference.

This principle decides whether inheritance was even the right call, and its violations tend to be sneaky.

```python
# BROKEN — the textbook example. A square IS a rectangle in geometry, but not safely in code.
class Rectangle:
    def __init__(self, w, h): self._w, self._h = w, h
    def set_width(self, w): self._w = w
    def set_height(self, h): self._h = h
    def area(self): return self._w * self._h

class Square(Rectangle):
    def __init__(self, side): super().__init__(side, side)
    def set_width(self, w): self._w = self._h = w      # forced to keep both sides equal
    def set_height(self, h): self._w = self._h = h

def client_expects_rectangle_behaviour(r: Rectangle) -> int:
    r.set_width(5)
    r.set_height(4)
    return r.area()          # any real Rectangle: 20

assert client_expects_rectangle_behaviour(Rectangle(1, 1)) == 20
assert client_expects_rectangle_behaviour(Square(1)) == 16      # ← this is the broken substitution
print("Square breaks the Rectangle contract: 16 != 20")
```

The subclass didn't add anything — it quietly *took away* a promise the parent made ("width and height change independently"). The real fix isn't a clever workaround, it's to stop inheriting altogether: make `Shape` an interface with just `area()`, and let `Square` and `Rectangle` be separate, unchangeable value objects that both implement it.

**Four rules a child type actually has to follow:**

| Rule | What it means | What breaking it looks like |
|---|---|---|
| **Never demand more from callers** | The child can't require stricter input than the parent did | Parent accepts any number; child insists on a positive one |
| **Never deliver less than promised** | The child must give back at least what the parent guaranteed | Parent promises a sorted list; child hands back an unsorted one |
| **Keep the parent's rules intact** | Whatever the parent guaranteed still has to hold | `Square` breaking the "sides move independently" rule above |
| **No surprise failures** | Callers shouldn't get an exception they never expected | A subclass throws an error from a method the parent never throws from |

That last row is the most common one you'll actually see in real code: a `ReadOnlyList` that inherits `List` and then throws whenever someone calls `add()`. If a subclass has to say "sorry, this doesn't apply to me," the class tree itself is wrong — split the interface instead, which is exactly the next principle.

> **Remember:** if a subclass throws on a method its parent promised would work, the class tree is broken — not the caller.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-lsp-q1", "type": "mcq",
      "prompt": "A `ReadOnlyCollection` extends `Collection` and throws an exception whenever `add()` is called. Which principle does this break, and what's the fix?",
      "options": [
        {"id":"a","text":"Single Responsibility — split the class into two"},
        {"id":"b","text":"Liskov Substitution — code holding a plain `Collection` can no longer safely call `add()`. Fix it by splitting the interface: a read-only base and a separate mutable one that extends it"},
        {"id":"c","text":"Open/Closed — add a flag instead of throwing"},
        {"id":"d","text":"Dependency Inversion — inject the collection instead"}
      ],
      "correct": "b",
      "explanation": "Throwing from a method the parent type promised would work breaks the substitution guarantee. The real fix is usually a narrower interface — LSP problems are very often ISP problems wearing a different name." }
] }
```

## I — Interface Segregation Principle

> Nobody should be forced to depend on a method they'll never use.

```python
from abc import ABC, abstractmethod

# BROKEN — one wide interface forces a meaningless implementation.
class BadWorker(ABC):
    @abstractmethod
    def work(self): ...
    @abstractmethod
    def eat(self): ...

class Robot(BadWorker):
    def work(self): return "working"
    def eat(self): raise NotImplementedError("robots don't eat")   # ← forced to write this
```

```python
from abc import ABC, abstractmethod

# FIXED — small, focused interfaces; each class implements only what it actually is.
class Workable(ABC):
    @abstractmethod
    def work(self) -> str: ...

class Feedable(ABC):
    @abstractmethod
    def eat(self) -> str: ...

class Human(Workable, Feedable):
    def work(self) -> str: return "working"
    def eat(self) -> str: return "eating"

class Robot(Workable):                       # nothing meaningless to implement anymore
    def work(self) -> str: return "working"

def run_shift(workers: list[Workable]) -> list[str]:
    return [w.work() for w in workers]       # only depends on what it actually needs


assert run_shift([Human(), Robot()]) == ["working", "working"]
assert Human().eat() == "eating"
assert not hasattr(Robot, "eat")
print("segregated interfaces ok")
```

**The practical tell**: any method body that's just `pass`, `return null`, or an exception saying "not implemented." Every single one of those is proof that the interface asked for more than that class actually is.

There's a related idea worth knowing by name: **role interfaces**. Instead of one giant `UserService` with twenty methods, split it into `UserReader`, `UserWriter`, `PasswordResetter`. Each piece of code that uses it only depends on the two methods it actually calls, so a change to password logic can't accidentally break code that only reads users. It also makes your test doubles small — a fake with two methods instead of twenty.

> **Remember:** a method body that just throws "not implemented" is proof the interface promised more than that class actually is.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-isp-q1", "type": "mcq",
      "prompt": "What's the clearest practical sign of an Interface Segregation violation?",
      "options": [
        {"id":"a","text":"An interface with more than three methods"},
        {"id":"b","text":"An implementation with an empty body, a `return null`, or a \"not implemented\" exception — proof that the interface demands more than that class actually is"},
        {"id":"c","text":"Two classes implementing the same interface"},
        {"id":"d","text":"An interface used by only one class"}
      ],
      "correct": "b",
      "explanation": "Method count alone doesn't prove anything — a cohesive interface can have several methods. The real evidence is an implementer that's forced to supply a method that means nothing for it, which also breaks Liskov the moment anyone calls it." }
] }
```

## D — Dependency Inversion Principle

> High-level code shouldn't depend on low-level details. Both should depend on an abstraction — and the abstraction shouldn't depend on the details either.

```
# BROKEN — the business rule is welded directly to MySQL and to SMTP.
class BadOrderService:
    def __init__(self):
        self.db = "MySQLConnection(...)"      # builds its own low-level detail
    def place(self, order): ...               # can't test this without a real database
```

```python
from abc import ABC, abstractmethod

# The interface belongs to the HIGH-level module and speaks its language, not the database's.
class OrderRepository(ABC):
    @abstractmethod
    def save(self, order: dict) -> str: ...

class Notifier(ABC):
    @abstractmethod
    def notify(self, to: str, message: str) -> None: ...

class OrderService:                            # high level: pure business rules
    def __init__(self, repo: OrderRepository, notifier: Notifier):
        self.repo, self.notifier = repo, notifier

    def place(self, order: dict) -> str:
        if order["total_paise"] <= 0:
            raise ValueError("order total must be positive")
        order_id = self.repo.save(order)
        self.notifier.notify(order["email"], f"Order {order_id} placed")
        return order_id

# Low level: the details depend on the abstraction, never the other way around.
class InMemoryOrderRepository(OrderRepository):
    def __init__(self): self.saved: dict[str, dict] = {}
    def save(self, order: dict) -> str:
        oid = f"ord_{len(self.saved) + 1}"
        self.saved[oid] = order
        return oid

class RecordingNotifier(Notifier):
    def __init__(self): self.messages: list[tuple[str, str]] = []
    def notify(self, to: str, message: str) -> None: self.messages.append((to, message))


repo, notifier = InMemoryOrderRepository(), RecordingNotifier()
order_id = OrderService(repo, notifier).place({"total_paise": 49_900, "email": "a@mindforge.test"})

assert order_id == "ord_1" and repo.saved[order_id]["total_paise"] == 49_900
assert notifier.messages == [("a@mindforge.test", "Order ord_1 placed")]
print("business logic tested with zero infrastructure:", order_id)
```

**The subtlety worth stating out loud in an interview**: what actually "inverts" is the *direction* of the dependency. Before: `OrderService → MySQLRepository`. After: both point at `OrderRepository` instead — and critically, that interface belongs to the business layer and is written in business language (`save(order)`), not database language (`executeQuery`). That's what makes swapping Postgres for DynamoDB a change in exactly one file.

**You've probably already used this without naming it.** FastAPI's `Depends()` is Dependency Inversion, applied at the framework level:

```python
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/orders/{order_id}")
def read_order(order_id: int, db: Session = Depends(get_db)):
    return db.query(Order).get(order_id)
```

The endpoint function depends on whatever `Depends(get_db)` resolves to — a real database session in production, a test session in your test suite. Swapping one for the other never means touching the endpoint function at all. That's this whole principle, doing its job, and you've likely already relied on it without stopping to name it.

This is also the reasoning behind hexagonal ("ports and adapters") architecture, and it's exactly why the test above needed no database, no network call, and no mocking library at all.

> **Remember:** the interface belongs to the business layer, written in its language — not to the database layer.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-dip-q1", "type": "mcq",
      "prompt": "In Dependency Inversion, which side should own and define the `OrderRepository` interface?",
      "options": [
        {"id":"a","text":"The database layer, since it's the one implementing it"},
        {"id":"b","text":"The high-level business layer — the interface is written in business language (`save(order)`), and the low-level adapter implements it, which is exactly what inverts the direction of the dependency"},
        {"id":"c","text":"A shared utility package that neither layer owns"},
        {"id":"d","text":"Whichever layer has fewer classes"}
      ],
      "correct": "b",
      "explanation": "If the persistence layer owns the interface, the business layer still points at persistence, and nothing was actually inverted. The business layer owning it is what lets you swap the adapter without touching a business rule." }
] }
```

## Quick recap

**Principle, warning sign, fix:**

| | Principle | Warning sign | Fix |
|---|---|---|---|
| **S** | One reason to change | A class three different teams keep editing; names like `Manager`/`Util` | Split it up by reason to change |
| **O** | Open to add, closed to edit | A growing `if/elif` on a type | Polymorphism, a strategy object, or a registry |
| **L** | Children are safely swappable for parents | An override that throws, or quietly weakens a guarantee | Split the class tree; lean on composition instead |
| **I** | No forced, unused dependencies | "Not implemented" bodies, empty methods | Small, focused interfaces |
| **D** | Depend on abstractions | Building infrastructure directly inside business logic | Inject an interface the business layer owns |

- **All five come down to one goal: making change cheap.** When someone asks "why does SOLID even matter," answer with a change, not a definition: "adding a payment method should mean adding a class, not editing a switch statement."
- **Present them as fixes, not definitions.** "Here's the broken version, here's what it breaks, here's the fix" is the format that actually scores points.
- **They lean on each other.** An LSP break is usually an ISP problem underneath. OCP is usually achieved by applying DIP. SRP is what makes all the others even possible.
- **They can absolutely be overdone.** Five one-method classes and an interface for every concrete type isn't SOLID — it's ceremony. Apply each principle where the requirements genuinely say something will change, and be ready to say out loud when you're deliberately choosing *not* to abstract something. That restraint is itself a senior-level signal.
