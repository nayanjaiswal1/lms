---
kind: lesson
id_key: advanced-python-interview/metaclasses-context-managers/nesting-context-managers
course: advanced-python-interview
section: metaclasses-context-managers
section_title: "Metaclasses & Context Managers"
section_position: 5
title: "Nesting & Combining Context Managers"
position: 2
estimated_minutes: 15
source: [fifty-advanced-python-concepts/37.nesting_and_combining_context_managers.py, fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md]
---
A single `with` statement can manage more than one resource at once — and when the *number* of resources isn't known until runtime, `contextlib.ExitStack` lets you manage a dynamic pile of them with the same guaranteed cleanup a plain `with` gives you.

## Multiple context managers on one `with` line

```python
with open("file1.txt", "w") as file1, open("file2.txt", "w") as file2:
    file1.write("first")
    file2.write("second")

print("both files written and closed")
```

`file1` and `file2` are entered left to right and exited right to left, and — critically — if `file2`'s `open()` fails, `file1` is still closed correctly. This is exactly equivalent to nesting two separate `with` blocks; the comma-separated form is just flatter to read.

## `ExitStack`: when you don't know how many resources up front

The two-file example above only works because you know at *write time* that there are exactly two files. If the list of files comes from a variable — a config file, a directory listing, an API response — you can't write a fixed number of `with` clauses. `ExitStack` solves this by letting you push an arbitrary number of context managers onto a stack programmatically, and unwinds all of them (in reverse order) when the `with` block exits, exception or not.

```python
from contextlib import ExitStack

filenames = ["file1.txt", "file2.txt", "file3.txt"]

with ExitStack() as stack:
    files = [stack.enter_context(open(name, "w")) for name in filenames]
    for file_obj in files:
        file_obj.write("Hello, World!")

print(f"wrote and closed {len(filenames)} files")
```

`stack.enter_context(cm)` calls `cm.__enter__()` immediately and registers `cm.__exit__()` to run when the `ExitStack` itself exits — so `files` ends up holding three already-open file objects, and all three get closed automatically no matter how many there turn out to be or whether an exception happens partway through the loop.

## Where this shows up in real code

Database connection pools, batches of temp files, and groups of related locks are the classic uses: any time "how many resources" is a runtime value rather than something you can spell out as a fixed number of `with` clauses. `ExitStack` also has `callback()` for registering plain cleanup functions (not just context managers) onto the same unwind-on-exit stack, which is handy for mixing "close this file" with "delete this temp directory" in one guaranteed-to-run teardown sequence.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-nesting-context-managers-q1",
      "type": "mcq",
      "prompt": "In `with open(a) as f1, open(b) as f2:`, in what order are the context managers exited?",
      "options": [
        { "id": "a", "text": "Left to right, same as entry order" },
        { "id": "b", "text": "Right to left — reverse of entry order" },
        { "id": "c", "text": "Simultaneously, order is undefined" },
        { "id": "d", "text": "Whichever finishes writing first" }
      ],
      "correct": "b",
      "explanation": "Context managers on one with-statement (or nested with-statements) are entered in order and exited in reverse order, like a stack."
    },
    {
      "id": "metaclasses-context-managers-nesting-context-managers-q2",
      "type": "mcq",
      "prompt": "Why would you reach for contextlib.ExitStack instead of a fixed `with a, b, c:` line?",
      "options": [
        { "id": "a", "text": "ExitStack is faster at opening files" },
        { "id": "b", "text": "When the number of context managers to manage isn't known until runtime" },
        { "id": "c", "text": "ExitStack is required for any context manager involving files" },
        { "id": "d", "text": "It removes the need for try/finally entirely, even outside context managers" }
      ],
      "correct": "b",
      "explanation": "A `with a, b, c:` line requires a fixed, known-at-write-time number of context managers. ExitStack lets you push a runtime-determined number of them via enter_context() and still get guaranteed reverse-order cleanup."
    }
  ]
}
```
