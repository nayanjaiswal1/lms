---
kind: lesson
id_key: advanced-python-interview/iterators-testing/generators
course: advanced-python-interview
section: iterators-testing
section_title: "Iterators, Generators & Testing"
section_position: 3
title: "Generators"
position: 1
estimated_minutes: 15
source: [fifty-advanced-python-concepts/22.generators.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
A generator is the easy way to build something that satisfies the iterator protocol from the previous lesson, without hand-writing `__iter__`/`__next__`/`StopIteration` yourself. Any function containing `yield` becomes a **generator function** — calling it doesn't run its body; it returns a generator object that runs the body lazily, one `yield` at a time.

## Calling a generator function doesn't execute it

```python
def my_generator():
    yield 1
    yield 2
    yield 3

gen = my_generator()   # nothing has printed yet — no code inside has run
print(next(gen))       # 1 — runs up to the first yield, pauses there
print(next(gen))       # 2 — resumes, runs to the second yield
print(next(gen))       # 3
print(next(gen))       # raises StopIteration — body has run to completion
```

This is the detail interviewers probe most: `my_generator()` returns immediately with a generator object — none of the function body has executed. Execution only happens as `next()` is called, and each call resumes exactly where the previous one left off (all local variables preserved), rather than starting the function over.

## `send()`: passing a value *into* a paused generator

`yield` isn't just an output — it can also be an expression that receives a value:

```python
def generator_with_send():
    value = yield "Start"       # pauses here, yielding "Start"
    yield f"Received: {value}"  # resumes here when send() is called

gen = generator_with_send()
print(next(gen))          # Start — runs to the first yield
print(gen.send("Data"))   # Received: Data — "Data" becomes `value`, runs to the next yield
```

`gen.send("Data")` does two things atomically: it resumes the paused generator with `"Data"` as the *result* of the `yield "Start"` expression, and it runs until the next `yield` (or `StopIteration`). The first `next(gen)` call is required before `send()` can pass a real value in — there's no paused `yield` expression to receive it until the generator has started.

## Why generators exist: laziness and memory

```python
def squares_list(n):
    return [i * i for i in range(n)]   # builds the entire list in memory up front

def squares_gen(n):
    for i in range(n):
        yield i * i                     # produces one value at a time, on demand

# squares_list(10_000_000) allocates ~10 million ints immediately.
# squares_gen(10_000_000) allocates nothing until you actually iterate it.
total = sum(squares_gen(10_000_000))
```

`squares_gen` never holds more than one value in memory at a time — this is why generators are the standard tool for streaming large datasets, reading huge files line by line, or building infinite sequences that would be impossible to materialize as a list.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-generators-q1",
      "type": "mcq",
      "prompt": "What happens when you call `gen = my_generator()` on a function containing `yield`?",
      "options": [
        { "id": "a", "text": "The entire function body runs immediately and gen holds the final return value" },
        { "id": "b", "text": "Nothing in the function body executes yet — gen is a generator object, and execution starts on the first next(gen) call" },
        { "id": "c", "text": "It raises a SyntaxError because generator functions can't be called directly" },
        { "id": "d", "text": "It runs until the first yield and then returns None" }
      ],
      "correct": "b",
      "explanation": "Calling a generator function only constructs the generator object. No code in the function body runs until next() is called on it."
    },
    {
      "id": "iterators-testing-generators-q2",
      "type": "mcq",
      "prompt": "Why is a generator preferred over building a full list for processing a very large dataset?",
      "options": [
        { "id": "a", "text": "Generators run faster per-element than list comprehensions in every case" },
        { "id": "b", "text": "Generators produce one value at a time on demand, so memory usage stays constant instead of scaling with dataset size" },
        { "id": "c", "text": "Lists cannot hold more than a few thousand elements" },
        { "id": "d", "text": "Generators automatically parallelize the work across CPU cores" }
      ],
      "correct": "b",
      "explanation": "A list comprehension materializes every element in memory before you can use any of them. A generator yields one value at a time, so memory usage stays flat regardless of how many items are eventually produced."
    }
  ]
}
```
