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
estimated_minutes: 11
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

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

#### Built-in complexity cheat sheet and the collections module

**Time complexity of built-in containers:**

| Operation | List | Dict / Set | Deque |
|---|---|---|---|
| Access by index | O(1) | — | O(n) |
| Search (`in`) | O(n) | O(1) avg | O(n) |
| Insert at end | O(1) amortized | O(1) avg | O(1) |
| Insert at start | O(n) | — | O(1) |
| Delete | O(n) | O(1) avg | O(1) at ends |

**`collections` module — the go-to extensions:**

```text
from collections import defaultdict, Counter, deque, OrderedDict

# defaultdict — no KeyError on a missing key
d = defaultdict(list)
d['a'].append(1)

# Counter — frequency map
c = Counter("banana")   # Counter({'a': 3, 'n': 2, 'b': 1})
c.most_common(2)         # [('a', 3), ('n', 2)]

# deque — O(1) push/pop at both ends (unlike list's O(n) at the front)
q = deque(maxlen=3)
q.appendleft(0); q.append(4)

# heapq — min-heap on a plain list
import heapq
h = [3, 1, 4, 1, 5]
heapq.heapify(h)
heapq.heappush(h, 2)
smallest = heapq.heappop(h)  # 1
```


#### Comprehension performance

Comprehension performance refers to why list, set, dict, and generator comprehensions execute faster and more efficiently than equivalent `for` loops in Python.

**Why comprehensions are faster:**
- Implemented with dedicated bytecode in CPython
- Fewer Python bytecode instructions than an equivalent loop
- Avoid repeated method calls like `.append()`
- Reduced temporary object creation

```text
# List comprehension (faster)
squares = [x*x for x in range(1000)]

# For loop (slower)
squares = []
for x in range(1000):
    squares.append(x*x)
```

**Types & performance characteristics:**

1. **List comprehension** — fastest way to build lists; eager evaluation (loads all data into memory).

```text
evens = [x for x in range(1_000_000) if x % 2 == 0]
```

2. **Set comprehension** — slightly slower than list comprehension; ensures uniqueness.

```text
unique = {x % 10 for x in range(1000)}
```

3. **Dict comprehension** — faster than manual dict construction; clean key-value mapping.

```text
squares = {x: x*x for x in range(1000)}
```

4. **Generator comprehension** — lazy evaluation, lowest memory usage, slightly slower per item.

```text
gen = (x*x for x in range(10**9))
```

**Performance comparison:**

| Method | Speed | Memory |
|---|---|---|
| List comprehension | High | High |
| For loop | Medium | High |
| Generator | Medium | Low |

**When to use:** simple transformations, filtering collections, creating lists/sets/dicts efficiently, large datasets (use generators).

**When to avoid:** complex business logic, deeply nested conditions, side effects (logging, DB writes).

*Correction: the source database had a second page titled "Explain comprehension performance," but its content was about human reading comprehension (accuracy, retention, prior knowledge) — an unrelated topic, not Python comprehension syntax. That content was dropped rather than merged in, since it didn't belong under this question and would have been actively misleading here.*

Further reading: [Python DS Interview Questions](https://interviewkickstart.com/blogs/interview-questions/python-data-structures-interview-questions)
