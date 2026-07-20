---
kind: lesson
id_key: java-mastery/exceptions/try-with-resources
course: java-mastery
section: exceptions
section_title: "Exceptions"
section_position: 6
title: "try-with-resources"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
The previous lesson showed `finally` guaranteeing cleanup code runs. The single most common thing that cleanup does is **close a resource** — a file, a network connection, a database cursor. That pattern is so common Java has dedicated syntax for it: `try-with-resources`.

## The manual way: try/finally

```java
import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner scanner = new Scanner("Design schema\n6.0\nHigh");
        try {
            String taskName = scanner.nextLine();
            double hours = Double.parseDouble(scanner.nextLine());
            String priority = scanner.nextLine();
            System.out.println(taskName + " — " + hours + "h — " + priority);
        } finally {
            scanner.close(); // must remember to do this, in every exit path
        }
    }
}
```

This works, but it has a real weakness: **every** resource that needs cleanup requires its own hand-written `try/finally`, and it's easy to forget — especially with multiple resources opened in sequence, where the second resource's `try/finally` has to nest inside the first's. Forgetting to close a resource is a classic source of production leaks: file handles or database connections that slowly exhaust a limited pool.

## The automatic way: try-with-resources

```java
import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        try (Scanner scanner = new Scanner("Design schema\n6.0\nHigh")) {
            String taskName = scanner.nextLine();
            double hours = Double.parseDouble(scanner.nextLine());
            String priority = scanner.nextLine();
            System.out.println(taskName + " — " + hours + "h — " + priority);
        } // scanner.close() is called automatically here, even if an exception was thrown
    }
}
```

Anything declared inside the parentheses after `try` is automatically closed when the block exits — normally or via an exception — with no `finally` needed. This works for any type implementing the `AutoCloseable` interface (which `Scanner`, file streams, and database connections all do). Multiple resources can be declared in the same parentheses, separated by semicolons, and they close in reverse declaration order.

## Why it exists: making your own `AutoCloseable`

```java
public class Main {
    static class TaskLock implements AutoCloseable {
        private final String taskName;

        TaskLock(String taskName) {
            this.taskName = taskName;
            System.out.println("Locked: " + taskName);
        }

        void doWork() {
            System.out.println("Working on: " + taskName);
        }

        @Override
        public void close() {
            System.out.println("Unlocked: " + taskName);
        }
    }

    public static void main(String[] args) {
        try (TaskLock lock = new TaskLock("Build REST API")) {
            lock.doWork();
            throw new RuntimeException("something went wrong mid-task");
        } catch (RuntimeException e) {
            System.out.println("Caught: " + e.getMessage());
        }
        // Output order proves close() ran before the catch block's println finished up:
        // Locked: Build REST API
        // Working on: Build REST API
        // Unlocked: Build REST API
        // Caught: something went wrong mid-task
    }
}
```

Implementing `AutoCloseable` requires exactly one method: `close()`. Once a class implements it, any `try (TaskLock lock = ...)` guarantees `close()` runs — here, `"Unlocked: ..."` prints even though the `try` block threw an exception, because `close()` runs as the block unwinds, *before* control reaches the matching `catch`. This is the pattern behind TaskFlow modeling anything that needs a guaranteed release step — a lock, a temporary hold on a shared resource, a session.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-try-with-resources-q1",
      "type": "mcq",
      "prompt": "What interface must a class implement to be usable in a try-with-resources statement?",
      "options": [
        { "id": "a", "text": "Closeable only, AutoCloseable doesn't work" },
        { "id": "b", "text": "AutoCloseable (which declares a close() method)" },
        { "id": "c", "text": "Runnable" },
        { "id": "d", "text": "Any class works automatically, no interface needed" }
      ],
      "correct": "b",
      "explanation": "Try-with-resources works with any type implementing AutoCloseable (Closeable, used by I/O classes, extends it). The compiler calls close() automatically when the try block exits."
    },
    {
      "id": "exceptions-try-with-resources-q2",
      "type": "mcq",
      "prompt": "In try (Resource r = ...) { ... }, when is r.close() called if the block throws an exception?",
      "options": [
        { "id": "a", "text": "It's never called if an exception is thrown" },
        { "id": "b", "text": "It's called automatically as the block unwinds, before any surrounding catch block runs" },
        { "id": "c", "text": "Only if you also add an explicit finally block" },
        { "id": "d", "text": "It's called, but only after the whole program exits" }
      ],
      "correct": "b",
      "explanation": "Try-with-resources guarantees close() runs as part of unwinding the try block — whether it completed normally or threw — before control reaches any enclosing catch."
    },
    {
      "id": "exceptions-try-with-resources-q3",
      "type": "mcq",
      "prompt": "What is the main advantage of try-with-resources over manual try/finally cleanup?",
      "options": [
        { "id": "a", "text": "It runs faster at the CPU level" },
        { "id": "b", "text": "It removes the need to remember to write cleanup code by hand for every exit path, reducing the chance of a leaked resource" },
        { "id": "c", "text": "It allows skipping exception handling entirely" },
        { "id": "d", "text": "It only works with Scanner" }
      ],
      "correct": "b",
      "explanation": "Try-with-resources shifts the burden of calling close() from the developer (who might forget it in some exit path) to the compiler, which guarantees it for every resource declared in the try's parentheses."
    }
  ]
}
```

## What's next

You've handled built-in exceptions like `IllegalArgumentException` and `IOException`. The next lesson covers writing your **own** exception types — tailored to TaskFlow's own error conditions — and chaining a lower-level cause into a higher-level one.
