---
kind: lesson
id_key: advanced-python-interview/oop-collections/polymorphism
course: advanced-python-interview
section: oop-collections
section_title: "Collections & OOP Foundations"
section_position: 2
title: "Polymorphism"
position: 5
estimated_minutes: 12
source: [fifty-advanced-python-concepts/19.polymorphism.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
Polymorphism means "the same interface, different behavior" — code written against a shared method name works correctly no matter which concrete type actually gets passed in, as long as that type implements the method.

## Same call, different behavior per type

```python
class Shape:
    def area(self):
        raise NotImplementedError("Subclasses must implement this method")

class Rectangle(Shape):
    def __init__(self, width, height):
        self.width = width
        self.height = height

    def area(self):
        return self.width * self.height

class Circle(Shape):
    def __init__(self, radius):
        self.radius = radius

    def area(self):
        return 3.14159 * self.radius * self.radius

def print_area(shape):
    print(f"The area is {shape.area()}")

rectangle = Rectangle(5, 10)
circle = Circle(7)

print_area(rectangle)  # The area is 50
print_area(circle)     # The area is 153.93899999999996
```

`print_area()` has no `if isinstance(shape, Rectangle)` branch anywhere. It calls `shape.area()` and trusts that whatever object it received knows how to answer that call correctly. Adding `Triangle(Shape)` tomorrow requires zero changes to `print_area()`.

## Duck typing: Python doesn't even require the shared base class

Because Python resolves `shape.area()` at call time by looking up `area` on the object's actual type — not by checking a declared type upfront — inheritance from `Shape` isn't strictly required for `print_area()` to work:

```python
class Square:  # doesn't inherit from Shape at all
    def __init__(self, side):
        self.side = side

    def area(self):
        return self.side ** 2

print_area(Square(4))  # The area is 16 — works, no shared base class
```

"If it walks like a duck and quacks like a duck, it's a duck": `print_area()` doesn't care what `Square` *is*, only that it *has* an `area()` method. This is polymorphism without a formal interface — a hallmark of how dynamically typed languages differ from statically typed ones, and a near-guaranteed interview follow-up once you mention polymorphism.

## Why it matters

Without polymorphism, adding a new shape means finding every function that branches on shape type and adding a new branch to each one — a maintenance burden that grows with every new type. With it, new types are additive: write the class, implement the shared method, done.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-polymorphism-q1",
      "type": "mcq",
      "prompt": "What does `print_area(shape)` need to know about `shape` in order to work correctly?",
      "options": [
        { "id": "a", "text": "Its exact class name, checked via isinstance" },
        { "id": "b", "text": "Only that it has an area() method that returns a number — nothing about its concrete type" },
        { "id": "c", "text": "That it inherits from a specific base class named Shape" },
        { "id": "d", "text": "Its memory address" }
      ],
      "correct": "b",
      "explanation": "Polymorphic code calls the shared method and trusts the object to implement it correctly — it doesn't need to know or check the object's concrete type."
    },
    {
      "id": "oop-collections-polymorphism-q2",
      "type": "mcq",
      "prompt": "Why does `print_area(Square(4))` work even though `Square` doesn't inherit from `Shape`?",
      "options": [
        { "id": "a", "text": "It doesn't — this would raise an AttributeError" },
        { "id": "b", "text": "Python's duck typing: print_area only needs shape.area() to exist and be callable, regardless of the object's class hierarchy" },
        { "id": "c", "text": "Square is automatically registered as a subclass of Shape" },
        { "id": "d", "text": "print_area() silently converts Square into a Rectangle first" }
      ],
      "correct": "b",
      "explanation": "Python looks up area on the object's actual type at call time — there's no compile-time interface check, so any object with a matching method works, shared base class or not."
    }
  ]
}
```
