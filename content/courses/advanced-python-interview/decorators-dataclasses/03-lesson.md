---
kind: lesson
id_key: advanced-python-interview/decorators-dataclasses/metaprogramming
course: advanced-python-interview
section: decorators-dataclasses
section_title: "Decorators, Dataclasses & Metaprogramming"
section_position: 7
title: "Metaprogramming"
position: 2
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md", "fifty-advanced-python-concepts/36.metaclasses.py", "fifty-advanced-python-concepts/45.advanced_decorators.py"]
---
Metaprogramming is code that writes, inspects, or modifies other code — at runtime, in Python's case, rather than at compile time. It's not a single feature; it's a category that decorators, metaclasses, dynamic attribute creation, and runtime introspection all belong to. Every ORM, dependency-injection container, and test framework you've used leans on it heavily, so recognizing the pattern (and its readability cost) is a senior-level skill in its own right.

## The three levers Python gives you

**1. Decorators** — wrap or rewrite a function/class definition at the moment it's created (covered in the previous lesson). This is metaprogramming at the *function/class* level.

**2. Metaclasses** — a metaclass controls how a *class itself* is built, the same way a class controls how its instances are built. `type` is the default metaclass for every class in Python; a custom metaclass hooks into that process (covered in a later lesson).

**3. Dynamic attribute creation & inspection** — building or reading attributes at runtime instead of writing them out in source. `type()` called with three arguments creates a class on the fly:

```python
def greet(self):
    return f"Hi, I'm {self.name}"

Person = type("Person", (), {"greet": greet, "species": "human"})

p = Person()
p.name = "Ana"
print(p.greet())     # Hi, I'm Ana
print(p.species)     # human
print(type(Person))  # <class 'type'>
```

`class Person: ...` is sugar for exactly this call — the interpreter builds the class body into a namespace dict and calls `type(name, bases, namespace)` on it. Writing that call directly is how frameworks generate classes from data they don't know about until runtime (an ORM building a model class from a database schema, for instance).

## Runtime inspection: `getattr`/`setattr`/`hasattr`

The introspection half of metaprogramming — reading or writing attributes by *name*, computed at runtime rather than known at write time:

```python
class Config:
    debug = False
    timeout = 30

settings = {"debug": True, "retries": 3}
cfg = Config()
for key, value in settings.items():
    setattr(cfg, key, value)   # cfg.debug = True; cfg.retries = 3

print(cfg.debug, cfg.timeout, cfg.retries)  # True 30 3
print(getattr(cfg, "missing", "default"))   # "default" — no AttributeError
```

This is how a config loader can populate arbitrary settings from a JSON file, or a serializer can round-trip arbitrary fields, without a hardcoded `if key == "debug": self.debug = value` branch per field.

## Where the industry uses this

- **ORMs** (Django, SQLAlchemy): a metaclass turns class-level attribute declarations (`name = CharField()`) into database column mappings.
- **Dependency injection containers**: inspect a function's parameter names/annotations at runtime and auto-supply matching registered objects.
- **Test frameworks** (pytest): discover functions named `test_*` via introspection, then wrap them with fixtures via decorators.

## The cost

Every lever above makes code *dynamic* — which also makes it harder to trace with a plain text search, harder for static type checkers to verify, and harder to debug because the "definition" of behavior isn't sitting in one readable place. The senior-level judgment call isn't "can I do this with metaprogramming" (usually yes) but "does the flexibility this buys pay for the readability it costs" — reach for it when you're building a reusable framework surface, not for one-off application code.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-metaprogramming-q1",
      "type": "mcq",
      "prompt": "Which of these is NOT one of Python's core metaprogramming mechanisms?",
      "options": [
        { "id": "a", "text": "Decorators" },
        { "id": "b", "text": "Metaclasses" },
        { "id": "c", "text": "List comprehensions" },
        { "id": "d", "text": "Dynamic attribute creation with setattr/type()" }
      ],
      "correct": "c",
      "explanation": "List comprehensions are ordinary syntax for building a list — they don't modify or generate code at runtime. Decorators, metaclasses, and dynamic attribute creation all do."
    },
    {
      "id": "decorators-dataclasses-metaprogramming-q2",
      "type": "mcq",
      "prompt": "What does `type(\"Person\", (), {\"species\": \"human\"})` do?",
      "options": [
        { "id": "a", "text": "Returns the string \"Person\"" },
        { "id": "b", "text": "Creates a new class named Person with no bases and a species class attribute — equivalent to a `class Person:` statement" },
        { "id": "c", "text": "Raises a TypeError because type() only takes one argument" },
        { "id": "d", "text": "Creates an instance of an existing Person class" }
      ],
      "correct": "b",
      "explanation": "type() called with three arguments (name, bases tuple, namespace dict) builds a new class object — exactly what a `class` statement compiles down to internally."
    },
    {
      "id": "decorators-dataclasses-metaprogramming-q3",
      "type": "mcq",
      "prompt": "What's the main tradeoff to weigh before reaching for metaprogramming in application code?",
      "options": [
        { "id": "a", "text": "Metaprogramming always makes code run slower, so it should be avoided for performance" },
        { "id": "b", "text": "It buys flexibility at the cost of readability and traceability — harder to grep, harder for type checkers, harder to debug" },
        { "id": "c", "text": "Python forbids metaprogramming outside of the standard library" },
        { "id": "d", "text": "It only works inside classes, never with plain functions" }
      ],
      "correct": "b",
      "explanation": "Dynamic behavior (metaclasses, runtime attribute creation, etc.) is harder to trace statically. It's the right tool when building a reusable framework surface, not a default for one-off code."
    }
  ]
}
```
