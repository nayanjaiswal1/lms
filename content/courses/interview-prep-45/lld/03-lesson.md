---
kind: lesson
id_key: interview-prep-45/lld-03-solid
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "SOLID Principles"
position: 3
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

SOLID is the vocabulary interviewers use to explain *why* one design is better than another, which is why "explain SOLID with an example" is one of the most-asked LLD questions. Reciting the five names earns nothing. What earns points is showing a bad design, naming the principle it violates, and refactoring it — which is exactly how each section below is structured.

The one thing to hold on to: **every SOLID principle is about making change cheap.** They all answer the question "when the requirements change, how much code has to change?"

## S — Single Responsibility Principle

> A class should have one reason to change.

"One reason to change" is stricter and more useful than "does one thing". The test: **who asks for changes to this class?** If the finance team, the ops team, and the marketing team can all cause an edit, it has three responsibilities.

```
# VIOLATION — three actors, three reasons to change, one class.
class BadReport:
    def compute(self, rows): ...        # finance changes the formula
    def to_pdf(self): ...               # design changes the layout
    def email(self, to): ...            # ops changes the mail server
```

```python
from dataclasses import dataclass

# REFACTORED — each class changes for exactly one reason.
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

class ReportMailer:                  # changes when delivery changes
    def __init__(self, transport): self.transport = transport
    def send(self, to: str, document: bytes) -> None:
        self.transport.send(to, document)


class FakeTransport:
    def __init__(self): self.outbox = []
    def send(self, to, doc): self.outbox.append((to, doc))

report = ReportCalculator().compute([10_000, 25_000, 5_000])
pdf = ReportPdfRenderer().render(report)
transport = FakeTransport()
ReportMailer(transport).send("cfo@example.com", pdf)

assert report.total_paise == 40_000
assert transport.outbox[0][0] == "cfo@example.com"
print("report pipeline ok:", pdf.decode())
```

The payoff is not aesthetic: the calculator is now unit-testable with no PDF library and no mail server, and a layout change cannot break the arithmetic.

**Where people over-apply it**: splitting a class into six classes with one method each is not SRP, it is anaemic design. Group by *reason to change*, not by *line count*.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-srp-q1", "type": "mcq",
      "prompt": "What is the sharpest test for whether a class violates the Single Responsibility Principle?",
      "options": [
        {"id":"a","text":"Whether it has more than 200 lines"},
        {"id":"b","text":"Whether more than one group of stakeholders can request a change to it — finance changing a formula, design changing a layout, and ops changing a mail server means three reasons to change"},
        {"id":"c","text":"Whether it has more than five methods"},
        {"id":"d","text":"Whether it uses more than one interface"}
      ],
      "correct": "b",
      "explanation": "SRP is about axes of change, not size. A 400-line class that only ever changes when one rule changes is fine; a 40-line class that three teams edit is not." }
] }
```

## O — Open/Closed Principle

> Open for extension, closed for modification.

Adding behaviour should mean **adding code**, not **editing working code**. The tell is a growing `if/elif` chain on a type or a name.

```python
# VIOLATION — every new payment method edits this method and risks the existing ones.
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

class Wallet(PaymentMethod):                 # NEW: added, nothing edited
    def pay(self, paise: int) -> str: return f"charged wallet {paise}"

class Checkout:
    def pay(self, method: PaymentMethod, paise: int) -> str:
        return method.pay(paise)             # closed: never changes again


checkout = Checkout()
assert checkout.pay(Card(), 49_900) == "charged card 49900"
assert checkout.pay(Wallet(), 1_000) == "charged wallet 1000"
print(checkout.pay(Upi(), 25_000))
```

**How to spot the axis to open.** You cannot make a class open to *every* possible change — that is over-engineering. Open it along the axis the requirements say will vary: "we will keep adding payment methods" → open there; "the tax formula is fixed by law and changes once a decade" → leave it concrete.

**Where OCP lives in the real world**: strategy objects, plugin registries, event subscribers, and — the humblest version — a dictionary lookup replacing an `if` chain.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-ocp-q1", "type": "mcq",
      "prompt": "Which code smell most reliably signals an Open/Closed violation?",
      "options": [
        {"id":"a","text":"A class with private fields"},
        {"id":"b","text":"A growing if/elif chain that switches on a type or name, so each new variant requires editing (and risking) tested code"},
        {"id":"c","text":"A method with two parameters"},
        {"id":"d","text":"Use of an abstract base class"}
      ],
      "correct": "b",
      "explanation": "The chain is the modification point. Replacing it with polymorphic dispatch — or a registry lookup — turns \"edit and retest this method\" into \"add a class\"." }
] }
```

## L — Liskov Substitution Principle

> A subtype must be usable anywhere its base type is expected, without the caller knowing.

This is the principle that decides whether inheritance was the right call, and its violations are subtle.

```python
# VIOLATION — the classic. A square IS-A rectangle in geometry, not in code.
class Rectangle:
    def __init__(self, w, h): self._w, self._h = w, h
    def set_width(self, w): self._w = w
    def set_height(self, h): self._h = h
    def area(self): return self._w * self._h

class Square(Rectangle):
    def __init__(self, side): super().__init__(side, side)
    def set_width(self, w): self._w = self._h = w      # must keep sides equal
    def set_height(self, h): self._w = self._h = h

def client_expects_rectangle_behaviour(r: Rectangle) -> int:
    r.set_width(5)
    r.set_height(4)
    return r.area()          # any Rectangle: 20

assert client_expects_rectangle_behaviour(Rectangle(1, 1)) == 20
assert client_expects_rectangle_behaviour(Square(1)) == 16      # ← broken substitution
print("Square breaks the Rectangle contract: 16 != 20")
```

The subclass did not add behaviour — it *removed a guarantee* the base class made ("width and height are independent"). The fix is not clever inheritance; it is to stop inheriting: make `Shape` an interface with `area()`, and let `Square` and `Rectangle` be immutable value objects that both implement it.

**The four rules a subtype must respect:**

| Rule | Meaning | Violation |
|---|---|---|
| **Preconditions may not be strengthened** | The subtype cannot demand more from callers | Base accepts any int; subtype requires positive |
| **Postconditions may not be weakened** | The subtype must deliver at least as much | Base guarantees a sorted list; subtype returns unsorted |
| **Invariants must be preserved** | The base's rules still hold | `Square` breaking independent sides |
| **No new exceptions** | Callers cannot be surprised | Subtype throws `NotImplementedError` for an inherited method |

That last row is the most common real-world violation: a `ReadOnlyList` inheriting `List` and throwing on `add()`. If the subclass has to say "this operation doesn't apply to me", the hierarchy is wrong — split the interface (which is exactly the next principle).

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-lsp-q1", "type": "mcq",
      "prompt": "A `ReadOnlyCollection` extends `Collection` and throws `UnsupportedOperationException` from `add()`. Which principle does this violate and what is the fix?",
      "options": [
        {"id":"a","text":"Single Responsibility; split the class in two"},
        {"id":"b","text":"Liskov Substitution — code holding a `Collection` cannot safely call `add()` any more. Fix by splitting the interface: a read-only `Iterable` contract and a separate `MutableCollection` that extends it"},
        {"id":"c","text":"Open/Closed; add a flag instead of throwing"},
        {"id":"d","text":"Dependency Inversion; inject the collection"}
      ],
      "correct": "b",
      "explanation": "Throwing from an inherited method introduces an exception callers of the base type do not expect, breaking substitutability. The structural fix is a narrower base interface — LSP violations are very often ISP problems in disguise." }
] }
```

## I — Interface Segregation Principle

> No client should be forced to depend on methods it does not use.

```python
from abc import ABC, abstractmethod

# VIOLATION — one fat interface forces meaningless implementations.
class BadWorker(ABC):
    @abstractmethod
    def work(self): ...
    @abstractmethod
    def eat(self): ...

class Robot(BadWorker):
    def work(self): return "working"
    def eat(self): raise NotImplementedError("robots don't eat")   # ← forced
```

```python
from abc import ABC, abstractmethod

# REFACTORED — small role interfaces; classes implement only what they are.
class Workable(ABC):
    @abstractmethod
    def work(self) -> str: ...

class Feedable(ABC):
    @abstractmethod
    def eat(self) -> str: ...

class Human(Workable, Feedable):
    def work(self) -> str: return "working"
    def eat(self) -> str: return "eating"

class Robot(Workable):                       # no meaningless method to implement
    def work(self) -> str: return "working"

def run_shift(workers: list[Workable]) -> list[str]:
    return [w.work() for w in workers]       # depends only on what it uses


assert run_shift([Human(), Robot()]) == ["working", "working"]
assert Human().eat() == "eating"
assert not hasattr(Robot, "eat")
print("segregated interfaces ok")
```

**The practical signal** is any implementation whose body is `pass`, `return null`, or `throw NotImplemented`. Each one is an interface that is too wide.

The related idea worth naming: **role interfaces**. Instead of one `IUserService` with twenty methods, define `UserReader`, `UserWriter`, `PasswordResetter` — each consumer depends on the two methods it needs, so a change to password logic cannot break the code that only reads users. This is also what makes test doubles small: a fake that implements two methods rather than twenty.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-isp-q1", "type": "mcq",
      "prompt": "What is the clearest practical signal of an Interface Segregation violation?",
      "options": [
        {"id":"a","text":"An interface with more than three methods"},
        {"id":"b","text":"Implementations containing empty bodies, `return null`, or `throw NotImplemented` — proof that the interface demands more than that implementer actually is"},
        {"id":"c","text":"Two classes implementing the same interface"},
        {"id":"d","text":"An interface used by only one class"}
      ],
      "correct": "b",
      "explanation": "Method count alone is not the test — a cohesive interface can have several methods. The evidence is implementers forced to supply a method that means nothing for them, which also breaks Liskov for any caller who invokes it." }
] }
```

## D — Dependency Inversion Principle

> High-level modules should not depend on low-level modules; both should depend on abstractions. Abstractions should not depend on details; details should depend on abstractions.

```
# VIOLATION — the business rule is welded to MySQL and to SMTP.
class BadOrderService:
    def __init__(self):
        self.db = "MySQLConnection(...)"      # constructs its own low-level detail
    def place(self, order): ...               # untestable without a real database
```

```python
from abc import ABC, abstractmethod

# The abstraction is owned by the HIGH-level module and expressed in its language.
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

# Low level: details depend on the abstraction, never the other way round.
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
order_id = OrderService(repo, notifier).place({"total_paise": 49_900, "email": "a@example.com"})

assert order_id == "ord_1" and repo.saved[order_id]["total_paise"] == 49_900
assert notifier.messages == [("a@example.com", "Order ord_1 placed")]
print("business logic tested with zero infrastructure:", order_id)
```

**The subtlety worth stating in an interview**: the *direction of the dependency* is what inverts. Normally `OrderService → MySQLRepository`. After inversion, both point at `OrderRepository` — and crucially, that interface belongs to the business layer and is written in business language (`save(order)`), not database language (`executeQuery`). That is what makes swapping Postgres for DynamoDB a change in one file.

This is also the principle behind hexagonal / ports-and-adapters architecture, and it is why the test above needed no database, no network, and no mocking framework.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-03-dip-q1", "type": "mcq",
      "prompt": "In Dependency Inversion, which module should own and define the `OrderRepository` interface?",
      "options": [
        {"id":"a","text":"The database layer, since it implements it"},
        {"id":"b","text":"The high-level business layer — the interface is written in domain language (`save(order)`) and the low-level adapter implements it, which is precisely what inverts the dependency direction"},
        {"id":"c","text":"A shared utility package that neither layer owns"},
        {"id":"d","text":"Whichever layer has fewer classes"}
      ],
      "correct": "b",
      "explanation": "If the persistence layer owns the interface, the business layer still points at persistence and nothing was inverted. Ownership by the domain is what lets you replace the adapter without touching a business rule." }
] }
```

## Key takeaways

**The recall card — principle, violation smell, fix:**

| | Principle | Smell | Fix |
|---|---|---|---|
| **S** | One reason to change | A class three teams edit; `Manager`/`Util` names | Split by axis of change |
| **O** | Open to extension, closed to modification | Growing `if/elif` on a type | Polymorphism, strategy, registry |
| **L** | Subtypes are substitutable | Overrides that throw, or weaken a guarantee | Split the hierarchy; prefer composition |
| **I** | No forced dependencies | `NotImplemented` / empty method bodies | Small role interfaces |
| **D** | Depend on abstractions | `new` / direct construction of infrastructure inside business logic | Inject an interface owned by the domain |

- **All five reduce to one goal: make change cheap.** When asked "why does SOLID matter", answer with the change, not the definition: "adding a payment method should add a class, not edit a switch."
- **Present them as refactorings, not definitions.** "Here's the violation, here's the smell, here's the fix" is the format that scores.
- **They interact.** LSP violations are usually ISP problems; OCP is usually achieved through DIP; SRP is what makes all the others possible.
- **They can be over-applied.** Five one-method classes and an interface per concrete type is not SOLID, it is ceremony. Apply each principle at an axis the requirements say will actually vary — and be ready to say that out loud, because knowing when *not* to abstract is itself a senior signal.
