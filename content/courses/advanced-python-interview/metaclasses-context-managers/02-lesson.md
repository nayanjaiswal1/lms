---
kind: lesson
id_key: advanced-python-interview/metaclasses-context-managers/metaclasses-in-frameworks
course: advanced-python-interview
section: metaclasses-context-managers
section_title: "Metaclasses & Context Managers"
section_position: 5
title: "Metaclasses in Frameworks (Django Example)"
position: 1
estimated_minutes: 12
source: [fifty-advanced-python-concepts/36.metaclasses.py, fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md]
---
Django models look like magic the first time you see them:

```python
class Article(models.Model):
    title = models.CharField(max_length=200)
    views = models.IntegerField()
```

`title` and `views` are just class attributes assigned instances of `CharField`/`IntegerField` — yet Django somehow turns them into database columns, gives the class a `.objects` manager, and lets you call `Article.objects.filter(views__gt=100)`. None of that is written anywhere in the `Article` class body. This is the previous lesson's metaclass hook, applied at framework scale.

## What actually happens at class-definition time

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

## Why this explains framework "magic"

This is the general pattern behind most "magic" class-based frameworks: a metaclass (or `__init_subclass__`) inspects the class body's declarative attributes — fields, routes, schema definitions — and generates the runtime machinery (database mappings, serializers, registries) automatically. Recognizing this pattern is what lets you read *any* unfamiliar framework's model/schema classes and know where to go looking for the code that's actually doing the work: the metaclass, not the subclass you're reading.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-metaclasses-in-frameworks-q1",
      "type": "mcq",
      "prompt": "In the toy ModelMeta example, why does Article.objects exist even though Article never defines it?",
      "options": [
        { "id": "a", "text": "Python automatically adds an `objects` attribute to every class" },
        { "id": "b", "text": "ModelMeta.__new__ injects `objects` into the namespace while the Article class is being built" },
        { "id": "c", "text": "It's inherited from the built-in `object` class" },
        { "id": "d", "text": "It's added lazily the first time Article() is instantiated" }
      ],
      "correct": "b",
      "explanation": "The metaclass's __new__ runs once at class-creation time and rewrites the namespace dict before the class object is finalized — that's where `objects` and `_meta` come from."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-in-frameworks-q2",
      "type": "mcq",
      "prompt": "What general pattern does Django's ModelBase metaclass demonstrate?",
      "options": [
        { "id": "a", "text": "Inspecting a class's declarative attributes at definition time to auto-generate runtime machinery" },
        { "id": "b", "text": "Encrypting class attributes for security" },
        { "id": "c", "text": "Replacing all instance methods with static methods" },
        { "id": "d", "text": "Preventing the class from ever being subclassed" }
      ],
      "correct": "a",
      "explanation": "This is the general shape of most 'magic' class-based frameworks: a metaclass reads declarative class-body attributes (fields, routes, schemas) and generates supporting machinery automatically."
    }
  ]
}
```
