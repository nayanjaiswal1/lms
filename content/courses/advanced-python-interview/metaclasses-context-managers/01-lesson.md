---
kind: lesson
id_key: advanced-python-interview/metaclasses-context-managers/metaclasses
course: advanced-python-interview
section: metaclasses-context-managers
section_title: "Metaclasses & Context Managers"
section_position: 5
title: "Metaclasses"
position: 0
estimated_minutes: 18
source: [fifty-advanced-python-concepts/36.metaclasses.py, fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md]
---
Every class you write in Python is itself an object — and like every object, it has a type. The type of a class is its **metaclass**. By default that metaclass is the built-in `type`, which means every `class Dog: ...` statement you've ever written was secretly a call to `type(...)`.

## `class` is sugar for calling `type`

```python
class Dog:
    pass

# The class statement above is equivalent to calling type() directly:
# type(name, bases, namespace) -> a new class
Dog2 = type("Dog2", (), {})

print(type(Dog))    # <class 'type'>
print(type(Dog2))   # <class 'type'>
print(Dog2().__class__.__name__)  # Dog2
```

`type` takes three arguments: the class's name, a tuple of base classes, and a dict of the class body's attributes and methods. The `class` keyword is just readable syntax for building that same call.

## Writing your own metaclass

A **metaclass** is a class that inherits from `type` and overrides `__new__` (or `__init__`) to hook into class *creation itself* — not instance creation. This lets you inspect, validate, or rewrite a class's attributes the moment the class is defined, before anyone ever instantiates it.

```python
class UpperAttrMeta(type):
    def __new__(mcs, name, bases, namespace):
        # Rewrite every non-dunder attribute name to uppercase
        uppercase_namespace = {
            (key.upper() if not key.startswith("__") else key): value
            for key, value in namespace.items()
        }
        return super().__new__(mcs, name, bases, uppercase_namespace)


class Config(metaclass=UpperAttrMeta):
    timeout = 30
    retries = 3


print(Config.TIMEOUT)  # 30
print(Config.RETRIES)  # 3
print(hasattr(Config, "timeout"))  # False — it was rewritten at class-creation time
```

`UpperAttrMeta.__new__` runs once, when the `Config` class body finishes executing — not once per instance. Every `Config()` you create afterward already has uppercase attributes; the metaclass did its work at class-definition time.

## When to actually reach for one

Metaclasses are the most powerful hook Python gives you into the language itself, and that power is exactly why the common advice is "metaclasses are solutions in search of a problem" for application code. They're the right tool when you need to enforce a rule across *every subclass* automatically — registering every subclass in a registry, validating that required class attributes are present, or generating boilerplate methods — the kind of thing frameworks do (see the next lesson for how Django's ORM uses this). For everyday code, a class decorator, `__init_subclass__`, or a plain base class usually solves the same problem with far less indirection.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-metaclasses-q1",
      "type": "mcq",
      "prompt": "What is the default metaclass of every Python class unless you specify otherwise?",
      "options": [
        { "id": "a", "text": "object" },
        { "id": "b", "text": "type" },
        { "id": "c", "text": "class" },
        { "id": "d", "text": "meta" }
      ],
      "correct": "b",
      "explanation": "Every class's type is `type` by default — the `class` statement is syntactic sugar for calling `type(name, bases, namespace)`."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-q2",
      "type": "mcq",
      "prompt": "When does a metaclass's __new__ method run?",
      "options": [
        { "id": "a", "text": "Every time an instance of the class is created" },
        { "id": "b", "text": "Once, when the class itself is defined" },
        { "id": "c", "text": "Only when the class is subclassed" },
        { "id": "d", "text": "Every time an attribute on the class is accessed" }
      ],
      "correct": "b",
      "explanation": "A metaclass's __new__/__init__ hook into class creation, not instance creation — they run once when the `class` statement executes, not per-instance."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-q3",
      "type": "mcq",
      "prompt": "What's the generally recommended alternative to a custom metaclass for everyday application code?",
      "options": [
        { "id": "a", "text": "There is no alternative — metaclasses are always required for class customization" },
        { "id": "b", "text": "A class decorator, __init_subclass__, or a plain base class, which solve most problems with less indirection" },
        { "id": "c", "text": "Rewriting the class as a set of module-level functions" },
        { "id": "d", "text": "Using multiple inheritance instead" }
      ],
      "correct": "b",
      "explanation": "Metaclasses are powerful but heavy machinery; simpler hooks like __init_subclass__ or class decorators cover most real-world needs with far less indirection."
    }
  ]
}
```
