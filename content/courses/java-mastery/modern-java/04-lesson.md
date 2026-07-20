---
kind: lesson
id_key: java-mastery/modern-java/pattern-matching
course: java-mastery
section: modern-java
section_title: "Modern Java"
section_position: 15
title: "Pattern Matching for instanceof and switch"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
The OOP module's polymorphism lesson used `instanceof` with a manual cast to recover a subtype's specific behavior. Modern Java lets you skip the manual cast entirely — the language does it for you, safely, as part of the check itself.

## instanceof, before and after

```java
public class Main {
    static class Task { String name = "generic task"; }
    static class UrgentTask extends Task {
        int escalationLevel = 2;
    }

    static String describeOldStyle(Task task) {
        if (task instanceof UrgentTask) {
            UrgentTask urgent = (UrgentTask) task; // manual cast, easy to forget or get wrong
            return "Urgent, level " + urgent.escalationLevel;
        }
        return "Regular: " + task.name;
    }

    static String describeModern(Task task) {
        if (task instanceof UrgentTask urgent) { // "urgent" is bound automatically, already cast
            return "Urgent, level " + urgent.escalationLevel;
        }
        return "Regular: " + task.name;
    }

    public static void main(String[] args) {
        Task t = new UrgentTask();
        System.out.println(describeOldStyle(t));
        System.out.println(describeModern(t));
    }
}
```

`task instanceof UrgentTask urgent` does two things at once: checks the type, and — only inside the branch where the check succeeded — introduces `urgent` as an already-cast, ready-to-use `UrgentTask` reference. The variable is only in scope where the compiler can prove the check passed, so there's no way to accidentally use `urgent` somewhere the cast might actually be unsafe.

## Pattern matching in switch expressions

Recall the sealed `TaskEvent` hierarchy from the previous lesson. A `switch` can pattern-match directly on the runtime type of each case, binding a typed variable per branch, exactly like `instanceof` does — but exhaustively, for every permitted type:

```java
public class Main {
    sealed interface TaskEvent permits TaskCreated, TaskCompleted, TaskCancelled {}
    record TaskCreated(String taskName) implements TaskEvent {}
    record TaskCompleted(String taskName, int actualHours) implements TaskEvent {}
    record TaskCancelled(String taskName, String reason) implements TaskEvent {}

    static String describe(TaskEvent event) {
        return switch (event) {
            case TaskCreated c -> c.taskName() + " was created";
            case TaskCompleted c -> c.taskName() + " finished in " + c.actualHours() + "h";
            case TaskCancelled c -> c.taskName() + " was cancelled: " + c.reason();
            // No default needed — TaskEvent is sealed to exactly these three types,
            // and the compiler verifies all three are handled.
        };
    }

    public static void main(String[] args) {
        TaskEvent[] events = {
            new TaskCreated("Deploy to prod"),
            new TaskCompleted("Design schema", 4),
            new TaskCancelled("Old feature flag", "Superseded")
        };
        for (TaskEvent e : events) {
            System.out.println(describe(e));
        }
    }
}
```

Because `TaskEvent` is sealed, the compiler proves every case is covered — if a fourth record type were ever added to `permits`, this `switch` would stop compiling until a matching `case` was added. That's a compile-time safety net a plain `if`/`instanceof` chain, or a switch over an unsealed type, simply cannot give you.

## Guarded patterns (`when` clauses)

A pattern-matching `case` can add a boolean condition with `when`, narrowing further without leaving the switch:

```java
public class Main {
    record TaskCompleted(String taskName, int actualHours) {}

    static String rate(Object event) {
        return switch (event) {
            case TaskCompleted c when c.actualHours() > 10 ->
                c.taskName() + " ran way over — flag for review";
            case TaskCompleted c ->
                c.taskName() + " completed normally (" + c.actualHours() + "h)";
            default -> "not a completion event";
        };
    }

    public static void main(String[] args) {
        System.out.println(rate(new TaskCompleted("Migrate database", 14)));
        System.out.println(rate(new TaskCompleted("Fix typo", 1)));
    }
}
```

Order matters here, same as any `if`/`else if` chain: the more specific guarded case (`when c.actualHours() > 10`) must come before the general one, or it would never be reached.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "modern-java-pattern-matching-q1",
      "type": "mcq",
      "prompt": "In `if (task instanceof UrgentTask urgent)`, where is the variable urgent usable?",
      "options": [
        { "id": "a", "text": "Everywhere in the method, regardless of the instanceof result" },
        { "id": "b", "text": "Only inside the branch where the compiler can prove the instanceof check succeeded" },
        { "id": "c", "text": "It must still be manually cast before use" },
        { "id": "d", "text": "It's only usable inside a switch statement, not an if" }
      ],
      "correct": "b",
      "explanation": "Pattern-matching instanceof scopes the bound variable to exactly the region where the type check is known to have passed, eliminating both the manual cast and any chance of using it unsafely."
    },
    {
      "id": "modern-java-pattern-matching-q2",
      "type": "mcq",
      "prompt": "Why doesn't the switch over the sealed TaskEvent hierarchy need a default case?",
      "options": [
        { "id": "a", "text": "default is never allowed in a switch expression" },
        { "id": "b", "text": "Because TaskEvent is sealed to exactly the permitted types, the compiler can verify all cases are covered without one" },
        { "id": "c", "text": "It does need one — omitting it is a bug" },
        { "id": "d", "text": "switch expressions never require exhaustiveness" }
      ],
      "correct": "b",
      "explanation": "Exhaustiveness checking is exactly what sealing buys you: the compiler knows the complete permitted type set and can confirm every case branch covers it."
    },
    {
      "id": "modern-java-pattern-matching-q3",
      "type": "mcq",
      "prompt": "In a guarded pattern like `case TaskCompleted c when c.actualHours() > 10 -> ...`, why must this case be ordered before a plainer `case TaskCompleted c -> ...`?",
      "options": [
        { "id": "a", "text": "Order doesn't matter for switch cases" },
        { "id": "b", "text": "Because the first matching case wins, top to bottom — a more general case placed first would always match and the guarded one would never be reached" },
        { "id": "c", "text": "when clauses are evaluated in a separate pass before the switch runs" },
        { "id": "d", "text": "It's a stylistic convention with no functional effect" }
      ],
      "correct": "b",
      "explanation": "Pattern-matching switch cases are still evaluated in source order — same principle as if/else if chains, where the most specific condition must be checked first or it gets shadowed by a broader one above it."
    }
  ]
}
```

## What's next

That closes out modern Java syntax. The next module, **Testing with JUnit**, shifts from language features to engineering practice: how you actually verify TaskFlow's classes behave correctly, automatically, every time the code changes.
