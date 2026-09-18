---
kind: lesson
id_key: advanced-python-interview/internals/no-return-mutable
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 0
title: "Not Returning Dicts & Lists from Functions"
position: 2
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/3.no_return.py", "fifty-advanced-python-concepts/no_return_other.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
Python passes arguments by **object reference** — a variable never holds a copy of a list or dict, it holds a reference to the same object everyone else who has that variable also points at. That has a direct, easy-to-miss consequence: a function that mutates a list or dict argument doesn't need to `return` it for the caller to see the change.

## The pattern

```python
def add_n_copies(items, n):
    for i in range(n):
        items.append(n)
    # no return statement at all

my_list = []
add_n_copies(my_list, 5)
print(my_list)  # [5, 5, 5, 5, 5] — mutated in place, no return needed
```

`items` inside the function and `my_list` outside it are the same object — `id(items) == id(my_list)` is `True` for the whole call. `.append()` mutates that shared object, so the caller's variable reflects the change the instant the function returns (or even before, if another piece of code peeked at `my_list` mid-call from another thread).

## Where this bites people

The mirror image of this rule is the actual interview trap: relying on mutation when you *meant* to return a new value.

```python
def broken_scale(numbers, factor):
    numbers = [n * factor for n in numbers]  # rebinds the LOCAL name only
    return numbers

original = [1, 2, 3]
result = broken_scale(original, 10)
print(original)  # [1, 2, 3] — untouched, because the function rebound `numbers`
print(result)     # [30, 20 ,10]... [10, 20, 30] — the new list, via the return value
```

`numbers = [...]` inside the function rebinds the local name `numbers` to a brand-new list — it does not touch the object `original` still points to. This is the same reference semantics as the mutation example above, just applied to reassignment instead of `.append()`. The rule that falls out of both examples: if a function **mutates** its argument in place (`.append`, `.update`, `[:] = `, `del items[i]`), the caller sees it with no `return` needed; if a function **rebinds** the parameter name to a new object, the caller sees nothing unless the function returns it.

Being explicit about which one you're doing — and returning a new object rather than silently mutating an argument the caller didn't expect to change — is usually the more maintainable choice, even though Python allows either.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-no-return-mutable-q1",
      "type": "mcq",
      "prompt": "A function does `items.append(n)` on its list argument with no return statement. Does the caller see the change?",
      "options": [
        { "id": "a", "text": "No, lists are always copied into functions" },
        { "id": "b", "text": "Yes — the parameter and the caller's variable reference the same list object, so mutating it in place is visible without returning anything" },
        { "id": "c", "text": "Only if the function is decorated with @mutates" },
        { "id": "d", "text": "Only in Python 2, not Python 3" }
      ],
      "correct": "b",
      "explanation": "Python passes object references. items and the caller's list are the same object, so in-place mutation (append, update, etc.) is visible to the caller immediately, with no return needed."
    },
    {
      "id": "internals-no-return-mutable-q2",
      "type": "mcq",
      "prompt": "Inside a function, `numbers = [n * 2 for n in numbers]` reassigns the parameter. Why doesn't the caller's original list change?",
      "options": [
        { "id": "a", "text": "List comprehensions are read-only and can't reassign" },
        { "id": "b", "text": "Reassignment rebinds the local name to a new object — it doesn't mutate the object the caller's variable still points to" },
        { "id": "c", "text": "Python silently copies lists on reassignment" },
        { "id": "d", "text": "It does change, unless the function returns None" }
      ],
      "correct": "b",
      "explanation": "`numbers = [...]` makes the local name point at a new list; the caller's variable still points at the original object, unaffected. Only in-place mutation (not reassignment) is visible without a return."
    }
  ]
}
```
