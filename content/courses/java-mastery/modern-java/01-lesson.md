---
kind: lesson
id_key: java-mastery/modern-java/var-and-text-blocks
course: java-mastery
section: modern-java
section_title: "Modern Java"
section_position: 15
title: "var Recap & Text Blocks"
position: 0
estimated_minutes: 15
source: [java-mastery-curriculum.md]
---
Java's release cadence sped up dramatically starting with Java 9 (a new version every six months, instead of the old multi-year cycles), and a steady stream of quality-of-life features has landed since. This module tours the ones that show up constantly in modern Java code — and increasingly, in interviews expecting you to know them.

## `var` — a quick recap

You met `var` back in the Getting Started module: local-variable type inference, still fully statically typed under the hood.

```java
public class Main {
    public static void main(String[] args) {
        var taskName = "Refactor TaskFlow API";   // inferred: String
        var estimateHours = 8;                     // inferred: int
        var isUrgent = estimateHours > 5;           // inferred: boolean

        System.out.println(taskName + " (" + estimateHours + "h, urgent=" + isUrgent + ")");
    }
}
```

The rule of thumb: use `var` when the right-hand side already makes the type obvious (`var tasks = new ArrayList<Task>();`), and prefer an explicit type when it doesn't (`var result = process();` hides the type entirely from a reader unless they check `process()`'s signature).

## Text blocks

Before text blocks (Java 15+), multi-line strings meant `\n` and `+` concatenation:

```java
public class Main {
    public static void main(String[] args) {
        String oldStyleReport = "TaskFlow Report\n" +
            "----------------\n" +
            "Task: Refactor API\n" +
            "Status: In Progress\n";
        System.out.println(oldStyleReport);
    }
}
```

A **text block**, delimited by `"""`, writes the same thing without the noise:

```java
public class Main {
    public static void main(String[] args) {
        String report = """
            TaskFlow Report
            ----------------
            Task: Refactor API
            Status: In Progress
            """;
        System.out.println(report);
    }
}
```

The opening `"""` must be followed immediately by a newline. Java determines the "incidental" leading whitespace shared by every line (based on the closing `"""`'s indentation) and strips it, so you can indent the whole block to match your code's structure without that indentation ending up in the string. Text blocks still support `+` concatenation, `.formatted(...)`, and escape sequences like `\n` when you genuinely need one.

## Where text blocks matter in practice

Text blocks shine anywhere you'd otherwise fight with escaped quotes and manual line breaks — embedded SQL, JSON payloads, HTML fragments, or formatted reports:

```java
public class Main {
    public static void main(String[] args) {
        String taskName = "Deploy to prod";
        int hours = 4;

        // .formatted(...) works directly on a text block, same as String.format
        String summary = """
            Task: %s
            Hours: %d
            """.formatted(taskName, hours);

        System.out.print(summary);
    }
}
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "modern-java-var-and-text-blocks-q1",
      "type": "mcq",
      "prompt": "What must immediately follow the opening \"\"\" of a text block?",
      "options": [
        { "id": "a", "text": "The first character of content, on the same line" },
        { "id": "b", "text": "A newline — content starts on the following line" },
        { "id": "c", "text": "A semicolon" },
        { "id": "d", "text": "Nothing is required; both forms are equivalent" }
      ],
      "correct": "b",
      "explanation": "A text block's opening \"\"\" must be followed by a line terminator; content begins on the next line. This is a compile error if violated."
    },
    {
      "id": "modern-java-var-and-text-blocks-q2",
      "type": "mcq",
      "prompt": "Does using var change Java's type system to be dynamically typed?",
      "options": [
        { "id": "a", "text": "Yes, var variables can hold any type at runtime" },
        { "id": "b", "text": "No — the compiler infers one fixed concrete type at compile time from the initializer, and that stays fixed" },
        { "id": "c", "text": "Only for primitive types, not objects" },
        { "id": "d", "text": "It depends on which JDK version is used" }
      ],
      "correct": "b",
      "explanation": "var is purely a compile-time convenience — the compiler still locks in a single concrete static type and enforces it exactly as if you'd written it explicitly."
    }
  ]
}
```

## What's next

Next: **records** — a feature that eliminates most of the boilerplate you hand-wrote for immutable data classes back in the OOP module.
