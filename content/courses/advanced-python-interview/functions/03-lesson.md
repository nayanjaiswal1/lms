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
estimated_minutes: 11
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

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

##### Return statement

```text
def add(a, b):
    return a + b

def min_max(numbers):
    return min(numbers), max(numbers)  # multiple return values as tuple

def divide(a, b):
    if b == 0:
        return None  # early return
    return a / b

def greet(name):
    print(f"Hello, {name}")
    # no return statement -> implicitly returns None

def make_multiplier(n):
    def multiply(x):
        return x * n
    return multiply  # returning a function

double = make_multiplier(2)
print(double(5))  # 10
```


##### Lambda functions

```text
square = lambda x: x ** 2
print(square(5))  # 25

# with sorted()
sorted_students = sorted(students, key=lambda s: s["grade"])

# with map()
squared = list(map(lambda x: x**2, numbers))

# with filter()
evens = list(filter(lambda x: x % 2 == 0, numbers))
```

Limitations: single expression only, no statements (no `if`/`while`/`for` as statements), less readable for complex logic, can't contain an explicit `return`.


##### Type hints and docstrings

```text
def calculate_area(length: float, width: float) -> float:
    """Calculate the area of a rectangle.

    Args:
        length: The length of the rectangle.
        width: The width of the rectangle.

    Returns:
        The area of the rectangle.

    Raises:
        ValueError: If length or width is negative.
    """
    if length < 0 or width < 0:
        raise ValueError("Dimensions must be positive")
    return length * width
```

Python does **not** enforce type hints at runtime — they're for IDEs, static checkers (mypy, pyright), and documentation only:

```text
def add(a: int, b: int) -> int:
    return a + b

result = add("hello", "world")  # "helloworld" — runs fine, no TypeError
# mypy would flag: Argument 1 to "add" has incompatible type "str"; expected "int"
```


##### Common patterns

**Guard clauses (early returns)** instead of deeply nested `if`s:

```text
def process_user(user):
    if user is None:
        return None
    if not user.is_active:
        return None
    if not user.has_permission:
        return None
    return do_something()
```

**Factory pattern:**

```text
def create_validator(min_val, max_val):
    def validate(value):
        return min_val <= value <= max_val
    return validate

validate_age = create_validator(0, 120)
```

**Pure functions vs side effects:**

```text
# BAD - mutates the input
def double_list(numbers):
    for i in range(len(numbers)):
        numbers[i] *= 2
    return numbers

# GOOD - returns a new list, leaves input untouched
def double_list(numbers):
    return [n * 2 for n in numbers]
```

**Argument order checklist:** positional-only (before `/`) → regular positional/keyword → `*args` → keyword-only → `**kwargs`.

**Common mistakes to avoid:** forgetting the parentheses when calling; mutable default arguments; too many parameters (more than ~5 usually means refactor); mixing side effects with return values; positional arguments after keyword arguments; undocumented complex functions; functions doing multiple unrelated things.
