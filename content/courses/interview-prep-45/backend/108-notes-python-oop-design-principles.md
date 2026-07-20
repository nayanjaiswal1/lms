---
kind: lesson
id_key: interview-prep-45/note-python-oop-design-principles
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: SOLID Principles, Polymorphism & Abstraction vs Encapsulation"
position: 108
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

These three OOP design concepts don't have a dedicated lesson anywhere in the course — they show up as isolated design-pattern examples (Day 27's Singleton/Factory/Observer) but not as the underlying principles interviewers actually name when they ask "how do you decide when to split a class" or "what's the difference between abstraction and encapsulation."

## SOLID principles

SOLID is the standard framework for "is this class doing too much / too rigid" — the question that separates junior from senior design answers.

**S — Single Responsibility.** A class should have one reason to change.
```python
# Violates SRP: a report generator that also knows how to save to disk and email
class Report:
    def generate(self): ...
    def save_to_disk(self, path): ...
    def email_to(self, address): ...

# Fixed: each concern is its own class
class Report:
    def generate(self): ...

class ReportSaver:
    def save(self, report, path): ...

class ReportMailer:
    def email(self, report, address): ...
```

**O — Open/Closed.** Open for extension, closed for modification — add new behavior via new code (subclasses, new strategy implementations), not by editing existing, already-tested code.
```python
# Violates OCP: adding a new discount type means editing this function forever
def calculate_discount(customer_type, price):
    if customer_type == "regular":
        return price * 0.95
    elif customer_type == "vip":
        return price * 0.80
    # every new tier means another elif here

# Fixed: new tiers are new classes, calculate_discount never changes
class DiscountStrategy:
    def apply(self, price): raise NotImplementedError

class RegularDiscount(DiscountStrategy):
    def apply(self, price): return price * 0.95

class VipDiscount(DiscountStrategy):
    def apply(self, price): return price * 0.80
```

**L — Liskov Substitution.** A subclass must be usable anywhere its parent is expected, without breaking correctness. The classic violation:
```python
class Rectangle:
    def __init__(self, w, h): self.w, self.h = w, h
    def area(self): return self.w * self.h

class Square(Rectangle):  # tempting: a square "is-a" rectangle
    def __init__(self, side): super().__init__(side, side)
    # but if setting .w must also update .h to stay a square,
    # Square silently breaks any code that expects Rectangle's
    # width and height to vary independently — LSP violation
```
The fix isn't a code trick — it's recognizing `Square` shouldn't inherit from `Rectangle` at all if the parent's contract (independent width/height) doesn't hold for the child.

**I — Interface Segregation.** Don't force a class to implement methods it doesn't need. Many small, focused interfaces beat one large one.
```python
# Violates ISP: a Printer forced to implement scan() and fax() it can't support
class MultiFunctionDevice(ABC):
    @abstractmethod
    def print(self): ...
    @abstractmethod
    def scan(self): ...
    @abstractmethod
    def fax(self): ...

# Fixed: split by capability, implement only what applies
class Printable(ABC):
    @abstractmethod
    def print(self): ...

class Scannable(ABC):
    @abstractmethod
    def scan(self): ...
```

**D — Dependency Inversion.** High-level code should depend on an abstraction, not a concrete implementation — so the concrete thing can be swapped (including for a test double) without touching the high-level code.
```python
# Violates DIP: OrderService is hard-wired to SmtpMailer
class OrderService:
    def __init__(self):
        self.mailer = SmtpMailer()  # can't swap this for a test

# Fixed: depend on an abstraction, inject the concrete implementation
class OrderService:
    def __init__(self, mailer: MailerProtocol):
        self.mailer = mailer  # SmtpMailer in prod, a fake in tests
```
This is the same pattern FastAPI's `Depends()` (Day 23) is built on — dependency injection is Dependency Inversion applied at the framework level.

## Polymorphism

Polymorphism means code can call the same method name on different types and get type-appropriate behavior, without an `if/elif` chain checking types.

```python
class Shape:
    def area(self): raise NotImplementedError

class Circle(Shape):
    def __init__(self, r): self.r = r
    def area(self): return 3.14159 * self.r ** 2

class Rectangle(Shape):
    def __init__(self, w, h): self.w, self.h = w, h
    def area(self): return self.w * self.h

for shape in [Circle(2), Rectangle(3, 4)]:
    print(shape.area())  # each object knows how to compute its own area
```

Python's polymorphism is **duck typing**-based, not interface-declaration-based like Java: "if it walks like a duck and quacks like a duck, it's a duck" — any object with an `area()` method works in the loop above, whether or not it formally inherits from `Shape`. This is different from statically-typed languages, where polymorphism is enforced by the compiler checking an explicit interface at compile time.

**Operator overloading** is polymorphism applied to built-in operators via dunder methods:
```python
class Vector:
    def __init__(self, x, y): self.x, self.y = x, y
    def __add__(self, other): return Vector(self.x + other.x, self.y + other.y)
    def __eq__(self, other): return self.x == other.x and self.y == other.y

v = Vector(1, 2) + Vector(3, 4)  # calls Vector.__add__
```

## Abstraction vs encapsulation — the distinction interviewers check

These are easy to conflate because both involve "hiding" something, but they hide different things:

| | Abstraction | Encapsulation |
|---|---|---|
| Hides | **Complexity** — the *how* | **Data** — the internal *state* |
| Goal | Present a simple interface for a complicated implementation | Protect internal state from invalid external modification |
| Mechanism | Abstract base classes, interfaces, high-level method names | Private/protected attributes (`_x`, `__x`), properties |
| Example | `car.start()` hides the ignition sequence, fuel injection, starter motor | `self.__balance` can't be set directly from outside the class |

```python
class BankAccount:
    def __init__(self, balance):
        self.__balance = balance  # encapsulation: name-mangled, not directly accessible

    def deposit(self, amount):    # abstraction: caller doesn't need to know
        if amount <= 0:           # HOW balance is validated/stored internally,
            raise ValueError("Deposit must be positive")
        self.__balance += amount  # just that deposit() does the right thing

    @property
    def balance(self):
        return self.__balance     # controlled read access — encapsulation via property
```

`deposit()` is abstraction: it gives the caller a simple verb without exposing the validation/arithmetic underneath. `__balance` plus the `balance` property is encapsulation: it prevents `account.__balance = -1000` from bypassing validation entirely. They work together — abstraction is about the interface's *shape*, encapsulation is about *who can touch what* behind that interface.

## Key takeaways

- SOLID: Single Responsibility (one reason to change), Open/Closed (extend via new code, not edits), Liskov Substitution (subtypes must honor the parent's contract), Interface Segregation (small focused interfaces), Dependency Inversion (depend on abstractions, inject concretes — the pattern behind FastAPI's `Depends()`).
- Python's polymorphism is duck-typing based — any object with the right method works, no formal interface declaration required, unlike statically-typed languages.
- Abstraction hides *complexity* (the how) behind a simple interface; encapsulation hides *data* (the state) behind controlled access. They're complementary, not the same thing.
- Operator overloading (`__add__`, `__eq__`, etc.) is polymorphism applied to Python's built-in operators.
