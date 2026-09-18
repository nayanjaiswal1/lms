---
kind: lesson
id_key: advanced-python-interview/serialization-data/bytecode-dis
course: advanced-python-interview
section: serialization-data
section_title: "Serialization & Low-Level Data"
section_position: 4
title: "Bytecode & the `dis` Module"
position: 7
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/34.python_bytecode.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md"]
---
Python source code isn't executed directly — it's first compiled into **bytecode**, a low-level instruction set for the CPython virtual machine, then that bytecode is what actually runs. You don't need to read bytecode day to day, but knowing it exists (and how to look at it) explains a surprising amount of Python's runtime behavior, and it's a question that separates "knows Python syntax" from "understands how Python actually executes."

## Disassembling a function

The `dis` module turns a function's compiled bytecode into human-readable instructions:

```python
import dis

def count_to_ten():
    total = 0
    for i in range(10):
        total += i
    return total

dis.dis(count_to_ten)
```

Running this prints a table of opcodes — things like `LOAD_FAST`, `LOAD_GLOBAL`, `CALL`, `STORE_FAST`, `POP_JUMP_IF_FALSE` — each corresponding to one step the interpreter takes: loading a local variable onto the stack, calling a function, jumping to loop back, and so on. `range(10)` compiles to a `LOAD_GLOBAL`+`CALL`, and the `for` loop compiles to a `GET_ITER`/`FOR_ITER` pair with a jump back to the top on each iteration.

## Why senior engineers care

A few places this pays off:

- **Explaining "why is A faster than B"** — two pieces of code that look equally simple can compile to a different number of bytecode instructions. `dis.dis` is the tool that turns "I have a hunch" into "here's the extra `LOAD_ATTR` this version does that the other doesn't."
- **Understanding CPython internals questions** — "what does the GIL actually protect?" and "why is `x += 1` not atomic?" both become concrete once you can see that even a simple augmented assignment is multiple separate bytecode instructions (`LOAD_FAST`, `BINARY_ADD`, `STORE_FAST`), any of which the interpreter can be preempted between.
- **Spotting accidental global lookups** — a variable dis shows as `LOAD_GLOBAL` inside a hot loop (instead of `LOAD_FAST`) is a real, measurable slowdown, because global lookups go through a dict rather than a fixed local-variable slot.

## What it isn't

`dis` is a diagnostic tool, not something used in day-to-day application code, and bytecode is a CPython implementation detail — it isn't part of the language specification, changes between Python versions, and other implementations (PyPy, for instance) don't use the same instruction set at all. Knowing it exists, and being able to reach for it when a performance question needs a concrete answer, is the actual skill being tested.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-bytecode-dis-q1",
      "type": "mcq",
      "prompt": "What does dis.dis(some_function) show you?",
      "options": [
        { "id": "a", "text": "The function's docstring and type hints" },
        { "id": "b", "text": "The low-level bytecode instructions the CPython VM executes for that function" },
        { "id": "c", "text": "A performance benchmark of the function" },
        { "id": "d", "text": "The machine code generated for the CPU" }
      ],
      "correct": "b",
      "explanation": "dis.dis disassembles a function's compiled bytecode into readable opcodes (LOAD_FAST, CALL, etc.) — the actual instruction set the CPython interpreter executes, one level below Python source."
    },
    {
      "id": "serialization-data-bytecode-dis-q2",
      "type": "mcq",
      "prompt": "Why does seeing dis reveals that even x += 1 compiles to multiple separate bytecode instructions matter for understanding the GIL?",
      "options": [
        { "id": "a", "text": "It doesn't relate to the GIL at all" },
        { "id": "b", "text": "It shows the interpreter can be preempted between those instructions, which is why simple-looking operations like x += 1 aren't atomic across threads" },
        { "id": "c", "text": "It proves the GIL makes all operations atomic automatically" },
        { "id": "d", "text": "It means bytecode instructions always run in parallel" }
      ],
      "correct": "b",
      "explanation": "Since x += 1 is really LOAD_FAST, BINARY_ADD, STORE_FAST as separate steps, a thread switch can happen between any of them, which is exactly why augmented assignment isn't thread-safe without a lock."
    }
  ]
}
```
