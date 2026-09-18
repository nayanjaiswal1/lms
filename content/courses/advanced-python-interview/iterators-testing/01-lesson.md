---
kind: lesson
id_key: advanced-python-interview/iterators-testing/iterators
course: advanced-python-interview
section: iterators-testing
section_title: "Iterators, Generators & Testing"
section_position: 3
title: "Iterators"
position: 0
estimated_minutes: 15
source: [fifty-advanced-python-concepts/21.iterators.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
Every `for x in obj:` loop in Python is powered by the **iterator protocol** — two dunder methods, `__iter__` and `__next__`. Understanding this protocol is what lets you explain *why* a `for` loop works on a list, a file, a dict, and a generator, all through the same syntax.

## The protocol: `__iter__` + `__next__`

- `__iter__(self)` returns an **iterator** — an object that knows how to produce the next value. For an object that's already an iterator, this is conventionally `return self`.
- `__next__(self)` returns the next value, or raises `StopIteration` when there's nothing left.

```python
class MyIterator:
    def __init__(self, start, end):
        self.current = start
        self.end = end

    def __iter__(self):
        return self  # an iterator returns itself here

    def __next__(self):
        if self.current >= self.end:
            raise StopIteration
        value = self.current
        self.current += 1
        return value

iterator = MyIterator(1, 5)
for num in iterator:
    print(num)  # 1, 2, 3, 4
```

`for num in iterator:` is doing this under the hood: call `iter(iterator)` once (returns `self`), then call `next(iterator)` repeatedly, catching `StopIteration` to know when to stop.

## Iterators are stateful and consumed once

```python
iterator = MyIterator(1, 5)
print(list(iterator))  # [1, 2, 3, 4]
print(list(iterator))  # [] — already exhausted; current is now stuck at 5
```

This is the gotcha that separates iterators from collections like `list`: a `list` can be looped over any number of times because each `for` loop calls `__iter__` and gets a *fresh* iterator over the same data. `MyIterator.__iter__` returns `self` — the *same* stateful object — so once its internal `current` reaches `end`, every future iteration attempt starts already exhausted.

## Iterable vs. iterator — a distinction interviewers probe

- **Iterable**: any object with `__iter__` (a `list`, `dict`, `str`, or a custom class like `MyIterator`) — something you *can* call `iter()` on.
- **Iterator**: the object `__iter__` returns — something with `__next__` that tracks position and can be *consumed*.

Every iterator is iterable (its `__iter__` returns itself), but not every iterable is an iterator — a `list` is iterable but is not itself an iterator (calling `next()` directly on a list raises `TypeError`; you must first call `iter(my_list)`).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-iterators-q1",
      "type": "mcq",
      "prompt": "What must `__next__` do once there are no more values to produce?",
      "options": [
        { "id": "a", "text": "Return None" },
        { "id": "b", "text": "Raise StopIteration" },
        { "id": "c", "text": "Return an empty list" },
        { "id": "d", "text": "Silently loop forever" }
      ],
      "correct": "b",
      "explanation": "StopIteration is the signal the for loop (and iter()/next() machinery generally) listens for to know iteration is complete."
    },
    {
      "id": "iterators-testing-iterators-q2",
      "type": "mcq",
      "prompt": "Why does looping over the same `MyIterator` instance twice produce results the second time but not the first — i.e. why is the second loop empty?",
      "options": [
        { "id": "a", "text": "It isn't empty — this is a trick question" },
        { "id": "b", "text": "__iter__ returns self, so both loops share the same stateful `current` counter, which the first loop already advanced to `end`" },
        { "id": "c", "text": "Python automatically resets custom iterators between loops" },
        { "id": "d", "text": "MyIterator can only be looped over inside a with block" }
      ],
      "correct": "b",
      "explanation": "Because __iter__ returns self instead of a fresh object, both for loops operate on the exact same current/end state — the first loop exhausts it, so the second loop's first __next__ call immediately raises StopIteration."
    }
  ]
}
```
