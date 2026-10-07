---
kind: lesson
id_key: advanced-python-interview/serialization-data/higher-order-functions
course: advanced-python-interview
section: functions
section_title: "Functions & Scope"
section_position: 1
section_group: Fundamentals
title: "Higher-Order Functions"
position: 3
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/30.higher_order_functions.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md"]
---
A higher-order function either takes a function as an argument, returns a function, or both. Python treats functions as first-class values — they can be stored in variables, passed around, and stored in data structures exactly like any other object — and higher-order functions are what you build once that's true.

## Taking functions as arguments

```python
def validate(data, *validators):
    for validator in validators:
        if not validator(data):
            return False
    return True

is_non_empty = lambda x: bool(x)
is_alpha = lambda x: x.isalpha()

print(validate("Python", is_non_empty, is_alpha))   # True
print(validate("", is_non_empty, is_alpha))          # False — fails is_non_empty
print(validate("Py3", is_non_empty, is_alpha))       # False — fails is_alpha
```

`validate` doesn't know or care what "valid" means — that logic lives entirely in whichever validator functions get passed in. Adding a new rule (`is_lowercase`, `max_length(20)`) never touches `validate` itself; this is the same shape as Django's form validators or FastAPI's dependency checks.

## Returning functions: closures as configuration

The other direction — a function that *returns* a function — lets you bake in configuration once and reuse the specialized result:

```python
def make_multiplier(factor):
    def multiplier(x):
        return x * factor
    return multiplier

double = make_multiplier(2)
triple = make_multiplier(3)

print(double(5))   # 10
print(triple(5))   # 15
```

`double` and `triple` are both `multiplier` functions, but each closes over its own `factor` — this is a closure, and it's the mechanism behind decorators, middleware chains, and callback factories.

## `filter`: a built-in higher-order function

`filter(predicate, iterable)` takes a predicate (a function returning `True`/`False`) and returns a lazy iterator yielding only the items the predicate accepted.

### Replacing a manual loop

```python
numbers = [1, 2, 3, 4, 5, 6]

# The loop version
evens = []
for n in numbers:
    if n % 2 == 0:
        evens.append(n)
print(evens)  # [2, 4, 6]

# The filter version — same result, one line
evens = list(filter(lambda n: n % 2 == 0, numbers))
print(evens)  # [2, 4, 6]
```

`filter` doesn't build a list itself — it returns a lazy iterator, so `list(...)` (or a `for` loop, or `next()`) is what actually pulls values through it. That laziness matters on large or infinite sequences: `filter` only evaluates the predicate on an item when something asks for the next result, instead of scanning the whole input up front.

### `filter(None, iterable)`: dropping falsy values

Passing `None` instead of a function tells `filter` to use each item's own truthiness as the predicate — a quick way to drop `None`/`0`/`""`/empty containers from a list:

```python
raw = [0, "hello", "", None, 42, [], "world"]
cleaned = list(filter(None, raw))
print(cleaned)  # ['hello', 42, 'world']
```

### `filter` vs. a list comprehension

Both work; the choice is style. `[x for x in items if predicate(x)]` reads naturally when there's also a transformation happening (`[x * 2 for x in items if predicate(x)]`), while `filter(predicate, items)` reads cleanly when there's *only* filtering and the predicate already exists as a named function — `filter(is_valid, records)` is more self-documenting than `[r for r in records if is_valid(r)]`.

## Why this matters at the senior level

Higher-order functions are how you avoid rewriting the same control flow (loop-and-check, loop-and-transform) for every new rule. Instead, the control flow is written once and parameterized by behavior — the same principle behind `sorted(items, key=...)`, `map`/`filter`, and every decorator you've ever used.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-higher-order-functions-q1",
      "type": "mcq",
      "prompt": "What makes validate() in the example a higher-order function?",
      "options": [
        {
          "id": "a",
          "text": "It has more than one parameter"
        },
        {
          "id": "b",
          "text": "It accepts other functions (validators) as arguments and calls them"
        },
        {
          "id": "c",
          "text": "It uses a for loop"
        },
        {
          "id": "d",
          "text": "It returns a boolean"
        }
      ],
      "correct": "b",
      "explanation": "A higher-order function takes a function as input or returns one; validate() takes validator functions as *validators and invokes each one, making it higher-order."
    },
    {
      "id": "serialization-data-higher-order-functions-q2",
      "type": "mcq",
      "prompt": "In make_multiplier, why do double and triple behave differently even though they share the same multiplier function body?",
      "options": [
        {
          "id": "a",
          "text": "Each call to make_multiplier creates a closure that remembers its own factor value"
        },
        {
          "id": "b",
          "text": "Python randomly assigns different factor values"
        },
        {
          "id": "c",
          "text": "double and triple are actually the same function object"
        },
        {
          "id": "d",
          "text": "multiplier reads factor from a global variable that changes each time"
        }
      ],
      "correct": "a",
      "explanation": "Each call to make_multiplier(factor) creates a new closure over that specific factor value, so the returned multiplier function 'remembers' the factor it was created with — 2 for double, 3 for triple."
    },
    {
      "id": "serialization-data-filter-q1",
      "type": "mcq",
      "prompt": "What does filter(lambda n: n % 2 == 0, numbers) return, before wrapping it in list()?",
      "options": [
        {
          "id": "a",
          "text": "A list of even numbers"
        },
        {
          "id": "b",
          "text": "A lazy iterator that yields even numbers only when consumed"
        },
        {
          "id": "c",
          "text": "A tuple of even numbers"
        },
        {
          "id": "d",
          "text": "A boolean indicating whether any even numbers exist"
        }
      ],
      "correct": "b",
      "explanation": "filter() returns a lazy filter object (an iterator) — it doesn't evaluate the predicate on every item until something iterates over it, such as list() or a for loop."
    },
    {
      "id": "serialization-data-filter-q2",
      "type": "mcq",
      "prompt": "What does filter(None, [0, \"hello\", \"\", None, 42]) return, as a list?",
      "options": [
        {
          "id": "a",
          "text": "[0, \"hello\", \"\", None, 42] — unchanged"
        },
        {
          "id": "b",
          "text": "[\"hello\", 42] — only the truthy values"
        },
        {
          "id": "c",
          "text": "[] — an empty list, since None isn't a valid predicate"
        },
        {
          "id": "d",
          "text": "A TypeError is raised"
        }
      ],
      "correct": "b",
      "explanation": "Passing None as the predicate tells filter to use each item's own truthiness — falsy values like 0, empty string, and None are dropped, leaving only 'hello' and 42."
    }
  ]
}
```
