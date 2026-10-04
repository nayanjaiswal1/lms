---
kind: lesson
id_key: interview-prep-45/lld-02-oop-foundations
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "OOP Foundations for Design"
position: 2
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

Almost everyone can recite "encapsulation, abstraction, inheritance, polymorphism" from memory. Far fewer can say why encapsulation actually matters when someone is reviewing their code, or when inheritance is the wrong tool, or what "tight coupling" costs in a real bug report. This lesson closes that gap. You'll leave it able to defend each pillar as a decision, not just name it.

## The four pillars, as decisions you can defend

**Encapsulation — hide the data, expose safe actions.** This isn't about typing `private` in front of a field. The real point is: **an object should never let outside code put it into a broken state.**

Picture a bank account. If any code anywhere can just set `balance = -500`, the rule "balance never goes negative" has to be remembered and re-checked by every single piece of code that touches an account. That's fragile. Move the rule inside the account instead, and it only has to be right once.

```python
# Weak: the rule "balance never goes negative" lives in every caller's head.
class BadAccount:
    def __init__(self):
        self.balance = 0          # anyone can write anything here

# Strong: the rule lives in one place, and the class enforces it.
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

Here's the payoff: if a bug report says "balance went negative," you now have exactly three methods to check, not the whole codebase. And here's a trap worth knowing: **writing a public getter and a public setter for every field is not encapsulation.** A setter that accepts anything is just a public field wearing a disguise. Real encapsulation means exposing *actions* (`withdraw`) that keep the object's rules intact, not raw access to its fields.

**Abstraction — show what something does, hide how.** `PaymentProcessor.charge(amount)` tells you nothing about whether it's Stripe or Razorpay underneath, so your code never has to care. Abstraction is what lets you swap one for the other later without touching anything else.

People mix up abstraction and encapsulation constantly, so here's the one line that separates them: **encapsulation hides data. Abstraction hides implementation.**

| | Abstraction | Encapsulation |
|---|---|---|
| Hides | Complexity — the *how* | Data — the internal state |
| Goal | Give a simple front door to something complicated | Stop invalid changes to internal state |
| Typical tool | An interface, an abstract class, a well-named method | Private fields, properties |
| Example | `car.start()` hides the ignition sequence and fuel injection | `self.__balance` can't be poked from outside the class |

```python
class BankAccount:
    def __init__(self, balance):
        self.__balance = balance  # encapsulation: name-mangled, not reachable from outside

    def deposit(self, amount):    # abstraction: the caller never sees HOW this is checked
        if amount <= 0:           # or stored — just that deposit() does the right thing
            raise ValueError("Deposit must be positive")
        self.__balance += amount

    @property
    def balance(self):
        return self.__balance     # controlled read access — this is the encapsulation part
```

`deposit()` is abstraction: it gives the caller one simple verb and hides the validation underneath. `__balance` plus the read-only `balance` property is encapsulation: it stops `account.__balance = -1000` from skipping the rules entirely (Python renames `__balance` internally so outside code can't reach it directly). The two work as a pair: abstraction shapes the *interface*, encapsulation decides *who gets to touch what* behind it.

**Inheritance — share a contract, not a shortcut to reuse code.** The one legitimate reason to inherit is that the child is genuinely, always substitutable for the parent — a `SavingsAccount` really is an `Account` everywhere an `Account` is expected. Inheriting purely to avoid retyping a method is the single most common design mistake in this whole topic, and the next section shows exactly why.

**Polymorphism — one call, many behaviours.** This is the thing that gets rid of long chains of `if type == ...`.

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

# One line calls .area() on anything. Adding Triangle means adding a class — nothing here changes.
shapes: list[Shape] = [Circle(1), Rectangle(2, 3)]
total = sum(s.area() for s in shapes)
assert abs(total - 9.14159) < 1e-6
print(f"total area = {total:.5f}")
```

Here's a quick test for whether polymorphism is doing real work: **can you add a new type without touching any existing code?** If adding `Triangle` means hunting down an `if shape_type == ...` chain somewhere and editing it, you've written types without actually using polymorphism.

**Python doesn't even require a shared parent for this to work.** This is called **duck typing**: "if it walks like a duck and quacks like a duck, treat it like a duck."

```python
class Circle:
    def __init__(self, r): self.r = r
    def area(self): return 3.14159 * self.r ** 2

class Square:                      # note: does NOT inherit from anything
    def __init__(self, side): self.side = side
    def area(self): return self.side ** 2

for shape in [Circle(2), Square(3)]:
    print(shape.area())            # works on both — Python never checks a shared ancestor
```

When that loop runs, Python doesn't ask "is this a `Shape`?" anywhere. It just calls whatever `.area()` method the object happens to have. This is looser than Java, where the compiler checks a declared interface before your code even runs.

**Operator overloading is polymorphism applied to symbols like `+` and `==`.** Python routes those symbols to methods with special names:

```python
class Vector:
    def __init__(self, x, y): self.x, self.y = x, y
    def __add__(self, other): return Vector(self.x + other.x, self.y + other.y)
    def __eq__(self, other): return self.x == other.x and self.y == other.y

v = Vector(1, 2) + Vector(3, 4)  # this line is really Vector(1, 2).__add__(Vector(3, 4))
```

Python has no special-case rule for `+` on a `Vector`. The `+` symbol is *defined* to call `.__add__()` on whatever sits on its left, and `Vector` happens to provide one. That call returns a brand new `Vector(4, 6)`.

> **Remember:** encapsulation hides data, abstraction hides how something works. A public getter-and-setter pair is not encapsulation — it's a field wearing a disguise.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-02-pillars-q1", "type": "mcq",
      "prompt": "A class has a public getter and setter for every single one of its private fields. What has that actually achieved?",
      "options": [
        {"id":"a","text":"Proper encapsulation, since the fields themselves are private"},
        {"id":"b","text":"Basically nothing — a public setter is a public field with extra typing; real encapsulation means exposing actions that protect the object's rules (like withdraw), not accessors that let outside code set anything"},
        {"id":"c","text":"Abstraction, because callers now go through methods"},
        {"id":"d","text":"Polymorphism, because the setters could be overridden"}
      ],
      "correct": "b",
      "explanation": "Encapsulation is about who is responsible for keeping an object valid. If anyone can set any field to any value, that responsibility has leaked out to every caller — exactly what encapsulation is supposed to prevent." }
] }
```

## Composition over inheritance

This is the single most useful habit in this whole topic, and it's the one interviewers lean on hardest.

**Here's the problem with inheritance.** It's the tightest coupling a language offers — a subclass depends on the parent's actual implementation, not just its promises. Change the parent, and every child might quietly break. This is called the "fragile base class" problem. Worse, inheritance can only express *one* dimension of change at a time. The moment two things vary independently, your class tree explodes.

```
Vehicle
├── ElectricCar
├── PetrolCar
├── ElectricTruck        this explodes:
├── PetrolTruck          (fuel type) × (body type) needs one class PER combination
├── ElectricMotorcycle
└── ...
```

**The fix: make the varying part something the object *has*, not something it *is*.**

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
    """One class. The thing that varies is a field, not a branch of a class tree."""
    def __init__(self, name: str, engine: Engine, wheels: int):
        self.name, self.engine, self.wheels = name, engine, wheels

    def start(self) -> str:
        return f"{self.name} ({self.wheels} wheels): {self.engine.start()}"


car = Vehicle("car", PetrolEngine(), 4)
bike = Vehicle("bike", ElectricMotor(), 2)
assert car.start().endswith("vroom") and bike.start().endswith("hum")

# You can even swap the engine while the program is running — inheritance can't do this.
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
        private Engine engine;   // the varying part, injected — not a subclass

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

        car.setEngine(new ElectricMotor());   // swapped while running
        assert car.start().endsWith("hum");
        System.out.println(car.start() + " | " + bike.start());
    }
}
```

| | Inheritance | Composition |
|---|---|---|
| Relationship | IS-A | HAS-A |
| Decided | When the code is written | While the program runs — swappable |
| Coupling | Tight — to the parent's actual code | Loose — only to an interface |
| Two things varying at once | Class count explodes | One field per varying thing |
| Testing | Must build the whole family tree | Just hand it a fake collaborator |

**When inheritance is genuinely the right call**: a real IS-A relationship where the child can stand in for the parent everywhere (a `SavingsAccount` really is an `Account`), a stable parent you control, and only one thing varying. A shallow tree — one or two levels — is usually fine and often the clearest option.

Here's a sentence worth having ready: **"I'd use composition here, because fuel type and body type vary independently. Inheritance would need one class per combination."**

> **Remember:** the moment two things vary independently, stop reaching for subclasses and start reaching for a field.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-02-composition-q1", "type": "mcq",
      "prompt": "A design already has `ElectricCar`, `PetrolCar`, `ElectricTruck`, `PetrolTruck` — and now needs hybrid engines and vans too. What's actually wrong here?",
      "options": [
        {"id":"a","text":"There just aren't enough subclasses yet — add HybridVan and it's fine"},
        {"id":"b","text":"Two things vary independently — power source and body type — but they're being forced through single-branch inheritance, so classes multiply; model each one as a field instead"},
        {"id":"c","text":"The base class needs more methods"},
        {"id":"d","text":"These should all be interfaces instead"}
      ],
      "correct": "b",
      "explanation": "A class tree can really only express one axis of change cleanly. Every extra independent axis multiplies the class count. Turning each axis into a field means hybrid engines cost one new class, not one per body type." }
] }
```

## Coupling and cohesion

These are the two words a reviewer actually means when they say a design is "clean."

**Coupling — how much one piece of code has to know about another.** Lower is better.

| Level | What it looks like | Verdict |
|---|---|---|
| **Data coupling** | Passing a plain number | Best |
| **Stamp coupling** | Passing a whole object when only one field gets used | Fine, a little wasteful |
| **Control coupling** | Passing a flag that changes what the method does (`save(dryRun=True)`) | A smell — usually should be two methods |
| **Common coupling** | Shared global state anyone can change | Bad — dependencies become invisible |
| **Content coupling** | Reaching straight into another object's insides (`order.items[0].price = 0`) | Worst |

Two quick tests to run on any design: *if I change class A, how many other classes have to change too?* And: *how many objects do I need to build just to test A on its own?* Both answers should be small.

**Cohesion — how well the contents of one class actually belong together.** Higher is better. A cohesive class has a name that tells you exactly what it does. A class with low cohesion tends to be named `Utils`, `Manager`, or `Helper`, and different methods inside it use completely different subsets of its fields.

There's a rule that makes low coupling concrete, called the **Law of Demeter**: *only talk to your immediate friends.*

```python
# A long chain — this method now depends on the shape of Order, Customer, AND Address.
def bad(order):
    return order.get_customer().get_address().get_city().upper()

# Ask the object you already have, and let IT answer the question.
def good(order):
    return order.shipping_city().upper()
```

Every extra `.` past the first one is one more thing that can break your code later.

**A five-item checklist you can run against any design**, with the standard fix for each:

| Smell | What it looks like | Fix |
|---|---|---|
| **God class** | `OrderManager` with 40 methods | Split it up by why each part would change |
| **Feature envy** | A method that mostly reads some other class's fields | Move the method to the class that owns the data |
| **Primitive obsession** | A plain string standing in for money, an id, a phone number | Wrap it in a value object: `Money`, `PhoneNumber`, `TicketId` |
| **Shotgun surgery** | One small change means editing seven different files | The idea is scattered — pull it into one class |
| **Long parameter list** | `create(a, b, c, d, e, f, g)` | Bundle the parameters into an object, or use a builder |

> **Remember:** every extra dot past the first one in a chain is a dependency you just took on. Ask the thing you already hold, don't reach through it.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-02-coupling-q1", "type": "mcq",
      "prompt": "`invoice.getCustomer().getAddress().getCountry().getTaxRate()` breaks the Law of Demeter. Why does that actually matter?",
      "options": [
        {"id":"a","text":"It runs more slowly than a single method call"},
        {"id":"b","text":"This code now depends on the internal shape of four different classes, so a change to any of them can break it — asking `invoice.taxRate()` instead leaves only one dependency, and everything behind it can change freely"},
        {"id":"c","text":"It can't be written in a statically typed language"},
        {"id":"d","text":"It prevents the use of interfaces"}
      ],
      "correct": "b",
      "explanation": "Every extra dot is knowledge of another class's internal shape. Shrinking the chain down to one call on an object you already hold means only that one object's contract can break you." }
] }
```

## Interfaces, abstract classes, and dependency injection

**Interface vs. abstract class shows up in almost every LLD interview**, and the answer really comes down to one question: *what are you sharing?*

**Abstract class means "IS-A."** Use it when the things involved share both a type relationship and some actual code. A `Dog` **is an** `Animal`.

**Interface means "CAN-DO."** Use it when unrelated things need to promise the same *capability*, with no code in common. A `Dog` **can** `Swim`; so **can** a `Boat`, and a `Boat` is definitely not an `Animal`.

| | Interface | Abstract class |
|---|---|---|
| Shares | Just a promise — "here's what I can do" | A promise, plus some real code |
| Holds state | No (constants only) | Yes — fields, a constructor |
| How many | A class can implement many | One parent only, in most languages |
| Answers | "What can you do, no matter what you are?" | "What kind of thing are you, and what do you already do?" |
| Cost of a change | Adding a method breaks everything that implements it | Adding a concrete method breaks nobody |

**In Python specifically**, there's no separate `abstract class` keyword. `abc.ABC` plus `@abstractmethod` gives you the same guarantee:

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    def __init__(self, color: str):
        self.color = color          # shared state — every Shape has a colour

    def describe(self) -> str:      # a real method, shared by every subclass
        return f"A {self.color} shape with area {self.area():.2f}"

    @abstractmethod
    def area(self) -> float: ...    # every subclass MUST provide this

class Circle(Shape):
    def __init__(self, color: str, radius: float):
        super().__init__(color)
        self.radius = radius

    def area(self) -> float:
        return 3.14159 * self.radius ** 2

Shape("red")     # TypeError: Can't instantiate abstract class Shape
Circle("red", 2).describe()   # "A red shape with area 12.57"
```

Trying to build a plain `Shape` raises a `TypeError` the instant you try. Python checks this while the program is running, not before, since there's no separate compile step. A subclass that forgets to write `area()` is also unbuildable, and the error only shows up the first time someone actually tries to construct it.

**Python's real answer to "CAN-DO" is `typing.Protocol`, not a keyword.** Java's `implements` requires you to declare the relationship up front — that's called nominal typing. Python's `Protocol` just checks the *shape* of an object — that's structural typing:

```python
from typing import Protocol

class Swimmer(Protocol):
    def swim(self) -> str: ...

class Dog:
    def swim(self) -> str:
        return "paddles"

class Boat:
    def swim(self) -> str:
        return "cuts through water"

def race(swimmer: Swimmer) -> str:
    return swimmer.swim()

race(Dog())   # works — Dog never said "I implement Swimmer", it just has the method
race(Boat())  # also works — Boat has nothing to do with Dog at all
```

Neither `Dog` nor `Boat` inherits from `Swimmer`. They satisfy it just by happening to have a matching method. When `race(Dog())` runs, Python doesn't check any declared relationship at all — it just calls `.swim()` and trusts that whatever was handed to it has one. That's the concrete Python answer to "CAN-DO": no shared parent, no shared code, just a shared ability, checked either by a type checker or simply by trying it at runtime.

**Abstract classes earn their keep through the Template Method pattern**: the abstract class nails down the *order* of a series of steps, and each subclass only fills in the steps that actually change.

```python
class DataPipeline(ABC):
    def run(self) -> None:              # the fixed order — never overridden
        data = self.extract()
        cleaned = self.transform(data)
        self.load(cleaned)

    @abstractmethod
    def extract(self): ...
    @abstractmethod
    def transform(self, data): ...
    @abstractmethod
    def load(self, data): ...

class CsvPipeline(DataPipeline):
    def extract(self): return open("in.csv").read()
    def transform(self, data): return data.upper()
    def load(self, data): open("out.csv", "w").write(data)
```

`run()` never changes. The *shape* of the process is fixed in the parent class, and only the individual steps vary per subclass. Calling `CsvPipeline().run()` runs `DataPipeline.run`, which calls `extract`, `transform`, and `load` in that exact order — but each one resolves to `CsvPipeline`'s own version. This is the answer to "why not just give me three methods and let me call them in the right order myself?" The abstract class owns and guarantees the order, so nobody can call the steps out of sequence or skip one by mistake.

Two interview questions worth having answers ready for:

**"Can an abstract class have a constructor if you can't build one directly?"** Yes — it runs whenever a subclass is built, through `super().__init__()`. You can't construct the parent alone, but its constructor is still part of building every child.

**"Why not just use Strategy instead of Template Method?"** Strategy swaps out a *whole* algorithm through composition — you hand in a different object. Template Method fixes the *order* of steps at write-time and only lets subclasses change individual steps. Pick Template Method when the sequence must never change. Pick Strategy when you need to swap the entire thing while the program runs.

**Dependency injection is what turns "depend on an interface" from advice into working code**: a class receives the things it needs from outside, instead of building them itself.

```python
class SmtpMailer:
    def send(self, to: str, body: str) -> None:
        print(f"[smtp] to {to}: {body}")

class FakeMailer:
    def __init__(self): self.sent: list[tuple[str, str]] = []
    def send(self, to: str, body: str) -> None: self.sent.append((to, body))

class SignupService:
    def __init__(self, mailer):            # handed in — not `self.mailer = SmtpMailer()`
        self.mailer = mailer

    def register(self, email: str) -> None:
        self.mailer.send(email, "Welcome!")


fake = FakeMailer()
SignupService(fake).register("a@example.com")
assert fake.sent == [("a@example.com", "Welcome!")]   # tested with no real mail server
SignupService(SmtpMailer()).register("b@example.com")
print("sent:", fake.sent)
```

Building your own dependency inside the class (`self.mailer = SmtpMailer()`) locks the class to one implementation, makes it impossible to test without real infrastructure, and hides what the class actually needs from anyone reading its constructor. Injecting it instead puts every dependency right there in the signature — which is also why **a constructor with eight parameters is a warning sign**: that class is doing eight different jobs.

> **Remember:** interface means "can do," abstract class means "is a." When in doubt, ask what's actually being shared — a promise, or a promise plus real code.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-02-di-q1", "type": "mcq",
      "prompt": "Why is `def __init__(self): self.mailer = SmtpMailer()` worse than accepting the mailer as a constructor argument?",
      "options": [
        {"id":"a","text":"It's slower to construct the object"},
        {"id":"b","text":"It locks the class to one implementation, hides the dependency from anyone reading the constructor, and makes the class impossible to test without a real mail server — passing it in instead makes the dependency visible and swappable"},
        {"id":"c","text":"Constructors can't build other objects in most languages"},
        {"id":"d","text":"It breaks encapsulation of the mailer"}
      ],
      "correct": "b",
      "explanation": "Passing a dependency in buys you three things at once: you can swap it, you can test with a fake, and the constructor honestly documents what the class needs." }
] }
```

## Quick recap

```
Encapsulation : hide state, expose actions that keep the object valid.
                A public setter is a public field. Validate in the constructor.
Abstraction   : hide HOW something works behind a simple interface
                (encapsulation hides DATA, abstraction hides HOW)
Inheritance   : share a contract, not just code. IS-A + substitutable + one axis + shallow.
Polymorphism  : one call, many behaviours. Test: can I add a type with zero edits elsewhere?
                Python also does this via duck typing — no shared parent required.

COMPOSITION OVER INHERITANCE
  Inheritance = fixed at write-time, tight coupling, one axis → class count explodes
  Composition = swappable while running, loose coupling, one field per axis, easy to fake

Coupling (low is good): data < stamp < control < common < content   ← worst
  Law of Demeter: every dot past the first is a new dependency. Ask, don't reach through.
Cohesion (high is good): a class whose name tells you exactly what it does.
  Smells: god class · feature envy · primitive obsession · shotgun surgery · long param list

Interface = a promise only, many per class, unrelated types (CAN-DO)
Abstract class = a promise plus real code, one per class (IS-A)
  Python: ABC + @abstractmethod for "IS-A"; Protocol (structural) for "CAN-DO"
  Template Method: the abstract class fixes the ORDER, subclasses fill in the STEPS
Dependency injection: receive collaborators, never build them yourself.
  A constructor with 8 parameters means that class is doing 8 jobs.
```

- **Encapsulation is about who's responsible for keeping the object valid** — and the answer has to be the class itself, never its callers.
- **Reach for composition first, every time**, and be ready to say why: independent things that vary, swapping while the program runs, easier testing.
- **Coupling and cohesion are the words reviewers actually use.** "This `Manager` class has low cohesion — I'd split pricing away from saving to disk" is exactly what a real design conversation sounds like.
- **Every smell in that checklist has a standard fix**, and knowing the pair — smell, then fix — is what lets you improve a design live, on the spot, when the interviewer pushes back.
