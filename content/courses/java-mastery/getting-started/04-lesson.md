---
kind: lesson
id_key: java-mastery/getting-started/scanner-input
course: java-mastery
section: getting-started
section_title: "Getting Started"
section_position: 1
title: "Reading Input with Scanner"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every program so far has printed hardcoded values. `Scanner` is the standard way to read input — from the keyboard, a file, or any text source — and is what you'll reach for constantly for exercises and small tools.

## Setting up a Scanner

```java
import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.print("Enter a task name: ");
        String taskName = scanner.nextLine();

        System.out.println("Task created: " + taskName);
        scanner.close();
    }
}
```

`import java.util.Scanner;` pulls in the `Scanner` class from the standard library — Java's core classes are organized into **packages**, and anything outside `java.lang` (which is imported automatically) needs an explicit `import`. `new Scanner(System.in)` wraps the standard input stream; `nextLine()` reads one line of text as a `String`.

**Always close a `Scanner` when you're done with it** — it holds a reference to the underlying stream, and not closing it can leak resources in longer-running programs. In this course's runnable boxes there's no live stdin to read from, so treat these examples as reference for how you'd wire input in a real program — the surrounding lessons focus on the parsing and type-conversion mechanics, which you can see and run directly.

## Reading typed values

```java
import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        // nextInt(), nextDouble(), nextBoolean() parse the next token as that type
        System.out.print("Estimated hours (as a number): ");
        // double hours = scanner.nextDouble();

        // Demonstrating the parsing Scanner does under the hood, without live input:
        double hours = Double.parseDouble("6.5");
        int priority = Integer.parseInt("3");

        System.out.println("Hours: " + hours + ", Priority: " + priority);
        scanner.close();
    }
}
```

`nextInt()` / `nextDouble()` read the next whitespace-delimited **token**, not a full line — mixing `nextInt()` and `nextLine()` calls is a classic gotcha, because `nextInt()` leaves the trailing newline in the buffer for the next `nextLine()` to immediately (and confusingly) consume as an empty string. The fix is usually to read everything with `nextLine()` and parse it yourself with `Integer.parseInt(...)` / `Double.parseDouble(...)`, as shown above — one consistent read strategy avoids the whole class of bug.

## Putting it together: TaskFlow's first CLI shape

```java
public class Main {
    public static void main(String[] args) {
        // Simulating three lines of "input" that would normally come from Scanner
        String[] simulatedInput = { "Design database schema", "6", "H" };

        String taskName = simulatedInput[0];
        int estimateHours = Integer.parseInt(simulatedInput[1]);
        char priority = simulatedInput[2].charAt(0);

        System.out.println("=== New Task ===");
        System.out.println("Name:     " + taskName);
        System.out.println("Estimate: " + estimateHours + "h");
        System.out.println("Priority: " + priority);
    }
}
```

This previews something important: `simulatedInput[0]` is **array indexing**, and `.charAt(0)` pulls a single character out of a `String`. Both get their own full treatment in the next module — this is just a taste of how raw input (whether from `Scanner` or elsewhere) becomes structured data your program can act on.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "getting-started-scanner-q1",
      "type": "mcq",
      "prompt": "Why does Scanner need `import java.util.Scanner;` at the top of the file?",
      "options": [
        { "id": "a", "text": "Scanner is part of java.lang, which is always auto-imported, so the import is optional" },
        { "id": "b", "text": "Scanner lives in the java.util package, and anything outside java.lang needs an explicit import" },
        { "id": "c", "text": "Imports are only needed for classes you write yourself" },
        { "id": "d", "text": "It's purely stylistic and has no effect on compilation" }
      ],
      "correct": "b",
      "explanation": "java.lang (String, System, Math, etc.) is imported automatically. Everything else, including java.util.Scanner, must be imported explicitly before you can reference it by its short name."
    },
    {
      "id": "getting-started-scanner-q2",
      "type": "mcq",
      "prompt": "What's the classic bug when mixing scanner.nextInt() followed immediately by scanner.nextLine()?",
      "options": [
        { "id": "a", "text": "nextInt() throws an exception if called before nextLine()" },
        { "id": "b", "text": "nextInt() leaves the trailing newline in the input buffer, so the following nextLine() reads it as an empty string" },
        { "id": "c", "text": "The two methods cannot be used in the same program" },
        { "id": "d", "text": "nextLine() automatically skips ahead to the next non-empty line" }
      ],
      "correct": "b",
      "explanation": "nextInt() consumes only the numeric token, not the newline after it. The next nextLine() call then immediately returns that leftover empty line instead of waiting for new input — a very common source of confusion."
    },
    {
      "id": "getting-started-scanner-q3",
      "type": "mcq",
      "prompt": "Why should a Scanner wrapping System.in typically be closed when a program is done reading input?",
      "options": [
        { "id": "a", "text": "It has no real effect, closing is purely cosmetic" },
        { "id": "b", "text": "Unclosed Scanners cause a compile error" },
        { "id": "c", "text": "It releases the underlying resource the Scanner holds a reference to, avoiding a resource leak" },
        { "id": "d", "text": "Closing a Scanner clears all variables in the program" }
      ],
      "correct": "c",
      "explanation": "Scanner wraps an input stream, and holding it open unnecessarily is a resource leak in longer-running programs — the same principle behind closing files, sockets, and database connections."
    }
  ]
}
```

## What's next

That's the full toolkit for basic programs: syntax, variables, operators, and input. The module quiz below checks your understanding across all four lessons before you move on to **control flow**.
