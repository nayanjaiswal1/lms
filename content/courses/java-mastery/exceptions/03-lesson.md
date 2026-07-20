---
kind: lesson
id_key: java-mastery/exceptions/custom-exceptions
course: java-mastery
section: exceptions
section_title: "Exceptions"
section_position: 6
title: "Custom Exceptions & Exception Chaining"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
`IllegalArgumentException` is a reasonable general-purpose exception, but it says nothing specific about what went wrong in TaskFlow's domain. A **custom exception type** lets calling code catch and react to precisely the failure it cares about — "this task doesn't exist" is a very different problem from "this argument was invalid" in general.

## Defining a custom exception

```java
public class Main {
    static class TaskNotFoundException extends RuntimeException {
        TaskNotFoundException(String message) {
            super(message); // passes the message up to RuntimeException's constructor
        }
    }

    static String findTaskName(String taskId) {
        if (!taskId.equals("T-100")) {
            throw new TaskNotFoundException("No task with id: " + taskId);
        }
        return "Build REST API";
    }

    public static void main(String[] args) {
        try {
            String name = findTaskName("T-999");
            System.out.println("Found: " + name);
        } catch (TaskNotFoundException e) {
            System.out.println("Lookup failed: " + e.getMessage());
        }
    }
}
```

`extends RuntimeException` makes `TaskNotFoundException` an unchecked exception — a reasonable default for most application-level errors in TaskFlow, since forcing every caller to declare `throws TaskNotFoundException` everywhere is often more ceremony than benefit. `super(message)` forwards the message to `RuntimeException`'s own constructor, so `e.getMessage()` works exactly like it does on built-in exceptions. Naming it `TaskNotFoundException` (ending in `Exception`, describing the specific failure) is the standard Java convention.

## Why a custom type matters: catching precisely

```java
public class Main {
    static class TaskNotFoundException extends RuntimeException {
        TaskNotFoundException(String message) { super(message); }
    }

    static class TaskValidationException extends RuntimeException {
        TaskValidationException(String message) { super(message); }
    }

    static void validateAndFind(String taskId, double hours) {
        if (hours < 0) {
            throw new TaskValidationException("Hours cannot be negative: " + hours);
        }
        if (!taskId.equals("T-100")) {
            throw new TaskNotFoundException("No task with id: " + taskId);
        }
    }

    public static void main(String[] args) {
        try {
            validateAndFind("T-999", 5.0);
        } catch (TaskNotFoundException e) {
            System.out.println("Handle missing task specifically: " + e.getMessage());
        } catch (TaskValidationException e) {
            System.out.println("Handle bad input specifically: " + e.getMessage());
        }
    }
}
```

With two distinct exception types, calling code can react differently to each — retry or prompt for a different ID on `TaskNotFoundException`, show a form validation error on `TaskValidationException`. A single generic `RuntimeException` for both would force every caller to inspect the message string to figure out what actually happened, which is fragile and easy to get wrong.

## Exception chaining: preserving the original cause

```java
public class Main {
    static class TaskNotFoundException extends RuntimeException {
        TaskNotFoundException(String message, Throwable cause) {
            super(message, cause); // chains the original exception in
        }
    }

    static String loadTaskFromDatabase(String taskId) {
        try {
            // simulate a lower-level failure, e.g. a database driver error
            throw new IllegalStateException("connection pool exhausted");
        } catch (IllegalStateException lowLevelFailure) {
            throw new TaskNotFoundException(
                "Could not load task " + taskId, lowLevelFailure);
        }
    }

    public static void main(String[] args) {
        try {
            loadTaskFromDatabase("T-100");
        } catch (TaskNotFoundException e) {
            System.out.println("Top-level message: " + e.getMessage());
            System.out.println("Root cause: " + e.getCause().getMessage());
            System.out.println("Root cause type: " + e.getCause().getClass().getSimpleName());
        }
    }
}
```

`new TaskNotFoundException("...", lowLevelFailure)` **wraps** the original low-level exception as the `cause`, rather than discarding it. `e.getCause()` recovers that original exception later — critical for debugging, since a stack trace with chained causes shows the *entire* failure path (the low-level database error *and* the higher-level "task not found" it triggered), instead of losing the real root cause the moment a higher layer translates it into its own exception type.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-custom-exceptions-q1",
      "type": "mcq",
      "prompt": "What does extending RuntimeException (rather than Exception) make a custom exception?",
      "options": [
        { "id": "a", "text": "Checked — callers must declare or catch it" },
        { "id": "b", "text": "Unchecked — the compiler does not require it to be caught or declared" },
        { "id": "c", "text": "Impossible to catch at all" },
        { "id": "d", "text": "Automatically logged to a file" }
      ],
      "correct": "b",
      "explanation": "RuntimeException and its subclasses are unchecked. Extending Exception directly (not RuntimeException) would make it checked, requiring every calling method to catch it or declare throws."
    },
    {
      "id": "exceptions-custom-exceptions-q2",
      "type": "mcq",
      "prompt": "In new TaskNotFoundException(\"Could not load task\", lowLevelFailure), what is lowLevelFailure?",
      "options": [
        { "id": "a", "text": "The error message" },
        { "id": "b", "text": "The chained cause, retrievable later via getCause()" },
        { "id": "c", "text": "An unused parameter with no effect" },
        { "id": "d", "text": "A boolean flag" }
      ],
      "correct": "b",
      "explanation": "Passing a Throwable as the second constructor argument (forwarded via super(message, cause)) sets it as the exception's cause, accessible later with getCause() — this is exception chaining."
    },
    {
      "id": "exceptions-custom-exceptions-q3",
      "type": "mcq",
      "prompt": "Why define distinct exception types like TaskNotFoundException and TaskValidationException instead of throwing a single generic RuntimeException for both?",
      "options": [
        { "id": "a", "text": "It has no practical benefit, it's purely stylistic" },
        { "id": "b", "text": "It lets calling code catch and handle each specific failure differently, instead of parsing message strings to figure out what went wrong" },
        { "id": "c", "text": "Generic RuntimeException cannot be caught at all" },
        { "id": "d", "text": "Custom exceptions run faster than built-in ones" }
      ],
      "correct": "b",
      "explanation": "Distinct exception types let a catch block target exactly the failure it knows how to handle (e.g. retry on TaskNotFoundException, show a form error on TaskValidationException) via normal type-based catch matching, rather than fragile string inspection."
    }
  ]
}
```

## What's next

You've now got the mechanics — throw, catch, finally, try-with-resources, custom types, chaining. The final lesson in this module covers **best practices**: the habits that separate exception handling that helps from exception handling that quietly hides bugs.
