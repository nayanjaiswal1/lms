---
kind: lesson
id_key: advanced-python-interview/oop-collections/collections-module
course: advanced-python-interview
section: oop-collections
section_title: "Collections & OOP Foundations"
section_position: 2
title: "The `collections` Module"
position: 0
estimated_minutes: 15
source: [fifty-advanced-python-concepts/14.collections.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
Interviewers ask about `collections` because it's a quick signal of how much of the standard library you actually use day to day. The module ships specialized container types that replace common `dict`/`list` boilerplate with something faster and more expressive.

## `defaultdict`: no more `if key not in dict`

The classic counting pattern with a plain `dict` requires checking whether a key already exists before you can increment it:

```python
counts = {}
for word in ["a", "b", "a", "c", "b", "a"]:
    if word not in counts:
        counts[word] = 0
    counts[word] += 1
print(counts)
```

`defaultdict` removes the check entirely by supplying a factory function that runs the first time a missing key is accessed:

```python
from collections import defaultdict

default_dict = defaultdict(int)
default_dict['a'] += 1
default_dict['b'] += 5
default_dict['a'] += 1

print(dict(default_dict))
print(default_dict['z'])  # missing key: factory int() -> 0, no KeyError
```

`defaultdict(int)` uses `int()` (which returns `0`) as the factory; `defaultdict(list)` is equally common for grouping items under keys without an `if key not in groups: groups[key] = []` guard.

## `Counter`: `defaultdict(int)`, specialized

`Counter` is purpose-built for the counting use case and adds convenience methods `defaultdict` doesn't have:

```python
from collections import Counter

votes = Counter(["python", "go", "python", "rust", "python", "go"])
print(votes)                # Counter({'python': 3, 'go': 2, 'rust': 1})
print(votes.most_common(2)) # [('python', 3), ('go', 2)]
print(votes["java"])        # 0 — missing keys don't raise, same as defaultdict
```

## `deque`: O(1) at both ends

A plain `list` is backed by a contiguous array, so `list.insert(0, x)` and `list.pop(0)` are O(n) — every remaining element shifts. `deque` (double-ended queue) is backed by a doubly linked structure of blocks, making operations at *both* ends O(1):

```python
from collections import deque

queue = deque([1, 2, 3])
queue.appendleft(0)
queue.append(4)
print(queue)        # deque([0, 1, 2, 3, 4])
print(queue.popleft())  # 0 — O(1), unlike list.pop(0)
```

This is why `deque` is the standard choice for BFS queues and sliding-window problems in coding interviews.

## `OrderedDict`: mostly legacy now

Before Python 3.7, plain `dict` did not guarantee insertion order — `OrderedDict` existed specifically to provide that guarantee. Since 3.7, regular `dict` preserves insertion order as a language guarantee, so `OrderedDict` is mainly useful today for its extra methods (`move_to_end`), not for ordering itself. Knowing this history is itself a common interview trivia question.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-collections-module-q1",
      "type": "mcq",
      "prompt": "What does `defaultdict(int)['missing_key']` return, given the key was never set?",
      "options": [
        { "id": "a", "text": "It raises a KeyError" },
        { "id": "b", "text": "0 — int() is called as the factory and the result is stored under that key" },
        { "id": "c", "text": "None" },
        { "id": "d", "text": "It raises a TypeError because int is not callable with no arguments" }
      ],
      "correct": "b",
      "explanation": "defaultdict calls its factory function (int() -> 0) the first time a missing key is accessed, stores the result, and returns it — no KeyError."
    },
    {
      "id": "oop-collections-collections-module-q2",
      "type": "mcq",
      "prompt": "Why is `deque.popleft()` preferred over `list.pop(0)` for a queue?",
      "options": [
        { "id": "a", "text": "deque.popleft() is O(1); list.pop(0) is O(n) because every remaining element must shift" },
        { "id": "b", "text": "list.pop(0) doesn't exist in Python 3" },
        { "id": "c", "text": "deque uses less memory per element than list" },
        { "id": "d", "text": "There is no difference; it's purely a style preference" }
      ],
      "correct": "a",
      "explanation": "list is a contiguous array, so removing the first element shifts everything left — O(n). deque is a doubly linked structure with O(1) operations at both ends."
    }
  ]
}
```
