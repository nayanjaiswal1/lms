---
kind: lesson
id_key: advanced-python-interview/internals/arrays
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 0
title: "Arrays (the `array` Module)"
position: 0
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/1.arrays.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
A Python `list` can hold anything — an int, a string, another list — in the same container. That flexibility costs memory: each element is a separate Python object, and the list itself stores an array of *pointers* to those objects, not the raw values. When you need a large, homogeneous run of numbers, the standard library's `array` module stores the raw values directly, packed the way a C array would be.

## Type-specific arrays

`array.array` takes a **type code** as its first argument — a single character that fixes what every element must be — and refuses anything that doesn't fit.

```python
from array import array

numbers = array('i', [1, 2, 3, 4, 5])  # 'i' = signed int
numbers.append(6)
numbers.extend([7, 8])
numbers.insert(0, 0)

print(numbers)          # array('i', [0, 1, 2, 3, 4, 5, 6, 7, 8])
print(numbers.itemsize)  # 4 — bytes per element on this platform

try:
    numbers.append("nine")
except TypeError as e:
    print(f"rejected: {e}")  # array only holds ints once created with 'i'
```

`array` supports the same `.append`/`.extend`/`.insert` methods as `list`, so the API is familiar — the difference is entirely in storage. Common type codes: `'b'`/`'B'` (signed/unsigned byte), `'i'`/`'I'` (signed/unsigned int), `'f'`/`'d'` (float/double), `'u'` (unicode char, deprecated).

## Why this matters at the memory level

A `list` of a million ints stores a million separate `int` objects (each with its own refcount and type pointer) plus a million 8-byte pointers in the list's backing array. An `array('i', ...)` of a million ints stores exactly one contiguous block of 4-million bytes — no per-element object overhead at all. That's the trade you're making: `array` is dramatically more memory-efficient and cache-friendly for large runs of one numeric type, at the cost of losing per-element flexibility and Python-level dynamic typing.

In practice, `array` shows up under the hood of other tools (it backs parts of `struct`, and libraries like NumPy generalize the same idea to N dimensions) more often than it's reached for directly — but recognizing when a list's flexibility is pure overhead is the actual interview signal.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-arrays-q1",
      "type": "mcq",
      "prompt": "What must you specify when creating a Python array.array that a list never requires?",
      "options": [
        { "id": "a", "text": "A fixed maximum length" },
        { "id": "b", "text": "A type code, fixing every element to the same type" },
        { "id": "c", "text": "A custom hash function" },
        { "id": "d", "text": "A thread-safety mode" }
      ],
      "correct": "b",
      "explanation": "array.array('i', ...) fixes the element type via a one-character type code; mixing types raises TypeError, unlike a list."
    },
    {
      "id": "internals-arrays-q2",
      "type": "mcq",
      "prompt": "Why is array more memory-efficient than list for a million integers?",
      "options": [
        { "id": "a", "text": "It stores raw values in one contiguous block instead of a million separate int objects plus pointers" },
        { "id": "b", "text": "It compresses the data automatically" },
        { "id": "c", "text": "It uses a different garbage collector" },
        { "id": "d", "text": "It stores values on disk instead of in RAM" }
      ],
      "correct": "a",
      "explanation": "A list holds pointers to individually-allocated int objects; array packs raw values contiguously like a C array, eliminating per-element object overhead."
    }
  ]
}
```
