---
kind: lesson
id_key: advanced-python-interview/functions/functions-in-practice
course: advanced-python-interview
section: functions
section_title: "Functions & Scope"
section_position: 1
section_group: Fundamentals
title: "Lambdas, Return Values, Type Hints & Pure Functions"
position: 2
estimated_minutes: 23
source: ["knowledge/backend/python/python-functions.md"]
---
The last pieces of function fundamentals: when a lambda is enough, what a function actually hands back, what type hints do and do not do, and how to write functions that are easy to test.

## Lambda limits

A `lambda` is an anonymous function whose body is a **single expression**. It cannot contain statements (no assignment, `for`, `while`, `return`), and the expression's value is returned automatically. It shines as a throwaway `key=` argument; once you name it or need logic, use `def`.

```python
students = [{"n": "A", "grade": 80}, {"n": "B", "grade": 65}]
print(sorted(students, key=lambda s: s["grade"]))

square = lambda x: x ** 2
print(square(5), square.__name__)

def square_def(x):
    return x ** 2
print(square_def.__name__)
```

Assigning a lambda to a name gains nothing over `def` and loses a useful `__name__` in tracebacks.

```knowledge-check
{
  "questions": [
    {
      "id": "functions-in-practice-q1",
      "type": "mcq",
      "prompt": "Which is NOT allowed inside a lambda body?",
      "options": [
        { "id": "a", "text": "A conditional expression like x if x > 0 else -x" },
        { "id": "b", "text": "A function call" },
        { "id": "c", "text": "An assignment statement or for loop" },
        { "id": "d", "text": "Arithmetic" }
      ],
      "correct": "c",
      "explanation": "A lambda body is one expression; statements such as assignment, for, and while are not allowed."
    }
  ]
}
```

## Return values

A function returns exactly **one** object. `return a, b` builds a tuple, which callers usually unpack. A function with no `return`, or a bare `return`, returns `None`. Printing is not returning: a function that only prints gives its caller nothing to use.

```python
def min_max(numbers):
    return min(numbers), max(numbers)

low, high = min_max([3, 1, 4])
print(low, high, min_max([3, 1, 4]))

def greet(name):
    print(f"Hello, {name}")

result = greet("Ann")
print(result)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-in-practice-q2",
      "type": "mcq",
      "prompt": "What does result hold after result = greet('Ann'), where greet only prints?",
      "options": [
        { "id": "a", "text": "The printed string" },
        { "id": "b", "text": "An empty string" },
        { "id": "c", "text": "None" },
        { "id": "d", "text": "It raises an error" }
      ],
      "correct": "c",
      "explanation": "Without an explicit return, a function implicitly returns None."
    },
    {
      "id": "functions-in-practice-q3",
      "type": "mcq",
      "prompt": "What is the type of the value returned by return min(xs), max(xs)?",
      "options": [
        { "id": "a", "text": "Two separate values" },
        { "id": "b", "text": "A list" },
        { "id": "c", "text": "A tuple" },
        { "id": "d", "text": "A set" }
      ],
      "correct": "c",
      "explanation": "Comma-separated return values are packed into a single tuple."
    }
  ]
}
```

## Type hints are not enforced

Annotations like `a: int` and `-> int` are stored on the function but **never checked at runtime**. They serve editors, static checkers (mypy, pyright), and readers. Do not rely on them for validation; validate at the boundary yourself.

```python
def add(a: int, b: int) -> int:
    return a + b

print(add("hello", "world"))
print(add.__annotations__)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-in-practice-q4",
      "type": "mcq",
      "prompt": "What happens when you call add(\"a\", \"b\") for def add(a: int, b: int) -> int?",
      "options": [
        { "id": "a", "text": "TypeError at call time" },
        { "id": "b", "text": "It runs normally and returns 'ab'; only a static checker would complain" },
        { "id": "c", "text": "SyntaxError at definition" },
        { "id": "d", "text": "Python converts the strings to int" }
      ],
      "correct": "b",
      "explanation": "Hints are metadata only; the interpreter performs no type enforcement."
    }
  ]
}
```

## Guard clauses

Handle invalid or trivial cases first and **return early**, leaving the main logic un-nested at the bottom. It flattens pyramids of `if`s and keeps the happy path readable.

```python
class User:
    def __init__(self, active, allowed):
        self.is_active = active
        self.has_permission = allowed

def process_user(user):
    if user is None:
        return None
    if not user.is_active:
        return None
    if not user.has_permission:
        return None
    return "processed"

print(process_user(None), process_user(User(True, False)), process_user(User(True, True)))
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-in-practice-q5",
      "type": "mcq",
      "prompt": "What is the main benefit of guard clauses?",
      "options": [
        { "id": "a", "text": "They make the function run faster" },
        { "id": "b", "text": "They reject bad input early and avoid deep nesting around the main logic" },
        { "id": "c", "text": "They replace exceptions entirely" },
        { "id": "d", "text": "They are required by Python" }
      ],
      "correct": "b",
      "explanation": "Early returns handle edge cases up front so the main path stays flat and readable."
    }
  ]
}
```

## Pure functions vs mutating input

A **pure** function depends only on its arguments and returns a new value without changing anything else. Mutating an argument is a hidden side effect: the caller's data changes behind its back. Prefer returning a new object; it is also far easier to test.

```python
def double_in_place(numbers):
    for i in range(len(numbers)):
        numbers[i] *= 2
    return numbers

def double_pure(numbers):
    return [n * 2 for n in numbers]

a = [1, 2, 3]
print(double_pure(a), a)
print(double_in_place(a), a)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-in-practice-q6",
      "type": "mcq",
      "prompt": "After b = double_pure(a) versus b = double_in_place(a), how does the original list a differ?",
      "options": [
        { "id": "a", "text": "No difference" },
        { "id": "b", "text": "double_pure leaves a unchanged; double_in_place changes it" },
        { "id": "c", "text": "double_in_place leaves a unchanged; double_pure changes it" },
        { "id": "d", "text": "Both change a" }
      ],
      "correct": "b",
      "explanation": "The pure version builds a new list; the in-place version mutates the caller's list, a side effect."
    }
  ]
}
```

## Not Returning Dicts & Lists from Functions

Python passes arguments by **object reference** — a variable never holds a copy of a list or dict, it holds a reference to the same object everyone else who has that variable also points at. That has a direct, easy-to-miss consequence: a function that mutates a list or dict argument doesn't need to `return` it for the caller to see the change.

### The pattern

```python
def add_n_copies(items, n):
    for i in range(n):
        items.append(n)
    # no return statement at all

my_list = []
add_n_copies(my_list, 5)
print(my_list)  # [5, 5, 5, 5, 5] — mutated in place, no return needed
```

`items` inside the function and `my_list` outside it are the same object — `id(items) == id(my_list)` is `True` for the whole call. `.append()` mutates that shared object, so the caller's variable reflects the change the instant the function returns (or even before, if another piece of code peeked at `my_list` mid-call from another thread).

### Where this bites people

The mirror image of this rule is the actual interview trap: relying on mutation when you *meant* to return a new value.

```python
def broken_scale(numbers, factor):
    numbers = [n * factor for n in numbers]  # rebinds the LOCAL name only
    return numbers

original = [1, 2, 3]
result = broken_scale(original, 10)
print(original)  # [1, 2, 3] — untouched, because the function rebound `numbers`
print(result)     # [30, 20 ,10]... [10, 20, 30] — the new list, via the return value
```

`numbers = [...]` inside the function rebinds the local name `numbers` to a brand-new list — it does not touch the object `original` still points to. This is the same reference semantics as the mutation example above, just applied to reassignment instead of `.append()`. The rule that falls out of both examples: if a function **mutates** its argument in place (`.append`, `.update`, `[:] = `, `del items[i]`), the caller sees it with no `return` needed; if a function **rebinds** the parameter name to a new object, the caller sees nothing unless the function returns it.

Being explicit about which one you're doing — and returning a new object rather than silently mutating an argument the caller didn't expect to change — is usually the more maintainable choice, even though Python allows either.

### Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-no-return-mutable-q1",
      "type": "mcq",
      "prompt": "A function does `items.append(n)` on its list argument with no return statement. Does the caller see the change?",
      "options": [
        { "id": "a", "text": "No, lists are always copied into functions" },
        { "id": "b", "text": "Yes — the parameter and the caller's variable reference the same list object, so mutating it in place is visible without returning anything" },
        { "id": "c", "text": "Only if the function is decorated with @mutates" },
        { "id": "d", "text": "Only in Python 2, not Python 3" }
      ],
      "correct": "b",
      "explanation": "Python passes object references. items and the caller's list are the same object, so in-place mutation (append, update, etc.) is visible to the caller immediately, with no return needed."
    },
    {
      "id": "internals-no-return-mutable-q2",
      "type": "mcq",
      "prompt": "Inside a function, `numbers = [n * 2 for n in numbers]` reassigns the parameter. Why doesn't the caller's original list change?",
      "options": [
        { "id": "a", "text": "List comprehensions are read-only and can't reassign" },
        { "id": "b", "text": "Reassignment rebinds the local name to a new object — it doesn't mutate the object the caller's variable still points to" },
        { "id": "c", "text": "Python silently copies lists on reassignment" },
        { "id": "d", "text": "It does change, unless the function returns None" }
      ],
      "correct": "b",
      "explanation": "`numbers = [...]` makes the local name point at a new list; the caller's variable still points at the original object, unaffected. Only in-place mutation (not reassignment) is visible without a return."
    }
  ]
}
```
