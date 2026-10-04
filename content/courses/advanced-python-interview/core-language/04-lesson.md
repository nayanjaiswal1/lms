---
kind: lesson
id_key: advanced-python-interview/core-language/monkey-patching
course: advanced-python-interview
section: core-language
section_title: "Core Language"
section_position: 0
section_group: Fundamentals
title: "Monkey Patching"
position: 3
estimated_minutes: 10
source: ["knowledge/backend/python/python-core.md"]
---
Because classes, modules and functions are ordinary objects with mutable attributes, Python lets you change them while the program runs. That power is called monkey patching, and interviewers ask about it to see whether you know both the mechanism and why it is usually discouraged.

## What monkey patching is

Monkey patching means changing the behavior of an existing class, module or function at runtime, without editing its source. The name comes from "guerrilla patching" (quick unofficial fixes), misheard as "gorilla" and then "monkey". In Python it is just attribute assignment.

```python
class Calculator:
    def add(self, a, b):
        return a + b

Calculator.add = lambda self, a, b: a + b + 10  # replace the method on the class

print(Calculator().add(2, 3))  # 15, not 5
```

Patching the **class** affects every instance, including ones created earlier, because method lookup happens at call time. Patching a single **instance** affects only that object.

```python
class Greeter:
    def hello(self):
        return "hello"

a, b = Greeter(), Greeter()
a.hello = lambda: "patched"  # instance attribute shadows the class method
print(a.hello(), b.hello())  # patched hello
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-patch-q1",
      "type": "mcq",
      "prompt": "What is monkey patching?",
      "options": [
        { "id": "a", "text": "Changing a class, module or function's behavior at runtime without editing its source" },
        { "id": "b", "text": "Recompiling a module to bytecode" },
        { "id": "c", "text": "Copying a function so the original is preserved" },
        { "id": "d", "text": "Installing a patch release of a package" }
      ],
      "correct": "a",
      "explanation": "It is runtime modification of existing code objects, done in Python by assigning to attributes."
    },
    {
      "id": "core-language-patch-q2",
      "type": "mcq",
      "prompt": "You assign `Calculator.add = new_func` after creating `calc = Calculator()`. What does `calc.add(1, 2)` use?",
      "options": [
        { "id": "a", "text": "The old method, since calc already exists" },
        { "id": "b", "text": "The new method, because lookup happens on the class at call time" },
        { "id": "c", "text": "Neither; it raises AttributeError" },
        { "id": "d", "text": "Both, and returns a tuple" }
      ],
      "correct": "b",
      "explanation": "Instances do not copy methods; they look them up on the class when called, so the patched version is used."
    }
  ]
}
```

## When it is used, and why it is risky

Legitimate uses: a hotfix for a third-party bug you cannot wait on, working around a framework limitation, and replacing dependencies in tests (this is how `unittest.mock.patch` works, and it restores the original afterward).

The downsides are serious. The change is invisible to anyone reading the original class, it can be silently undone or broken by a library upgrade, and load order decides which patch wins. Prefer subclassing, composition or dependency injection, and treat patching as a last resort that is documented, narrow and reversible.

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-patch-risk-q1",
      "type": "mcq",
      "prompt": "Why is monkey patching generally considered a code smell?",
      "options": [
        { "id": "a", "text": "It is not allowed by the Python interpreter in production" },
        { "id": "b", "text": "The changed behavior is invisible in the original source and can break when the patched library updates" },
        { "id": "c", "text": "It always makes programs slower by a large factor" },
        { "id": "d", "text": "It permanently modifies the library's files on disk" }
      ],
      "correct": "b",
      "explanation": "Patches live outside the original definition, so readers miss them and upgrades can silently invalidate them."
    },
    {
      "id": "core-language-patch-risk-q2",
      "type": "mcq",
      "prompt": "Which is a typical legitimate use of monkey patching?",
      "options": [
        { "id": "a", "text": "Temporarily replacing a network call with a fake during a unit test" },
        { "id": "b", "text": "Renaming every method in your own codebase for style" },
        { "id": "c", "text": "Avoiding writing a subclass in your own new code" },
        { "id": "d", "text": "Hiding bugs from other developers" }
      ],
      "correct": "a",
      "explanation": "Test doubles are the common accepted case, ideally through a scoped tool like unittest.mock.patch that restores the original."
    }
  ]
}
```

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

#### What is monkey patching?

Monkey patching is a technique where you modify or extend code at runtime by changing the behavior of classes, modules, or functions after they've been defined — without editing their source code.

The term comes from "guerrilla patching" (making quick, unofficial fixes), which was misheard as "gorilla patching" and evolved into "monkey patching."

**How it works** — in languages like Python, Ruby, or JavaScript, you can reassign methods or attributes of existing objects:

```text
# Original class
class Calculator:
    def add(self, a, b):
        return a + b

# Monkey patching - changing the method at runtime
Calculator.add = lambda self, a, b: a + b + 10

calc = Calculator()
calc.add(2, 3)  # Returns 15 instead of 5
```

**Common uses:**
- Fixing bugs in third-party libraries when you can't wait for an official patch
- Adding functionality to libraries for testing purposes
- Working around limitations in frameworks
- Creating mock objects for unit tests

**Downsides:** monkey patching is generally a code smell — it makes code harder to understand and maintain. Someone reading the original class definition won't see the changes, which leads to confusion and bugs. It's also fragile — if the library updates, patches can break or behave unexpectedly. Most developers treat it as a last resort, preferring subclassing, composition, or dependency injection when possible.
