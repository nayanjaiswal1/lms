---
kind: lesson
id_key: advanced-python-interview/functions/arguments
course: advanced-python-interview
section: functions
section_title: "Functions & Scope"
section_position: 1
section_group: Fundamentals
title: "Function Arguments"
position: 0
estimated_minutes: 13
source: ["knowledge/backend/python/python-functions.md"]
---
Interviewers love function signatures because one line reveals whether you know how Python binds arguments. This lesson covers every way a value can reach a parameter, and the order the language forces on them.

## Positional and keyword arguments

A **positional** argument is matched to a parameter by its place in the call. A **keyword** argument is matched by name, so order stops mattering and the call documents itself. You can mix them, but every positional argument must come before the first keyword argument.

```python
def calculate_cost(item, quantity, price):
    return f"{item}: {quantity * price:.2f}"

print(calculate_cost("apple", 5, 0.99))
print(calculate_cost("apple", quantity=5, price=0.99))
print(calculate_cost("apple", price=0.99, quantity=5))

try:
    eval('calculate_cost(item="apple", 5, 0.99)')
except SyntaxError as e:
    print("SyntaxError:", e.msg)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-arguments-q1",
      "type": "mcq",
      "prompt": "Which call to def f(a, b, c) is a SyntaxError?",
      "options": [
        { "id": "a", "text": "f(1, 2, c=3)" },
        { "id": "b", "text": "f(1, c=3, b=2)" },
        { "id": "c", "text": "f(a=1, 2, 3)" },
        { "id": "d", "text": "f(c=3, b=2, a=1)" }
      ],
      "correct": "c",
      "explanation": "A positional argument cannot follow a keyword argument. The other calls keep positionals first or use only keywords."
    }
  ]
}
```

## Defaults are evaluated once

A default value is created **once, when `def` executes**, and stored on the function object. Every call that omits the argument shares that same object. For immutable defaults (numbers, strings, `None`) this is harmless; for a list or dict it becomes shared state. The standard fix is a `None` sentinel. (The mutable-default trap is treated in depth in the core-language section; here, remember only the rule and the sentinel idiom.)

```python
def add_item(item, bucket=[]):
    bucket.append(item)
    return bucket

print(add_item(1))
print(add_item(2))
print(add_item.__defaults__)

def add_item_safe(item, bucket=None):
    if bucket is None:
        bucket = []
    bucket.append(item)
    return bucket

print(add_item_safe(1))
print(add_item_safe(2))
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-arguments-q2",
      "type": "mcq",
      "prompt": "When is the default value expression in def f(x, y=[]) evaluated?",
      "options": [
        { "id": "a", "text": "Every time f is called without y" },
        { "id": "b", "text": "Once, when the def statement runs" },
        { "id": "c", "text": "Once, the first time f is called" },
        { "id": "d", "text": "At import time of the caller" }
      ],
      "correct": "b",
      "explanation": "Defaults are evaluated at function definition time and stored in __defaults__, so all calls share the same object."
    }
  ]
}
```

## *args and **kwargs

`*args` collects extra positional arguments into a **tuple**; `**kwargs` collects extra keyword arguments into a **dict**. The names are convention, the stars are the syntax. They are how wrappers and decorators forward whatever they were given.

```python
def average(*numbers):
    return sum(numbers) / len(numbers)

def print_info(**kwargs):
    print(type(kwargs).__name__, kwargs)

print(average(1, 2, 3))
print_info(name="Alice", age=25)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-arguments-q3",
      "type": "mcq",
      "prompt": "Inside def f(*args, **kwargs), what are the types of args and kwargs?",
      "options": [
        { "id": "a", "text": "list and dict" },
        { "id": "b", "text": "tuple and dict" },
        { "id": "c", "text": "tuple and tuple" },
        { "id": "d", "text": "list and list of pairs" }
      ],
      "correct": "b",
      "explanation": "*args is packed into a tuple and **kwargs into a dict."
    }
  ]
}
```

## Positional-only (/) and keyword-only (*) parameters

Parameters before a bare `/` can only be passed by position (Python 3.8+), which lets you rename them later without breaking callers. Parameters after a bare `*` (or after `*args`) can only be passed by keyword, which forces readable call sites for flags.

```python
def divide(a, b, /):
    return a / b

def greet(name, *, greeting="Hello", excited=False):
    return f"{greeting}, {name}" + ("!" if excited else "")

print(divide(10, 2))
print(greet("Bob", greeting="Hi", excited=True))

for call in ("divide(a=10, b=2)", 'greet("Dave", "Howdy")'):
    try:
        eval(call)
    except TypeError as e:
        print("TypeError:", e)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-arguments-q4",
      "type": "mcq",
      "prompt": "Given def greet(name, *, greeting=\"Hello\"), what does greet(\"Dave\", \"Howdy\") do?",
      "options": [
        { "id": "a", "text": "Returns 'Howdy, Dave'" },
        { "id": "b", "text": "Returns 'Hello, Dave'" },
        { "id": "c", "text": "Raises TypeError because greeting is keyword-only" },
        { "id": "d", "text": "Raises SyntaxError" }
      ],
      "correct": "c",
      "explanation": "Parameters after the bare * must be passed by keyword; the extra positional argument has nowhere to go, so TypeError."
    },
    {
      "id": "functions-arguments-q5",
      "type": "mcq",
      "prompt": "Why would you put / in a signature?",
      "options": [
        { "id": "a", "text": "To make the parameters required" },
        { "id": "b", "text": "To force the preceding parameters to be passed positionally so their names can change freely" },
        { "id": "c", "text": "To allow unlimited arguments" },
        { "id": "d", "text": "To make the function faster" }
      ],
      "correct": "b",
      "explanation": "Positional-only parameters are not part of the public keyword interface, so renaming them is not a breaking change."
    }
  ]
}
```

## The full parameter order

A signature must list parameter kinds in this order: positional-only, `/`, normal, `*args`, keyword-only, `**kwargs`. Any group may be absent, but the order is fixed.

```python
def ultimate(p1, p2, /, n1, n2, *args, k1, k2="default", **kwargs):
    return p1, p2, n1, n2, args, k1, k2, kwargs

print(ultimate(1, 2, 3, n2=4, k1="x", extra=True))
print(ultimate(1, 2, 3, 4, 5, 6, k1="x"))
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-arguments-q6",
      "type": "mcq",
      "prompt": "Which signature has a valid parameter order?",
      "options": [
        { "id": "a", "text": "def f(**kwargs, *args)" },
        { "id": "b", "text": "def f(a, /, b, *args, c, **kwargs)" },
        { "id": "c", "text": "def f(*args, a, /, b)" },
        { "id": "d", "text": "def f(a, **kwargs, *, c)" }
      ],
      "correct": "b",
      "explanation": "Order is positional-only, /, normal, *args, keyword-only, **kwargs. Option b follows it exactly."
    }
  ]
}
```

## Unpacking in calls

The stars also work at the **call site**: `*iterable` spreads items as positional arguments and `**mapping` spreads key/value pairs as keyword arguments. This is the mirror image of packing, and it is how wrappers forward arguments unchanged.

```python
def add(a, b, c):
    return a + b + c

def greet(first, last):
    return f"Hello, {first} {last}"

print(add(*[1, 2, 3]))
print(greet(**{"first": "John", "last": "Doe"}))
print(add(*(1, 2), **{"c": 10}))
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-arguments-q7",
      "type": "mcq",
      "prompt": "What does greet(**{\"first\": \"John\", \"last\": \"Doe\"}) expand to?",
      "options": [
        { "id": "a", "text": "greet(\"first\", \"last\")" },
        { "id": "b", "text": "greet(\"John\", \"Doe\")" },
        { "id": "c", "text": "greet(first=\"John\", last=\"Doe\")" },
        { "id": "d", "text": "greet({\"first\": \"John\", \"last\": \"Doe\"})" }
      ],
      "correct": "c",
      "explanation": "** unpacks a mapping into keyword arguments, using its keys as parameter names."
    }
  ]
}
```
