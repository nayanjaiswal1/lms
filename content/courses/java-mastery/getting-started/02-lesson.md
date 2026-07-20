---
kind: lesson
id_key: java-mastery/getting-started/variables-and-types
course: java-mastery
section: getting-started
section_title: "Getting Started"
section_position: 1
title: "Variables, Primitive Types & Casting"
position: 1
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Java is **statically typed**: every variable has a fixed type, declared up front, and the compiler rejects code that tries to put the wrong kind of value into it. This catches a whole class of bugs before the program ever runs — the tradeoff is you have to be explicit about types everywhere.

## The eight primitive types

Java has exactly eight primitive types — not objects, just raw values stored directly in memory:

| Type | Size | Holds | Example |
|---|---|---|---|
| `byte` | 8-bit | Whole number, -128 to 127 | `byte small = 100;` |
| `short` | 16-bit | Whole number | `short s = 30000;` |
| `int` | 32-bit | Whole number (the default for integers) | `int taskCount = 42;` |
| `long` | 64-bit | Whole number (large) | `long id = 9000000000L;` |
| `float` | 32-bit | Decimal (single precision) | `float f = 3.14f;` |
| `double` | 64-bit | Decimal (the default for decimals) | `double price = 19.99;` |
| `char` | 16-bit | A single Unicode character | `char grade = 'A';` |
| `boolean` | 1-bit (conceptually) | `true` or `false` | `boolean done = false;` |

```java
public class Main {
    public static void main(String[] args) {
        int taskCount = 5;
        double avgHoursPerTask = 3.5;
        char priority = 'H'; // High
        boolean isComplete = false;

        System.out.println("Tasks: " + taskCount);
        System.out.println("Avg hours: " + avgHoursPerTask);
        System.out.println("Priority: " + priority);
        System.out.println("Complete: " + isComplete);
    }
}
```

`long` literals need an `L` suffix and `float` literals need an `f` suffix — without them, a whole number literal defaults to `int` and a decimal literal defaults to `double`, and the compiler will reject assigning an `int`/`double` literal to a smaller/different type.

## Variables are declared, then optionally initialized

```java
public class Main {
    public static void main(String[] args) {
        int retryLimit; // declared, not yet initialized
        retryLimit = 3; // initialized here

        final int MAX_TASKS_PER_USER = 50; // final = cannot be reassigned
        System.out.println("Retry limit: " + retryLimit);
        System.out.println("Max tasks per user: " + MAX_TASKS_PER_USER);
    }
}
```

`final` marks a variable as a constant — attempting `MAX_TASKS_PER_USER = 100;` later would be a compile error. By convention, constants are named in `SCREAMING_SNAKE_CASE`.

## Type inference with `var`

Since Java 10, `var` lets the compiler infer the type from the right-hand side — it's still statically typed underneath, just less typing for you:

```java
public class Main {
    public static void main(String[] args) {
        var taskName = "Design database schema"; // inferred as String
        var estimateHours = 6;                    // inferred as int
        System.out.println(taskName + " — " + estimateHours + "h");
    }
}
```

`var` only works for local variables with an initializer on the same line — it can't be used for fields, method parameters, or return types, and `var x;` without an initializer is a compile error since there's nothing to infer from.

## Casting between types

**Widening** (small type → big type, e.g. `int` → `long`) happens automatically since no information can be lost. **Narrowing** (big type → small type, e.g. `double` → `int`) needs an explicit cast, because it can lose information:

```java
public class Main {
    public static void main(String[] args) {
        int wholeHours = 7;
        double preciseHours = wholeHours; // widening: automatic

        double actualHoursSpent = 6.75;
        int roundedDown = (int) actualHoursSpent; // narrowing: explicit cast required

        System.out.println("Precise: " + preciseHours);
        System.out.println("Rounded down: " + roundedDown); // 6 — truncates, doesn't round
    }
}
```

Casting `double` to `int` **truncates** the decimal part rather than rounding — `(int) 6.75` gives `6`, not `7`. For proper rounding, use `Math.round(actualHoursSpent)` instead.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "getting-started-variables-q1",
      "type": "mcq",
      "prompt": "What is the default type of a whole-number literal like 42 with no suffix?",
      "options": [
        { "id": "a", "text": "long" },
        { "id": "b", "text": "int" },
        { "id": "c", "text": "short" },
        { "id": "d", "text": "It depends on the variable it's assigned to" }
      ],
      "correct": "b",
      "explanation": "Whole-number literals default to int. Assigning 42 to a long is fine (widening), but assigning a literal that needs more than 32 bits requires the L suffix."
    },
    {
      "id": "getting-started-variables-q2",
      "type": "mcq",
      "prompt": "What does (int) 9.9 evaluate to?",
      "options": [
        { "id": "a", "text": "10, because it rounds" },
        { "id": "b", "text": "9, because narrowing casts truncate the decimal part" },
        { "id": "c", "text": "A compile error" },
        { "id": "d", "text": "9.0" }
      ],
      "correct": "b",
      "explanation": "Casting double to int discards the fractional part entirely rather than rounding — (int) 9.9 is 9, and so is (int) 9.1."
    },
    {
      "id": "getting-started-variables-q3",
      "type": "mcq",
      "prompt": "Which statement about `var` is correct?",
      "options": [
        { "id": "a", "text": "var makes Java dynamically typed, like Python" },
        { "id": "b", "text": "var can be used for method parameters and return types" },
        { "id": "c", "text": "var infers a fixed type at compile time from the initializer, and that type cannot change later" },
        { "id": "d", "text": "var must always be declared final" }
      ],
      "correct": "c",
      "explanation": "var is compile-time type inference, not dynamic typing — the compiler locks in a concrete type from the initializer, and Java remains fully statically typed."
    }
  ]
}
```

## What's next

With variables and types in hand, the next lesson covers Java's **operators** — arithmetic, comparison, logical, and the assignment operators you'll use to manipulate TaskFlow's data.
