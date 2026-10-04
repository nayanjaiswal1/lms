---
kind: lesson
id_key: advanced-python-interview/core-language/how-python-runs-and-types
course: advanced-python-interview
section: core-language
section_title: "Core Language"
section_position: 0
section_group: Fundamentals
title: "How Python Runs & Data Types"
position: 0
estimated_minutes: 12
source: ["knowledge/backend/python/python-core.md"]
---
Opening interview questions usually probe two things: do you know what actually happens when you run a `.py` file, and do you understand which built-in types can change in place. Most "weird Python behavior" bugs trace back to one of those two.

## How CPython runs your code

Python is dynamically typed and object-oriented, and it is usually called "interpreted" — but the reference implementation (CPython) first **compiles** your source to bytecode, then a **Python Virtual Machine (PVM)** executes that bytecode instruction by instruction. Bytecode is cached in `.pyc` files so unchanged modules skip recompilation. There is no native machine code up front, which is why pure-Python loops are slower than compiled languages.

```python
import dis

def f(a):
    return a + 1

dis.dis(f)  # prints the bytecode the PVM runs: load a, load 1, add, return
```

The exact opcode names differ between Python versions, but the shape is always the same: a short stack-machine program per function.

```text
source (.py) -> CPython compiler -> bytecode (.pyc) -> PVM -> execution
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-runs-q1",
      "type": "mcq",
      "prompt": "What does CPython do with your source file before executing it?",
      "options": [
        { "id": "a", "text": "Compiles it to native machine code for your CPU" },
        { "id": "b", "text": "Compiles it to bytecode, which the Python Virtual Machine then executes" },
        { "id": "c", "text": "Reads and executes each source character directly with no intermediate form" },
        { "id": "d", "text": "Translates it to C and calls the system compiler" }
      ],
      "correct": "b",
      "explanation": "CPython compiles source to bytecode (cached as .pyc) and the PVM interprets that bytecode. It does not emit native machine code."
    }
  ]
}
```

## Mutable vs immutable types

An **immutable** object cannot change after creation; "modifying" it really builds a new object. A **mutable** object changes in place, so every name bound to it sees the change.

- Immutable: `int`, `float`, `bool`, `str`, `tuple`, `None`
- Mutable: `list`, `set`, `dict`

```python
x = "hello"
y = x
y = "world"   # rebinds y to a new object
print(x)      # hello

a = [1, 2, 3]
b = a         # same object, two names
b.append(4)
print(a)      # [1, 2, 3, 4]
```

A tuple is immutable, but only *shallowly*: it fixes which objects it holds, not whether those objects can change.

```python
t = ([1], 2)
t[0].append(9)
print(t)  # ([1, 9], 2)
try:
    t[1] = 3
except TypeError as e:
    print(e)  # 'tuple' object does not support item assignment
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-mutability-q1",
      "type": "mcq",
      "prompt": "After `a = [1, 2, 3]; b = a; b.append(4)`, what is `a`?",
      "options": [
        { "id": "a", "text": "[1, 2, 3]" },
        { "id": "b", "text": "[1, 2, 3, 4]" },
        { "id": "c", "text": "A TypeError is raised" },
        { "id": "d", "text": "[4]" }
      ],
      "correct": "b",
      "explanation": "Assignment copies the reference, not the list. Both names point to one mutable list, so the append is visible through both."
    },
    {
      "id": "core-language-mutability-q2",
      "type": "mcq",
      "prompt": "Given `t = ([1], 2)`, which statement is true?",
      "options": [
        { "id": "a", "text": "`t[0].append(9)` raises TypeError because tuples are immutable" },
        { "id": "b", "text": "`t[0].append(9)` works, but `t[1] = 3` raises TypeError" },
        { "id": "c", "text": "Both operations work" },
        { "id": "d", "text": "Both operations raise TypeError" }
      ],
      "correct": "b",
      "explanation": "A tuple's slots cannot be reassigned, but a mutable object stored inside it can still be mutated."
    }
  ]
}
```

## list vs tuple vs set vs dict

| Type | Ordered | Mutable | Duplicates | Typical use |
|---|---|---|---|---|
| `list` | yes, indexed | yes | allowed | ordered, changing sequence |
| `tuple` | yes, indexed | no | allowed | fixed record; hashable if its items are, so usable as a dict key |
| `set` | no index | yes | removed | uniqueness, fast membership tests |
| `dict` | insertion-ordered (3.7+) | yes | unique keys | key-to-value lookup |

Dict keys and set members must be **hashable**, which in practice means immutable. A tuple of numbers works as a key; a list raises `TypeError: unhashable type`.

```python
print([1, 2, 2, 3])   # [1, 2, 2, 3]
print((1, 2, 2, 3))   # (1, 2, 2, 3)
print({1, 2, 2, 3})   # {1, 2, 3}
print({(0, 0): "origin"}[(0, 0)])  # origin
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-containers-q1",
      "type": "mcq",
      "prompt": "Which of these can be used as a dictionary key?",
      "options": [
        { "id": "a", "text": "[1, 2]" },
        { "id": "b", "text": "{1, 2}" },
        { "id": "c", "text": "(1, 2)" },
        { "id": "d", "text": "{'a': 1}" }
      ],
      "correct": "c",
      "explanation": "Keys must be hashable. A tuple of hashable items is hashable; lists, sets and dicts are mutable and therefore unhashable."
    }
  ]
}
```

## The mutable default argument trap

Default values are evaluated **once**, when the `def` statement runs, not on each call. A mutable default is therefore one shared object across all calls.

```python
def add(item, lst=[]):
    lst.append(item)
    return lst

print(add(1))  # [1]
print(add(2))  # [1, 2] -- same list reused
print(add.__defaults__)  # ([1, 2],)
```

The standard fix is a `None` sentinel, creating the list inside the body.

```python
def add(item, lst=None):
    if lst is None:
        lst = []
    lst.append(item)
    return lst

print(add(1))  # [1]
print(add(2))  # [2]
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-default-arg-q1",
      "type": "mcq",
      "prompt": "Why does `def add(item, lst=[])` accumulate items across calls?",
      "options": [
        { "id": "a", "text": "The default list is created once at function definition time and shared by every call" },
        { "id": "b", "text": "Python caches the return value of every function" },
        { "id": "c", "text": "Lists are global variables by default" },
        { "id": "d", "text": "The default is re-evaluated each call but appended to the previous result" }
      ],
      "correct": "a",
      "explanation": "Defaults are evaluated once when `def` executes. Use `None` and build a fresh list inside the function."
    }
  ]
}
```

## Truthy and falsy values

Every object has a boolean value, used implicitly by `if`, `while` and `filter`. The **falsy** ones are `0`, `0.0`, `""`, `[]`, `{}`, `()`, `set()`, `None` and `False`. Everything else is truthy — including the non-empty string `"0"`, a classic trap.

```python
a = [1, 0, "0", [], {}, (), "hello", ""]
print(list(filter(bool, a)))  # [1, '0', 'hello']
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-truthy-q1",
      "type": "mcq",
      "prompt": "Which value is truthy?",
      "options": [
        { "id": "a", "text": "\"0\"" },
        { "id": "b", "text": "0.0" },
        { "id": "c", "text": "set()" },
        { "id": "d", "text": "None" }
      ],
      "correct": "a",
      "explanation": "Only empty or zero values are falsy. \"0\" is a non-empty string, so it is truthy."
    }
  ]
}
```

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

#### What is Python?

- **Interpreted** — executed line by line, not compiled to a native binary upfront.
- **High level** — abstracts away memory management and low-level detail.
- **Dynamically typed** — no variable type declarations; types are checked at runtime.
- **Object-oriented** — everything is an object, including functions and classes themselves.
- **General-purpose** — web, automation, ML, scripting, APIs, data science, etc.

How it runs internally:

```
Your Python Code (.py)
        ↓
    Compiler (CPython)
        ↓
   Bytecode (.pyc file)
        ↓
Python Virtual Machine (PVM)
        ↓
Execution
```

See python-internals for what happens inside the PVM (reference counting, GC, pymalloc).


#### Python Data Types

**Immutable** (objects create new copies when modified) → `int`, `float`, `str`, `tuple`, `bool`
**Mutable** (objects modify in place) → `list`, `set`, `dict`

**Primitive (immutable) types** — value cannot be changed after creation.

| Type | Example |
|---|---|
| `int` | `x = 5` |
| `float` | `x = 3.14` |
| `bool` | `x = True` |
| `str` | `x = "hello"` |
| `NoneType` | `x = None` |

**Non-primitive (mutable) types** — value can be changed in place.

| Type | Example |
|---|---|
| `list` | `x = [1, 2, 3]` |
| `dict` | `x = {"a": 1}` |
| `set` | `x = {1, 2, 3}` |

**One exception — tuple** is non-primitive but immutable.

| Type | Example |
|---|---|
| `tuple` | `x = (1, 2, 3)` |

**Data types and mutability at a glance:**

| Type | Examples | Mutable? |
|---|---|---|
| int | `10` | No |
| float | `1.5` | No |
| str | `"hello"` | No |
| list | `[1,2,3]` | Yes |
| tuple | `(1,2,3)` | No |
| set | `{1,2,3}` | Yes |
| dict | `{"a":1}` | Yes |
| bool | `True/False` | No |

**Why it matters in interviews:**

```text
# Immutable — reassignment creates a new object
x = "hello"
y = x
y = "world"
print(x)  # "hello" — x unchanged

# Mutable — both point to same object
a = [1, 2, 3]
b = a
b.append(4)
print(a)  # [1, 2, 3, 4] — a is affected!
```

This is also why you should never use a mutable default argument in a function:

```text
# BAD
def add(item, lst=[]):
    lst.append(item)
    return lst

add(1)  # [1]
add(2)  # [1, 2] — same list reused!

# GOOD
def add(item, lst=None):
    if lst is None:
        lst = []
    lst.append(item)
    return lst
```


#### Truthy and falsy values

Every object has a boolean context, tested implicitly in `if`/`while`/`filter()`.

**Falsy** — `0`, `0.0`, `""`, `[]`, `{}`, `()`, `set()`, `None`, `False`. Everything else is **truthy**.

```text
a = [1, 0, "0", [], {}, (), "hello", ""]
list(filter(bool, a))  # [1, '0', 'hello'] — non-empty/non-zero survive
```

Rule of thumb: empty or zero → `False`, non-empty or non-zero → `True` (note `"0"` — a non-empty string — is truthy, a common trap).


#### Difference between list, tuple, set, dict

**List** — ordered, mutable collection
- Created with square brackets: `[1, 2, 3]`
- Allows duplicate values
- Elements accessed by index: `my_list[0]`
- Can be modified after creation (add, remove, change items)
- Use when you need an ordered collection that might change

**Tuple** — ordered, immutable collection
- Created with parentheses: `(1, 2, 3)`
- Allows duplicate values
- Elements accessed by index: `my_tuple[0]`
- Cannot be modified after creation (immutable)
- Use when you need an ordered collection that shouldn't change, or as dictionary keys

**Set** — unordered, mutable collection of unique items
- Created with curly braces: `{1, 2, 3}`
- No duplicate values (automatically removes duplicates)
- No index access (unordered)
- Can add/remove elements, but not change existing ones
- Use when you need unique values or fast membership testing

**Dictionary** — unordered collection of key-value pairs
- Created with curly braces and colons: `{'name': 'Alice', 'age': 30}`
- Keys must be unique and immutable (strings, numbers, tuples)
- Values accessed by key: `my_dict['name']`
- Mutable — can add, remove, or change key-value pairs
- Use when you need to associate values with unique keys for fast lookup

```text
my_list = [1, 2, 2, 3]      # [1, 2, 2, 3] - keeps duplicates
my_tuple = (1, 2, 2, 3)     # (1, 2, 2, 3) - can't change
my_set = {1, 2, 2, 3}       # {1, 2, 3} - removes duplicates
my_dict = {'a': 1, 'b': 2}  # maps keys to values
```
