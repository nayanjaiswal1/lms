---
kind: lesson
id_key: advanced-python-interview/exceptions-oop/exceptions
course: advanced-python-interview
section: errors-testing
section_title: "Exceptions & Testing"
section_position: 4
section_group: Fundamentals
title: "Exception Handling & How It Works Internally"
position: 0
estimated_minutes: 14
source: ["knowledge/backend/python/python-exceptions.md"]
---
Exceptions are Python's normal error-propagation mechanism, so interviewers probe two layers: how you use `try`/`except` correctly, and what the interpreter does when something is raised. This lesson covers both.

## try / except / else / finally

Each clause has one job. `except` handles a failure, `else` runs only if the `try` body raised nothing, and `finally` runs no matter what (including on `return` or an unhandled exception). Keep the `try` body tiny so you only catch what you meant to catch, and put the success-path follow-up in `else`.

```python
def parse(text):
    try:
        value = int(text)
    except ValueError:
        print("not a number")
        return None
    else:
        print("parsed ok")
        return value
    finally:
        print("cleanup always runs")

print(parse("42"))
print(parse("abc"))
```

Catch specific exception types, never a bare `except:` (it also swallows `KeyboardInterrupt` and `SystemExit`). Catching `Exception` is the broadest reasonable net.

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-exceptions-q1",
      "type": "mcq",
      "prompt": "When does the `else` block of a try statement run?",
      "options": [
        { "id": "a", "text": "Only when the try body completed without raising an exception" },
        { "id": "b", "text": "Whenever an exception is raised" },
        { "id": "c", "text": "Always, after finally" },
        { "id": "d", "text": "Only when the exception is not caught" }
      ],
      "correct": "a",
      "explanation": "else is the success path: it runs only if try finished without an exception, and exceptions raised inside else are not caught by the sibling except clauses."
    },
    {
      "id": "exceptions-oop-exceptions-q2",
      "type": "mcq",
      "prompt": "Why is a bare `except:` considered bad practice?",
      "options": [
        { "id": "a", "text": "It is a syntax error in Python 3" },
        { "id": "b", "text": "It also catches KeyboardInterrupt and SystemExit and hides real bugs" },
        { "id": "c", "text": "It disables the finally block" },
        { "id": "d", "text": "It is slower than except Exception" }
      ],
      "correct": "b",
      "explanation": "A bare except catches BaseException subclasses too, so Ctrl+C and sys.exit() get swallowed and programming errors are silently hidden."
    }
  ]
}
```

## Raising and chaining with raise ... from

Use `raise` to signal failure and a bare `raise` inside `except` to re-raise the current exception unchanged. When you translate a low-level error into a domain error, use `raise NewError(...) from err` so the original is kept as `__cause__` and the traceback shows both. `from None` suppresses the chained context when it is just noise.

```python
class ConfigError(Exception):
    pass

def load(value):
    try:
        return int(value)
    except ValueError as err:
        raise ConfigError(f"bad port: {value!r}") from err

try:
    load("http")
except ConfigError as e:
    print(e)
    print(type(e.__cause__).__name__)
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-exceptions-q3",
      "type": "mcq",
      "prompt": "What does `raise ConfigError(...) from err` accomplish?",
      "options": [
        { "id": "a", "text": "Stores err as __cause__ so the traceback shows the original failure that led to the new one" },
        { "id": "b", "text": "Catches err and discards it" },
        { "id": "c", "text": "Makes ConfigError a subclass of type(err)" },
        { "id": "d", "text": "Re-raises err after ConfigError is handled" }
      ],
      "correct": "a",
      "explanation": "Explicit chaining sets __cause__, preserving the root cause when you wrap a low-level error in a domain-specific one."
    }
  ]
}
```

## Stack unwinding and exception tables

When an exception is raised the runtime does not just jump to a handler. It performs **stack unwinding**: look for a matching handler in the current function; if none, run its cleanup code (`finally` blocks, destructors), pop that frame, and repeat in the caller, until a handler is found or the program terminates.

To make the search possible the compiler emits **exception tables**: metadata mapping each protected code region (a `try` body) to its handler location, the exception types it catches, and any cleanup code. This general design is the table-based approach used by C++; the alternative, code-based (setjmp/longjmp style), embeds handler setup into the running code, so raising is cheaper but every call pays overhead.

```text
raise in f()  ->  look in f's table
   no match   ->  run cleanup, pop f's frame
              ->  look in caller's table  ->  ... until handler or exit
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-exceptions-q4",
      "type": "mcq",
      "prompt": "What happens when a raised exception finds no handler in the current function?",
      "options": [
        { "id": "a", "text": "The program terminates immediately" },
        { "id": "b", "text": "Cleanup code runs, the frame is popped, and the search repeats in the caller" },
        { "id": "c", "text": "The exception is silently ignored" },
        { "id": "d", "text": "The interpreter restarts the function" }
      ],
      "correct": "b",
      "explanation": "That repeated frame-by-frame search with cleanup is stack unwinding; the program only terminates if no frame handles the exception."
    }
  ]
}
```

## How CPython implements it: block stack vs zero-cost tables

Before Python 3.11, each frame kept a **block stack**: `SETUP_FINALLY`/`SETUP_WITH` bytecodes pushed an entry when entering a `try`, so even a `try` that never raised executed extra instructions. Errors propagated by C functions returning `NULL` while the exception sat in thread-local state (`PyErr_Occurred`).

Since 3.11 CPython uses **zero-cost exception tables**: the compiler records, per code object, which bytecode offset ranges map to which handler offsets. Entering a `try` emits no instructions. Only when an exception occurs does the interpreter look the offset up in the table.

You can see the table yourself:

```python
import dis

def f():
    try:
        return 1 / 0
    except ZeroDivisionError:
        return 0

dis.dis(f)  # the trailing "ExceptionTable:" section is the handler map (3.11+)
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-exceptions-q5",
      "type": "mcq",
      "prompt": "What changed in CPython 3.11 regarding try blocks?",
      "options": [
        { "id": "a", "text": "A try block now compiles to no setup instructions; handlers are found via an exception table only when an exception is raised" },
        { "id": "b", "text": "try blocks were removed in favor of match statements" },
        { "id": "c", "text": "Exceptions now use C++ frame-pointer unwinding" },
        { "id": "d", "text": "The block stack was made larger" }
      ],
      "correct": "a",
      "explanation": "Pre-3.11 used a per-frame block stack pushed by SETUP_FINALLY; 3.11 replaced it with zero-cost exception tables consulted lazily at raise time."
    }
  ]
}
```

## Why raising is costly but try is free

On the happy path a `try` costs nothing in 3.11+ (and little before), so wrapping code in `try` is not a performance concern. Raising, however, is real work: create the exception object, build a traceback entry per frame, look up tables, and unwind. That makes EAFP (`try: d[k] except KeyError`) great when failure is rare, but a poor choice when a key is missing most of the time, where `if k in d` or `d.get(k)` wins.

```python
import timeit

d = {}

def eafp():
    try:
        d["k"]
    except KeyError:
        pass

def lbyl():
    if "k" in d:
        d["k"]

print("raising is slower:", timeit.timeit(eafp, number=200_000) > timeit.timeit(lbyl, number=200_000))
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-exceptions-q6",
      "type": "mcq",
      "prompt": "When is `if key in d` a better choice than `try: d[key] except KeyError`?",
      "options": [
        { "id": "a", "text": "When the key is usually missing, because each raise costs far more than a membership check" },
        { "id": "b", "text": "When the key is usually present, because try blocks are expensive" },
        { "id": "c", "text": "Never; EAFP is always faster" },
        { "id": "d", "text": "Only in Python versions before 3.11, where raising was free" }
      ],
      "correct": "a",
      "explanation": "Entering try is free, but raising and unwinding is expensive, so frequent failures favor an explicit check."
    },
    {
      "id": "exceptions-oop-exceptions-q7",
      "type": "mcq",
      "prompt": "Which statement about exception cost in CPython 3.11+ is correct?",
      "options": [
        { "id": "a", "text": "Cost is paid on every try entry, not on raise" },
        { "id": "b", "text": "Cost is near zero on the no-exception path and paid when an exception is raised" },
        { "id": "c", "text": "Both raising and entering try are free" },
        { "id": "d", "text": "Raising is cheap but entering try is expensive" }
      ],
      "correct": "b",
      "explanation": "Zero-cost tables move all the work (object creation, traceback, table lookup, unwinding) to the raise path."
    }
  ]
}
```
