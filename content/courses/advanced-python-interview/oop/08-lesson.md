---
kind: lesson
id_key: advanced-python-interview/exceptions-oop/mixins
course: advanced-python-interview
section: oop
section_title: "Object-Oriented Python"
section_position: 3
section_group: Fundamentals
title: "Mixins"
position: 7
estimated_minutes: 10
source: ["knowledge/backend/python/python-oop-lld.md"]
---
A mixin is a small class that packages one reusable behavior and is added to other classes through multiple inheritance. It is not meant to be instantiated on its own and does not describe what something *is*, only something extra it can *do*.

## What a mixin looks like

Name it with a `Mixin` suffix, give it methods only, and list it among the bases of the classes that need it.

```python
class LogMixin:
    def log(self, msg):
        print(f"[{self.__class__.__name__}] {msg}")

class SerializeMixin:
    def to_dict(self):
        return dict(vars(self))

class Base:
    def __init__(self, name):
        self.name = name

class User(LogMixin, SerializeMixin, Base):
    pass

u = User("ann")
u.log("hello")
print(u.to_dict())
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-mixins-q1",
      "type": "mcq",
      "prompt": "What is a mixin?",
      "options": [
        { "id": "a", "text": "A class that adds reusable methods to other classes via multiple inheritance and is not used on its own" },
        { "id": "b", "text": "A function that merges two dictionaries" },
        { "id": "c", "text": "A class that must define __init__ to share state" },
        { "id": "d", "text": "A special keyword for abstract classes" }
      ],
      "correct": "a",
      "explanation": "Mixins are small single-purpose classes composed into others through inheritance to share behavior."
    }
  ]
}
```

## Rules and ordering

Place mixins before the main base class so their methods take priority in the lookup order, and Python resolves left to right. A mixin that wants to extend a method should call `super()` so the chain continues.

```python
class Base:
    def hello(self):
        return "base"

class ShoutMixin:
    def hello(self):
        return super().hello().upper()

class Good(ShoutMixin, Base):
    pass

class Bad(Base, ShoutMixin):
    pass

print(Good().hello())  # mixin first: wraps Base
print(Bad().hello())   # Base wins, mixin never runs
print([c.__name__ for c in Good.__mro__])
```

Other conventions: avoid `__init__` and shared state in mixins (they should rely only on the host class's attributes), and keep each mixin to one concern.

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-mixins-q2",
      "type": "mcq",
      "prompt": "Why list mixins before the main base class, as in `class User(LogMixin, Base)`?",
      "options": [
        { "id": "a", "text": "Lookup goes left to right, so mixin methods override the base's and can wrap them with super()" },
        { "id": "b", "text": "Python requires abstract classes to come last" },
        { "id": "c", "text": "It makes the mixin instantiable" },
        { "id": "d", "text": "The order has no effect" }
      ],
      "correct": "a",
      "explanation": "The MRO follows base order, so earlier classes take precedence; putting the base first would shadow the mixin."
    },
    {
      "id": "exceptions-oop-mixins-q3",
      "type": "mcq",
      "prompt": "Which is a good guideline for writing a mixin?",
      "options": [
        { "id": "a", "text": "Give it its own __init__ with state for every host class" },
        { "id": "b", "text": "Keep it stateless, single-purpose, and rely on the host class's attributes" },
        { "id": "c", "text": "Make it inherit from several unrelated mixins" },
        { "id": "d", "text": "Use it to share constructor logic" }
      ],
      "correct": "b",
      "explanation": "Mixins that manage state or constructors make multiple-inheritance chains fragile; keep them behavior-only."
    }
  ]
}
```

## When to use a mixin

Good fits: logging, caching, serialization, comparison helpers, behavior reused across unrelated classes while keeping hierarchies flat. Poor fits: sharing constructor logic, holding state, or anything better expressed as composition. If the behavior needs real collaborators, hold an object instead.

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-mixins-q4",
      "type": "mcq",
      "prompt": "Which task suits a mixin best?",
      "options": [
        { "id": "a", "text": "Adding a to_dict() serialization method to many unrelated classes" },
        { "id": "b", "text": "Sharing complex constructor setup between classes" },
        { "id": "c", "text": "Managing a shared database connection pool" },
        { "id": "d", "text": "Replacing every has-a relationship" }
      ],
      "correct": "a",
      "explanation": "Stateless cross-cutting behavior like serialization or logging is the classic mixin use case."
    }
  ]
}
```

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

#### Mixins

A class that adds methods to other classes via multiple inheritance. Not meant to be used alone.

##### Basic syntax

```text
class LogMixin:
    def log(self, msg):
        print(f"[{self.__class__.__name__}] {msg}")

class User(LogMixin):
    pass

User().log("hello")  # [User] hello
```

##### Rules

- Named with `Mixin` suffix by convention.
- Avoid `__init__` — don't manage state.
- Place mixins before the main base class.
- A class can use multiple mixins.

##### Multiple mixins

```text
class User(LogMixin, SerializeMixin, Base):
    pass
```

##### MRO — Method Resolution Order

Python looks up methods left to right.

```text
class MyClass(MixinB, MixinA, Base):
    pass

print(MyClass.__mro__)  # MyClass -> MixinB -> MixinA -> Base -> object
```

##### When to use

| Use | Avoid |
|---|---|
| Logging, caching, serialization | Sharing `__init__` logic |
| Reusable behavior across classes | Managing shared state |
| Keeping inheritance flat | Deep inheritance chains |
