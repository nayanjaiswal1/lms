---
kind: lesson
id_key: advanced-python-interview/core-language/shallow-vs-deep-copy
course: advanced-python-interview
section: core-language
section_title: "Core Language"
section_position: 0
section_group: Fundamentals
title: "Shallow vs Deep Copy"
position: 2
estimated_minutes: 10
source: ["knowledge/backend/python/python-core.md"]
---
Assignment never copies in Python; it just adds another name for the same object. When you do need an independent copy of a container, the real question is how deep the copy goes.

## Shallow copy

A shallow copy builds a new outer container but fills it with **references to the same inner objects**. Replacing a top-level element affects only the copy; mutating a shared nested object affects both.

```python
import copy

original = [1, 2, [3, 4]]
shallow = copy.copy(original)  # same idea: original.copy(), list(original), original[:]

shallow[2].append(5)  # mutates the shared inner list
shallow[0] = 99       # rebinds a slot in the copy only
print(original)  # [1, 2, [3, 4, 5]]
print(shallow)   # [99, 2, [3, 4, 5]]
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-shallow-q1",
      "type": "mcq",
      "prompt": "After `s = copy.copy(o)` where `o = [1, 2, [3, 4]]`, you run `s[2].append(5)`. What is `o`?",
      "options": [
        { "id": "a", "text": "[1, 2, [3, 4]]" },
        { "id": "b", "text": "[1, 2, [3, 4, 5]]" },
        { "id": "c", "text": "[1, 2, [5]]" },
        { "id": "d", "text": "An error is raised" }
      ],
      "correct": "b",
      "explanation": "A shallow copy shares the inner list, so appending through the copy changes the original's nested list too."
    },
    {
      "id": "core-language-shallow-q2",
      "type": "mcq",
      "prompt": "Which of these is NOT a shallow copy of list `x`?",
      "options": [
        { "id": "a", "text": "x[:]" },
        { "id": "b", "text": "list(x)" },
        { "id": "c", "text": "x.copy()" },
        { "id": "d", "text": "y = x" }
      ],
      "correct": "d",
      "explanation": "`y = x` creates no new object at all; both names refer to the same list."
    }
  ]
}
```

## Deep copy

`copy.deepcopy` recursively copies every nested object, so the result shares nothing mutable with the original. It also tracks objects it has already copied, so self-referencing structures do not recurse forever.

```python
import copy

original = [1, 2, [3, 4]]
deep = copy.deepcopy(original)
deep[2].append(5)
print(original)  # [1, 2, [3, 4]]
print(deep)      # [1, 2, [3, 4, 5]]

loop = [1]
loop.append(loop)  # list containing itself
clone = copy.deepcopy(loop)
print(clone[1] is clone)  # True -- cycle preserved, no infinite recursion
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-deep-q1",
      "type": "mcq",
      "prompt": "What does `copy.deepcopy` guarantee that a shallow copy does not?",
      "options": [
        { "id": "a", "text": "Nested mutable objects are duplicated, so changing them in the copy leaves the original untouched" },
        { "id": "b", "text": "The copy is faster to create" },
        { "id": "c", "text": "Immutable values are converted to mutable ones" },
        { "id": "d", "text": "The copy shares memory with the original" }
      ],
      "correct": "a",
      "explanation": "deepcopy recursively duplicates nested objects, giving a fully independent structure at the cost of time and memory."
    }
  ]
}
```

## Choosing between them, and the `[[0]*n]*n` trap

Use a shallow copy for flat data, or when sharing inner objects is intended. Use a deep copy for nested mutable structures you will modify independently; it is slower and uses more memory.

The same sharing bug appears when building grids. `*` repeats the **reference**, not the object.

```python
bad = [[0] * 2] * 2         # two references to one inner list
bad[0][0] = 1
print(bad)   # [[1, 0], [1, 0]]

good = [[0] * 2 for _ in range(2)]  # a fresh inner list per row
good[0][0] = 1
print(good)  # [[1, 0], [0, 0]]
```

```knowledge-check
{
  "questions": [
    {
      "id": "core-language-grid-q1",
      "type": "mcq",
      "prompt": "After `g = [[0] * 2] * 2; g[0][0] = 1`, what is `g`?",
      "options": [
        { "id": "a", "text": "[[1, 0], [0, 0]]" },
        { "id": "b", "text": "[[1, 0], [1, 0]]" },
        { "id": "c", "text": "[[0, 0], [0, 0]]" },
        { "id": "d", "text": "[[1, 1], [1, 1]]" }
      ],
      "correct": "b",
      "explanation": "Multiplying the outer list repeats the same inner list object, so both rows are one list. Use a list comprehension to build independent rows."
    }
  ]
}
```
