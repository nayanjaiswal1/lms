---
kind: lesson
id_key: advanced-python-interview/performance-testing/builtin-complexity
course: advanced-python-interview
section: data-structures
section_title: "Data Structures & Complexity"
section_position: 2
section_group: Fundamentals
title: "Built-in Complexity & Comprehension Performance"
position: 0
estimated_minutes: 23
source: ["knowledge/backend/python/python-collections-complexity.md"]
---
Interviewers love "what is the cost of this line?" Knowing the Big-O of the built-in containers lets you spot an accidental O(n²) at a glance. This lesson covers the cost table and why comprehensions are the idiomatic, faster way to build collections. For how `defaultdict`, `Counter` and `deque` are actually used, see the collections lesson in the Collections & OOP section; here we only care about their costs.

## Complexity of list, dict, set and deque

| Operation | list | dict / set | deque |
|---|---|---|---|
| Index access | O(1) | n/a (dict: O(1) by key) | O(n) in the middle |
| Search (`in`) | O(n) | O(1) average | O(n) |
| Append at end | O(1) amortized | O(1) average | O(1) |
| Insert at start | O(n) | n/a | O(1) |
| Delete | O(n) | O(1) average | O(1) at the ends |

Two things drive almost every answer. A list is a contiguous array, so indexing is instant but inserting or deleting near the front shifts every later element. Dicts and sets are hash tables, so lookup is O(1) *on average* (worst case O(n) with pathological collisions). A `deque` makes both ends cheap but gives up fast random indexing.

```python
import timeit

items = list(range(50_000))
as_set = set(items)

slow = timeit.timeit(lambda: 49_999 in items, number=200)
fast = timeit.timeit(lambda: 49_999 in as_set, number=200)
print(slow > fast * 10)  # True: list scan is O(n), set lookup is O(1)
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-builtin-complexity-q1",
      "type": "mcq",
      "prompt": "Which operation is O(n) on a list but O(1) on a deque?",
      "options": [
        { "id": "a", "text": "Indexing the middle element" },
        { "id": "b", "text": "Inserting or popping at the front" },
        { "id": "c", "text": "Checking membership with `in`" },
        { "id": "d", "text": "Appending at the end" }
      ],
      "correct": "b",
      "explanation": "A list must shift every element when the front changes; a deque is built for O(1) operations at both ends."
    },
    {
      "id": "performance-testing-builtin-complexity-q2",
      "type": "mcq",
      "prompt": "Why is `x in some_set` O(1) on average while `x in some_list` is O(n)?",
      "options": [
        { "id": "a", "text": "Sets keep elements sorted and binary search them" },
        { "id": "b", "text": "Sets are hash tables, so the element's hash points straight at its slot" },
        { "id": "c", "text": "Sets cache the last lookup" },
        { "id": "d", "text": "Lists cannot be compared with `==`" }
      ],
      "correct": "b",
      "explanation": "Hashing jumps directly to the bucket; a list has no index on values, so it scans element by element."
    }
  ]
}
```

## Why comprehensions beat loops

A comprehension compiles to a specialised loop in CPython. Compared with `for ...: out.append(...)` it executes fewer bytecode instructions per item and skips the repeated attribute lookup and method call for `.append`. The gain is a constant factor, not a better Big-O, but it is real and the code is also shorter.

```python
def with_loop(n):
    out = []
    for x in range(n):
        out.append(x * x)
    return out

def with_comprehension(n):
    return [x * x for x in range(n)]

assert with_loop(1000) == with_comprehension(1000)
print("same result, comprehension has less per-item overhead")
```

Avoid comprehensions when the body has side effects (logging, DB writes) or deeply nested conditions; a plain loop is clearer there, and a comprehension used only for side effects builds a throwaway list.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-builtin-complexity-q3",
      "type": "mcq",
      "prompt": "Why is a list comprehension usually faster than an equivalent for-loop with `.append`?",
      "options": [
        { "id": "a", "text": "It changes the algorithm from O(n²) to O(n)" },
        { "id": "b", "text": "It runs in parallel threads" },
        { "id": "c", "text": "It uses fewer bytecode instructions and avoids a method call per item" },
        { "id": "d", "text": "It skips building the result in memory" }
      ],
      "correct": "c",
      "explanation": "Both are O(n); the comprehension just has lower constant overhead per element."
    }
  ]
}
```

## Choosing list, set, dict or generator comprehension

All four have the same shape; pick by the result you need.

- **List `[...]`**: ordered, indexable, eager. All items are in memory at once.
- **Set `{...}`**: de-duplicates and gives O(1) membership; slightly more work per item because each is hashed.
- **Dict `{k: v ...}`**: builds a mapping cleanly, faster than assigning keys in a loop.
- **Generator `(...)`**: lazy, constant memory, but single-pass and not indexable; a little slower per item because each value is produced on demand.

```python
nums = range(10)
print([n % 3 for n in nums])          # [0, 1, 2, 0, 1, 2, 0, 1, 2, 0]
print({n % 3 for n in nums})          # {0, 1, 2}
print({n: n * n for n in range(4)})   # {0: 0, 1: 1, 2: 4, 3: 9}

gen = (n * n for n in range(10**9))   # nothing computed yet
print(next(gen), next(gen), next(gen))  # 0 1 4
```

Rule of thumb: need the whole thing more than once, use a list or set; streaming a huge sequence into `sum`, `any` or a file, use a generator.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-builtin-complexity-q4",
      "type": "mcq",
      "prompt": "You must total a billion computed values and never reuse them. Which is the best fit?",
      "options": [
        { "id": "a", "text": "`sum([f(x) for x in data])`" },
        { "id": "b", "text": "`sum(f(x) for x in data)`" },
        { "id": "c", "text": "`sum({f(x) for x in data})`" },
        { "id": "d", "text": "A list comprehension stored in a variable" }
      ],
      "correct": "b",
      "explanation": "A generator expression streams values one at a time with constant memory. The set version would also change the total by dropping duplicates."
    }
  ]
}
```

## Advanced List Comprehensions

A basic list comprehension — `[expr for x in iterable]` — is familiar to every Python developer. Senior-level fluency is knowing the extra clauses comprehensions support, and knowing when a comprehension stops being readable and a plain loop wins.

### Nested loops inside a comprehension

Multiple `for` clauses in one comprehension flatten nested structures, reading left to right exactly like nested `for` loops would:

```python
matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
flattened = [num for row in matrix for num in row]
print(flattened)  # [1, 2, 3, 4, 5, 6, 7, 8, 9]
```

This is equivalent to:

```python
flattened = []
for row in matrix:
    for num in row:
        flattened.append(num)
```

### Conditional expressions vs. filtering clauses

These look similar but do different things. An `if/else` *before* the `for` is a conditional expression — it runs for every item and picks between two output values:

```python
numbers = [1, 2, 3, 4, 5]
labels = ["even" if n % 2 == 0 else "odd" for n in numbers]
print(labels)  # ['odd', 'even', 'odd', 'even', 'odd']
```

An `if` *after* the `for` (no `else`) is a filter — it decides whether the item appears in the output at all:

```python
numbers = [1, 2, 3, 4, 5, 6]
evens_only = [n for n in numbers if n % 2 == 0]
print(evens_only)  # [2, 4, 6]
```

The two combine: `[n for n in numbers if n % 2 == 0 if n > 2]` chains filters, and `["big" if n > 3 else "small" for n in numbers if n % 2 == 0]` filters first, then labels what survives.

### Calling functions inline

Any expression is valid as the output, including a function call:

```python
def celsius_to_fahrenheit(c):
    return (c * 9 / 5) + 32

temperatures_c = [0, 20, 30, 40]
temperatures_f = [celsius_to_fahrenheit(t) for t in temperatures_c]
print(temperatures_f)  # [32.0, 68.0, 86.0, 104.0]
```

### Knowing when to stop

A comprehension is the right call when it stays a single, readable transformation. Once it needs more than one `if`/`for` clause stacked together, or the body has real side effects, a plain loop is more debuggable — you can't put a breakpoint inside a comprehension expression as easily as inside a loop body, and a comprehension that needs a comment to explain what it's doing has already lost the readability it was supposed to buy.

### Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-advanced-list-comprehensions-q1",
      "type": "mcq",
      "prompt": "What's the difference between [\"even\" if n % 2 == 0 else \"odd\" for n in numbers] and [n for n in numbers if n % 2 == 0]?",
      "options": [
        { "id": "a", "text": "They produce identical output" },
        { "id": "b", "text": "The first labels every item (conditional expression); the second filters out odd items entirely (filter clause)" },
        { "id": "c", "text": "The first is invalid syntax" },
        { "id": "d", "text": "The second labels every item; the first filters" }
      ],
      "correct": "b",
      "explanation": "An if/else before the for is a conditional expression that runs on every item and picks an output value; an if after the for with no else is a filter that decides whether the item is included at all."
    },
    {
      "id": "serialization-data-advanced-list-comprehensions-q2",
      "type": "mcq",
      "prompt": "When should a senior engineer prefer a plain for loop over a list comprehension?",
      "options": [
        { "id": "a", "text": "Never — comprehensions are always strictly better" },
        { "id": "b", "text": "When the comprehension would need multiple stacked if/for clauses or real side effects, hurting readability and debuggability" },
        { "id": "c", "text": "Only when the list has more than 100 items" },
        { "id": "d", "text": "Comprehensions can't be used with functions, so any function call requires a loop" }
      ],
      "correct": "b",
      "explanation": "Comprehensions are a readability tool. Once one needs multiple conditions/loops stacked together or has side effects, a plain loop is easier to read, debug, and set breakpoints in."
    }
  ]
}
```
