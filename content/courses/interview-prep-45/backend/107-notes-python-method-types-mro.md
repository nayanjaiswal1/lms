---
kind: lesson
id_key: interview-prep-45/note-python-method-types-mro
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Instance/Class/Static Methods & Method Resolution Order"
position: 107
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

Day 27's Factory pattern example uses `@staticmethod` in passing, but this course doesn't have a dedicated lesson on the three method types or on how Python resolves `super()` calls through multiple inheritance — both are warm-up questions nearly every Python interview opens with.

## Instance, class, and static methods

```python
class Pizza:
    total_made = 0

    def __init__(self, toppings):
        self.toppings = toppings
        Pizza.total_made += 1

    def describe(self):                    # instance method: needs self
        return f"Pizza with {', '.join(self.toppings)}"

    @classmethod
    def margherita(cls):                    # classmethod: needs cls, not an instance
        return cls(["tomato", "mozzarella"])  # cls() so subclasses get the right type

    @staticmethod
    def is_valid_topping(name):             # staticmethod: needs neither
        return name in {"tomato", "mozzarella", "basil", "pepperoni"}
```

- **Instance method** (`self`) — the default. Operates on one instance's state; call it via `instance.method()`.
- **Classmethod** (`cls`) — operates on the class itself, not a particular instance. The canonical use case is an **alternate constructor**: `Pizza.margherita()` builds a `Pizza` without callers needing to know the internal topping list. Using `cls(...)` instead of `Pizza(...)` inside the method matters for inheritance — a subclass calling `Margherita.margherita()` correctly constructs a `Margherita`, not a `Pizza`, because `cls` is bound to whichever class the call went through.
- **Staticmethod** — takes neither `self` nor `cls`. It's a plain function that happens to live in the class's namespace because it's conceptually related (like `is_valid_topping` here) — a signal to readers "this doesn't touch instance or class state," not a mechanism with special binding behavior.

**Interview framing:** if the method needs the instance's data, it's an instance method. If it needs to know the class but not a specific instance (factory functions, alternate constructors), it's a classmethod. If it's just a utility that happens to belong near the class conceptually, it's a staticmethod — and if you're using `@staticmethod` a lot, it's often a sign the function should just be a module-level function instead.

## Multiple inheritance and Method Resolution Order (MRO)

When a class inherits from multiple parents, and those parents share a common ancestor (the "diamond problem"), Python needs a deterministic rule for which parent's method wins when you call `super()` or access an inherited attribute. That rule is the **C3 linearization algorithm**, and the resulting order is the class's MRO.

```python
class Base:
    def greet(self):
        return "Base"

class Left(Base):
    def greet(self):
        return f"Left -> {super().greet()}"

class Right(Base):
    def greet(self):
        return f"Right -> {super().greet()}"

class Diamond(Left, Right):
    def greet(self):
        return f"Diamond -> {super().greet()}"

d = Diamond()
print(d.greet())        # Diamond -> Left -> Right -> Base
print(Diamond.__mro__)  # (Diamond, Left, Right, Base, object)
```

C3 linearization guarantees two things that make the order predictable rather than arbitrary:
1. **Local precedence order** — a class always appears before its own parents, and parents are checked in the order they're listed in the class definition (`Left` before `Right` because `class Diamond(Left, Right)` lists them that way).
2. **Monotonicity** — if `Diamond`'s MRO says `Left` comes before `Right`, no subclass of `Diamond` can ever put `Right` before `Left`. This is what makes `super()` calls chain correctly instead of jumping around unpredictably as the hierarchy grows.

Critically, `Base.greet` only runs **once** even though both `Left` and `Right` inherit from it — C3 linearization visits each class exactly once, which is precisely what makes it solve the diamond problem (naive "depth-first" resolution would call `Base.greet` twice, once via each path).

```python
print([c.__name__ for c in Diamond.__mro__])
# ['Diamond', 'Left', 'Right', 'Base', 'object']
```

`super()` doesn't mean "my direct parent" — it means "the next class in the MRO after the current one." That distinction is what lets cooperative multiple inheritance (every class calling `super().method()`) walk the whole chain exactly once instead of each class hardcoding a specific parent to call.

**When Python can't compute a valid MRO** (inconsistent ordering — e.g. one base requires `A` before `B` and another requires `B` before `A`), it raises `TypeError: Cannot create a consistent method resolution order` at class-definition time rather than silently picking one — a good detail to mention if asked about failure modes.

## Key takeaways

- Instance methods need `self` (per-instance state); classmethods need `cls` (use `cls()` for inheritance-safe alternate constructors); staticmethods need neither and are just namespaced utility functions.
- Python resolves multiple inheritance via C3 linearization (`Class.__mro__`), which guarantees each ancestor is visited exactly once and that parent order is respected consistently across the whole hierarchy.
- `super()` means "the next class in the MRO," not "my direct parent" — that's what makes cooperative multi-inheritance chains work correctly.
- An inconsistent MRO (conflicting base-class orderings) raises `TypeError` at class-definition time, not at call time.
