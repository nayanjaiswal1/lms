---
kind: lesson
id_key: java-mastery/arrays-strings/stringbuilder-and-formatting
course: java-mastery
section: arrays-strings
section_title: "Arrays & Strings"
section_position: 5
title: "StringBuilder & String Formatting"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
The previous lesson established that every `String` "modification" actually builds a brand-new `String`. That's fine for one or two concatenations — but inside a loop, it becomes a real performance problem. This lesson covers the fix, plus proper formatted output.

## Why `+=` in a loop is wasteful

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design schema", "Build API", "Write tests", "Deploy" };

        String report = "";
        for (String name : taskNames) {
            report += name + "\n"; // a NEW String object is allocated every iteration
        }

        System.out.print(report);
    }
}
```

Each `report += ...` throws away the old `String` object `report` pointed at and allocates an entirely new one containing the combined characters — because `String` is immutable, there's no other way for `+=` to work. For 4 tasks that's cheap and invisible. For a report over 10,000 tasks, that's 10,000 discarded intermediate `String` objects, each one copying everything accumulated so far. It's an easy-to-miss O(n²) cost hiding behind an innocent-looking loop.

## `StringBuilder`: one mutable buffer

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design schema", "Build API", "Write tests", "Deploy" };

        StringBuilder report = new StringBuilder();
        for (String name : taskNames) {
            report.append(name).append("\n"); // mutates the SAME buffer, no new String each time
        }

        System.out.print(report.toString());
    }
}
```

`StringBuilder` is a **mutable** sequence of characters — `append()` grows the same internal buffer in place instead of allocating a new object every call, so building up a long piece of text in a loop is efficient. `append()` returns the `StringBuilder` itself, which is why `.append(name).append("\n")` can be chained on one line. Call `.toString()` once at the end to get back an immutable `String` for printing, storing, or comparing.

## Other useful `StringBuilder` methods

```java
public class Main {
    public static void main(String[] args) {
        StringBuilder sb = new StringBuilder("Design schema");

        sb.append(" — 6h");             // "Design schema — 6h"
        sb.insert(0, "[TODO] ");        // "[TODO] Design schema — 6h"
        sb.reverse();                    // just to show it's mutable in-place
        sb.reverse();                    // reverse back
        sb.deleteCharAt(0);              // removes '['

        System.out.println(sb.toString());
        System.out.println("Length: " + sb.length());
    }
}
```

`insert(index, text)` inserts at a position, `deleteCharAt(index)` removes a single character, and `reverse()` flips the whole buffer — all mutate `sb` directly rather than returning something new to reassign, which is the whole point of using a mutable buffer.

## `String.format()` and `printf`-style formatting

```java
public class Main {
    public static void main(String[] args) {
        String taskName = "Build REST API";
        double hoursSpent = 7.5;
        int priority = 8;

        String line = String.format("%-20s %6.2fh  priority=%d", taskName, hoursSpent, priority);
        System.out.println(line);

        // printf writes directly instead of returning a String
        System.out.printf("%-20s %6.2fh  priority=%d%n", "Write tests", 3.0, 5);
    }
}
```

Format specifiers start with `%`: `%s` for a `String`, `%d` for an integer, `%f` for a decimal. `%-20s` left-aligns a string in a 20-character-wide field (the `-` means left-align; without it, the default is right-align); `%6.2f` right-aligns a decimal in a 6-character-wide field with exactly 2 digits after the decimal point. `String.format(...)` returns a formatted `String` to use however you like; `System.out.printf(...)` does the same formatting and writes it straight to stdout — note the `%n` at the end for a platform-appropriate newline, instead of `\n`.

## Building a TaskFlow report line by line

```java
public class Main {
    public static void main(String[] args) {
        String[] names = { "Design schema", "Build REST API", "Write tests" };
        double[] hours = { 6.0, 10.5, 3.25 };
        int[] priorities = { 8, 9, 4 };

        StringBuilder report = new StringBuilder();
        report.append(String.format("%-20s %8s %10s%n", "TASK", "HOURS", "PRIORITY"));

        double totalHours = 0;
        for (int i = 0; i < names.length; i++) {
            report.append(String.format("%-20s %8.2f %10d%n", names[i], hours[i], priorities[i]));
            totalHours += hours[i];
        }
        report.append(String.format("%-20s %8.2f%n", "TOTAL", totalHours));

        System.out.print(report.toString());
    }
}
```

This combines both tools naturally: `StringBuilder` accumulates the growing report efficiently across the loop, and `String.format` produces each well-aligned line inside it. This is the realistic shape of report-generation code in any Java service — build once with a mutable buffer, format each piece precisely, emit the final `String` once.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "arrays-strings-stringbuilder-and-formatting-q1",
      "type": "mcq",
      "prompt": "Why is StringBuilder preferred over repeated String += concatenation inside a loop?",
      "options": [
        { "id": "a", "text": "+= doesn't compile inside loops" },
        { "id": "b", "text": "StringBuilder mutates one buffer in place, while += allocates a brand-new String object on every iteration" },
        { "id": "c", "text": "StringBuilder produces shorter output" },
        { "id": "d", "text": "There's no real performance difference, it's purely a style preference" }
      ],
      "correct": "b",
      "explanation": "Because String is immutable, += must create a whole new String each time, copying everything accumulated so far. StringBuilder's internal buffer grows in place, avoiding that repeated copying — a real difference at scale."
    },
    {
      "id": "arrays-strings-stringbuilder-and-formatting-q2",
      "type": "mcq",
      "prompt": "What does the format specifier %6.2f mean in String.format?",
      "options": [
        { "id": "a", "text": "A string field padded to 6 characters" },
        { "id": "b", "text": "A decimal number right-aligned in a 6-character-wide field, with exactly 2 digits after the decimal point" },
        { "id": "c", "text": "An integer with 6 leading zeros" },
        { "id": "d", "text": "A decimal rounded to 6 significant figures" }
      ],
      "correct": "b",
      "explanation": "%f formats a floating-point value; the 6 before the dot sets the minimum field width (right-aligned by default), and the 2 after the dot sets the number of decimal places shown."
    },
    {
      "id": "arrays-strings-stringbuilder-and-formatting-q3",
      "type": "mcq",
      "prompt": "What does sb.append(\"a\").append(\"b\") rely on to be chainable?",
      "options": [
        { "id": "a", "text": "append() returns void, and Java allows chaining on void methods" },
        { "id": "b", "text": "append() returns the StringBuilder instance itself, so another method can be called immediately on the result" },
        { "id": "c", "text": "It's special syntax unique to append()" },
        { "id": "d", "text": "This code does not actually compile" }
      ],
      "correct": "b",
      "explanation": "append() returns `this` (the same StringBuilder), which is what makes fluent chaining like .append(x).append(y).append(z) possible."
    }
  ]
}
```

## What's next

You now have a solid handle on arrays and strings — the fixed-size and text building blocks TaskFlow leans on constantly. Up next: **exceptions**, so TaskFlow can handle bad input and failures gracefully instead of crashing.
