---
kind: lesson
id_key: advanced-python-interview/internals/cpython
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 0
title: "CPython"
position: 6
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/34.python_bytecode.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
"Python" is a language specification; **CPython** is the reference implementation almost everyone actually runs (`python3` on your machine is CPython unless you deliberately installed PyPy, Jython, or GraalPy). Knowing the difference — and what CPython specifically does under the hood — is what separates "I write Python" from "I understand what my Python program is actually doing."

## The pipeline: source → bytecode → PVM

CPython never interprets your `.py` text directly. It compiles it to **bytecode** — a lower-level, portable instruction set — and then the **Python Virtual Machine (PVM)**, a stack-based interpreter loop written in C, executes that bytecode instruction by instruction. You can see the bytecode for any function with `dis`:

```python
import dis

def add(a, b):
    return a + b

dis.dis(add)
# 2           0 RESOURCE_ARG ...  (exact opcodes vary by version)
#             LOAD_FAST                a
#             LOAD_FAST                b
#             BINARY_OP                +
#             RETURN_VALUE
```

This is also why a `.pyc` file exists in `__pycache__` — it's the cached compiled bytecode, so re-running the same script skips recompilation when the source hasn't changed.

## What CPython specifically gives you (and costs you)

- **A huge standard library** and a stable C-API — this is *why* the PyPI ecosystem exists: NumPy, PyTorch, and most performance-critical packages are C extensions written directly against CPython's API, not portable across every Python implementation.
- **Reference counting** for memory management (see the garbage-collection lesson) — a direct consequence of being written in C, and the reason the GIL exists at all.
- **The GIL** — only one thread executes Python bytecode at a time, a direct consequence of reference counting needing to stay thread-safe cheaply (covered in depth in the next section).
- **Slower raw execution** than a compiled language, since every bytecode instruction still goes through the PVM's interpreter loop rather than running as native machine code.

Interviewers ask about CPython specifically to check whether you can reason about *why* Python behaves the way it does — why threads don't parallelize CPU work, why `id()` returns a memory address, why small integers are cached — rather than treating the language as a black box.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-cpython-q1",
      "type": "mcq",
      "prompt": "What does CPython actually execute when you run a .py file?",
      "options": [
        { "id": "a", "text": "The raw source text, interpreted line by line" },
        { "id": "b", "text": "Bytecode compiled from the source, executed by the Python Virtual Machine" },
        { "id": "c", "text": "Native machine code, compiled ahead of time" },
        { "id": "d", "text": "A translation into C source, compiled on the fly" }
      ],
      "correct": "b",
      "explanation": "CPython compiles source to bytecode (visible via the dis module, cached in __pycache__/*.pyc) and the PVM, a C-based interpreter loop, executes that bytecode."
    },
    {
      "id": "internals-cpython-q2",
      "type": "mcq",
      "prompt": "Which of these is a direct consequence of CPython being written in C and using reference counting?",
      "options": [
        { "id": "a", "text": "The Global Interpreter Lock, which keeps refcount updates thread-safe without per-object locks" },
        { "id": "b", "text": "Python's dynamic typing" },
        { "id": "c", "text": "List comprehensions" },
        { "id": "d", "text": "The availability of type hints" }
      ],
      "correct": "a",
      "explanation": "The GIL exists specifically because CPython uses cheap, non-atomic reference counting for memory management — the GIL is what keeps concurrent refcount updates from racing, at the cost of true multi-core parallelism for threads."
    }
  ]
}
```
