---
kind: lesson
id_key: java-mastery/concurrency/threads-and-runnable
course: java-mastery
section: concurrency
section_title: "Concurrency"
section_position: 11
title: "Threads and Runnable Basics"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every TaskFlow program you've written so far runs on a single thread: one instruction after another, top to bottom. That's fine for small examples, but real TaskFlow workloads don't look like that — imagine a nightly job that has to process a batch of 10,000 overdue tasks (recalculating priority, sending reminder emails, updating status). Doing that one task at a time, waiting for each to finish before starting the next, wastes the CPU's other cores sitting idle while each individual task is mostly waiting on I/O anyway. **Concurrency** is how Java lets a program make progress on more than one unit of work at a time.

## Concurrency vs. parallelism

These two words get used interchangeably, but they mean different things. **Concurrency** is about *structure*: a program is concurrent if it's composed of multiple independent tasks that can be worked on out of order or in overlapping time windows — even on a single CPU core, by rapidly switching between them. **Parallelism** is about *execution*: tasks are parallel if they are literally running at the same physical instant, which requires multiple CPU cores. A single-core machine can still run concurrent code (the OS time-slices between threads), but it can never truly run two threads in parallel. Java's threading APIs give you concurrency; whether the JVM turns that into real parallelism depends on how many cores the underlying hardware has. In practice, for TaskFlow's batch job, you write it as concurrent (independent per-task units of work) and let the JVM and OS exploit however many cores are actually available.

## Creating and starting a Thread

Java models a thread of execution with the `Thread` class. The simplest way to give it work to do is to hand it a `Runnable` — a functional interface with a single method, `void run()`:

```java
public class Main {
    public static void main(String[] args) {
        Runnable processTask = () -> {
            System.out.println("Processing task on: " + Thread.currentThread().getName());
        };

        Thread worker = new Thread(processTask, "task-worker-1");
        worker.start();

        try {
            worker.join(); // wait for the worker thread to finish before continuing
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        System.out.println("Main thread continues after worker finished.");
    }
}
```

A few pieces worth calling out:

- `new Thread(processTask, "task-worker-1")` wraps the `Runnable` in a `Thread` object and gives it a name — useful for debugging when you have many threads running at once.
- `worker.start()` is what actually creates a new OS-level thread and begins running `run()` concurrently with `main`. **Calling `worker.run()` directly instead of `start()` is a common mistake** — that just calls the method like any other, on the current thread, with no concurrency at all.
- `worker.join()` blocks the calling thread (here, `main`) until `worker` finishes. Without it, `main` could reach the end of the program before the worker thread ever gets scheduled to run, and you might not see its output at all.
- `Thread.currentThread()` returns a reference to whichever thread is currently executing that line — inside the lambda, that's `worker`, not `main`.

## Running several TaskFlow jobs concurrently

Here's the batch-processing scenario made concrete: three independent tasks, each simulated by a short unit of "work," run on their own threads instead of sequentially. Because thread scheduling order between the three worker threads is not guaranteed, this example joins every thread before printing anything from the workers' *results* — the workers themselves don't print in the middle, only the main thread prints a final, deterministic summary after all of them are done:

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        String[] taskNames = { "Design database schema", "Build REST API", "Write tests" };
        int[] results = new int[taskNames.length];
        List<Thread> workers = new ArrayList<>();

        for (int i = 0; i < taskNames.length; i++) {
            final int index = i;
            Thread worker = new Thread(() -> {
                // Simulate work: compute something and store it, don't print from here.
                results[index] = taskNames[index].length();
            });
            workers.add(worker);
            worker.start();
        }

        // Join every worker before reading results — guarantees all writes finished.
        for (Thread worker : workers) {
            worker.join();
        }

        int totalCharacters = 0;
        for (int i = 0; i < taskNames.length; i++) {
            System.out.println(taskNames[i] + " -> " + results[i] + " characters");
            totalCharacters += results[i];
        }
        System.out.println("Total: " + totalCharacters);
    }
}
```

Notice the pattern: each thread only writes to its own slot in `results` (`results[index]`), so there's no shared mutable state being written by two threads at once, and the `main` thread only reads `results` after every worker has been joined. That combination is what makes the output deterministic on every run, even though the JVM is free to schedule the three worker threads in any order or interleaving it likes. The next lesson covers what goes wrong when two threads *do* write to the same shared state without this kind of coordination.

## Why not just use more threads for everything?

Creating a `Thread` per unit of work is fine for a handful of tasks, but it doesn't scale: each OS thread costs real memory (a stack, typically at least half a megabyte) and real scheduling overhead. Spinning up 10,000 raw `Thread` objects for that overdue-tasks batch job would likely exhaust memory or thrash the OS scheduler before it exhausted the actual work. That's the motivation for thread pools, covered in the `ExecutorService` lesson later in this module — they let you reuse a small, bounded number of threads across a much larger number of tasks.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-threads-and-runnable-q1",
      "type": "mcq",
      "prompt": "What's the difference between concurrency and parallelism?",
      "options": [
        { "id": "a", "text": "They are the same thing, just different names for multithreading" },
        { "id": "b", "text": "Concurrency is about structuring a program as independent tasks that can overlap; parallelism is about those tasks literally executing at the same instant on multiple cores" },
        { "id": "c", "text": "Parallelism only applies to Java, concurrency only applies to other languages" },
        { "id": "d", "text": "Concurrency requires multiple CPU cores; parallelism does not" }
      ],
      "correct": "b",
      "explanation": "Concurrency is a structural property of the program (independent tasks that can be interleaved); parallelism is a runtime property that requires multiple cores actually executing simultaneously. Concurrent code can run on one core via time-slicing without ever being parallel."
    },
    {
      "id": "concurrency-threads-and-runnable-q2",
      "type": "mcq",
      "prompt": "What happens if you call worker.run() instead of worker.start()?",
      "options": [
        { "id": "a", "text": "It throws an IllegalStateException" },
        { "id": "b", "text": "It behaves identically to start() but is slightly slower" },
        { "id": "c", "text": "run() executes like a normal method call on the current thread — no new thread is created, so there's no concurrency" },
        { "id": "d", "text": "It starts the thread but does not run any code until join() is called" }
      ],
      "correct": "c",
      "explanation": "start() is the only method that actually creates a new OS thread and schedules run() to execute on it. Calling run() directly just invokes that method synchronously on whichever thread called it."
    },
    {
      "id": "concurrency-threads-and-runnable-q3",
      "type": "mcq",
      "prompt": "In the batch-processing example, why does every result print in the same order on every run despite thread scheduling being nondeterministic?",
      "options": [
        { "id": "a", "text": "Because Thread objects always execute in the order they were created" },
        { "id": "b", "text": "Because each worker writes only to its own array slot, and all workers are joined before the main thread reads any results and prints" },
        { "id": "c", "text": "Because println is thread-safe, which guarantees ordering" },
        { "id": "d", "text": "It doesn't — the output order is actually random" }
      ],
      "correct": "b",
      "explanation": "Determinism here comes from the coordination pattern, not luck: no shared slot is written by more than one thread, and join() guarantees every write has completed before main reads results[] and prints in a fixed, sequential order."
    }
  ]
}
```

## What's next

Sharing state safely between threads — not just writing to separate array slots — is where concurrency gets genuinely tricky. The next lesson demonstrates a real race condition and fixes it with `synchronized`.
