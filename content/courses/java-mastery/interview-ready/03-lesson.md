---
kind: lesson
id_key: java-mastery/interview-ready/concurrency-jvm-theory
course: java-mastery
section: interview-ready
section_title: "Interview Ready"
section_position: 18
title: "Concurrency & JVM Theory"
position: 2
estimated_minutes: 35
source: [java-mastery-curriculum.md]
---
Concurrency and JVM internals questions have a reputation for being the hardest part of a Java interview, mostly because they're the topics people learn by copying a pattern (`synchronized` this, `ExecutorService` that) without ever building the mental model underneath. This lesson builds that model, still grounded in TaskFlow.

## What makes a race condition, restated precisely

You built and fixed a real one in the concurrency module: two threads both running `count++` on TaskFlow's shared completion counter, with one increment silently lost. The precise definition an interviewer wants: a race condition requires **shared mutable state**, **at least one thread writing to it**, and **no synchronization enforcing a consistent order** between the operations — the outcome then depends on timing the program doesn't control or guarantee. All three conditions have to hold; remove any one (make the state immutable, make it thread-local instead of shared, or add synchronization that fixes an order) and the race disappears. Interviewers often follow up with "is reading shared state without writing to it ever a race condition?" — the answer is no by this definition, but it can still be a **visibility** problem, which is the volatile/synchronized distinction below.

## Deadlock: four necessary conditions

A deadlock is what happens when two or more threads each hold a resource the other needs, and neither will ever release what it's holding. Unlike a race condition (wrong *result*), a deadlock is a **complete halt** — the threads involved are stuck forever, not just producing bad data.

Computer science names four conditions that must **all** be true simultaneously for deadlock to be possible (this is the standard interview answer — know all four by name):

1. **Mutual exclusion** — a resource can only be held by one thread at a time (true of any `synchronized` lock).
2. **Hold and wait** — a thread holds at least one resource while waiting to acquire another.
3. **No preemption** — a resource can't be forcibly taken away from the thread holding it; it must be released voluntarily.
4. **Circular wait** — a cycle of threads exists where each is waiting on a resource held by the next one in the cycle.

The classic concrete example — two TaskFlow objects, `Task` and `Project`, each with their own lock, acquired in **opposite order** by two different threads:

```text
Thread A:                          Thread B:
synchronized (task.lock) {         synchronized (project.lock) {
    // ... do work ...                  // ... do work ...
    synchronized (project.lock) {       synchronized (task.lock) {
        // never reached                    // never reached
    }                                   }
}                                   }
```

This is deliberately shown as illustrative pseudocode, not a runnable Java program — actually executing this shape would hang forever by design, which is exactly the bug being demonstrated: Thread A acquires `task.lock` and then waits for `project.lock`; Thread B, running at the same time, has already acquired `project.lock` and is now waiting for `task.lock`. Neither will ever get what it's waiting for — a circular wait, satisfying all four conditions at once.

The standard fix — and the one interviewers want to hear — is breaking the **circular wait** condition, usually the easiest of the four to attack directly: establish a single, consistent global ordering for lock acquisition (e.g., "always lock the object with the lower ID first") so it becomes structurally impossible for two threads to be waiting on each other in a cycle. This runnable example shows that fix using `ReentrantLock.tryLock(timeout)` as a defensive belt-and-suspenders measure on top of consistent ordering — `tryLock` gives up and backs off instead of waiting forever, which is itself a common real-world deadlock-avoidance technique when strict ordering isn't practical to enforce everywhere:

```java
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;

public class Main {
    static final ReentrantLock taskLock = new ReentrantLock();
    static final ReentrantLock projectLock = new ReentrantLock();

    // Both threads acquire in the SAME order (taskLock, then projectLock) —
    // this alone eliminates the circular wait that causes deadlock.
    static boolean linkTaskToProject(String label) throws InterruptedException {
        if (taskLock.tryLock(1, TimeUnit.SECONDS)) {
            try {
                if (projectLock.tryLock(1, TimeUnit.SECONDS)) {
                    try {
                        return true; // both locks acquired safely
                    } finally {
                        projectLock.unlock();
                    }
                }
            } finally {
                taskLock.unlock();
            }
        }
        return false;
    }

    public static void main(String[] args) throws InterruptedException {
        Thread t1 = new Thread(() -> {
            try {
                boolean linked = linkTaskToProject("t1");
                System.out.println("t1 linked: " + linked);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        Thread t2 = new Thread(() -> {
            try {
                boolean linked = linkTaskToProject("t2");
                System.out.println("t2 linked: " + linked);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        t1.start();
        t2.start();
        t1.join();
        t2.join();
        System.out.println("Done — consistent lock ordering avoided deadlock.");
    }
}
```

Both threads always try `taskLock` first and `projectLock` second, so there's no possible interleaving where one thread holds `projectLock` while waiting on `taskLock` — the circular-wait condition simply cannot arise, and the program always finishes.

## `volatile` vs. `synchronized`: visibility vs. atomicity

These solve two genuinely different problems, and confusing them is one of the most common intermediate-level Java mistakes.

- **`volatile`** guarantees **visibility only**: a write to a `volatile` field by one thread is guaranteed to be immediately visible to every other thread's subsequent read, bypassing per-CPU-core caching that could otherwise let one thread keep reading a stale, cached value indefinitely. `volatile` does **not** make compound operations (`count++`, `if (x == null) x = new Thing()`) atomic — a `volatile int` can still lose updates to the exact race condition described above, because `count++` is still three separate steps.
- **`synchronized`** guarantees **both**: mutual exclusion (only one thread executes the block at a time — atomicity for whatever's inside) *and* visibility (entering/exiting a synchronized block also establishes the same kind of memory barrier `volatile` does, so changes made inside are guaranteed visible to the next thread that enters).

The practical rule: use `volatile` for a simple flag or status field that's only ever **read** by other threads and **written** by one (a `stopRequested` flag is the textbook case) — no compound read-modify-write happens on it. Reach for `synchronized` (or `java.util.concurrent` types like `AtomicInteger`) the moment more than one thread needs to both read and write the same field, or when multiple fields need to stay consistent with each other.

```java
public class Main {
    // volatile: writes from main are guaranteed visible to worker without any lock.
    static volatile boolean stopRequested = false;

    public static void main(String[] args) throws InterruptedException {
        Thread worker = new Thread(() -> {
            long iterations = 0;
            // Bounded by a max, as a safety net — but stopRequested being volatile
            // means the loop reliably exits as soon as main sets it, not "eventually maybe."
            while (!stopRequested && iterations < 50_000_000L) {
                iterations++;
            }
            System.out.println("Worker stopped after seeing the flag (iterations bounded).");
        });

        worker.start();
        Thread.sleep(20); // let the worker spin briefly
        stopRequested = true; // this write is guaranteed visible to worker's next read
        worker.join();

        System.out.println("Main done.");
    }
}
```

## Stack vs. heap, revisited at interview depth

You've seen the basic split: primitives and object *references* live on the stack, objects themselves live on the heap. The interview-depth version adds the concurrency angle and the failure modes:

- **The stack is per-thread.** Every thread gets its own stack, holding a frame per active method call — local variables, method parameters, and the return address. This is exactly why thread-local data (a loop counter, a local `Task` reference variable) needs no synchronization: no other thread can even see another thread's stack.
- **The heap is shared across all threads.** Every `new Task(...)` lives on one shared heap, reachable by any thread that has a reference to it — which is precisely why heap-resident, shared, mutable state is where every race condition and visibility bug in this lesson actually happens. Stack-local data can't race with anything.
- **Failure modes differ correspondingly.** Recursing too deeply (or infinitely) exhausts a thread's stack and throws `StackOverflowError`. Allocating too many long-lived objects that can't be garbage collected exhausts the heap and throws `OutOfMemoryError`. Seeing one versus the other in a stack trace immediately tells you which side of the split to investigate.

## What garbage collection roots are

The JVM's garbage collector doesn't ask "is this object unused" — it asks "is this object **reachable**" starting from a fixed set of **GC roots**: references the JVM knows are definitely still "live" without needing to trace anything else first. GC roots typically include:

- Local variables and parameters currently on any thread's stack (an active method's `Task task = ...` local variable).
- Active `Thread` objects themselves.
- `static` fields on loaded classes (they live for the lifetime of the class, effectively always reachable).
- JNI references held by native code.

The collector walks outward from every root, marking everything reachable through a chain of references as **live**. Anything left unmarked afterward — unreachable from any root, by any path — is garbage, regardless of whether it was expensive to build or was "in use" a moment ago. This is why a common memory leak pattern in long-running Java services is an ever-growing `static` collection (a `static Map` that entries get added to but never removed from): every entry stays reachable forever through that static root, so the GC correctly, faithfully never collects any of it — the leak isn't a GC bug, it's a reachability fact the GC is honoring exactly as designed.

## Why String concatenation in a loop is a performance smell

This ties directly back to the immutability lesson: every `+` or `+=` on a `String` doesn't mutate anything — it allocates a **brand-new** `String` containing the combined characters, because the original can't be changed. Do this inside a loop and each iteration allocates a new, slightly-longer string, copying all the previous characters over again:

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design schema", "Build API", "Write tests", "Deploy", "Monitor" };

        // Anti-pattern: each += allocates a whole new String, recopying everything so far.
        String badReport = "";
        for (String name : taskNames) {
            badReport += name + ", "; // O(n) work per iteration -> O(n^2) total for n tasks
        }

        // Fix: StringBuilder mutates an internal, resizable buffer in place.
        StringBuilder goodReport = new StringBuilder();
        for (String name : taskNames) {
            goodReport.append(name).append(", "); // O(1) amortized per append
        }

        System.out.println(badReport);
        System.out.println(goodReport);
    }
}
```

For `n` names, the `+=` version does roughly `1 + 2 + 3 + ... + n` characters worth of copying — O(n²) total — because each new string re-copies every character built so far. `StringBuilder` holds a single mutable, resizable `char`/`byte` buffer internally and only allocates a new backing array when it actually needs to grow, giving O(n) total work for the same loop. For a handful of iterations the difference is invisible; for a report built over thousands of `Task` names, it's the difference between a snappy response and a visible slowdown — and it's a direct, mechanical consequence of `String` immutability, not an unrelated JVM quirk.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-concurrency-jvm-theory-q1",
      "type": "mcq",
      "prompt": "Which four conditions must all hold simultaneously for deadlock to be possible?",
      "options": [
        { "id": "a", "text": "High CPU usage, many threads, large heap, slow disk" },
        { "id": "b", "text": "Mutual exclusion, hold and wait, no preemption, circular wait" },
        { "id": "c", "text": "Race condition, visibility failure, memory leak, stack overflow" },
        { "id": "d", "text": "Atomicity, consistency, isolation, durability" }
      ],
      "correct": "b",
      "explanation": "The four Coffman conditions — mutual exclusion, hold and wait, no preemption, and circular wait — must all be true at once for deadlock to occur. Breaking any single one (most commonly circular wait, via consistent lock ordering) prevents it."
    },
    {
      "id": "interview-ready-concurrency-jvm-theory-q2",
      "type": "mcq",
      "prompt": "Why does making a field volatile NOT fix a race condition on count++?",
      "options": [
        { "id": "a", "text": "volatile only guarantees visibility of writes across threads — it does not make the three-step read-modify-write of ++ atomic" },
        { "id": "b", "text": "volatile fields cannot be incremented at all" },
        { "id": "c", "text": "volatile is identical to synchronized and should fix it, but doesn't due to a JVM bug" },
        { "id": "d", "text": "volatile only works on object references, not primitives like int" }
      ],
      "correct": "a",
      "explanation": "volatile guarantees that writes are immediately visible to other threads' reads, but it does not make compound operations atomic. count++ is still a separate read, modify, and write, so two threads can still interleave and lose an update even with volatile."
    },
    {
      "id": "interview-ready-concurrency-jvm-theory-q3",
      "type": "mcq",
      "prompt": "Which of these is typically considered a GC root?",
      "options": [
        { "id": "a", "text": "Every object ever allocated on the heap" },
        { "id": "b", "text": "A local variable currently on an active thread's stack" },
        { "id": "c", "text": "Any object with a low hashCode()" },
        { "id": "d", "text": "Objects stored in a HashMap" }
      ],
      "correct": "b",
      "explanation": "GC roots are references the JVM treats as inherently live without needing further justification: active threads' stack locals, static fields, active Thread objects, and JNI references. The GC then marks everything transitively reachable from those roots as live."
    },
    {
      "id": "interview-ready-concurrency-jvm-theory-q4",
      "type": "mcq",
      "prompt": "Why is String concatenation with += inside a loop an O(n^2) performance smell?",
      "options": [
        { "id": "a", "text": "Because String is thread-safe and every += acquires a lock" },
        { "id": "b", "text": "Because each += allocates a new String and copies all previously-accumulated characters again, since Strings are immutable" },
        { "id": "c", "text": "Because the JVM interprets += as a method call with high overhead" },
        { "id": "d", "text": "It isn't a real performance concern in modern Java" }
      ],
      "correct": "b",
      "explanation": "Every += on a String produces a brand-new String object holding the combined characters, re-copying everything accumulated so far — n iterations of growing copies sum to O(n^2) total work. StringBuilder avoids this by mutating one resizable buffer in place."
    }
  ]
}
```

## What's next

Next: design principles and modern Java at interview depth — SOLID with concrete violation-and-fix examples, composition vs. inheritance, and when records and functional interfaces are (and aren't) the right tool.
