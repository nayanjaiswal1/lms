---
kind: lesson
id_key: java-mastery/exceptions/best-practices
course: java-mastery
section: exceptions
section_title: "Exceptions"
section_position: 6
title: "Exception-Handling Best Practices"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Knowing the mechanics of `try`/`catch`/`throw` is only half the story. Exceptions can also be misused in ways that compile fine and quietly make a codebase worse. This lesson covers the habits that keep exception handling honest.

## Never swallow an exception silently

```java
public class Main {
    static double parseHours(String raw) {
        try {
            return Double.parseDouble(raw);
        } catch (NumberFormatException e) {
            // BAD: swallowed. The caller has no idea parsing failed —
            // it silently gets 0.0 as if that were a real, valid estimate.
            return 0.0;
        }
    }

    public static void main(String[] args) {
        double hours = parseHours("not-a-number");
        System.out.println("Parsed hours: " + hours); // looks fine, but it's WRONG data
    }
}
```

An empty (or effectively empty) `catch` block is one of the most damaging patterns in Java code: the failure disappears, and the program keeps running on bad data as if nothing happened. Bugs caused by swallowed exceptions are notoriously hard to track down later, because by the time something visibly breaks, the actual failure happened somewhere upstream and left no trace.

```java
public class Main {
    static double parseHours(String raw) {
        try {
            return Double.parseDouble(raw);
        } catch (NumberFormatException e) {
            // GOOD: fail loudly, or handle it in a way the caller can see.
            throw new IllegalArgumentException("Invalid hours value: '" + raw + "'", e);
        }
    }

    public static void main(String[] args) {
        try {
            double hours = parseHours("not-a-number");
            System.out.println("Parsed hours: " + hours);
        } catch (IllegalArgumentException e) {
            System.out.println("Rejected: " + e.getMessage());
        }
    }
}
```

The fix re-throws a clearer exception (chaining the original as the cause, as covered last lesson) instead of pretending nothing went wrong. At minimum, if you truly intend to ignore a failure, log it explicitly and say why in a comment — never leave a `catch` block that does nothing at all.

## Catch specific types before general ones

```java
public class Main {
    static double createTaskEstimate(String raw) {
        return Double.parseDouble(raw);
    }

    public static void main(String[] args) {
        try {
            double hours = createTaskEstimate("abc");
            System.out.println("Estimate: " + hours);
        } catch (NumberFormatException e) {
            // Specific: handle exactly this known failure mode.
            System.out.println("Bad number format: " + e.getMessage());
        } catch (RuntimeException e) {
            // General fallback: anything else unexpected.
            System.out.println("Unexpected failure: " + e.getMessage());
        }
    }
}
```

Java requires this ordering — a `catch (RuntimeException e)` placed *before* `catch (NumberFormatException e)` is actually a compile error, since `NumberFormatException` is a subtype of `RuntimeException` and would be unreachable. The principle behind the rule matters beyond the compiler check: catching the most specific type you can lets you handle known failure modes precisely, while a broader catch further down acts as a genuine last-resort safety net, not a way to lazily lump every possible failure into one vague handler.

## Exceptions are for exceptional cases, not control flow

```java
public class Main {
    public static void main(String[] args) {
        int[] taskIds = { 101, 102, 103 };

        // BAD: using an exception to detect "reached the end" is a control-flow misuse.
        int i = 0;
        try {
            while (true) {
                System.out.println("Task: " + taskIds[i]);
                i++;
            }
        } catch (ArrayIndexOutOfBoundsException e) {
            System.out.println("Done (via exception).");
        }

        // GOOD: a plain bounds check expresses the same logic directly.
        for (int j = 0; j < taskIds.length; j++) {
            System.out.println("Task: " + taskIds[j]);
        }
        System.out.println("Done (via loop condition).");
    }
}
```

Both blocks above produce the same visible output, but the first one is a misuse: exceptions carry the overhead of capturing a stack trace and are meant to signal genuinely abnormal conditions, not to implement ordinary loop termination that a plain condition already expresses clearly. If you find yourself deliberately triggering an exception to detect a normal, expected state (end of a collection, "not found" in a lookup that's expected to sometimes miss), that's usually a sign to use a direct check, a boolean return, or an `Optional` instead.

## Checked exceptions: when they help vs. when they're overused

Checked exceptions make sense when a caller genuinely has a reasonable, different way to recover — reading a file that might not exist, where the caller can sensibly prompt for a different path. They become a burden when they're used for conditions nearly every caller can't meaningfully act on except to log and rethrow, forcing `throws` declarations to ripple through layers of code that have no real recovery option. This is exactly why modern Java APIs, and this course's own `TaskNotFoundException` and `TaskValidationException` from the previous lesson, lean toward unchecked exceptions for application-level errors — reserving checked exceptions for the narrower case of genuinely recoverable, external failure conditions like I/O.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-best-practices-q1",
      "type": "mcq",
      "prompt": "What is the main danger of an empty catch block?",
      "options": [
        { "id": "a", "text": "It causes a compile error" },
        { "id": "b", "text": "The failure disappears silently, and the program continues running on bad or incomplete data with no trace of what went wrong" },
        { "id": "c", "text": "It makes the program run slower" },
        { "id": "d", "text": "It automatically retries the failed operation" }
      ],
      "correct": "b",
      "explanation": "Swallowing an exception hides the failure entirely. The program proceeds as if nothing happened, and any resulting bug becomes far harder to trace back to its real cause later."
    },
    {
      "id": "exceptions-best-practices-q2",
      "type": "mcq",
      "prompt": "Why must a more specific catch block (e.g. NumberFormatException) come before a more general one (e.g. RuntimeException) for the same try block?",
      "options": [
        { "id": "a", "text": "It's just a style convention with no compiler enforcement" },
        { "id": "b", "text": "Because NumberFormatException is a subtype of RuntimeException, placing the general catch first would make the specific one unreachable — the compiler rejects this" },
        { "id": "c", "text": "Order never matters in catch blocks" },
        { "id": "d", "text": "General exceptions must always be caught first for performance" }
      ],
      "correct": "b",
      "explanation": "Java catch blocks are checked top to bottom, and an unreachable catch (one whose exception type a prior catch would already match) is a compile error. Specific types must precede their broader supertypes."
    },
    {
      "id": "exceptions-best-practices-q3",
      "type": "mcq",
      "prompt": "Why is deliberately using an exception to detect a normal, expected condition (like reaching the end of a loop) considered a misuse?",
      "options": [
        { "id": "a", "text": "It's technically impossible to do in Java" },
        { "id": "b", "text": "Exceptions carry overhead and are meant for genuinely abnormal conditions; a plain condition check expresses ordinary control flow more directly and clearly" },
        { "id": "c", "text": "Catch blocks cannot contain loop logic" },
        { "id": "d", "text": "It always produces different output than a plain loop condition would" }
      ],
      "correct": "b",
      "explanation": "Using exceptions for expected, routine outcomes conflates normal control flow with abnormal failure signaling, adds needless overhead, and makes the code's real intent harder to read compared to a direct boolean or bounds check."
    }
  ]
}
```

## What's next

That covers exception handling end to end. The module quiz below checks your understanding across all four lessons — checked vs. unchecked, try-with-resources, custom exceptions and chaining, and these best practices — before you move on to the **Collections Framework**.
