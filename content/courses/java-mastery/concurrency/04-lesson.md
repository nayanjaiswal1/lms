---
kind: lesson
id_key: java-mastery/concurrency/completablefuture-concurrent-collections
course: java-mastery
section: concurrency
section_title: "Concurrency"
section_position: 11
title: "CompletableFuture and Concurrent Collections"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
`Future.get()` works, but it's a blocking call — the thread that calls it just sits there waiting. `CompletableFuture` is a richer version of `Future` that lets you describe a *pipeline* of async work — "when this finishes, then do that" — without ever having to block a thread just to chain the next step.

## Chaining work with thenApply

```java
import java.util.concurrent.CompletableFuture;

public class Main {
    public static void main(String[] args) {
        String taskName = "Design database schema";

        CompletableFuture<Integer> estimateHours = CompletableFuture
            .supplyAsync(() -> taskName.length()) // runs async, returns a value
            .thenApply(charCount -> charCount / 3); // transforms the result once it's ready

        int hours = estimateHours.join(); // blocks only here, at the very end, to print
        System.out.println(taskName + " -> estimated " + hours + "h");
    }
}
```

`CompletableFuture.supplyAsync(Supplier<T>)` runs the given supplier on a background thread (by default, the common `ForkJoinPool`) and returns a `CompletableFuture<T>` representing its eventual result. `.thenApply(Function<T, R>)` registers a transformation to run *once that result is available* — it doesn't block the calling thread to do so, it just describes what should happen next. Only `.join()` (or `.get()`) actually blocks, and in this example that block only happens once, right before printing, to keep the final output deterministic.

## Composing multiple async steps with thenCompose

`.thenApply` is for transforming a value. `.thenCompose` is for chaining a step that *itself* returns another `CompletableFuture` — flattening what would otherwise be a `CompletableFuture<CompletableFuture<T>>` into a single `CompletableFuture<T>`:

```java
import java.util.concurrent.CompletableFuture;

public class Main {
    public static void main(String[] args) {
        CompletableFuture<Integer> pipeline = fetchTaskEstimate("Build REST API")
            .thenCompose(hours -> applyTeamMultiplier(hours, 3)); // chains a second async step

        System.out.println("Final person-hours: " + pipeline.join());
    }

    static CompletableFuture<Integer> fetchTaskEstimate(String taskName) {
        return CompletableFuture.supplyAsync(() -> taskName.length() / 3);
    }

    static CompletableFuture<Integer> applyTeamMultiplier(int hours, int teamSize) {
        return CompletableFuture.supplyAsync(() -> hours * teamSize);
    }
}
```

If `applyTeamMultiplier` had instead been called from inside `.thenApply`, the result would be a `CompletableFuture<CompletableFuture<Integer>>` — a future wrapping another future, which is awkward to use. `.thenCompose` unwraps that automatically, which is the same relationship `flatMap` has to `map` on a `Stream` or `Optional`.

## Combining independent futures

`.thenCombine` merges the results of two independent `CompletableFuture`s once both are done:

```java
import java.util.concurrent.CompletableFuture;

public class Main {
    public static void main(String[] args) {
        CompletableFuture<Integer> designEstimate =
            CompletableFuture.supplyAsync(() -> "Design database schema".length() / 3);
        CompletableFuture<Integer> apiEstimate =
            CompletableFuture.supplyAsync(() -> "Build REST API".length() / 3);

        CompletableFuture<Integer> combined = designEstimate.thenCombine(
            apiEstimate,
            (designHours, apiHours) -> designHours + apiHours
        );

        System.out.println("Combined estimate: " + combined.join() + "h");
    }
}
```

Both `designEstimate` and `apiEstimate` can run concurrently on separate background threads; `thenCombine` waits for both and then applies the given function to their two results — a natural fit for TaskFlow scenarios like "fetch two independent estimates, then sum them," without manually managing two `Thread` objects and joining both.

## ConcurrentHashMap vs. a synchronized HashMap

Regular `HashMap` is not thread-safe — concurrent reads and writes from multiple threads can corrupt its internal structure, not just race on a value. One historical fix is `Collections.synchronizedMap(new HashMap<>())`, which wraps every single method call in a lock on the whole map — safe, but it means only one thread can touch the map at all, at any time, even for two unrelated keys.

`ConcurrentHashMap` is built for concurrent access from the ground up: it allows multiple threads to read and write different parts of the map simultaneously, using much finer-grained internal locking instead of one lock for the entire map.

```java
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        Map<String, Integer> taskStatusCounts = new ConcurrentHashMap<>();
        taskStatusCounts.put("DONE", 0);
        taskStatusCounts.put("IN_PROGRESS", 0);
        taskStatusCounts.put("TODO", 0);

        ExecutorService pool = Executors.newFixedThreadPool(4);
        String[] statuses = { "DONE", "IN_PROGRESS", "TODO", "DONE", "DONE", "IN_PROGRESS" };

        for (String status : statuses) {
            pool.submit(() -> taskStatusCounts.merge(status, 1, Integer::sum));
        }

        pool.shutdown();
        pool.awaitTermination(5, TimeUnit.SECONDS);

        // Print in a fixed, known key order so output is deterministic regardless of
        // internal map iteration order (which ConcurrentHashMap does not guarantee).
        System.out.println("DONE: " + taskStatusCounts.get("DONE"));
        System.out.println("IN_PROGRESS: " + taskStatusCounts.get("IN_PROGRESS"));
        System.out.println("TODO: " + taskStatusCounts.get("TODO"));
    }
}
```

`merge(key, 1, Integer::sum)` is itself an atomic operation on `ConcurrentHashMap` — it reads the current value (or uses `1` if absent) and combines it with the new value in one indivisible step, avoiding the exact same read-modify-write race from the previous lesson, but scoped per-key instead of needing a single lock around the whole map. Note the example prints each status by name explicitly, rather than iterating the map — `HashMap` and `ConcurrentHashMap` never guarantee iteration order, so printing via iteration would make the output's line order unpredictable even though the counts themselves are correct.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-completablefuture-concurrent-collections-q1",
      "type": "mcq",
      "prompt": "What is thenCompose for, that thenApply can't do as cleanly?",
      "options": [
        { "id": "a", "text": "thenCompose runs code synchronously instead of on a background thread" },
        { "id": "b", "text": "thenCompose chains a step that itself returns a CompletableFuture, flattening the result instead of nesting one future inside another" },
        { "id": "c", "text": "thenCompose is just a faster alias for thenApply" },
        { "id": "d", "text": "thenCompose can only be used with Callable, not Supplier" }
      ],
      "correct": "b",
      "explanation": "If the next step already returns a CompletableFuture<T>, chaining it with thenApply would produce a nested CompletableFuture<CompletableFuture<T>>. thenCompose flattens that into a single CompletableFuture<T>, the same relationship flatMap has to map."
    },
    {
      "id": "concurrency-completablefuture-concurrent-collections-q2",
      "type": "mcq",
      "prompt": "Why is ConcurrentHashMap generally preferred over Collections.synchronizedMap(new HashMap<>()) under heavy concurrent access?",
      "options": [
        { "id": "a", "text": "synchronizedMap is not actually thread-safe" },
        { "id": "b", "text": "ConcurrentHashMap uses finer-grained internal locking, letting multiple threads operate on different parts of the map at once, instead of one lock guarding the entire map for every operation" },
        { "id": "c", "text": "ConcurrentHashMap guarantees a specific iteration order, synchronizedMap does not" },
        { "id": "d", "text": "There is no meaningful difference between the two" }
      ],
      "correct": "b",
      "explanation": "synchronizedMap wraps every call in one lock on the whole map, serializing all access. ConcurrentHashMap is designed for concurrency internally, allowing much higher throughput when multiple threads touch different keys at once."
    },
    {
      "id": "concurrency-completablefuture-concurrent-collections-q3",
      "type": "mcq",
      "prompt": "In the ConcurrentHashMap example, why does the code print each status count by an explicit key lookup instead of iterating over the map?",
      "options": [
        { "id": "a", "text": "ConcurrentHashMap cannot be iterated at all" },
        { "id": "b", "text": "Map iteration order is not guaranteed, so iterating could print the counts in an unpredictable line order across runs even though the values themselves are correct" },
        { "id": "c", "text": "get() is faster than any form of iteration" },
        { "id": "d", "text": "merge() removes entries after they are read once" }
      ],
      "correct": "b",
      "explanation": "Neither HashMap nor ConcurrentHashMap guarantees a stable iteration order. Looking up each known key explicitly, in a fixed sequence, keeps the printed output deterministic regardless of the map's internal ordering."
    }
  ]
}
```

## What's next

This module's quiz mixes multiple-choice theory with a hands-on coding question that uses an `ExecutorService` internally, then reflects on which concurrency concept felt least intuitive.
