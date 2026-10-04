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

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

#### Python Functions

**What are functions?** A function is a reusable, self-contained block of code that performs a specific task.

```text
def function_name(parameters):
    """Docstring - explains what function does"""
    statement_1
    statement_2
    return result
```

Components: `def` keyword, `function_name` (valid identifier), optional `parameters`, `:` header terminator, indented body, optional `return`.

```text
def greet(name):
    """Print a greeting message."""
    print(f"Hello, {name}!")

greet("Alice")  # Output: Hello, Alice!
```

**Why use functions?**

1. **Abstraction** — hide complex details, show only the interface (name + parameters). Example: `len()` — you don't need to know how it counts.
2. **Encapsulation** — variables inside a function are isolated, no conflicts with outer variables, data stays safe inside the function.
3. **Modularity** — break large programs into smaller pieces, each function does one specific task, easier to understand and debug.
4. **Reusability** — write once, use many times; change in one place updates everywhere.
5. **Maintainability** — easier to find and fix bugs; well-named functions explain what the code does.
6. **Testability** — test each function independently with clear inputs and outputs.


##### Defining and calling

```text
def function_name():
    pass  # empty function (stub)

def add(a, b):
    return a + b

def greet(name, greeting="Hello"):
    return f"{greeting}, {name}!"

def get_min_max(numbers):
    return min(numbers), max(numbers)  # returns tuple
```

Rules: function names follow variable naming rules; parameters must be valid identifiers; indentation is mandatory (4 spaces); `:` is required after the header; empty functions need `pass` or `...`.

```text
function_name()             # no arguments
result = add(5, 3)          # store return value
total = add(5, 3) + add(2, 4)  # use in expressions

print(add)       # <function add at 0x...> — forgot the parentheses
print(add(5, 3)) # 8 — actually calls it
```


##### Arguments deep dive

**Positional arguments** — matched by order.

```text
def describe_pet(animal, name):
    print(f"I have a {animal} named {name}")

describe_pet("dog", "Buddy")  # correct
describe_pet("Buddy", "dog")  # wrong order!
```

**Keyword arguments** — specified by parameter name, order-independent, more readable.

```text
describe_pet(animal="cat", name="Whiskers")
describe_pet(name="Max", animal="hamster")  # order doesn't matter
```

**Mixing positional and keyword** — positional arguments must come before keyword arguments.

```text
def calculate_cost(item, quantity, price):
    return quantity * price

calculate_cost("apple", 5, 0.99)
calculate_cost("apple", quantity=5, price=0.99)
calculate_cost("apple", price=0.99, quantity=5)
# calculate_cost(item="apple", 5, 0.99)  # SyntaxError - positional after keyword
```

**Default arguments** — the default is created once, at function definition time, not on each call. This is the mutable-default trap again:

```text
# WRONG
def add_item(item, my_list=[]):
    my_list.append(item)
    return my_list

add_item(1)  # [1]
add_item(2)  # [1, 2] - NOT [2]! same list every call

# CORRECT — use None as sentinel
def add_item(item, my_list=None):
    if my_list is None:
        my_list = []
    my_list.append(item)
    return my_list
```

**`*args`** — packs any number of positional arguments into a tuple:

```text
def average(*numbers):
    return sum(numbers) / len(numbers)

average(1, 2, 3)  # 2.0
```

**`**kwargs`** — packs any number of keyword arguments into a dict:

```text
def print_info(**kwargs):
    for key, value in kwargs.items():
        print(f"{key}: {value}")

print_info(name="Alice", age=25, city="NYC")
```

**Combining all argument types** — order matters:

```text
def func(pos1, pos2, *args, kw1, kw2, **kwargs):
    pass

def make_sandwich(bread, *fillings, sauce="mayo", **extras):
    print(f"Bread: {bread}")
    print(f"Fillings: {fillings}")
    print(f"Sauce: {sauce}")
    print(f"Extras: {extras}")
```

**Positional-only arguments** (Python 3.8+) — `/` marks the end of positional-only parameters:

```text
def divide(a, b, /):
    return a / b

divide(10, 2)       # works
# divide(a=10, b=2) # TypeError
```

**Keyword-only arguments** — parameters after `*` or `*args` must be passed by keyword:

```text
def greet(name, *, greeting="Hello", excited=False):
    msg = f"{greeting}, {name}"
    if excited:
        msg += "!"
    return msg

greet("Alice")                            # Hello, Alice
greet("Bob", greeting="Hi")               # Hi, Bob
# greet("Dave", "Howdy")                  # TypeError
```

**Complete argument order:**

```text
def ultimate_func(
    pos_only1, pos_only2, /,           # positional-only
    normal1, normal2,                   # normal (positional or keyword)
    *args,                              # variable positional
    kw_only1, kw_only2="default",       # keyword-only
    **kwargs                            # variable keyword
):
    pass
```


##### Unpacking in function calls

```text
def add(a, b, c):
    return a + b + c

numbers = [1, 2, 3]
result = add(*numbers)  # same as add(1, 2, 3)

def greet(first, last):
    print(f"Hello, {first} {last}")

person = {"first": "John", "last": "Doe"}
greet(**person)  # same as greet(first="John", last="Doe")
```
