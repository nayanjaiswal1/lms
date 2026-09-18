---
kind: lesson
id_key: advanced-python-interview/serialization-data/filter
course: advanced-python-interview
section: serialization-data
section_title: "Serialization & Low-Level Data"
section_position: 4
title: "`filter`"
position: 4
estimated_minutes: 10
source: ["fifty-advanced-python-concepts/31.filter.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md"]
---
`filter` is a built-in higher-order function: give it a predicate (a function returning `True`/`False`) and an iterable, and it returns an iterator yielding only the items the predicate accepted.

## Replacing a manual loop

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

## `filter(None, iterable)`: dropping falsy values

Passing `None` instead of a function tells `filter` to use each item's own truthiness as the predicate — a quick way to drop `None`/`0`/`""`/empty containers from a list:

```python
raw = [0, "hello", "", None, 42, [], "world"]
cleaned = list(filter(None, raw))
print(cleaned)  # ['hello', 42, 'world']
```

## `filter` vs. a list comprehension

Both work; the choice is style. `[x for x in items if predicate(x)]` reads naturally when there's also a transformation happening (`[x * 2 for x in items if predicate(x)]`), while `filter(predicate, items)` reads cleanly when there's *only* filtering and the predicate already exists as a named function — `filter(is_valid, records)` is more self-documenting than `[r for r in records if is_valid(r)]`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-filter-q1",
      "type": "mcq",
      "prompt": "What does filter(lambda n: n % 2 == 0, numbers) return, before wrapping it in list()?",
      "options": [
        { "id": "a", "text": "A list of even numbers" },
        { "id": "b", "text": "A lazy iterator that yields even numbers only when consumed" },
        { "id": "c", "text": "A tuple of even numbers" },
        { "id": "d", "text": "A boolean indicating whether any even numbers exist" }
      ],
      "correct": "b",
      "explanation": "filter() returns a lazy filter object (an iterator) — it doesn't evaluate the predicate on every item until something iterates over it, such as list() or a for loop."
    },
    {
      "id": "serialization-data-filter-q2",
      "type": "mcq",
      "prompt": "What does filter(None, [0, \"hello\", \"\", None, 42]) return, as a list?",
      "options": [
        { "id": "a", "text": "[0, \"hello\", \"\", None, 42] — unchanged" },
        { "id": "b", "text": "[\"hello\", 42] — only the truthy values" },
        { "id": "c", "text": "[] — an empty list, since None isn't a valid predicate" },
        { "id": "d", "text": "A TypeError is raised" }
      ],
      "correct": "b",
      "explanation": "Passing None as the predicate tells filter to use each item's own truthiness — falsy values like 0, empty string, and None are dropped, leaving only 'hello' and 42."
    }
  ]
}
```
