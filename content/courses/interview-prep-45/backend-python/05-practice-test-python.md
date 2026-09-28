---
kind: quiz
id_key: interview-prep-45/test-backend-python
course: interview-prep-45
section: backend-python
section_title: "Python"
section_position: 6
section_group: "Backend"
title: "Practice Test: Python"
position: 5
estimated_minutes: 18
pass_percentage: 70
duration_minutes: 18
source:
    - interview-prep-notes.md
questions:
  - id_key: interview-prep-45/test-backend-python/refcount-cycle
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Two objects reference only each other, and nothing else in the program references either one. Which mechanism actually frees them?"
    options:
      - text: "The cyclic garbage collector, since reference counting alone never reaches zero for a cycle"
        correct: true
      - text: "Reference counting alone, the instant the last del runs"
      - text: "Neither; Python leaks the pair until the process exits"
      - text: "The GIL frees them as part of releasing the lock"
    explanation: "Each object in a two-way cycle keeps a refcount of at least 1 from the other, so plain reference counting never reaches zero. The cyclic collector detects that the only references left are internal to the cycle and frees both."

  - id_key: interview-prep-45/test-backend-python/gil-purpose
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the main technical reason CPython has a Global Interpreter Lock?"
    options:
      - text: "To keep reference count updates thread-safe, since two threads racing on the same counter could both free the same object"
        correct: true
      - text: "To make disk I/O faster"
      - text: "Because Python has no way to run more than one thread at all"
      - text: "To simplify the syntax of the threading module"
    explanation: "Without the GIL, two threads could both decrement an object's refcount to zero at the same time and both try to free it: a double-free. The GIL serializes access to protect that counter."

  - id_key: interview-prep-45/test-backend-python/xrange-removed
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Why was xrange removed in Python 3?"
    options:
      - text: "range() itself became lazy in Python 3, doing what xrange used to do, making a separate function unnecessary"
        correct: true
      - text: "Python 3 dropped support for iterating over numbers entirely"
      - text: "xrange caused memory leaks"
      - text: "It was renamed to list()"
    explanation: "Python 2's range() built a full list eagerly, while xrange() was lazy. Python 3 made range() lazy by default, so xrange had no remaining purpose."

  - id_key: interview-prep-45/test-backend-python/closure-loop
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "`funcs = [lambda: i for i in range(3)]` then calling every function in funcs. What do you get?"
    options:
      - text: "[0, 1, 2]"
      - text: "[2, 2, 2], because all three lambdas share the same i cell, which ends at 2"
        correct: true
      - text: "A NameError for each call"
      - text: "[0, 0, 0]"
    explanation: "A closure keeps a live link to the variable, not a snapshot. All three lambdas read the same i, which is 2 once the loop finishes."

  - id_key: interview-prep-45/test-backend-python/contextmanager-exit-true
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A context manager's __exit__ method returns True. What happens to an exception raised inside the with block?"
    options:
      - text: "It is swallowed and never propagates past the with block"
        correct: true
      - text: "It always re-raises with extra detail"
      - text: "It is converted into a warning"
      - text: "Nothing changes; the return value of __exit__ is ignored"
    explanation: "Returning True from __exit__ tells Python the exception was handled. Returning False or None (the usual choice) lets it propagate normally."

  - id_key: interview-prep-45/test-backend-python/generator-memory
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Why does `sum(x*x for x in range(10_000_000))` use much less memory than `sum([x*x for x in range(10_000_000)])`?"
    options:
      - text: "The generator expression produces one value at a time; the list comprehension builds all ten million values in memory first"
        correct: true
      - text: "Generators use a more compact number format"
      - text: "There is no real difference between the two"
      - text: "sum() ignores most of the values in a generator"
    explanation: "A generator expression is lazy: it computes and hands off one value at a time. A list comprehension must materialize the entire list before sum() ever sees it."

  - id_key: interview-prep-45/test-backend-python/legb-global
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A function tries to do `count += 1` on a module-level variable without declaring `global count`. What happens?"
    options:
      - text: "It works normally and updates the module-level variable"
      - text: "UnboundLocalError, because the assignment makes count local to the whole function, breaking the read half of count += 1"
        correct: true
      - text: "It silently creates a second, unrelated global variable"
      - text: "A SyntaxError at import time"
    explanation: "Any assignment to a name inside a function makes Python treat that name as local for the entire function body, decided before the function runs. Reading it before it's locally assigned raises UnboundLocalError."

  - id_key: interview-prep-45/test-backend-python/mutable-default
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "def add_item(item, cart=[]): why do items from unrelated earlier calls show up in a later call?"
    options:
      - text: "The empty list is created once at function-definition time and shared by every call that relies on the default"
        correct: true
      - text: "Python always shares lists between function calls"
      - text: "append() has a bug that duplicates items across calls"
      - text: "This only happens if the function is called recursively"
    explanation: "Default argument values are evaluated once, when def runs, not once per call. A mutable default becomes one object reused and mutated by every call that doesn't supply its own."

  - id_key: interview-prep-45/test-backend-python/mro-diamond
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "class Diamond(Left, Right), where both Left and Right inherit from Base and each calls super() in its method. How many times does Base's method run when Diamond's chain of super() calls reaches it?"
    options:
      - text: "Exactly once, since C3 linearization places each class in the MRO exactly one time"
        correct: true
      - text: "Twice, once via each parent"
      - text: "Zero, because Diamond always overrides it"
      - text: "It depends on which parent is listed first"
    explanation: "The whole point of C3 linearization is to build one order that visits each ancestor exactly once, which is what actually solves the diamond problem."

  - id_key: interview-prep-45/test-backend-python/metaclass-default
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the default metaclass of every Python class that doesn't specify one?"
    options:
      - text: "type"
        correct: true
      - text: "object"
      - text: "ABCMeta"
      - text: "There is no metaclass unless you write one"
    explanation: "Every class is an instance of type unless told otherwise. That's why type(SomeClass) prints <class 'type'> for an ordinary class."

  - id_key: interview-prep-45/test-backend-python/pickle-untrusted
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why is calling pickle.load() on data from an untrusted external client dangerous?"
    options:
      - text: "A crafted pickle payload can execute arbitrary code during deserialization"
        correct: true
      - text: "Pickle cannot handle dictionaries or nested structures"
      - text: "Pickle only works with Python 2, not Python 3"
      - text: "It always raises a MemoryError on large payloads"
    explanation: "Pickle can rebuild an object by calling arbitrary functions with arbitrary arguments, via __reduce__. An attacker controlling the bytes controls what code runs on load. json has no equivalent mechanism."
---
This test covers how Python manages memory, functions as closures and generators, the class and method-resolution model, and the standard library modules and serialization formats every backend interview expects you to know cold. Pass 70% to complete the section.
