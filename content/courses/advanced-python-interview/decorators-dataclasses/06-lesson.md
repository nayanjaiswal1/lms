---
kind: lesson
id_key: advanced-python-interview/metaclasses-context-managers/metaclasses
course: advanced-python-interview
section: decorators-dataclasses
section_title: "Decorators, Dataclasses & Metaprogramming"
section_position: 10
section_group: Advanced
title: "Metaclasses"
position: 4
estimated_minutes: 30
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

## Metaclasses in Frameworks (Django Example)

Django models look like magic the first time you see them:

```python
class Article(models.Model):
    title = models.CharField(max_length=200)
    views = models.IntegerField()
```

`title` and `views` are just class attributes assigned instances of `CharField`/`IntegerField` — yet Django somehow turns them into database columns, gives the class a `.objects` manager, and lets you call `Article.objects.filter(views__gt=100)`. None of that is written anywhere in the `Article` class body. This is the previous lesson's metaclass hook, applied at framework scale.

### What actually happens at class-definition time

`models.Model`'s metaclass (`ModelBase`, a subclass of `type`) intercepts every subclass's creation. When `class Article(models.Model): ...` executes, Python calls `ModelBase.__new__`, which walks the class's namespace, pulls out every attribute that's an instance of `Field`, and rewrites the class before it's ever used.

```python
class Field:
    """Toy stand-in for django.db.models.CharField/IntegerField."""
    def __init__(self, kind):
        self.kind = kind


class DatabaseManager:
    def filter(self, **kwargs):
        print(f"SELECT * FROM table WHERE {kwargs}")


class ModelMeta(type):
    def __new__(mcs, name, bases, namespace):
        # Collect every attribute that's a Field instance
        fields = {
            key: value for key, value in namespace.items()
            if isinstance(value, Field)
        }
        namespace["_meta"] = {"fields": fields}
        namespace["objects"] = DatabaseManager()
        return super().__new__(mcs, name, bases, namespace)


class Model(metaclass=ModelMeta):
    pass


class Article(Model):
    title = Field("char")
    views = Field("int")


print(Article._meta["fields"])   # {'title': <Field ...>, 'views': <Field ...>}
Article.objects.filter(views__gt=100)  # SELECT * FROM table WHERE {'views__gt': 100}
```

`Article` never defines `_meta` or `objects` itself — `ModelMeta.__new__` injects both while the class is being built, before the module finishes importing. By the time your code runs `Article.objects`, the attribute has existed since class-definition time.

### Why this explains framework "magic"

This is the general pattern behind most "magic" class-based frameworks: a metaclass (or `__init_subclass__`) inspects the class body's declarative attributes — fields, routes, schema definitions — and generates the runtime machinery (database mappings, serializers, registries) automatically. Recognizing this pattern is what lets you read *any* unfamiliar framework's model/schema classes and know where to go looking for the code that's actually doing the work: the metaclass, not the subclass you're reading.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-metaclasses-q1",
      "type": "mcq",
      "prompt": "What is the default metaclass of every Python class unless you specify otherwise?",
      "options": [
        {
          "id": "a",
          "text": "object"
        },
        {
          "id": "b",
          "text": "type"
        },
        {
          "id": "c",
          "text": "class"
        },
        {
          "id": "d",
          "text": "meta"
        }
      ],
      "correct": "b",
      "explanation": "Every class's type is `type` by default — the `class` statement is syntactic sugar for calling `type(name, bases, namespace)`."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-q2",
      "type": "mcq",
      "prompt": "When does a metaclass's __new__ method run?",
      "options": [
        {
          "id": "a",
          "text": "Every time an instance of the class is created"
        },
        {
          "id": "b",
          "text": "Once, when the class itself is defined"
        },
        {
          "id": "c",
          "text": "Only when the class is subclassed"
        },
        {
          "id": "d",
          "text": "Every time an attribute on the class is accessed"
        }
      ],
      "correct": "b",
      "explanation": "A metaclass's __new__/__init__ hook into class creation, not instance creation — they run once when the `class` statement executes, not per-instance."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-q3",
      "type": "mcq",
      "prompt": "What's the generally recommended alternative to a custom metaclass for everyday application code?",
      "options": [
        {
          "id": "a",
          "text": "There is no alternative — metaclasses are always required for class customization"
        },
        {
          "id": "b",
          "text": "A class decorator, __init_subclass__, or a plain base class, which solve most problems with less indirection"
        },
        {
          "id": "c",
          "text": "Rewriting the class as a set of module-level functions"
        },
        {
          "id": "d",
          "text": "Using multiple inheritance instead"
        }
      ],
      "correct": "b",
      "explanation": "Metaclasses are powerful but heavy machinery; simpler hooks like __init_subclass__ or class decorators cover most real-world needs with far less indirection."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-in-frameworks-q1",
      "type": "mcq",
      "prompt": "In the toy ModelMeta example, why does Article.objects exist even though Article never defines it?",
      "options": [
        {
          "id": "a",
          "text": "Python automatically adds an `objects` attribute to every class"
        },
        {
          "id": "b",
          "text": "ModelMeta.__new__ injects `objects` into the namespace while the Article class is being built"
        },
        {
          "id": "c",
          "text": "It's inherited from the built-in `object` class"
        },
        {
          "id": "d",
          "text": "It's added lazily the first time Article() is instantiated"
        }
      ],
      "correct": "b",
      "explanation": "The metaclass's __new__ runs once at class-creation time and rewrites the namespace dict before the class object is finalized — that's where `objects` and `_meta` come from."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-in-frameworks-q2",
      "type": "mcq",
      "prompt": "What general pattern does Django's ModelBase metaclass demonstrate?",
      "options": [
        {
          "id": "a",
          "text": "Inspecting a class's declarative attributes at definition time to auto-generate runtime machinery"
        },
        {
          "id": "b",
          "text": "Encrypting class attributes for security"
        },
        {
          "id": "c",
          "text": "Replacing all instance methods with static methods"
        },
        {
          "id": "d",
          "text": "Preventing the class from ever being subclassed"
        }
      ],
      "correct": "a",
      "explanation": "This is the general shape of most 'magic' class-based frameworks: a metaclass reads declarative class-body attributes (fields, routes, schemas) and generates supporting machinery automatically."
    }
  ]
}
```
