---
kind: lesson
id_key: java-mastery/exceptions/try-catch-finally
course: java-mastery
section: exceptions
section_title: "Exceptions"
section_position: 6
title: "Checked vs. Unchecked Exceptions & try/catch/finally"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every program eventually meets bad input, a missing file, or a network failure. Java's answer is **exceptions**: objects that represent something going wrong, thrown at the point of failure and caught wherever it's handled — instead of every function returning an error code that callers might forget to check.

## Throwing an exception

```java
public class Main {
    static double createTaskEstimate(String taskName, double hours) {
        if (hours < 0) {
            throw new IllegalArgumentException("Estimate hours cannot be negative: " + hours);
        }
        return hours;
    }

    public static void main(String[] args) {
        double estimate = createTaskEstimate("Build REST API", -3.0);
        System.out.println("Estimate: " + estimate); // never reached
    }
}
```

`throw new IllegalArgumentException(...)` immediately stops normal execution and starts unwinding the call stack, looking for a `catch` block that can handle it. If nothing catches it, the JVM prints a stack trace and the program terminates. Run this as-is and you'll see exactly that — an uncaught exception crashing the program. The next example fixes it.

## Catching with try/catch

```java
public class Main {
    static double createTaskEstimate(String taskName, double hours) {
        if (hours < 0) {
            throw new IllegalArgumentException("Estimate hours cannot be negative: " + hours);
        }
        return hours;
    }

    public static void main(String[] args) {
        try {
            double estimate = createTaskEstimate("Build REST API", -3.0);
            System.out.println("Estimate: " + estimate);
        } catch (IllegalArgumentException e) {
            System.out.println("Rejected task: " + e.getMessage());
        }

        System.out.println("Program continues normally.");
    }
}
```

Code that might throw goes inside `try { }`. `catch (IllegalArgumentException e)` only runs if that specific exception type (or a subtype of it) is thrown inside the `try` block — `e` is the exception object itself, and `e.getMessage()` returns the string passed to its constructor. Once the `catch` block finishes, execution continues normally after the whole try/catch, which is why the final `println` still runs.

## Checked vs. unchecked exceptions

Java splits exceptions into two families, and the difference is enforced by the compiler:

| | Checked | Unchecked |
|---|---|---|
| Base class | `Exception` (not `RuntimeException`) | `RuntimeException` |
| Compiler enforcement | Must be caught or declared with `throws` | No such requirement |
| Examples | `IOException`, `SQLException` | `IllegalArgumentException`, `NullPointerException`, `ArrayIndexOutOfBoundsException` |
| Represents | Recoverable conditions external to the program (a missing file, a network drop) | Programming errors or invalid arguments — usually bugs |

```java
import java.io.IOException;

public class Main {
    // Declaring "throws IOException" is required for a checked exception
    // if this method doesn't catch it itself.
    static void riskyRead() throws IOException {
        throw new IOException("simulated read failure");
    }

    public static void main(String[] args) {
        try {
            riskyRead();
        } catch (IOException e) {
            System.out.println("Handled checked exception: " + e.getMessage());
        }

        // IllegalArgumentException is unchecked — no "throws" declaration needed anywhere.
        try {
            throw new IllegalArgumentException("bad input");
        } catch (IllegalArgumentException e) {
            System.out.println("Handled unchecked exception: " + e.getMessage());
        }
    }
}
```

If `riskyRead()` didn't catch its `IOException` and `main` didn't declare `throws IOException` or catch it, the code simply would not compile — that's what "checked" means: the compiler checks that you've dealt with it somehow. Unchecked exceptions carry no such obligation, which is why `IllegalArgumentException` needs no `throws` clause anywhere in this example.

## What `finally` guarantees

```java
public class Main {
    static double createTaskEstimate(double hours) {
        if (hours < 0) {
            throw new IllegalArgumentException("Estimate hours cannot be negative: " + hours);
        }
        return hours;
    }

    public static void main(String[] args) {
        try {
            System.out.println("Attempting to create task...");
            createTaskEstimate(-5.0);
        } catch (IllegalArgumentException e) {
            System.out.println("Caught: " + e.getMessage());
        } finally {
            System.out.println("Cleanup: this always runs, exception or not.");
        }

        System.out.println("Done.");
    }
}
```

`finally` runs **no matter what** — whether the `try` block completes normally, throws an exception that gets caught, or even throws one that *isn't* caught (in which case `finally` still runs before the exception propagates further up). It's the place for cleanup that must happen either way: closing a file, releasing a lock, logging that an operation finished. The next lesson covers `try-with-resources`, which automates the most common use of `finally` — closing a resource.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-try-catch-finally-q1",
      "type": "mcq",
      "prompt": "What distinguishes a checked exception from an unchecked one?",
      "options": [
        { "id": "a", "text": "Checked exceptions are faster to throw" },
        { "id": "b", "text": "The compiler requires checked exceptions to be caught or declared with throws; unchecked exceptions have no such requirement" },
        { "id": "c", "text": "Unchecked exceptions cannot be caught at all" },
        { "id": "d", "text": "There is no real difference in modern Java" }
      ],
      "correct": "b",
      "explanation": "Checked exceptions (subclasses of Exception, not RuntimeException) must be either caught or declared in a throws clause, or the code won't compile. Unchecked exceptions (RuntimeException subclasses) carry no such compiler-enforced obligation."
    },
    {
      "id": "exceptions-try-catch-finally-q2",
      "type": "mcq",
      "prompt": "In a try/catch/finally block, when does the finally block run?",
      "options": [
        { "id": "a", "text": "Only if no exception was thrown" },
        { "id": "b", "text": "Only if an exception was caught" },
        { "id": "c", "text": "Always — whether the try succeeds, an exception is caught, or an exception propagates uncaught" },
        { "id": "d", "text": "Only if the catch block itself throws" }
      ],
      "correct": "c",
      "explanation": "finally is guaranteed to run in every case: normal completion, a caught exception, or even an uncaught one (it runs before the exception continues propagating up the call stack)."
    },
    {
      "id": "exceptions-try-catch-finally-q3",
      "type": "mcq",
      "prompt": "Which of these is an unchecked exception?",
      "options": [
        { "id": "a", "text": "IOException" },
        { "id": "b", "text": "SQLException" },
        { "id": "c", "text": "IllegalArgumentException" },
        { "id": "d", "text": "Any exception that extends Exception directly" }
      ],
      "correct": "c",
      "explanation": "IllegalArgumentException extends RuntimeException, making it unchecked. IOException and SQLException extend Exception (not RuntimeException) and are checked."
    }
  ]
}
```

## What's next

`finally` is the manual way to guarantee cleanup. The next lesson covers `try-with-resources`, which does the same job automatically for anything that implements `AutoCloseable`.
