---
kind: lesson
id_key: advanced-python-interview/oop-collections/inheritance
course: advanced-python-interview
section: oop-collections
section_title: "Collections & OOP Foundations"
section_position: 2
title: "Inheritance"
position: 4
estimated_minutes: 12
source: [fifty-advanced-python-concepts/18.inheritance.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
Inheritance lets a subclass reuse a parent's attributes and methods, and override the ones that need to differ. It's the mechanism behind both abstraction (Shape/Rectangle) and polymorphism (next lesson) — but used carelessly it's also the single biggest source of tightly coupled, fragile object hierarchies.

## Overriding a method

```python
class Animal:
    def __init__(self, name):
        self.name = name

    def speak(self):
        raise NotImplementedError("Subclasses must implement this method")

class Dog(Animal):
    def speak(self):
        return f"{self.name} says Woof!"

class Cat(Animal):
    def speak(self):
        return f"{self.name} says Meow!"

dog = Dog("Buddy")
cat = Cat("Kitty")
print(dog.speak())  # Buddy says Woof!
print(cat.speak())  # Kitty says Meow!
```

`Dog` and `Cat` both inherit `__init__` unchanged — `self.name = name` doesn't need to be repeated — but each overrides `speak()` with its own behavior. That's the reuse win: shared logic lives once, in `Animal`, and only the parts that genuinely differ are rewritten.

## The design question: is `Animal` ever instantiated?

`Animal.speak()` raises `NotImplementedError`, which signals "this class is never meant to be used directly — only subclassed." That's a real design decision with two options:

- **The parent is never instantiated on its own** → make it an `ABC` (previous lesson). The interpreter then enforces the contract at instantiation time instead of trusting a comment and a raised exception.
- **The parent is a genuinely usable, concrete class** (e.g. `Animal` could reasonably have a default `speak()` that returns `"..."`) → plain inheritance is the right tool, no `ABC` needed.

Reaching for `NotImplementedError` in a concrete base class, as the example above does, is the middle ground the handbook material calls out directly: it *works*, but an `ABC` communicates the same intent to both the reader and the interpreter more clearly.

## Where inheritance goes wrong

Deep inheritance chains (`D(C)`, `C(B)`, `B(A)`) couple every subclass to decisions made several classes up, so a change to `A` can silently break `D` in ways that are hard to trace. The common senior-level guidance — "favor composition over inheritance" — isn't a rule against inheritance itself; it's a reminder to reach for it only when there's a genuine **is-a** relationship (`Dog` *is an* `Animal`), and to model **has-a** relationships (`Car` *has an* `Engine`) by holding a reference to an object instead of inheriting from it.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-inheritance-q1",
      "type": "mcq",
      "prompt": "In the Animal/Dog/Cat example, why don't Dog and Cat redefine `__init__`?",
      "options": [
        { "id": "a", "text": "They can't — subclasses are never allowed to have their own __init__" },
        { "id": "b", "text": "Because they inherit Animal's __init__ unchanged, which already does everything they need" },
        { "id": "c", "text": "Python auto-generates a blank __init__ for every subclass" },
        { "id": "d", "text": "speak() implicitly calls __init__ every time" }
      ],
      "correct": "b",
      "explanation": "Inheritance means a subclass automatically has every method the parent defines, including __init__, unless the subclass explicitly overrides it. Dog and Cat only override speak() because that's the only behavior that differs."
    },
    {
      "id": "oop-collections-inheritance-q2",
      "type": "mcq",
      "prompt": "When is 'favor composition over inheritance' guidance actually pointing at?",
      "options": [
        { "id": "a", "text": "Inheritance should never be used in Python" },
        { "id": "b", "text": "Prefer modeling has-a relationships (e.g. Car has an Engine) via composition, and reserve inheritance for genuine is-a relationships" },
        { "id": "c", "text": "Composition is always faster at runtime than inheritance" },
        { "id": "d", "text": "Multiple inheritance is banned in modern Python" }
      ],
      "correct": "b",
      "explanation": "Inheritance is the right tool for a real is-a relationship (Dog is an Animal). Modeling has-a relationships as inheritance instead of composition is the classic path to fragile, deeply coupled hierarchies."
    }
  ]
}
```
