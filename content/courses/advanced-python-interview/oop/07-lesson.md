---
kind: lesson
id_key: advanced-python-interview/exceptions-oop/property
course: advanced-python-interview
section: oop
section_title: "Object-Oriented Python"
section_position: 3
section_group: Fundamentals
title: "`@property`: Getters, Setters & Validation"
position: 6
estimated_minutes: 10
source: ["knowledge/backend/python/python-oop-lld.md"]
---
Python has no `get_x()`/`set_x()` convention because `@property` lets a plain attribute grow logic later without changing how callers use it. Callers write `person.age`; the class decides what happens behind it.

## Getter: a method that reads like an attribute

Decorating a method with `@property` makes `obj.name` call it with no parentheses. Store the real value in a "protected" attribute (`_age`) and expose the property under the public name. A property with no setter is read-only, which is the idiomatic way to expose computed or immutable values.

```python
class Circle:
    def __init__(self, r):
        self.r = r

    @property
    def area(self):
        return 3.14159 * self.r ** 2

c = Circle(2)
print(c.area)
try:
    c.area = 5
except AttributeError as e:
    print("read-only:", type(e).__name__)
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-property-q1",
      "type": "mcq",
      "prompt": "What happens when you assign to a property defined with only a getter?",
      "options": [
        { "id": "a", "text": "The value is stored silently on the instance" },
        { "id": "b", "text": "AttributeError is raised, making it read-only" },
        { "id": "c", "text": "The getter is called with the new value" },
        { "id": "d", "text": "The property is converted into a normal attribute" }
      ],
      "correct": "b",
      "explanation": "A property is a data descriptor; without a setter, assignment raises AttributeError."
    }
  ]
}
```

## Setter: validate on assignment

Add a setter with `@<name>.setter`. It runs on every `obj.attr = value`, including inside `__init__` if you assign through the property (not the underscore field), so the invariant holds from construction onward.

```python
class Person:
    def __init__(self, age):
        self.age = age  # goes through the setter, so validation applies

    @property
    def age(self):
        return self._age

    @age.setter
    def age(self, val):
        if val < 0:
            raise ValueError("Age must be >= 0")
        self._age = val

p = Person(30)
p.age = 31
print(p.age)
try:
    Person(-1)
except ValueError as e:
    print(e)
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-property-q2",
      "type": "mcq",
      "prompt": "Why does `__init__` assign `self.age = age` rather than `self._age = age`?",
      "options": [
        { "id": "a", "text": "So the setter's validation also runs when the object is constructed" },
        { "id": "b", "text": "Because underscore attributes cannot be set in __init__" },
        { "id": "c", "text": "It is faster" },
        { "id": "d", "text": "Because the getter requires it" }
      ],
      "correct": "a",
      "explanation": "Going through the property applies the same validation to the initial value; writing _age directly would bypass it."
    }
  ]
}
```

## Why properties beat get/set methods

You can start with a plain public attribute and later convert it into a property (adding validation, caching or computation) without breaking any caller, because the access syntax is identical. That is why Python style says: no getters and setters until you need logic. It also gives encapsulation without a `private` keyword, since writes funnel through code you control. Under the hood `property` is a descriptor implementing `__get__`/`__set__`, and an optional `@x.deleter` handles `del obj.x`.

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-property-q3",
      "type": "mcq",
      "prompt": "What is the main advantage of starting with a plain attribute and switching to @property later?",
      "options": [
        { "id": "a", "text": "Callers' code (`obj.x`) stays unchanged while the class gains validation or computation" },
        { "id": "b", "text": "Properties are stored in a faster slot" },
        { "id": "c", "text": "It makes the attribute truly private" },
        { "id": "d", "text": "It avoids needing __init__" }
      ],
      "correct": "a",
      "explanation": "Property access syntax matches attribute access, so adding logic is backward compatible, unlike Java-style getX()/setX()."
    }
  ]
}
```

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

##### `@property` — getter/setter with validation

```text
class Person:
    def __init__(self, age):
        self._age = age

    @property
    def age(self):             # getter — accessed like an attribute: person.age
        return self._age

    @age.setter
    def age(self, val):        # setter — validated on assignment: person.age = val
        if val < 0:
            raise ValueError("Age must be >= 0")
        self._age = val
```

`@property` turns a method into an attribute-like accessor, so callers write `person.age` instead of `person.get_age()`, while the setter still lets you validate or transform the value on assignment — the key mechanism for encapsulation in Python (see below), since there's no `private` keyword to enforce it otherwise.
