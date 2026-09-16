---
kind: lesson
id_key: interview-prep-45/lld-02-oop-foundations
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "OOP Foundations for Design"
position: 2
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Everybody can recite the four pillars. Very few can say *why* encapsulation matters in a design review, or when inheritance is the wrong tool, or what "coupling" costs in concrete terms. That gap is what this lesson closes — the pillars restated as design decisions you defend, plus the two ideas (composition over inheritance, coupling and cohesion) that decide most LLD outcomes.

## The four pillars, as design arguments

**Encapsulation — hide state, expose behaviour.** The point is not `private` keywords; it is that **an object should never be able to be put into an invalid state by its callers**.

```python
# Weak: the invariant "balance never goes negative" lives in every caller.
class BadAccount:
    def __init__(self):
        self.balance = 0          # anyone can write anything

# Strong: the invariant lives in one place, and the class enforces it.
class Account:
    def __init__(self, opening_paise: int = 0):
        if opening_paise < 0:
            raise ValueError("opening balance cannot be negative")
        self._balance = opening_paise      # private by convention

    @property
    def balance(self) -> int:              # read-only view
        return self._balance

    def deposit(self, paise: int) -> None:
        if paise <= 0:
            raise ValueError("deposit must be positive")
        self._balance += paise

    def withdraw(self, paise: int) -> None:
        if paise > self._balance:
            raise ValueError("insufficient funds")
        self._balance -= paise


acct = Account(10_000)
acct.deposit(5_000)
acct.withdraw(2_000)
assert acct.balance == 13_000

for bad in (lambda: acct.withdraw(999_999), lambda: acct.deposit(-1), lambda: Account(-5)):
    try:
        bad()
        raise AssertionError("invalid operation was allowed")
    except ValueError:
        pass
print("invariants held; balance =", acct.balance)
```

The design payoff: when a bug says "balance went negative", there are three methods to inspect, not the whole codebase. **Getters and setters for every field are not encapsulation** — a public setter is a public field with extra typing. Expose *operations* (`withdraw`), not *fields*.

**Abstraction — expose what, hide how.** `PaymentProcessor.charge(amount)` says nothing about Stripe or Razorpay, so the caller cannot depend on either. Abstraction is what makes substitution possible; encapsulation is what keeps state valid. They are frequently confused, and the one-line distinction is: **encapsulation hides data, abstraction hides implementation.**

**Inheritance — share a contract, not code.** The legitimate use is "these things are genuinely substitutable for one another". Inheriting merely to reuse a method is the most common design mistake in LLD, covered in the next section.

**Polymorphism — one call site, many behaviours.** This is what removes conditional chains:

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self) -> float: ...

class Circle(Shape):
    def __init__(self, r: float): self.r = r
    def area(self) -> float: return 3.14159 * self.r ** 2

class Rectangle(Shape):
    def __init__(self, w: float, h: float): self.w, self.h = w, h
    def area(self) -> float: return self.w * self.h

# One call site. Adding Triangle requires editing nothing here.
shapes: list[Shape] = [Circle(1), Rectangle(2, 3)]
total = sum(s.area() for s in shapes)
assert abs(total - 9.14159) < 1e-6
print(f"total area = {total:.5f}")
```

The test for whether polymorphism is doing its job: **can you add a new type without editing existing code?** If adding `Triangle` means finding an `if shape_type == ...` chain, you have types without polymorphism.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-02-pillars-q1", "type": "mcq",
      "prompt": "A class exposes a public getter and setter for every private field. What has actually been achieved?",
      "options": [
        {"id":"a","text":"Proper encapsulation, since the fields are private"},
        {"id":"b","text":"Essentially nothing — a public setter is a public field with more typing; encapsulation means exposing operations that preserve invariants (`withdraw`), not accessors that let callers set any value"},
        {"id":"c","text":"Abstraction, because callers use methods"},
        {"id":"d","text":"Polymorphism, because setters can be overridden"}
      ],
      "correct": "b",
      "explanation": "Encapsulation is about who is responsible for the object's invariants. If any caller can assign any value, the invariant lives in the callers — which is exactly the state encapsulation is supposed to prevent." }
] }
```

## Composition over inheritance

The single most useful design heuristic in LLD, and the one interviewers probe hardest.

**The problem with inheritance** is that it is the tightest coupling a language offers: a subclass depends on its parent's *implementation*, not just its interface. Change the parent and every subclass may break — the "fragile base class" problem. And it is single-axis: the moment two independent things vary, the hierarchy explodes.

```
Vehicle
├── ElectricCar
├── PetrolCar
├── ElectricTruck        combinatorial explosion:
├── PetrolTruck          (fuel type) × (body type) × (transmission) = one class each
├── ElectricMotorcycle
└── ...
```

**The fix is composition**: model each varying axis as a collaborator the object *has*, rather than a branch of a hierarchy it *is*.

```python
from abc import ABC, abstractmethod

class Engine(ABC):
    @abstractmethod
    def start(self) -> str: ...

class PetrolEngine(Engine):
    def start(self) -> str: return "vroom"

class ElectricMotor(Engine):
    def start(self) -> str: return "hum"

class Vehicle:
    """One class. The varying axis is a field, not a subclass."""
    def __init__(self, name: str, engine: Engine, wheels: int):
        self.name, self.engine, self.wheels = name, engine, wheels

    def start(self) -> str:
        return f"{self.name} ({self.wheels} wheels): {self.engine.start()}"


car = Vehicle("car", PetrolEngine(), 4)
bike = Vehicle("bike", ElectricMotor(), 2)
assert car.start().endswith("vroom") and bike.start().endswith("hum")

# Behaviour can even change at runtime — impossible with inheritance.
car.engine = ElectricMotor()
assert car.start().endswith("hum")
print(car.start(), "|", bike.start())
```

```java +
public class Main {
    interface Engine { String start(); }

    static class PetrolEngine implements Engine {
        @Override public String start() { return "vroom"; }
    }

    static class ElectricMotor implements Engine {
        @Override public String start() { return "hum"; }
    }

    static class Vehicle {
        private final String name;
        private final int wheels;
        private Engine engine;   // the varying axis, injected — not a subclass

        Vehicle(String name, Engine engine, int wheels) {
            this.name = name; this.engine = engine; this.wheels = wheels;
        }

        void setEngine(Engine engine) { this.engine = engine; }

        String start() {
            return name + " (" + wheels + " wheels): " + engine.start();
        }
    }

    public static void main(String[] args) {
        Vehicle car = new Vehicle("car", new PetrolEngine(), 4);
        Vehicle bike = new Vehicle("bike", new ElectricMotor(), 2);
        assert car.start().endsWith("vroom") && bike.start().endsWith("hum");

        car.setEngine(new ElectricMotor());   // runtime swap
        assert car.start().endsWith("hum");
        System.out.println(car.start() + " | " + bike.start());
    }
}
```

| | Inheritance | Composition |
|---|---|---|
| Relationship | IS-A | HAS-A |
| Bound at | Compile time | Runtime — swappable |
| Coupling | Tightest (to implementation) | Loose (to an interface) |
| Multiple axes | Combinatorial explosion | One field per axis |
| Testing | Must construct the whole hierarchy | Inject a fake collaborator |

**When inheritance *is* right**: a genuine IS-A that satisfies substitutability (a `SavingsAccount` really is an `Account` everywhere an `Account` is expected), a stable base you control, and a single axis of variation. Shallow hierarchies — one or two levels — are fine and often clearest.

The sentence to have ready: **"I'd use composition here because fuel type and body type vary independently; inheritance would need a class per combination."**

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-02-composition-q1", "type": "mcq",
      "prompt": "A design has `ElectricCar`, `PetrolCar`, `ElectricTruck`, `PetrolTruck`, and now needs hybrid engines and vans. What is the underlying problem?",
      "options": [
        {"id":"a","text":"Too few subclasses — add HybridVan and the model is complete"},
        {"id":"b","text":"Two independent axes of variation (power source × body type) are being expressed through single-axis inheritance, so classes multiply combinatorially; model each axis as a composed collaborator instead"},
        {"id":"c","text":"The base class needs more methods"},
        {"id":"d","text":"The classes should be interfaces"}
      ],
      "correct": "b",
      "explanation": "Inheritance can only express one axis. Each additional independent axis multiplies the class count; composition turns each axis into a field, so adding hybrid engines is one new class instead of one per body type." }
] }
```

## Coupling and cohesion

Two words that describe most of what a reviewer means by "clean".

**Coupling** — how much one module must know about another. **Low is good.**

| Level | Example | Verdict |
|---|---|---|
| **Data coupling** | Passing an `int` parameter | Best |
| **Stamp coupling** | Passing a whole object when only one field is used | Fine, mildly wasteful |
| **Control coupling** | Passing a flag that switches the callee's behaviour (`save(dryRun=True)`) | Smell — usually two methods |
| **Common coupling** | Shared global mutable state | Bad — invisible dependencies |
| **Content coupling** | Reaching into another object's internals (`order.items[0].price = 0`) | Worst |

The practical tests: *if I change class A, how many other classes must change?* and *how many things must I construct to test A alone?* Both answers should be small.

**Cohesion** — how strongly one class's contents belong together. **High is good.** A class with high cohesion has a name that describes exactly what it does; a class with low cohesion has a name like `Utils`, `Manager`, or `Helper`, and every field is used by a different subset of methods.

The **Law of Demeter** ("only talk to your immediate friends") makes low coupling concrete:

```python
# Train wreck — this method now depends on Order, Customer, Address AND their shapes.
def bad(order):
    return order.get_customer().get_address().get_city().upper()

# Ask, don't reach: the object you know answers the question.
def good(order):
    return order.shipping_city().upper()
```

Every `.` past the first is a dependency you have just acquired.

**A quick audit you can run on any design** — five smells and their fixes:

| Smell | Looks like | Fix |
|---|---|---|
| **God class** | `OrderManager` with 40 methods | Split by responsibility: pricing, persistence, notification |
| **Feature envy** | A method that mostly reads another class's fields | Move the method to the class that owns the data |
| **Primitive obsession** | `str` for money, ids, phone numbers, currencies | Value objects: `Money`, `PhoneNumber`, `TicketId` |
| **Shotgun surgery** | One change requires edits in seven files | The concept is scattered — gather it into one class |
| **Long parameter list** | `create(a, b, c, d, e, f, g)` | A parameter object, or a builder |

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-02-coupling-q1", "type": "mcq",
      "prompt": "`invoice.getCustomer().getAddress().getCountry().getTaxRate()` violates the Law of Demeter. Why does that matter in practice?",
      "options": [
        {"id":"a","text":"It is slower than a single method call"},
        {"id":"b","text":"The calling code now depends on the internal structure of four classes, so a change to any of them breaks it — asking `invoice.taxRate()` leaves one dependency and lets the chain change freely behind it"},
        {"id":"c","text":"It cannot be written in a statically typed language"},
        {"id":"d","text":"It prevents the use of interfaces"}
      ],
      "correct": "b",
      "explanation": "Each additional dot is knowledge of another object's shape. Reducing the chain to one call on the object you already hold means only that object's contract can break you." }
] }
```

## Interfaces, abstract classes, and dependency injection

**Interface vs abstract class** is asked in almost every LLD round, and the answer is about *what you are sharing*:

| | Interface | Abstract class |
|---|---|---|
| Shares | A **contract** — what can be done | A contract **plus partial implementation** |
| State | None (constants only) | Fields, constructors, invariants |
| Multiple | A class can implement many | Single inheritance only |
| Relationship | CAN-DO ("Comparable", "Serializable") | IS-A ("an `AbstractShape` is a shape") |
| Change cost | Adding a method breaks all implementers (unless defaulted) | Adding a concrete method breaks nobody |

The rule: **interface when unrelated classes need to be substitutable; abstract class when related classes genuinely share implementation and state.** In Python the distinction is softer (`ABC` covers both, and duck typing covers many cases) but the design reasoning is identical, and interviewers usually want the Java framing.

**Dependency injection** is the mechanism that turns "depend on abstractions" from a slogan into code: a class receives its collaborators instead of constructing them.

```python
class SmtpMailer:
    def send(self, to: str, body: str) -> None:
        print(f"[smtp] to {to}: {body}")

class FakeMailer:
    def __init__(self): self.sent: list[tuple[str, str]] = []
    def send(self, to: str, body: str) -> None: self.sent.append((to, body))

class SignupService:
    def __init__(self, mailer):            # injected — not `self.mailer = SmtpMailer()`
        self.mailer = mailer

    def register(self, email: str) -> None:
        self.mailer.send(email, "Welcome!")


fake = FakeMailer()
SignupService(fake).register("a@example.com")
assert fake.sent == [("a@example.com", "Welcome!")]   # testable with no SMTP server
SignupService(SmtpMailer()).register("b@example.com")
print("sent:", fake.sent)
```

Constructing your own dependencies (`self.mailer = SmtpMailer()`) hard-wires the class to one implementation, makes it untestable without real infrastructure, and hides the dependency from anyone reading the constructor. Injection makes every dependency visible in the signature — which is also why **a constructor with eight parameters is a design smell**: the class is doing eight things.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-02-di-q1", "type": "mcq",
      "prompt": "Why is `def __init__(self): self.mailer = SmtpMailer()` worse than accepting the mailer as a constructor parameter?",
      "options": [
        {"id":"a","text":"It is slower to construct"},
        {"id":"b","text":"It hard-codes one implementation, hides the dependency from the class's signature, and makes the class impossible to unit test without a real SMTP server — injection makes the dependency explicit and substitutable"},
        {"id":"c","text":"Constructors cannot create objects in most languages"},
        {"id":"d","text":"It violates encapsulation of the mailer"}
      ],
      "correct": "b",
      "explanation": "Injection buys three things at once: substitutability, testability, and an honest constructor signature that documents what the class actually needs." }
] }
```

## Key takeaways

**The recall card:**

```
Encapsulation : hide state, expose operations that preserve invariants.
                A public setter is a public field. Validate in the constructor.
Abstraction   : hide implementation behind a contract  (encapsulation hides DATA,
                abstraction hides HOW)
Inheritance   : share a contract, not code. IS-A + substitutable + single axis + shallow.
Polymorphism  : one call site, many behaviours. Test = "can I add a type without edits?"

COMPOSITION OVER INHERITANCE
  Inheritance = compile-time, tightest coupling, one axis → combinatorial explosion
  Composition = runtime-swappable, loose, one field per axis, easy to fake in tests

Coupling (low): data < stamp < control < common < content   ← worst
  Law of Demeter: every dot past the first is a new dependency. Ask, don't reach.
Cohesion (high): a class whose name describes exactly what it does.
  Smells: god class · feature envy · primitive obsession · shotgun surgery · long params

Interface = contract, many per class, unrelated types (CAN-DO)
Abstract class = contract + shared state/implementation, one per class (IS-A)
Dependency injection: receive collaborators, never construct them.
  Constructor with 8 params = the class does 8 things.
```

- **Encapsulation is about who owns the invariant**, and the answer must be the class, not its callers.
- **Reach for composition first, every time**, and say why: independent axes of variation, runtime swappability, testability.
- **Coupling and cohesion are the vocabulary reviewers use.** "This `Manager` has low cohesion — I'd split pricing from persistence" is exactly how a design discussion sounds.
- **Every design smell in the table has a standard fix**, and knowing the pair (smell → fix) is what lets you improve a design live, in front of the interviewer, when they push on it.
