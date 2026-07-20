---
kind: lesson
id_key: java-mastery/concurrency/executorservice-callable-future
course: java-mastery
section: concurrency
section_title: "Concurrency"
section_position: 11
title: "ExecutorService, Callable, and Future"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
The first lesson in this module flagged the problem: creating a raw `Thread` per unit of work doesn't scale, because every OS thread costs real memory and scheduling overhead. If TaskFlow needs to process 10,000 overdue tasks, you don't want 10,000 threads fighting over the CPU at once. What you actually want is a small, fixed pool of worker threads that pulls jobs off a queue and reuses itself for the next job when it finishes the current one. That's exactly what `ExecutorService` gives you.

## Why thread pools exist

Two problems drive the design: **reuse** and **bounded resource usage**. Creating and destroying an OS thread is expensive relative to the work it might do; a pool amortizes that cost by keeping a fixed set of threads alive and handing them job after job. Bounding the pool size also protects the rest of the system — instead of letting 10,000 tasks spin up 10,000 threads and exhaust memory, a pool of, say, 8 threads processes them 8 at a time, queuing the rest until a worker frees up.

## Submitting work to an ExecutorService

```java
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        ExecutorService pool = Executors.newFixedThreadPool(4);

        String[] taskNames = {
            "Design database schema", "Build REST API", "Write tests", "Deploy to staging"
        };

        for (String taskName : taskNames) {
            pool.submit(() -> {
                // "Process" the task — in real TaskFlow this might recalculate
                // priority, send a reminder, or update a status field.
                System.out.println("Would process: " + taskName.length() + " chars"); // not deterministic output order
            });
        }

        pool.shutdown();
        pool.awaitTermination(5, TimeUnit.SECONDS);
        System.out.println("Batch submitted and pool shut down.");
    }
}
```

`Executors.newFixedThreadPool(4)` creates a pool of exactly 4 worker threads that stay alive and get reused across all four submitted jobs. `pool.submit(Runnable)` hands a job to the pool without blocking the caller — it returns immediately and the job runs whenever a worker thread is free. `pool.shutdown()` tells the pool to stop accepting new jobs and to shut its threads down once the queued work finishes; `awaitTermination` blocks (with a timeout) until that happens. Note the comment on the print line: with four jobs interleaved across four threads, the *order* those lines print in isn't guaranteed — this specific example is here to show the submission pattern, not to demonstrate deterministic output (the next example fixes that).

## Callable and Future: getting a result back

`Runnable.run()` returns nothing and can't throw a checked exception. `Callable<V>` is `Runnable`'s more capable sibling — its single method `V call()` returns a value and is allowed to throw. Submitting a `Callable` to an `ExecutorService` gives you back a `Future<V>`, a handle representing a result that may not exist yet:

```java
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class Main {
    public static void main(String[] args) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(3);

        String[] taskNames = {
            "Design database schema", "Build REST API", "Write tests"
        };

        List<Future<Integer>> futures = new ArrayList<>();
        for (String taskName : taskNames) {
            Callable<Integer> processTask = () -> {
                // Simulate computing an estimate in hours based on task complexity.
                return taskName.length() / 3;
            };
            futures.add(pool.submit(processTask));
        }

        int totalEstimatedHours = 0;
        for (int i = 0; i < futures.size(); i++) {
            int hours = futures.get(i).get(); // blocks until that task's result is ready
            System.out.println(taskNames[i] + " -> estimated " + hours + "h");
            totalEstimatedHours += hours;
        }

        System.out.println("Total estimated hours: " + totalEstimatedHours);
        pool.shutdown();
    }
}
```

`Future.get()` blocks the calling thread until that specific job finishes, then returns its result (or rethrows its exception, wrapped in an `ExecutionException`, if the job failed). Because the loop that prints results calls `futures.get(i).get()` **in the original task order** — not whichever job happens to finish first — the printed output is deterministic and identical every run, even though the three `Callable`s might actually complete on the pool's threads in any order.

## Choosing a pool size and shutting down cleanly

`Executors` offers a few common factory presets:

| Factory method | Behavior |
|---|---|
| `newFixedThreadPool(n)` | Exactly `n` threads, reused for all submitted work — good default for CPU-bound or bounded work |
| `newCachedThreadPool()` | Creates threads as needed, reuses idle ones, can grow unbounded — risky under sustained heavy load |
| `newSingleThreadExecutor()` | Exactly one worker thread — jobs run one at a time, in submission order |

Always call `shutdown()` (or `shutdownNow()` to cancel in-flight work) when a pool is no longer needed — an `ExecutorService` that's never shut down keeps its threads alive indefinitely, which is a resource leak in a long-running application like a server.

```java
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        ExecutorService pool = Executors.newSingleThreadExecutor();
        try {
            pool.submit(() -> System.out.println("Single-threaded job ran."));
        } finally {
            pool.shutdown();
        }
    }
}
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-executorservice-callable-future-q1",
      "type": "mcq",
      "prompt": "Why use a thread pool instead of creating a new Thread for every task?",
      "options": [
        { "id": "a", "text": "Thread pools make individual tasks run faster" },
        { "id": "b", "text": "Thread pools reuse a bounded set of threads instead of paying thread-creation cost per task and risking unbounded resource usage" },
        { "id": "c", "text": "Raw Thread objects cannot call methods that return a value" },
        { "id": "d", "text": "There is no real difference; it's just a style preference" }
      ],
      "correct": "b",
      "explanation": "Thread creation and teardown is relatively expensive, and an unbounded number of live threads can exhaust memory or overwhelm the OS scheduler. A pool caps how many threads exist while still processing arbitrarily many tasks."
    },
    {
      "id": "concurrency-executorservice-callable-future-q2",
      "type": "mcq",
      "prompt": "What's the key difference between Runnable and Callable<V>?",
      "options": [
        { "id": "a", "text": "Callable can be submitted to an ExecutorService, Runnable cannot" },
        { "id": "b", "text": "Callable's call() method returns a value and can throw a checked exception; Runnable's run() returns void and cannot throw checked exceptions" },
        { "id": "c", "text": "Runnable always runs faster than Callable" },
        { "id": "d", "text": "Callable is only usable with newSingleThreadExecutor" }
      ],
      "correct": "b",
      "explanation": "Both are functional interfaces submittable to an ExecutorService, but Callable<V> exists specifically to produce a result (via Future<V>) and to propagate checked exceptions, which Runnable cannot do."
    },
    {
      "id": "concurrency-executorservice-callable-future-q3",
      "type": "mcq",
      "prompt": "What does future.get() do?",
      "options": [
        { "id": "a", "text": "Returns immediately with null if the task hasn't finished yet" },
        { "id": "b", "text": "Cancels the task and returns its partial result" },
        { "id": "c", "text": "Blocks the calling thread until that task completes, then returns its result (or throws if the task failed)" },
        { "id": "d", "text": "Starts the task, which does not begin running until get() is called" }
      ],
      "correct": "c",
      "explanation": "Future.get() is a blocking call — it waits for the specific task behind that Future to finish, then hands back its result. An overload with a timeout is also available if you don't want to block indefinitely."
    }
  ]
}
```

## What's next

`Future.get()` is a blocking way to wait for a result. The next lesson covers `CompletableFuture`, which lets you chain async work without blocking, plus a look at thread-safe collections like `ConcurrentHashMap`.
