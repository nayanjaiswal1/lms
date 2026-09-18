---
kind: lesson
id_key: advanced-python-interview/async-typing/asyncio
course: advanced-python-interview
section: async-typing
section_title: "Async, Callables & Advanced Typing"
section_position: 8
title: "`asyncio`"
position: 0
estimated_minutes: 20
source: ["fifty-advanced-python-concepts/50.asyncio.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md"]
---
Threads give you concurrency by having the OS preempt them; `asyncio` gives you concurrency by having your own code voluntarily yield control at `await` points, all on a single thread. No GIL contention, no locks needed for data that's never touched between `await`s — which makes it the standard choice for I/O-bound workloads (network calls, database queries, web scraping) where a thread would otherwise sit idle waiting on a socket.

## A single coroutine

`async def` defines a coroutine function — calling it doesn't run the body, it returns a coroutine object that has to be driven by an event loop. `asyncio.run()` is that driver for top-level code:

```python
import asyncio

async def greet():
    print("Hello!")
    await asyncio.sleep(1)  # yields control back to the event loop for 1 second
    print("World!")

asyncio.run(greet())
# Hello!
# (1 second pause)
# World!
```

`await asyncio.sleep(1)` is not `time.sleep(1)` — it doesn't block the thread, it tells the event loop "wake me up in 1 second, and run something else meanwhile." With only one coroutine there's nothing else to run, but that's the mechanism concurrency is built on.

## Running coroutines concurrently with `gather`

`asyncio.gather` schedules multiple coroutines on the same event loop and lets them interleave at their `await` points:

```python
import asyncio

async def task_1():
    print("Task 1: Start")
    await asyncio.sleep(0.2)
    print("Task 1: End")

async def task_2():
    print("Task 2: Start")
    await asyncio.sleep(0.1)
    print("Task 2: End")

async def main():
    await asyncio.gather(task_1(), task_2())

asyncio.run(main())
# Task 1: Start
# Task 2: Start
# Task 2: End   (0.1s sleep finishes first)
# Task 1: End   (0.2s sleep finishes second)
```

Both tasks start immediately — the "Start" prints happen back to back — then whichever one's `sleep` elapses first resumes first. Total wall-clock time is ~0.2s (the longer of the two), not ~0.3s (their sum), because they overlap instead of running sequentially.

## Producer/consumer with `asyncio.Queue`

`asyncio.Queue` coordinates coroutines the same way `queue.Queue` coordinates threads — but a consumer that loops forever must be given a way to know when to stop, or `gather` never returns. A sentinel value (`None`) signals "no more items":

```python
import asyncio

async def producer(queue):
    for i in range(3):
        await asyncio.sleep(0.1)
        await queue.put(f"item-{i}")
        print(f"produced item-{i}")
    await queue.put(None)  # sentinel: tells the consumer to stop

async def consumer(queue):
    while True:
        item = await queue.get()
        if item is None:
            break
        print(f"consumed {item}")

async def main():
    queue = asyncio.Queue()
    await asyncio.gather(producer(queue), consumer(queue))

asyncio.run(main())
```

Without that `await queue.put(None)` sentinel, `consumer`'s `while True: await queue.get()` would wait forever for an item that never arrives, and `gather` — which waits for *every* coroutine it was given — would hang indefinitely. This is the single most common bug in hand-written async producer/consumer code: always give the consumer an explicit stop signal.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-asyncio-q1",
      "type": "mcq",
      "prompt": "What's the key difference between await asyncio.sleep(1) and time.sleep(1) inside a coroutine?",
      "options": [
        { "id": "a", "text": "There is no difference — they behave identically" },
        { "id": "b", "text": "asyncio.sleep yields control back to the event loop so other coroutines can run during the wait; time.sleep blocks the entire thread" },
        { "id": "c", "text": "time.sleep is faster because it doesn't involve the event loop" },
        { "id": "d", "text": "asyncio.sleep can only be used outside of async functions" }
      ],
      "correct": "b",
      "explanation": "await asyncio.sleep(1) suspends only the current coroutine and lets the event loop run other scheduled coroutines during that second. time.sleep(1) blocks the whole thread, starving every other coroutine too — a classic asyncio antipattern."
    },
    {
      "id": "async-typing-asyncio-q2",
      "type": "mcq",
      "prompt": "In the gather(task_1(), task_2()) example, why does Task 2 finish before Task 1 even though task_1 was listed first?",
      "options": [
        { "id": "a", "text": "gather always runs coroutines in reverse order" },
        { "id": "b", "text": "Both start immediately and interleave at their await points; task_2's shorter sleep(0.1) elapses before task_1's sleep(0.2), so it resumes and finishes first" },
        { "id": "c", "text": "task_1 raised an exception and was skipped" },
        { "id": "d", "text": "Order in gather() only affects print statements, not execution" }
      ],
      "correct": "b",
      "explanation": "gather starts every coroutine right away; they run cooperatively, and whichever one's await resolves first resumes first. task_2's 0.1s sleep finishes before task_1's 0.2s sleep, so it completes first regardless of argument order."
    },
    {
      "id": "async-typing-asyncio-q3",
      "type": "mcq",
      "prompt": "What happens if the producer never puts a None sentinel on the queue, given a consumer written as `while True: item = await queue.get(); if item is None: break`?",
      "options": [
        { "id": "a", "text": "The consumer exits automatically once the producer finishes" },
        { "id": "b", "text": "The consumer's await queue.get() blocks forever waiting for another item, and gather() never returns" },
        { "id": "c", "text": "asyncio.Queue raises a TimeoutError after a default timeout" },
        { "id": "d", "text": "The program exits cleanly since there's nothing left to consume" }
      ],
      "correct": "b",
      "explanation": "Without a sentinel, the consumer has no signal to stop looping — its await queue.get() call simply waits forever for an item that will never come, and gather() waits for every coroutine it was given, so the whole program hangs."
    }
  ]
}
```
