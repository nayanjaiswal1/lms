---
kind: lesson
id_key: advanced-python-interview/serialization-data/higher-order-functions
course: advanced-python-interview
section: serialization-data
section_title: "Serialization & Low-Level Data"
section_position: 4
title: "Higher-Order Functions"
position: 3
estimated_minutes: 12
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
        { "id": "a", "text": "It has more than one parameter" },
        { "id": "b", "text": "It accepts other functions (validators) as arguments and calls them" },
        { "id": "c", "text": "It uses a for loop" },
        { "id": "d", "text": "It returns a boolean" }
      ],
      "correct": "b",
      "explanation": "A higher-order function takes a function as input or returns one; validate() takes validator functions as *validators and invokes each one, making it higher-order."
    },
    {
      "id": "serialization-data-higher-order-functions-q2",
      "type": "mcq",
      "prompt": "In make_multiplier, why do double and triple behave differently even though they share the same multiplier function body?",
      "options": [
        { "id": "a", "text": "Each call to make_multiplier creates a closure that remembers its own factor value" },
        { "id": "b", "text": "Python randomly assigns different factor values" },
        { "id": "c", "text": "double and triple are actually the same function object" },
        { "id": "d", "text": "multiplier reads factor from a global variable that changes each time" }
      ],
      "correct": "a",
      "explanation": "Each call to make_multiplier(factor) creates a new closure over that specific factor value, so the returned multiplier function 'remembers' the factor it was created with — 2 for double, 3 for triple."
    }
  ]
}
```
