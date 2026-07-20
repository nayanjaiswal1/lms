---
kind: lesson
id_key: java-mastery/control-flow/if-else-ternary
course: java-mastery
section: control-flow
section_title: "Control Flow"
section_position: 2
title: "if / else and the Ternary Operator"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every program so far has run top to bottom with no decisions. Real programs branch — TaskFlow needs to decide what to show a user based on a task's priority, status, or deadline. `if` / `else` is the fundamental branching tool, and the ternary operator is a compact expression form of the same idea.

## Basic if / else

```java
public class Main {
    public static void main(String[] args) {
        int priorityScore = 8; // 1-10 scale

        if (priorityScore >= 8) {
            System.out.println("Priority: HIGH");
        } else if (priorityScore >= 4) {
            System.out.println("Priority: MEDIUM");
        } else {
            System.out.println("Priority: LOW");
        }
    }
}
```

Java evaluates conditions top to bottom and runs the **first branch whose condition is true**, skipping the rest — `priorityScore = 8` never even checks the `>= 4` condition, because the first branch already matched. `else` is optional; a chain of `else if` is just nested `if` statements formatted flat for readability.

## Comparing objects: `==` vs `.equals()`

```java
public class Main {
    public static void main(String[] args) {
        String status = "IN_PROGRESS";

        if (status.equals("DONE")) {
            System.out.println("No action needed");
        } else if (status.equals("IN_PROGRESS")) {
            System.out.println("Active work — check in with assignee");
        } else {
            System.out.println("Unhandled status: " + status);
        }
    }
}
```

For `String` (and any object type), use `.equals()` to compare *content*, not `==`. `==` on objects compares whether two variables point to the **same object in memory**, which is a different question and a classic source of bugs for anyone coming from a language where `==` compares values. Primitives (`int`, `char`, `boolean`, ...) are the exception — `==` is correct and idiomatic for them, because there's no separate "object identity" for a primitive value.

## The ternary operator

The ternary operator `condition ? valueIfTrue : valueIfFalse` is an **expression**, not a statement — it evaluates to a value you can assign or print directly, which makes it a compact stand-in for a simple `if` / `else` whose only job is picking between two values:

```java
public class Main {
    public static void main(String[] args) {
        boolean isBlocked = true;
        String displayStatus = isBlocked ? "BLOCKED" : "IN_PROGRESS";
        System.out.println("Status: " + displayStatus);

        int hoursRemaining = 0;
        String urgency = hoursRemaining <= 0 ? "OVERDUE" : "ON_TRACK";
        System.out.println("Urgency: " + urgency);

        // Ternaries can nest, but readability drops fast — prefer if/else once
        // you need more than one decision point.
        int priorityScore = 6;
        String bucket = priorityScore >= 8 ? "HIGH" : priorityScore >= 4 ? "MEDIUM" : "LOW";
        System.out.println("Bucket: " + bucket);
    }
}
```

Reach for the ternary when you're choosing between two values to assign or print in one line. Reach for `if` / `else` as soon as a branch needs to run more than one statement, or the logic has more than two outcomes — nested ternaries save a few lines but cost readability quickly.

## Nested conditions

```java
public class Main {
    public static void main(String[] args) {
        String status = "IN_PROGRESS";
        int priorityScore = 9;

        if (status.equals("DONE")) {
            System.out.println("No action needed");
        } else {
            if (priorityScore >= 8) {
                System.out.println("Escalate: high-priority task still open");
            } else {
                System.out.println("Normal queue");
            }
        }
    }
}
```

Nesting `if` inside `if` lets you combine independent conditions, but deeply nested branches get hard to read fast. Where possible, combine conditions with `&&` / `||` instead of nesting — `if (!status.equals("DONE") && priorityScore >= 8)` says the same thing as the nested version above in one line.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "control-flow-if-else-ternary-q1",
      "type": "mcq",
      "prompt": "Why should you use .equals() instead of == to compare two String values in TaskFlow?",
      "options": [
        { "id": "a", "text": "== does not compile for String variables" },
        { "id": "b", "text": "== compares whether two variables reference the same object, not whether their content matches" },
        { "id": "c", "text": ".equals() is faster than ==" },
        { "id": "d", "text": "There is no difference; they are interchangeable for Strings" }
      ],
      "correct": "b",
      "explanation": "== checks object identity (same reference). Two String objects can hold identical text but be different objects in memory, so .equals() — which compares content — is the correct choice for value comparison."
    },
    {
      "id": "control-flow-if-else-ternary-q2",
      "type": "mcq",
      "prompt": "In an if / else-if / else chain, what happens once a branch's condition evaluates to true?",
      "options": [
        { "id": "a", "text": "Every remaining condition is still checked" },
        { "id": "b", "text": "The matching branch runs, and all later branches in the chain are skipped" },
        { "id": "c", "text": "All matching branches run" },
        { "id": "d", "text": "It's a compile error unless exactly one condition can be true" }
      ],
      "correct": "b",
      "explanation": "Java evaluates the chain top to bottom and stops at the first true condition — later else-if / else branches are never evaluated, even if their condition would also be true."
    },
    {
      "id": "control-flow-if-else-ternary-q3",
      "type": "mcq",
      "prompt": "What kind of construct is the ternary operator (condition ? a : b)?",
      "options": [
        { "id": "a", "text": "A statement, like if/else — it cannot be used inside an assignment" },
        { "id": "b", "text": "An expression that evaluates to a value, which can be assigned or printed directly" },
        { "id": "c", "text": "A loop construct" },
        { "id": "d", "text": "Syntactic sugar for a switch statement" }
      ],
      "correct": "b",
      "explanation": "Unlike if/else, the ternary operator is an expression — it produces a value in place, which is why `String x = cond ? \"a\" : \"b\";` is valid but there's no equivalent one-line assignment form of if/else."
    }
  ]
}
```

## What's next

The next lesson covers `switch` — both the classic form with fall-through and `break`, and the modern arrow form introduced in recent Java versions, which fixes several of `switch`'s oldest footguns.
