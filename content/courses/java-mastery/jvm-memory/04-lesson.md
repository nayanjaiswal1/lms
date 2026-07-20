---
kind: lesson
id_key: java-mastery/jvm-memory/memory-leaks-and-string-pool
course: java-mastery
section: jvm-memory
section_title: "JVM & Memory Internals"
section_position: 12
title: "Common Memory Leaks in Java, and the String Pool"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Java has a garbage collector, so it seems like "memory leak" shouldn't be a thing that happens — and yet Java programs leak memory constantly in production. The GC only reclaims **unreachable** objects; it has no idea whether you actually still need something you're still holding a reference to. A "Java memory leak" almost always means: code is unintentionally keeping a reference alive long after the object should have been forgotten.

## Leak pattern #1: a static collection that only grows

`static` fields are GC roots — they're reachable for the entire lifetime of the JVM. A static collection that objects get added to but never removed from is one of the most common real-world Java leaks:

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        for (int i = 0; i < 5; i++) {
            TaskCache.recordProcessed(new Task("Task #" + i, i + 1));
        }
        System.out.println("Tasks recorded in cache: " + TaskCache.size());
        // In a real long-running server, this loop runs forever as tasks are processed,
        // and TaskCache.processedTasks grows without bound — a classic unbounded-cache leak.
    }
}

class TaskCache {
    private static final List<Task> processedTasks = new ArrayList<>();

    static void recordProcessed(Task task) {
        processedTasks.add(task); // added forever, never removed — this is the leak
    }

    static int size() {
        return processedTasks.size();
    }
}

class Task {
    private String name;
    private int estimateHours;

    Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }
}
```

Every `Task` ever passed to `recordProcessed` stays reachable through `TaskCache.processedTasks` forever, because it's a `static` field — reachable for the JVM's entire lifetime — and nothing ever removes old entries. In a real server processing thousands of tasks a day, this list grows without bound until the JVM runs out of heap and throws `OutOfMemoryError`. The fix is usually a bounded cache with an eviction policy (size limit, time-to-live) instead of an unbounded `List` — the GC can only reclaim what actually becomes unreachable, and a growing static collection never does.

## Leak pattern #2: unclosed resources

Objects that wrap external resources (files, database connections, network sockets) often hold onto native memory or OS handles that the garbage collector doesn't know how to release on its own — the GC can eventually collect the Java object itself, but that doesn't guarantee the underlying OS-level resource gets freed promptly, or ever, if the object lingers.

```java
import java.io.FileReader;
import java.io.IOException;

public class Main {
    public static void main(String[] args) {
        // Illustrative shape only — no file exists in this sandbox, so this would throw
        // if actually run; the point is the resource-handling pattern.
        readTaskExportLeaky("tasks-export.csv");
        readTaskExportSafely("tasks-export.csv");
    }

    // LEAKY: if an exception happens between open and close, close() is never reached.
    static void readTaskExportLeaky(String path) {
        try {
            FileReader reader = new FileReader(path);
            // ... read the file ...
            reader.close();
        } catch (IOException e) {
            // reader was never closed if the exception happened after opening it
        }
    }

    // SAFE: try-with-resources guarantees close() runs, even if an exception is thrown.
    static void readTaskExportSafely(String path) {
        try (FileReader reader = new FileReader(path)) {
            // ... read the file ...
        } catch (IOException e) {
            // reader.close() has already been called automatically by this point
        }
    }
}
```

`try-with-resources` (any resource implementing `AutoCloseable`, which includes `FileReader`, database `Connection`s, and sockets) guarantees `close()` runs when the block exits — normally or via an exception — which is why it's the standard, "day one" way to handle any closeable resource in modern Java, not an optional nicety.

## The string constant pool and .intern()

String literals get special treatment for memory efficiency: the JVM maintains a **string constant pool**, a cache of unique `String` values, so that identical string literals across your whole program share the exact same object instead of each being a separate allocation.

```java
public class Main {
    public static void main(String[] args) {
        String a = "Design database schema"; // literal — goes into (or reuses from) the pool
        String b = "Design database schema"; // same literal — reuses the exact same pooled object
        String c = new String("Design database schema"); // new String() forces a fresh heap object

        System.out.println("a == b: " + (a == b));               // true — same pooled reference
        System.out.println("a == c: " + (a == c));               // false — c is a distinct heap object
        System.out.println("a.equals(c): " + a.equals(c));       // true — same content

        String d = c.intern(); // returns the pooled instance for this content
        System.out.println("a == d: " + (a == d));               // true — d now points at the pooled string
    }
}
```

`==` on objects compares **references** (are these the same object?), while `.equals()` compares **content** (do these represent the same value?) — this is the single most common `String` bug for anyone new to Java, and it's exactly why this course has consistently used `.equals()` for string comparisons throughout. String literals (`"..."`) are automatically pooled and compare `==`-equal when identical; `new String(...)` deliberately bypasses the pool to create a distinct object, even with identical content. `.intern()` looks up (or adds) the equivalent pooled string and returns that shared reference — it's rarely needed in everyday TaskFlow code, but it's useful when you're deduplicating a large number of repeated string values (e.g. thousands of `Task` objects that all share a small set of status strings) and want them to share memory instead of each holding its own copy.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jvm-memory-memory-leaks-and-string-pool-q1",
      "type": "mcq",
      "prompt": "Why can a static List that objects are only ever added to cause a memory leak, despite Java having a garbage collector?",
      "options": [
        { "id": "a", "text": "static fields are exempt from garbage collection entirely, as a JVM bug" },
        { "id": "b", "text": "static fields are reachable for the entire lifetime of the JVM, so every object added to the list stays reachable — and therefore un-collectible — forever, since nothing removes them" },
        { "id": "c", "text": "ArrayList objects are always garbage collected immediately regardless of references" },
        { "id": "d", "text": "It can't — static collections are always safe" }
      ],
      "correct": "b",
      "explanation": "The GC only reclaims unreachable objects. A static field is reachable as long as the JVM is running, so anything only ever added to (never removed from) a static collection is kept alive indefinitely — a classic real-world leak, even with automatic GC."
    },
    {
      "id": "jvm-memory-memory-leaks-and-string-pool-q2",
      "type": "mcq",
      "prompt": "Why is try-with-resources preferred over manually calling close() at the end of a try block?",
      "options": [
        { "id": "a", "text": "It runs faster than a manual close() call" },
        { "id": "b", "text": "It guarantees close() is called even if an exception is thrown partway through the block, whereas a manual close() at the end of the try body can be skipped entirely if an exception occurs first" },
        { "id": "c", "text": "It removes the need to handle IOException at all" },
        { "id": "d", "text": "It's purely a stylistic preference with no functional difference" }
      ],
      "correct": "b",
      "explanation": "A manual close() placed at the end of a try block is never reached if an earlier line throws — leaving the resource open. try-with-resources calls close() automatically on the way out of the block regardless of how it exits."
    },
    {
      "id": "jvm-memory-memory-leaks-and-string-pool-q3",
      "type": "mcq",
      "prompt": "Given String a = \"X\"; String b = new String(\"X\");, what does a == b evaluate to, and why?",
      "options": [
        { "id": "a", "text": "true, because both hold the text \"X\"" },
        { "id": "b", "text": "false — new String(\"X\") deliberately creates a distinct heap object outside the string constant pool, even though its content equals the pooled literal" },
        { "id": "c", "text": "It throws a compile error" },
        { "id": "d", "text": "true, because Java automatically interns every String" }
      ],
      "correct": "b",
      "explanation": "== compares references, not content. String literals are pooled and share one instance, but new String(...) explicitly allocates a fresh object — so a == b is false even though a.equals(b) is true."
    }
  ]
}
```

## What's next

That closes out JVM and memory internals. The next module moves to **JDBC** — how Java programs talk to a relational database like the one backing TaskFlow itself.
