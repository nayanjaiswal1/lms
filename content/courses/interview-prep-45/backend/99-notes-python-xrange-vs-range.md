---
kind: lesson
id_key: interview-prep-45/note-python-xrange-vs-range
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Python 2 xrange vs range (and why Python 3 dropped xrange)"
position: 99
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

A recurring Python fundamentals question, not specific to Django/FastAPI but common as a warm-up before backend rounds.

## The Python 2 split

Python 2 had two functions for iterating over a numeric range:

- `range()` builds the **entire list in memory at once** — `range(1000000)` allocates all 1,000,000 integers immediately.
- `xrange()` is a **lazy generator** — it produces one number at a time, only when the loop asks for the next value, so memory use stays constant regardless of range size.

## Python 3

`xrange` was removed. `range()` itself became lazy — it now returns a `range` object (not a list), evaluated on demand, exactly like Python 2's `xrange`. Calling `list(range(...))` still gives you an eagerly-built list when you actually want one.

| | Python 2 `range()` | Python 2 `xrange()` | Python 3 `range()` |
|---|---|---|---|
| Returns | Full list | Generator object | Range object (lazy) |
| Memory | High | Low | Low |
| Speed over large ranges | Slow | Fast | Fast |

## One-liner for the interview

"`xrange` is lazy, `range` is greedy — and Python 3 made `range` lazy too, so `xrange` was no longer needed."

## Key takeaways

- Python 2: `range()` eager (full list), `xrange()` lazy (generator) — use `xrange` for large loops to avoid the memory hit.
- Python 3: `range()` is lazy by default (a `range` object), so `xrange` was redundant and removed.
- `list(range(...))` still gets you an eager list in Python 3 when you actually need one materialized.
