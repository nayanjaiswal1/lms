---
kind: lesson
id_key: advanced-python-interview/weakrefs-memory/getsizeof
course: advanced-python-interview
section: weakrefs-memory
section_title: "Weak References & Memory Optimization"
section_position: 6
title: "sys.getsizeof()"
position: 4
estimated_minutes: 10
source: [fifty-advanced-python-concepts/44.getsizeof.py, fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md]
---
`sys.getsizeof(obj)` returns the number of bytes an object itself occupies in memory. It's the quickest way to compare the raw size of two objects — and the single most common mistake with it is assuming it accounts for more than it actually does.

## What it measures: shallow size only

```python
import sys

empty_list = []
list_of_ten_ints = [0] * 10
list_of_ten_big_objects = [object()] * 10

print(sys.getsizeof(empty_list))            # base overhead of an empty list
print(sys.getsizeof(list_of_ten_ints))      # bigger -- room for 10 pointers
print(sys.getsizeof(list_of_ten_big_objects))  # same as the ints list!
```

The last two lines report *the same size*, even though one list holds ten small integers and the other holds ten `object()` instances. That's because `getsizeof` on a list only measures the list's own internal array of pointers — not the objects those pointers point to. Ten pointers is ten pointers, regardless of what they point at.

## A concrete "gotcha": 10 million identical references

```python
import sys


class MyClass:
    my_var = "foo"


my_list = [MyClass()] * 10_000_000  # ONE instance, referenced 10 million times

print(len(my_list))               # 10000000
print(sys.getsizeof(my_list))     # roughly the size of 10 million pointers -- not 10 million objects
```

`[MyClass()] * 10_000_000` creates a *single* `MyClass` instance and repeats the same reference ten million times — it does not call `MyClass()` ten million times. `sys.getsizeof(my_list)` reports the size of the list's pointer array (large, but nowhere near "ten million object instances" large), because it never looks past the pointers to measure what they point to. If you actually wanted ten million distinct instances, you'd need `[MyClass() for _ in range(10_000_000)]` — and even then, `getsizeof` on the resulting list would *still* only report the list's own pointer array, not the total size of every instance it points to.

## Getting the deep size instead

When you need the *total* memory a nested structure occupies — a dict of lists, a tree of objects — `getsizeof` alone under-reports it, because it never recurses. You have to walk the structure yourself (or use a library like `pympler.asizeof`) and sum `getsizeof` at every level:

```python
import sys

def deep_size(obj, seen=None):
    """Recursively sum getsizeof over a nested dict/list/tuple structure."""
    seen = seen if seen is not None else set()
    obj_id = id(obj)
    if obj_id in seen:
        return 0
    seen.add(obj_id)

    size = sys.getsizeof(obj)
    if isinstance(obj, dict):
        size += sum(deep_size(k, seen) + deep_size(v, seen) for k, v in obj.items())
    elif isinstance(obj, (list, tuple, set)):
        size += sum(deep_size(item, seen) for item in obj)
    return size


nested = {"a": [1, 2, 3], "b": {"c": [4, 5]}}
print(sys.getsizeof(nested))   # shallow -- just the dict's own overhead
print(deep_size(nested))       # much larger -- recurses into every value
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-getsizeof-q1",
      "type": "mcq",
      "prompt": "sys.getsizeof([object()] * 10) and sys.getsizeof([0] * 10) report roughly the same size. Why?",
      "options": [
        { "id": "a", "text": "getsizeof always returns a fixed constant regardless of content" },
        { "id": "b", "text": "A list's getsizeof measures its own array of pointers, not the size of the objects those pointers reference" },
        { "id": "c", "text": "object() and 0 happen to be exactly the same size in Python" },
        { "id": "d", "text": "Python caches all small lists to the same memory address" }
      ],
      "correct": "b",
      "explanation": "getsizeof reports shallow size: for a list, that's the overhead of the list object plus its internal array of references, not the total size of whatever those references point to."
    },
    {
      "id": "weakrefs-memory-getsizeof-q2",
      "type": "mcq",
      "prompt": "What does [MyClass()] * 10_000_000 actually create?",
      "options": [
        { "id": "a", "text": "10 million separate MyClass instances" },
        { "id": "b", "text": "One MyClass instance, referenced 10 million times in the list" },
        { "id": "c", "text": "A generator that lazily creates instances on access" },
        { "id": "d", "text": "A MemoryError, since MyClass() can only be called once" }
      ],
      "correct": "b",
      "explanation": "The * operator on a list repeats the same object reference; MyClass() is called exactly once, and the resulting single instance is referenced 10 million times."
    },
    {
      "id": "weakrefs-memory-getsizeof-q3",
      "type": "mcq",
      "prompt": "How do you measure the total memory of a nested structure (e.g. a dict of lists), given that getsizeof doesn't recurse?",
      "options": [
        { "id": "a", "text": "sys.getsizeof always recurses automatically for dicts and lists" },
        { "id": "b", "text": "Walk the structure yourself, summing getsizeof at every level (or use a library like pympler.asizeof)" },
        { "id": "c", "text": "It's impossible to measure nested structures in Python" },
        { "id": "d", "text": "Call sys.getsizeof(obj, deep=True)" }
      ],
      "correct": "b",
      "explanation": "getsizeof only measures one object's shallow size. Getting a true total for a nested structure requires recursing through it yourself (tracking visited ids to avoid double-counting shared references) or using a dedicated deep-size library."
    }
  ]
}
```
