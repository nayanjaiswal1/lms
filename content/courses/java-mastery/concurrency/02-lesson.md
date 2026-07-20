---
kind: lesson
id_key: java-mastery/concurrency/synchronized-and-race-conditions
course: java-mastery
section: concurrency
section_title: "Concurrency"
section_position: 11
title: "synchronized and Race Conditions"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
The previous lesson's example avoided a whole category of bug by having each thread write only to its own array slot. Real TaskFlow code isn't always that lucky — sometimes multiple threads genuinely need to update the *same* shared value, like a running counter of how many tasks a batch job has completed so far. That's where **race conditions** come from, and where `synchronized` earns its keep.

## What a race condition actually is

A race condition happens when two or more threads access shared mutable state, at least one of them writes to it, and the final result depends on the unpredictable timing of how their operations interleave. The classic example is `count++`. It looks like a single atomic operation, but it's actually three separate steps at the instruction level:

1. **Read** the current value of `count` from memory.
2. **Modify** it — compute `current value + 1`.
3. **Write** the new value back to memory.

If two threads both execute `count++` at "the same time," the CPU can interleave their three steps. Imagine `count` starts at 5:

- Thread A reads `count` (5).
- Thread B reads `count` (5) — before A has written anything back.
- Thread A computes `5 + 1 = 6` and writes `6`.
- Thread B computes `5 + 1 = 6` (using the stale value it read) and writes `6`.

Two increments happened, but `count` only went from 5 to 6 instead of 7 — one update was silently lost. This is exactly the kind of bug that's maddening in production: it doesn't happen every time, only under the "wrong" timing, so it can pass every manual test and still corrupt data under real concurrent load.

## Demonstrating the race condition

```java
public class Main {
    public static void main(String[] args) throws InterruptedException {
        Counter counter = new Counter();
        int incrementsPerThread = 100_000;

        Runnable incrementTask = () -> {
            for (int i = 0; i < incrementsPerThread; i++) {
                counter.incrementUnsafe();
            }
        };

        Thread t1 = new Thread(incrementTask);
        Thread t2 = new Thread(incrementTask);
        t1.start();
        t2.start();
        t1.join();
        t2.join();

        int expected = incrementsPerThread * 2;
        System.out.println("Expected: " + expected);
        System.out.println("Actual is less than or equal to expected: " + (counter.getCount() <= expected));
    }
}

class Counter {
    private int count = 0;

    void incrementUnsafe() {
        count++; // read-modify-write, NOT atomic — this is the race
    }

    int getCount() {
        return count;
    }
}
```

Notice this example doesn't print `counter.getCount()` directly — the whole point is that its exact value is *not* deterministic (it will typically be some number less than 200,000, but exactly how much less varies run to run and machine to machine). Instead it prints a comparison (`<= expected`) that is always `true` regardless of how badly the race lost updates, keeping the visible output identical on every run while still demonstrating that the race exists.

## Fixing it with synchronized

The `synchronized` keyword makes a block of code (or an entire method) **mutually exclusive**: only one thread can be executing inside a `synchronized` block guarded by a given object's lock at any moment. Every Java object has an intrinsic lock (also called a monitor) built in; `synchronized` acquires and releases it automatically.

```java
public class Main {
    public static void main(String[] args) throws InterruptedException {
        SafeCounter counter = new SafeCounter();
        int incrementsPerThread = 100_000;

        Runnable incrementTask = () -> {
            for (int i = 0; i < incrementsPerThread; i++) {
                counter.incrementSafe();
            }
        };

        Thread t1 = new Thread(incrementTask);
        Thread t2 = new Thread(incrementTask);
        t1.start();
        t2.start();
        t1.join();
        t2.join();

        System.out.println("Final count: " + counter.getCount()); // always exactly 200000
    }
}

class SafeCounter {
    private int count = 0;

    synchronized void incrementSafe() {
        count++; // only one thread executes this at a time
    }

    synchronized int getCount() {
        return count;
    }
}
```

With `incrementSafe()` declared `synchronized`, each call to `count++` fully completes (read, modify, write) before another thread is allowed to enter the method — the three-step race from before can no longer interleave. This version reliably prints `200000` every single time, because the lock forces the two threads' increments to happen one after another rather than overlapping. `getCount()` is also synchronized so a reader can't observe a half-written value, though for a single `int` field that specific case is less of a concern than for larger, multi-field state.

## synchronized blocks vs. synchronized methods

You don't have to synchronize an entire method — a `synchronized (someObject) { ... }` block locks on just the critical section, which can be narrower and more efficient if a method does other work that doesn't touch shared state:

```java
public class Main {
    public static void main(String[] args) throws InterruptedException {
        TaskFlowStats stats = new TaskFlowStats();

        Runnable recordTask = () -> {
            for (int i = 0; i < 1000; i++) {
                stats.recordCompletion(2); // 2 hours per completed task
            }
        };

        Thread t1 = new Thread(recordTask);
        Thread t2 = new Thread(recordTask);
        t1.start();
        t2.start();
        t1.join();
        t2.join();

        System.out.println("Completed: " + stats.getCompletedCount());
        System.out.println("Total hours: " + stats.getTotalHours());
    }
}

class TaskFlowStats {
    private final Object lock = new Object();
    private int completedCount = 0;
    private int totalHours = 0;

    void recordCompletion(int hours) {
        synchronized (lock) {
            completedCount++;
            totalHours += hours;
        }
    }

    int getCompletedCount() {
        synchronized (lock) {
            return completedCount;
        }
    }

    int getTotalHours() {
        synchronized (lock) {
            return totalHours;
        }
    }
}
```

Using a dedicated private `lock` object (rather than `this`) is a common defensive pattern: it guarantees nothing outside the class can accidentally synchronize on the same lock and create unexpected contention or deadlocks. Both `completedCount` and `totalHours` are updated together inside the same `synchronized` block, so a reader thread never sees one field updated without the other — that's the real value of grouping related state under one lock.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-synchronized-and-race-conditions-q1",
      "type": "mcq",
      "prompt": "Why is count++ not atomic even though it looks like a single operation?",
      "options": [
        { "id": "a", "text": "It's actually three separate steps — read the current value, compute the increment, write the new value back — and another thread can interleave between them" },
        { "id": "b", "text": "Because int is not a primitive type in Java" },
        { "id": "c", "text": "It is atomic; race conditions on count++ are a myth" },
        { "id": "d", "text": "Because ++ always triggers a full garbage collection cycle" }
      ],
      "correct": "a",
      "explanation": "count++ compiles to a read, a modify, and a write. Without synchronization, two threads can both read the same stale value before either writes back, silently losing one of the two increments."
    },
    {
      "id": "concurrency-synchronized-and-race-conditions-q2",
      "type": "mcq",
      "prompt": "What does declaring a method synchronized guarantee?",
      "options": [
        { "id": "a", "text": "The method will run faster because the JVM optimizes it" },
        { "id": "b", "text": "Only one thread at a time can be executing inside that method on a given object's lock, so its operations can't interleave with another thread's call to a method synchronized on the same lock" },
        { "id": "c", "text": "The method's return value is cached across calls" },
        { "id": "d", "text": "The method can no longer throw exceptions" }
      ],
      "correct": "b",
      "explanation": "synchronized enforces mutual exclusion on the associated lock (an object's intrinsic monitor by default). Other threads trying to enter a block synchronized on the same lock must wait until the current thread exits it."
    },
    {
      "id": "concurrency-synchronized-and-race-conditions-q3",
      "type": "mcq",
      "prompt": "Why might a class use a dedicated private Object lock field instead of synchronizing on `this`?",
      "options": [
        { "id": "a", "text": "synchronized(this) is a compile error" },
        { "id": "b", "text": "A private lock object guarantees no external code can accidentally synchronize on the same lock, avoiding unexpected contention or deadlocks from outside the class" },
        { "id": "c", "text": "Private lock objects execute faster than synchronizing on this" },
        { "id": "d", "text": "It has no practical difference; it's purely stylistic" }
      ],
      "correct": "b",
      "explanation": "this is publicly reachable by anyone with a reference to the object, so external code could synchronize on it too, creating surprising coupling. A private lock field is only ever visible to the class itself."
    }
  ]
}
```

## What's next

Manually creating and synchronizing raw threads doesn't scale past a handful of tasks. The next lesson introduces `ExecutorService`, a managed thread pool that TaskFlow can submit jobs to instead.
