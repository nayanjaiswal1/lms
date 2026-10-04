---
kind: lesson
id_key: advanced-python-interview/functions/scope-legb-closures
course: advanced-python-interview
section: functions
section_title: "Functions & Scope"
section_position: 1
section_group: Fundamentals
title: "Scope (LEGB) & Closures"
position: 1
estimated_minutes: 13
source: ["knowledge/backend/python/python-functions.md"]
---
Scope questions test whether you can predict which variable a name refers to. Python answers with a fixed lookup rule, and closures are what that rule enables once functions can be returned.

## The LEGB lookup rule

When Python reads a name it searches four scopes in order: **L**ocal (the current function), **E**nclosing (any outer functions), **G**lobal (the module), **B**uilt-in (`len`, `print`, ...). The first match wins, so an inner name *shadows* an outer one without changing it.

```python
x = "global"

def outer():
    x = "enclosing"

    def inner():
        x = "local"
        print(x)

    inner()
    print(x)

outer()
print(x)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-scope-legb-closures-q1",
      "type": "mcq",
      "prompt": "In what order does Python look up a name?",
      "options": [
        { "id": "a", "text": "Global, Enclosing, Local, Built-in" },
        { "id": "b", "text": "Local, Enclosing, Global, Built-in" },
        { "id": "c", "text": "Built-in, Global, Enclosing, Local" },
        { "id": "d", "text": "Local, Global, Enclosing, Built-in" }
      ],
      "correct": "b",
      "explanation": "LEGB: Local, Enclosing, Global, Built-in."
    }
  ]
}
```

## global and nonlocal

Reading an outer name needs no declaration. **Rebinding** one does: `global x` says "this name is the module-level one" and `nonlocal x` says "this name is in the nearest enclosing function". Without them, assignment creates a new local. Note the two keywords target different variables even when names collide.

```python
x = 100

def outer():
    x = 10
    def inner():
        global x
        x += 5
        return x
    print(inner())
    print(x)

outer()
print(x)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-scope-legb-closures-q2",
      "type": "mcq",
      "prompt": "In the example, inner() declares global x and does x += 5. What happens to outer()'s own local x?",
      "options": [
        { "id": "a", "text": "It also becomes 15" },
        { "id": "b", "text": "It is unchanged; only the module-level x was modified" },
        { "id": "c", "text": "It is deleted" },
        { "id": "d", "text": "It raises NameError" }
      ],
      "correct": "b",
      "explanation": "global skips the enclosing scope and binds to the module-level name, so outer's local x stays 10."
    }
  ]
}
```

## The UnboundLocalError trap

If a name is assigned **anywhere** in a function body, the compiler treats it as local for the **whole** body. A read before that assignment does not fall back to the global; it fails.

```python
x = 5

def foo():
    print(x)
    x = 10

try:
    foo()
except UnboundLocalError as e:
    print("UnboundLocalError:", e)
```

The fix is to rename the local, pass the value in, or declare `global x` if you truly mean to rebind the module variable.

```knowledge-check
{
  "questions": [
    {
      "id": "functions-scope-legb-closures-q3",
      "type": "mcq",
      "prompt": "Why does print(x) before x = 10 inside foo() raise UnboundLocalError even though a global x exists?",
      "options": [
        { "id": "a", "text": "Globals cannot be read inside functions" },
        { "id": "b", "text": "The assignment makes x local for the entire function body, decided at compile time" },
        { "id": "c", "text": "print cannot see variables" },
        { "id": "d", "text": "Python runs the last line first" }
      ],
      "correct": "b",
      "explanation": "Scope is determined statically per function: any assignment makes the name local throughout, so the early read hits an unset local."
    }
  ]
}
```

## Closures

A **closure** is an inner function that keeps access to variables of its enclosing function after that function has returned. Each call to the outer function creates a fresh set of those variables, so closures carry private, per-instance state. Use `nonlocal` to rebind them.

```python
def make_counter():
    count = 0

    def increment():
        nonlocal count
        count += 1
        return count

    return increment

c1 = make_counter()
print(c1(), c1())
c2 = make_counter()
print(c2())
print(c1.__closure__[0].cell_contents)
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-scope-legb-closures-q4",
      "type": "mcq",
      "prompt": "Two counters come from make_counter(). Calling the first twice and the second once gives which results?",
      "options": [
        { "id": "a", "text": "1, 2 then 3" },
        { "id": "b", "text": "1, 2 then 1" },
        { "id": "c", "text": "2, 2 then 1" },
        { "id": "d", "text": "1, 1 then 1" }
      ],
      "correct": "b",
      "explanation": "Every make_counter() call creates a new count variable, so each closure has independent state."
    },
    {
      "id": "functions-scope-legb-closures-q5",
      "type": "mcq",
      "prompt": "What happens if increment() does count += 1 without nonlocal?",
      "options": [
        { "id": "a", "text": "It works the same" },
        { "id": "b", "text": "UnboundLocalError, because count is treated as local" },
        { "id": "c", "text": "It modifies a global count" },
        { "id": "d", "text": "SyntaxError" }
      ],
      "correct": "b",
      "explanation": "The augmented assignment makes count local to increment, and it is read before being set."
    }
  ]
}
```

## Factory functions

A function that builds and returns configured functions is a **factory**. The configuration lives in the closure, so you avoid classes or repeated arguments. This is also the mechanism underneath decorators.

```python
def create_validator(min_val, max_val):
    def validate(value):
        return min_val <= value <= max_val
    return validate

validate_age = create_validator(0, 120)
print(validate_age(30), validate_age(150))

def make_multiplier(n):
    return lambda x: x * n

double = make_multiplier(2)
print(double(5))
```

```knowledge-check
{
  "questions": [
    {
      "id": "functions-scope-legb-closures-q6",
      "type": "mcq",
      "prompt": "Where does validate_age remember min_val and max_val?",
      "options": [
        { "id": "a", "text": "In module-level globals" },
        { "id": "b", "text": "In the closure cells captured from create_validator's call" },
        { "id": "c", "text": "In the function's default arguments" },
        { "id": "d", "text": "In a hidden class instance" }
      ],
      "correct": "b",
      "explanation": "The inner function captures the enclosing variables as closure cells that outlive the outer call."
    }
  ]
}
```

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

##### Scope & namespaces (LEGB)

```text
x = "global"

def outer():
    x = "enclosing"

    def inner():
        x = "local"
        print(x)  # local

    inner()
    print(x)  # enclosing

outer()
print(x)  # global
```

Python resolves names in order: **L**ocal → **E**nclosing → **G**lobal → **B**uilt-in.

Modifying a global from inside a function requires `global`; modifying an enclosing variable from a nested function requires `nonlocal`:

```text
x = 10

def change_x():
    global x
    x = 20

change_x()
print(x)  # 20
```

**`UnboundLocalError` trap** — assigning to a name anywhere in a function makes Python treat it as local for the *entire* function body, even before the assignment line:

```text
x = 5
def foo():
    print(x)  # UnboundLocalError: local variable 'x' referenced before assignment
    x = 10
foo()
```

Python sees `x = 10` at compile time and marks `x` local to `foo`, so the earlier `print(x)` tries to read a local that doesn't exist yet — it does **not** fall back to the global. Fix with `global x` if you genuinely need to read-then-reassign the global.

**Same name, different scopes** — `global`/`nonlocal` point at completely different variables that just share a name:

```text
x = 100                     # global x = 100
def outer():
    x = 10                  # local x in outer(), shadows global
    def inner():
        global x
        x += 5               # modifies the GLOBAL x (100 -> 105), zero effect on outer()'s local x
        return x
    print(inner())           # 105
    print(x)                 # 10 — outer's own local x, untouched
outer()
print(x)                     # 105 — global, now updated
```


##### Closures

A closure is an inner function that remembers variables from its enclosing scope, even after the outer function has returned.

```text
def make_counter():
    count = 0

    def increment():
        nonlocal count  # modify enclosing variable
        count += 1
        return count

    return increment

counter1 = make_counter()
print(counter1())  # 1
print(counter1())  # 2

counter2 = make_counter()
print(counter2())  # 1 (separate counter)
```

Use cases: factory functions, data hiding, callbacks with state, and the basis for how decorators work.
