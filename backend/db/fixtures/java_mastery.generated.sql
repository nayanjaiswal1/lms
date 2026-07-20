-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-07-20T13:03:01Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Java Mastery: From Scratch to Interview-Ready ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, estimated_hours)
VALUES ('2166677d-878d-5c38-b01b-0ce7d5e4edc7', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Java Mastery: From Scratch to Interview-Ready', 'java-mastery', 'A comprehensive, hands-on Java course built around a single running example — TaskFlow, a small task-management system (tasks, users, projects, teams) that grows in sophistication as the course progresses. Every lesson ships runnable "Try it Yourself" Java code boxes (server-side execution, real javac/java under the hood) so you write and run real Java with zero local setup. Covers syntax and control flow, full OOP (encapsulation, inheritance, polymorphism, interfaces), arrays and strings, exceptions, the Collections Framework, generics, file I/O and NIO, lambdas and the Stream API, concurrency, JVM and memory internals, JDBC, classic design patterns, modern Java (records, sealed types, pattern matching), testing with JUnit, Maven/Gradle build tooling, and a final interview-mastery module of theory questions and mixed assessments.', '/course-covers/java-mastery.svg', 'beginner', ARRAY['java','programming','oop','interview-prep'], 'published', true, 29.1)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

-- Section: Getting Started
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('2c18af73-0348-5ae9-9e0d-ca78a0f72f27', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Getting Started', 1)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4ab1266a-fe70-5985-89be-cad047931d35', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '2c18af73-0348-5ae9-9e0d-ca78a0f72f27', 'What Java Is, and Your First Program', 'notes', 0, $md$Java is a **compiled, statically-typed, object-oriented** language that runs on the **JVM** (Java Virtual Machine) instead of talking to your CPU directly. That one design decision — compile to an intermediate format, run it on a virtual machine — is why "write once, run anywhere" became Java's slogan: the same compiled output runs unmodified on Windows, Linux, or macOS, as long as a JVM is installed.

Every example in this course builds toward the same running project: **TaskFlow**, a small task-management system (tasks, users, projects, teams) that grows a little more sophisticated in every module. By the time you reach the interview-ready module, you'll have touched every major Java feature by using it inside TaskFlow, not in isolation.

Every code box in this course is live. Edit the Java, hit **Run**, and it compiles and executes for real — no local JDK install needed, it runs server-side and streams back stdout/stderr.

## JDK, JRE, and JVM — three letters that matter

| Term | What it is |
|---|---|
| **JVM** | Java Virtual Machine — executes compiled bytecode (`.class` files). This is what makes Java portable. |
| **JRE** | Java Runtime Environment — JVM + the standard library classes needed to *run* Java programs. |
| **JDK** | Java Development Kit — JRE + the compiler (`javac`) and other dev tools needed to *build* Java programs. |

You develop with the JDK, and your compiled program runs on any machine with a compatible JVM. `javac` compiles `.java` source files into `.class` bytecode files; the `java` command loads those `.class` files into the JVM and runs them.

## Your first program

Every standalone Java program needs a class containing a `main` method — that's the entry point the JVM looks for when you run a program:

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("TaskFlow booting up...");
    }
}
```

Run it — you'll see the string printed to stdout. Walk through each piece:

- `public class Main` — every piece of Java code lives inside a class. `Main` is the class name; by convention it matches the filename (`Main.java`).
- `public static void main(String[] args)` — the fixed signature the JVM looks for to start execution. `public` so the JVM (outside the class) can call it, `static` so it can be called without creating a `Main` object first, `void` because it returns nothing, and `String[] args` holds any command-line arguments passed in.
- `System.out.println(...)` — `System.out` is the standard output stream; `println` writes a line and appends a newline. Its sibling `print` writes without the trailing newline.

## Statements, blocks, and semicolons

Java is a **semicolon-terminated, brace-delimited** language. Every statement ends in `;`, and every block of code — a method body, a loop body, an `if` branch — is wrapped in `{ }`:

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("Task 1: Design database schema");
        System.out.println("Task 2: Build REST API");
        System.out.println("Task 3: Write tests");
    }
}
```

Unlike Python, indentation is purely cosmetic in Java — the compiler only cares about the braces and semicolons. Consistent indentation still matters enormously for humans reading the code, though.

## Comments

```java
public class Main {
    // Single-line comment — runs to the end of the line
    public static void main(String[] args) {
        /*
         * Multi-line comment block — useful for longer explanations
         * or temporarily disabling a chunk of code.
         */
        System.out.println("TaskFlow v0.1"); // trailing comment
    }
}
```

There's a third form, `/** ... */` (Javadoc), used to generate API documentation from source comments — you'll see it once we start writing classes with public APIs in the OOP modules.

## Knowledge check

Answer all questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "getting-started-what-is-java-q1",
      "type": "mcq",
      "prompt": "What does the JVM execute?",
      "options": [
        { "id": "a", "text": "Raw .java source files directly" },
        { "id": "b", "text": "Compiled .class bytecode files" },
        { "id": "c", "text": "Machine code specific to the host CPU" },
        { "id": "d", "text": "Python bytecode" }
      ],
      "correct": "b",
      "explanation": "javac compiles .java source into .class bytecode. The JVM loads and executes that bytecode — this indirection is what makes Java portable across operating systems."
    },
    {
      "id": "getting-started-what-is-java-q2",
      "type": "mcq",
      "prompt": "Why is the main method declared static?",
      "options": [
        { "id": "a", "text": "So it runs faster than instance methods" },
        { "id": "b", "text": "So the JVM can call it without first creating an instance of the class" },
        { "id": "c", "text": "Static is required for all methods that return void" },
        { "id": "d", "text": "It has no real effect and is only a convention" }
      ],
      "correct": "b",
      "explanation": "static methods belong to the class itself, not to any object. The JVM needs to invoke main before any object of your class exists, so it must be static."
    },
    {
      "id": "getting-started-what-is-java-q3",
      "type": "mcq",
      "prompt": "Which JDK tool compiles a .java file into bytecode?",
      "options": [
        { "id": "a", "text": "java" },
        { "id": "b", "text": "jvm" },
        { "id": "c", "text": "javac" },
        { "id": "d", "text": "jar" }
      ],
      "correct": "c",
      "explanation": "javac is the compiler. The java command then loads and runs the resulting .class file on the JVM."
    }
  ]
}
```

## What's next

You can already write and run a minimal Java program. The next lesson covers **variables and primitive types** — the building blocks every TaskFlow feature from here on will be made of.
$md$, 20, $json$[{"id":"getting-started-what-is-java-q1","type":"mcq","correct":"b"},{"id":"getting-started-what-is-java-q2","type":"mcq","correct":"b"},{"id":"getting-started-what-is-java-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('96ab3467-c4cd-565d-98a1-da09a6b18503', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '2c18af73-0348-5ae9-9e0d-ca78a0f72f27', 'Variables, Primitive Types & Casting', 'notes', 1, $md$Java is **statically typed**: every variable has a fixed type, declared up front, and the compiler rejects code that tries to put the wrong kind of value into it. This catches a whole class of bugs before the program ever runs — the tradeoff is you have to be explicit about types everywhere.

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
$md$, 25, $json$[{"id":"getting-started-variables-q1","type":"mcq","correct":"b"},{"id":"getting-started-variables-q2","type":"mcq","correct":"b"},{"id":"getting-started-variables-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('17e430c5-09f9-5117-8c14-5df39c728cdb', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '2c18af73-0348-5ae9-9e0d-ca78a0f72f27', 'Operators & Expressions', 'notes', 2, $md$Operators combine variables and values into expressions. Java groups them into a few families you'll use constantly.

## Arithmetic operators

```java
public class Main {
    public static void main(String[] args) {
        int totalTasks = 17;
        int completedTasks = 5;

        int remaining = totalTasks - completedTasks;
        int doubledLoad = totalTasks * 2;
        int perDay = totalTasks / 3;      // integer division: truncates
        int leftover = totalTasks % 3;    // modulo: the remainder

        System.out.println("Remaining: " + remaining);
        System.out.println("Per day (int division): " + perDay);
        System.out.println("Leftover (modulo): " + leftover);
    }
}
```

**Integer division truncates** — `17 / 3` is `5`, not `5.666...`. If either operand is a `double`, the result is a `double`: `17.0 / 3` gives `5.666666666666667`. This is one of the most common early Java bugs — dividing two `int`s when you wanted a decimal result.

## Increment, decrement, and compound assignment

```java
public class Main {
    public static void main(String[] args) {
        int taskCount = 10;
        taskCount++;        // post-increment: taskCount is now 11
        taskCount += 5;      // compound assignment: taskCount is now 16
        taskCount -= 2;      // now 14

        int index = 0;
        int first = index++; // first = 0, then index becomes 1 (post-increment)
        int second = ++index; // index becomes 2, then second = 2 (pre-increment)

        System.out.println("taskCount: " + taskCount);
        System.out.println("first: " + first + ", second: " + second);
    }
}
```

`x++` (post) returns the value *before* incrementing; `++x` (pre) increments first, then returns the new value. When the result isn't used in the same expression — `taskCount++;` on its own line — the two behave identically.

## Comparison and logical operators

```java
public class Main {
    public static void main(String[] args) {
        int priority = 8;
        boolean isUrgent = priority >= 7;
        boolean isAssigned = true;

        boolean needsAttention = isUrgent && !isAssigned; // AND + NOT
        boolean showInDigest = isUrgent || priority == 10; // OR

        System.out.println("Needs attention: " + needsAttention);
        System.out.println("Show in digest: " + showInDigest);
    }
}
```

`==` compares primitive values directly. `&&` and `||` **short-circuit**: in `a && b`, if `a` is `false`, `b` is never evaluated at all — useful (and sometimes necessary) when `b` would otherwise throw, like `list != null && list.size() > 0`.

## String concatenation with `+`

```java
public class Main {
    public static void main(String[] args) {
        String taskName = "Deploy to prod";
        int hoursSpent = 3;

        // + concatenates when either operand is a String
        String summary = taskName + " took " + hoursSpent + " hours";
        System.out.println(summary);

        // Order matters! Left-to-right evaluation:
        System.out.println("Total: " + 1 + 2);   // "Total: 12" — string concat both times
        System.out.println("Total: " + (1 + 2)); // "Total: 3"  — parens force numeric addition first
    }
}
```

Once `+` sees a `String` on either side, everything to its right is concatenated as text, left to right — `1 + 2` inside `"Total: " + 1 + 2` never gets a chance to run as arithmetic, because `"Total: " + 1` already produced a `String`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "getting-started-operators-q1",
      "type": "mcq",
      "prompt": "What does 17 / 3 evaluate to when both operands are int?",
      "options": [
        { "id": "a", "text": "5.67" },
        { "id": "b", "text": "5" },
        { "id": "c", "text": "6" },
        { "id": "d", "text": "A compile error" }
      ],
      "correct": "b",
      "explanation": "Integer division truncates toward zero and discards the remainder — 17 / 3 is 5. Use 17.0 / 3 or cast an operand to double to get a decimal result."
    },
    {
      "id": "getting-started-operators-q2",
      "type": "mcq",
      "prompt": "What does \"Total: \" + 1 + 2 print?",
      "options": [
        { "id": "a", "text": "Total: 3" },
        { "id": "b", "text": "Total: 12" },
        { "id": "c", "text": "3Total: " },
        { "id": "d", "text": "A compile error" }
      ],
      "correct": "b",
      "explanation": "+ is evaluated left to right. \"Total: \" + 1 produces the String \"Total: 1\" first, and appending 2 to a String concatenates rather than adds, giving \"Total: 12\"."
    },
    {
      "id": "getting-started-operators-q3",
      "type": "mcq",
      "prompt": "In `a && b`, if a evaluates to false, what happens to b?",
      "options": [
        { "id": "a", "text": "b is always evaluated regardless" },
        { "id": "b", "text": "b is never evaluated — && short-circuits" },
        { "id": "c", "text": "It causes a compile error" },
        { "id": "d", "text": "b is evaluated but its result is discarded" }
      ],
      "correct": "b",
      "explanation": "&& and || short-circuit: once the overall result is determined by the left operand, the right operand is skipped entirely — this is why `list != null && list.size() > 0` is safe."
    }
  ]
}
```

## What's next

The last lesson in this module puts everything together: reading input from the user with `Scanner`, so TaskFlow can respond to something other than hardcoded values.
$md$, 20, $json$[{"id":"getting-started-operators-q1","type":"mcq","correct":"b"},{"id":"getting-started-operators-q2","type":"mcq","correct":"b"},{"id":"getting-started-operators-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('449b4bd5-330e-5d20-b9e1-11eec176325d', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '2c18af73-0348-5ae9-9e0d-ca78a0f72f27', 'Reading Input with Scanner', 'notes', 3, $md$Every program so far has printed hardcoded values. `Scanner` is the standard way to read input — from the keyboard, a file, or any text source — and is what you'll reach for constantly for exercises and small tools.

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
$md$, 20, $json$[{"id":"getting-started-scanner-q1","type":"mcq","correct":"b"},{"id":"getting-started-scanner-q2","type":"mcq","correct":"b"},{"id":"getting-started-scanner-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('34f5e338-722f-5842-a0fd-eb1e13c08298', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which of these do you need installed to compile Java source code, not just ru...', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('720f6707-7422-5bf2-940d-8d4e1c01904f', '34f5e338-722f-5842-a0fd-eb1e13c08298', 1, $json${"prompt":"Which of these do you need installed to compile Java source code, not just run already-compiled programs?","multiple":false,"options":[{"id":"a","text":"JRE only","is_correct":false},{"id":"b","text":"JVM only","is_correct":false},{"id":"c","text":"JDK","is_correct":true},{"id":"d","text":"None — any text editor is sufficient","is_correct":false}],"explanation":"The JDK includes javac (the compiler) plus everything in the JRE. The JRE alone can run compiled bytecode but cannot compile source."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f5e857ab-735e-5f31-a9b5-16a5fc08b077', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does it mean that Java is statically typed?', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a3839b41-2d3a-5f2e-999a-34168eb80078', 'f5e857ab-735e-5f31-a9b5-16a5fc08b077', 1, $json${"prompt":"What does it mean that Java is statically typed?","multiple":false,"options":[{"id":"a","text":"Variable types are checked and fixed at compile time, not decided at runtime","is_correct":true},{"id":"b","text":"Variables cannot change their value once set","is_correct":false},{"id":"c","text":"Every variable must be declared final","is_correct":false},{"id":"d","text":"Types are only enforced when the program crashes","is_correct":false}],"explanation":"Static typing means the compiler knows and enforces every variable's type before the program ever runs — a type mismatch is a compile error, not a runtime surprise."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('39a2b35e-0b5e-5d62-a421-969127941c9f', '00000000-0000-0000-0000-000000000001', 'mcq', 'A TaskFlow report divides totalMinutes (int) by 60 to get hours, using totalM...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('454a2eb2-0d84-5562-b0fe-441413601bdc', '39a2b35e-0b5e-5d62-a421-969127941c9f', 1, $json${"prompt":"A TaskFlow report divides totalMinutes (int) by 60 to get hours, using totalMinutes / 60. For totalMinutes = 150, what's the risk?","multiple":false,"options":[{"id":"a","text":"No risk — this correctly gives 2.5 hours","is_correct":false},{"id":"b","text":"Integer division truncates to 2, silently discarding the remaining 30 minutes' worth of decimal precision","is_correct":true},{"id":"c","text":"It throws an ArithmeticException","is_correct":false},{"id":"d","text":"It's a compile error because int can't be divided","is_correct":false}],"explanation":"150 / 60 with two ints is integer division: it truncates to 2, not 2.5. Getting a decimal result requires making at least one operand a double, e.g. totalMinutes / 60.0."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('94e68847-f08f-5adf-8dec-76de1739f03d', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which declaration is invalid?', 'intermediate', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('000c1711-a349-51ca-b696-29f260cd800f', '94e68847-f08f-5adf-8dec-76de1739f03d', 1, $json${"prompt":"Which declaration is invalid?","multiple":false,"options":[{"id":"a","text":"var taskCount = 5;","is_correct":false},{"id":"b","text":"var taskName = \"Deploy\";","is_correct":false},{"id":"c","text":"var pending;","is_correct":true},{"id":"d","text":"final var MAX = 100;","is_correct":false}],"explanation":"var requires an initializer on the same line so the compiler has something to infer the type from — var pending; alone is a compile error."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('eb08ae0d-3858-5814-bd2e-e94a7857327e', '00000000-0000-0000-0000-000000000001', 'mcq', 'Code calls scanner.nextInt() to read a priority number, then immediately scan...', 'advanced', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('df11d9f3-f35f-5b34-8a38-56d6d73373f7', 'eb08ae0d-3858-5814-bd2e-e94a7857327e', 1, $json${"prompt":"Code calls scanner.nextInt() to read a priority number, then immediately scanner.nextLine() expecting the task description on the next line — but it gets an empty string. Why?","multiple":false,"options":[{"id":"a","text":"nextInt() left the trailing newline character in the buffer, which the following nextLine() immediately consumed as an empty line","is_correct":true},{"id":"b","text":"Scanner can only be used once per program","is_correct":false},{"id":"c","text":"nextLine() always returns an empty string after any numeric read","is_correct":false},{"id":"d","text":"The Scanner needs to be re-created between reads","is_correct":false}],"explanation":"nextInt() stops at the numeric token and doesn't consume the newline after it. The next nextLine() call reads up to that leftover newline, returning an empty string — a very common real-world Scanner bug."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('111f572c-ea30-5882-9ea3-178ab17b233b', '00000000-0000-0000-0000-000000000001', 'coding', 'TaskFlow needs a quick utility. Read two integers from a single line of input...', 'beginner', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cd23017e-26c1-5b2f-94de-d0457ca5263f', '111f572c-ea30-5882-9ea3-178ab17b233b', 1, $json${"prompt":"TaskFlow needs a quick utility. Read two integers from a single line of input, separated by a space: the estimated hours for a task, and the number of team members assigned. Print a single integer: hours multiplied by members (the total person-hours), with no extra text.","languages":["java"],"starter_code":{"java":"import java.util.Scanner;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        // Read two space-separated integers from one line and print their product.\n\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"6 3","expected":"18","hidden":false,"weight":1},{"id":"t2","stdin":"10 2","expected":"20","hidden":true,"weight":1},{"id":"t3","stdin":"0 5","expected":"0","hidden":true,"weight":1},{"id":"t4","stdin":"7 1","expected":"7","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7a4b5e88-6422-5beb-9eb0-b1eda8a1d228', '00000000-0000-0000-0000-000000000001', 'subjective', 'In your own words: which single concept from this module (JVM/JDK/JRE, primit...', 'beginner', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('42702116-7801-598e-800c-b50a548c150f', '7a4b5e88-6422-5beb-9eb0-b1eda8a1d228', 1, $json${"prompt":"In your own words: which single concept from this module (JVM/JDK/JRE, primitive types and casting, operators, or Scanner input) felt least intuitive to you, and why? Be specific about what confused you — this answer feeds directly into what gets flagged for extra review.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('090b102e-9aa1-5477-806b-f62d6d58e627', '00000000-0000-0000-0000-000000000001', 'Module Assessment: Java Fundamentals', 'java-mastery-getting-started-quiz', 'Quiz covering Getting Started.', 'mixed', 'published', 'module', '31eca51e-ba72-580d-8511-f25f73b3ff4d', 20, 70, 5, 12, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('8fd32e10-84ac-5c53-9e29-7dcc5085f475', '090b102e-9aa1-5477-806b-f62d6d58e627', '34f5e338-722f-5842-a0fd-eb1e13c08298', '720f6707-7422-5bf2-940d-8d4e1c01904f', 0, 1),
('d38afb42-a8bd-5286-a93b-01d5a988d5ef', '090b102e-9aa1-5477-806b-f62d6d58e627', 'f5e857ab-735e-5f31-a9b5-16a5fc08b077', 'a3839b41-2d3a-5f2e-999a-34168eb80078', 1, 1),
('d5831f4d-d8b4-5195-8b82-6425940ad20b', '090b102e-9aa1-5477-806b-f62d6d58e627', '39a2b35e-0b5e-5d62-a421-969127941c9f', '454a2eb2-0d84-5562-b0fe-441413601bdc', 2, 2),
('5253b7e4-5c59-5456-97f9-03824d7d9057', '090b102e-9aa1-5477-806b-f62d6d58e627', '94e68847-f08f-5adf-8dec-76de1739f03d', '000c1711-a349-51ca-b696-29f260cd800f', 3, 1),
('fb479bee-d542-5bf1-9338-39de90c9f92b', '090b102e-9aa1-5477-806b-f62d6d58e627', 'eb08ae0d-3858-5814-bd2e-e94a7857327e', 'df11d9f3-f35f-5b34-8a38-56d6d73373f7', 4, 2),
('ebbf5ee7-4698-5ece-82a5-927f2054ce0b', '090b102e-9aa1-5477-806b-f62d6d58e627', '111f572c-ea30-5882-9ea3-178ab17b233b', 'cd23017e-26c1-5b2f-94de-d0457ca5263f', 5, 3),
('39cf0365-41f8-5ee1-ab64-0b0657d1c688', '090b102e-9aa1-5477-806b-f62d6d58e627', '7a4b5e88-6422-5beb-9eb0-b1eda8a1d228', '42702116-7801-598e-800c-b50a548c150f', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('31eca51e-ba72-580d-8511-f25f73b3ff4d', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '2c18af73-0348-5ae9-9e0d-ca78a0f72f27', 'Module Assessment: Java Fundamentals', 'assessment', 4, 20, '090b102e-9aa1-5477-806b-f62d6d58e627')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Control Flow
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('0a1568fb-eae1-5692-9d3e-8035568fb4d8', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Control Flow', 2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f25ac64c-4c5e-5a82-ba02-d36e4756bcaa', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '0a1568fb-eae1-5692-9d3e-8035568fb4d8', 'if / else and the Ternary Operator', 'notes', 0, $md$Every program so far has run top to bottom with no decisions. Real programs branch — TaskFlow needs to decide what to show a user based on a task's priority, status, or deadline. `if` / `else` is the fundamental branching tool, and the ternary operator is a compact expression form of the same idea.

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
$md$, 20, $json$[{"id":"control-flow-if-else-ternary-q1","type":"mcq","correct":"b"},{"id":"control-flow-if-else-ternary-q2","type":"mcq","correct":"b"},{"id":"control-flow-if-else-ternary-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('26d551dd-4096-5c44-a430-ceb1070f83a8', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '0a1568fb-eae1-5692-9d3e-8035568fb4d8', 'switch: Classic and Arrow Form', 'notes', 1, $md$`switch` picks a branch based on matching a single value against a list of candidates. It has two forms in modern Java: the original **classic** form (fall-through, `break`), and the **arrow** form added in Java 14, which is safer by default and can produce a value directly.

## Classic switch

```java
public class Main {
    public static void main(String[] args) {
        String status = "REVIEW";
        String label;

        switch (status) {
            case "TODO":
            case "REVIEW":
                label = "Not started work";
                break;
            case "IN_PROGRESS":
                label = "Active work";
                break;
            case "DONE":
                label = "Complete";
                break;
            default:
                label = "Unknown status";
        }

        System.out.println(label);
    }
}
```

Stacking `case "TODO":` directly above `case "REVIEW":` with no code between them is a deliberate idiom: both labels fall into the same body. `break` exits the `switch` once a matching case has run — without it, execution **falls through** into the next case's code, regardless of whether that case's label matches.

## Fall-through, on purpose and by accident

```java
public class Main {
    public static void main(String[] args) {
        int priority = 3; // 1 = low, 2 = medium, 3 = high

        switch (priority) {
            case 3:
                System.out.println("Notify team lead");
                // intentional fall-through: a high-priority task also gets
                // the normal assignee notification below
            case 2:
                System.out.println("Notify assignee");
                break;
            case 1:
                System.out.println("Add to backlog digest");
                break;
            default:
                System.out.println("Unknown priority");
        }
    }
}
```

For `priority = 3`, this prints **both** "Notify team lead" and "Notify assignee" — execution enters `case 3`, finds no `break`, and keeps running straight into `case 2`'s body. That's a real, occasionally useful pattern (as here), but it's also the single most common `switch` bug: forgetting a `break` and silently running code you didn't mean to run. This is exactly the footgun the arrow form was designed to eliminate.

## The arrow form

```java
public class Main {
    public static void main(String[] args) {
        String status = "IN_PROGRESS";

        String label = switch (status) {
            case "TODO" -> "Not started";
            case "IN_PROGRESS" -> "Active";
            case "DONE" -> "Complete";
            default -> "Unknown";
        };

        System.out.println(label);
    }
}
```

`switch` as an **expression** (note the trailing `;` after the closing `}`) evaluates to a value directly — no `label` variable declared-then-assigned across branches, no `break` needed, and no accidental fall-through: each arrow branch runs only its own single expression and nothing else. Multiple labels can share one branch with a comma:

```java
public class Main {
    public static void main(String[] args) {
        int priority = 4;

        String bucket = switch (priority) {
            case 1, 2 -> "LOW";
            case 3, 4 -> "MEDIUM";
            case 5 -> "HIGH";
            default -> "INVALID";
        };

        System.out.println("Priority bucket: " + bucket);
    }
}
```

## Which one should you use?

Prefer the **arrow form** for new code: it can't fall through by accident, it works naturally as an expression, and the compiler checks exhaustiveness more strictly. Reach for the **classic form** when you deliberately need fall-through behavior (rare but real, as in the notification example above), or when maintaining existing code that already uses it. Both forms support `String`, primitives like `int`, `char`, and `enum` values as the switched-on type.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "control-flow-switch-q1",
      "type": "mcq",
      "prompt": "In a classic switch, what happens if a matching case has no break statement?",
      "options": [
        { "id": "a", "text": "The switch exits immediately after that case, same as with break" },
        { "id": "b", "text": "A compile error occurs — break is mandatory" },
        { "id": "c", "text": "Execution falls through and keeps running the code in the next case, regardless of whether its label matches" },
        { "id": "d", "text": "Java automatically inserts an implicit break" }
      ],
      "correct": "c",
      "explanation": "Classic switch has no implicit break — once a case matches, execution runs every statement below it until it hits a break or the end of the switch block, even if the next case's label doesn't match the switched value."
    },
    {
      "id": "control-flow-switch-q2",
      "type": "mcq",
      "prompt": "What is a key advantage of the arrow form (case X -> ...) over the classic form?",
      "options": [
        { "id": "a", "text": "It runs faster at execution time" },
        { "id": "b", "text": "Each branch is isolated — no accidental fall-through into the next case" },
        { "id": "c", "text": "It can switch on types that classic switch cannot, such as int" },
        { "id": "d", "text": "It does not require a default case ever" }
      ],
      "correct": "b",
      "explanation": "Arrow-form branches only execute their own expression or block — there's no shared fall-through path between cases, which removes the most common classic-switch bug entirely."
    },
    {
      "id": "control-flow-switch-q3",
      "type": "mcq",
      "prompt": "What does `case 1, 2 -> \"LOW\";` mean in an arrow-form switch?",
      "options": [
        { "id": "a", "text": "It's a syntax error — only one value per case is allowed" },
        { "id": "b", "text": "Both 1 and 2 map to the same branch, producing \"LOW\" for either" },
        { "id": "c", "text": "It matches only when the switched value equals both 1 and 2" },
        { "id": "d", "text": "It creates a range from 1 to 2" }
      ],
      "correct": "b",
      "explanation": "A comma-separated list of labels lets multiple values share one arrow branch — equivalent to stacking case labels in classic switch, but in a single line."
    }
  ]
}
```

## What's next

Next up: loops. `for`, `while`, `do-while`, and the enhanced for-each — the tools for repeating work across TaskFlow's tasks instead of writing out each one by hand.
$md$, 20, $json$[{"id":"control-flow-switch-q1","type":"mcq","correct":"c"},{"id":"control-flow-switch-q2","type":"mcq","correct":"b"},{"id":"control-flow-switch-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5b7a02e6-129b-561b-a8a2-ba6873144f06', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '0a1568fb-eae1-5692-9d3e-8035568fb4d8', 'Loops: for, while, do-while, and for-each', 'notes', 2, $md$Loops repeat a block of code without you writing it out N times. Java has four loop forms, each suited to a different shape of problem: counting through indices, repeating while a condition holds, guaranteeing at least one run, and walking every element of a collection.

## The classic for loop

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design schema", "Build API", "Write tests", "Deploy" };

        for (int i = 0; i < taskNames.length; i++) {
            System.out.println((i + 1) + ". " + taskNames[i]);
        }
    }
}
```

A `for` loop has three parts separated by `;`: **initialization** (`int i = 0`, runs once), **condition** (`i < taskNames.length`, checked before every iteration), and **update** (`i++`, runs after every iteration). It's the natural choice when you need the index itself — here, to number each task — not just each value. `taskNames.length` is a field (no parentheses) on the array, giving its size.

## while: repeat until a condition fails

```java
public class Main {
    public static void main(String[] args) {
        int tasksRemaining = 5;

        while (tasksRemaining > 0) {
            System.out.println("Processing task, " + tasksRemaining + " remaining");
            tasksRemaining--;
        }

        System.out.println("Queue empty");
    }
}
```

`while` checks its condition **before** each iteration, including the first — if `tasksRemaining` started at `0`, the loop body would never run at all. Use `while` when the number of iterations isn't known up front and depends on something changing inside the loop, like draining a queue.

## do-while: guaranteed at least one run

```java
public class Main {
    public static void main(String[] args) {
        int attempt = 1;
        boolean connected = false;

        do {
            System.out.println("Connection attempt " + attempt);
            connected = attempt >= 3; // simulate success on the 3rd try
            attempt++;
        } while (!connected);

        System.out.println("Connected after " + (attempt - 1) + " attempt(s)");
    }
}
```

`do-while` checks its condition **after** the body runs, so the body always executes at least once — exactly right for "try something, then keep retrying until it succeeds," like a connection attempt where you need to try before you have anything to check.

## Enhanced for-each

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design schema", "Build API", "Write tests" };

        for (String taskName : taskNames) {
            System.out.println("Task: " + taskName);
        }
    }
}
```

The for-each loop (`for (Type element : collection)`) reads "for each `taskName` in `taskNames`" and hands you each element directly — no index bookkeeping, no risk of an off-by-one `ArrayIndexOutOfBoundsException`. Use it whenever you need every element and don't need the index; fall back to the classic `for` when you do need the index (to number items, skip every other one, or walk backwards).

## Choosing between them

| Loop | Use when |
|---|---|
| `for` | You need an index, or a known number of iterations |
| `while` | The stopping condition depends on something checked *before* each run, iteration count unknown |
| `do-while` | The body must run at least once no matter what |
| for-each | You just need every element, in order, and don't need the index |

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "control-flow-loops-q1",
      "type": "mcq",
      "prompt": "If tasksRemaining starts at 0, how many times does `while (tasksRemaining > 0) { ... }` run its body?",
      "options": [
        { "id": "a", "text": "Exactly once" },
        { "id": "b", "text": "Zero times — while checks the condition before the first iteration" },
        { "id": "c", "text": "It causes a compile error" },
        { "id": "d", "text": "It runs forever" }
      ],
      "correct": "b",
      "explanation": "while evaluates its condition before every iteration, including the first. If the condition is already false, the body never runs at all — this is the key difference from do-while."
    },
    {
      "id": "control-flow-loops-q2",
      "type": "mcq",
      "prompt": "What guarantee does a do-while loop provide that a while loop does not?",
      "options": [
        { "id": "a", "text": "It runs faster" },
        { "id": "b", "text": "The loop body executes at least once, since the condition is checked after the body runs" },
        { "id": "c", "text": "It can only be used with arrays" },
        { "id": "d", "text": "It never needs a stopping condition" }
      ],
      "correct": "b",
      "explanation": "do-while runs the body first and checks the condition afterward, so the body is guaranteed to run at least one time regardless of the condition's initial value."
    },
    {
      "id": "control-flow-loops-q3",
      "type": "mcq",
      "prompt": "Why might you choose a classic for loop over a for-each loop when iterating an array of task names?",
      "options": [
        { "id": "a", "text": "for-each cannot iterate arrays, only collections" },
        { "id": "b", "text": "You need the index — for example, to number each task in the output" },
        { "id": "c", "text": "Classic for loops are always faster" },
        { "id": "d", "text": "for-each requires the array to be sorted first" }
      ],
      "correct": "b",
      "explanation": "for-each gives you each element but not its position. When you need the index — numbering items, skipping alternating entries, iterating backwards — the classic for loop's explicit index is what you need."
    }
  ]
}
```

## What's next

The last lesson in this module covers `break`, `continue`, and **labeled** loops — how to exit early, skip an iteration, and control nested loops precisely when scanning through TaskFlow's tasks grouped by project.
$md$, 25, $json$[{"id":"control-flow-loops-q1","type":"mcq","correct":"b"},{"id":"control-flow-loops-q2","type":"mcq","correct":"b"},{"id":"control-flow-loops-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ffcfe770-8b73-57b4-a8fb-3a28f65d08b1', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '0a1568fb-eae1-5692-9d3e-8035568fb4d8', 'break, continue, and Labeled Loops', 'notes', 3, $md$`break` and `continue` change a loop's normal flow: `break` exits the loop entirely, `continue` skips straight to the next iteration. Both work on the loop they're written inside — but sometimes you need to control an **outer** loop from inside a **nested** one, which is what labels are for.

## continue: skip this iteration

```java
public class Main {
    public static void main(String[] args) {
        String[] statuses = { "DONE", "IN_PROGRESS", "DONE", "TODO" };

        for (String status : statuses) {
            if (status.equals("DONE")) {
                continue; // skip completed tasks, nothing to report
            }
            System.out.println("Needs attention: " + status);
        }
    }
}
```

`continue` jumps immediately to the next iteration — for a `for` loop, that means running the update step (`i++`) and re-checking the condition, skipping everything below `continue` for the current pass. Here, `DONE` tasks are skipped entirely; only `IN_PROGRESS` and `TODO` get printed.

## break: exit the loop entirely

```java
public class Main {
    public static void main(String[] args) {
        int[] priorities = { 2, 3, 5, 4, 1 };

        for (int priority : priorities) {
            if (priority == 5) {
                System.out.println("Found urgent task, stopping scan");
                break;
            }
            System.out.println("Checked priority " + priority + ", not urgent");
        }
    }
}
```

`break` stops the loop immediately — no more iterations run, even though `priorities` still has elements left (`4` and `1` are never checked). This is the standard pattern for "search until found, then stop."

## Labeled loops: breaking out of nested loops

A plain `break` only exits the **innermost** loop it's written in. When you're scanning a nested structure — TaskFlow's projects, each holding a list of tasks — and need to stop the *entire* search the moment you find what you're after, a **label** on the outer loop lets `break` (or `continue`) target it directly:

```java
public class Main {
    public static void main(String[] args) {
        String[] projectNames = { "Website Revamp", "Mobile App", "Internal Tools" };
        String[][] tasksByProject = {
            { "Wireframes", "Homepage build" },
            { "Login screen", "Push notifications", "URGENT: Crash on launch" },
            { "Cleanup scripts" }
        };

        searchProjects:
        for (int p = 0; p < projectNames.length; p++) {
            for (int t = 0; t < tasksByProject[p].length; t++) {
                String taskName = tasksByProject[p][t];
                if (taskName.startsWith("URGENT")) {
                    System.out.println("Found \"" + taskName + "\" in " + projectNames[p]);
                    break searchProjects;
                }
            }
        }
    }
}
```

`searchProjects:` labels the outer loop. `break searchProjects;` exits **that** loop directly, skipping the rest of both the inner loop and any remaining outer iterations — without a label, a plain `break` here would only stop the inner loop over `tasksByProject[p]`, and the outer loop would move on to check the next project unnecessarily. `continue searchProjects;` follows the same idea: it would skip to the outer loop's next iteration instead of the inner one's.

Labeled breaks are a niche tool — reach for them only when a genuinely nested search needs to abort completely from deep inside, which is rarer than it sounds. For most nested-loop logic, restructuring into a separate method that simply `return`s once it finds what it's looking for reads more clearly than a label.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "control-flow-break-continue-labels-q1",
      "type": "mcq",
      "prompt": "What does continue do inside a loop?",
      "options": [
        { "id": "a", "text": "Exits the loop entirely" },
        { "id": "b", "text": "Skips the rest of the current iteration and moves to the next one" },
        { "id": "c", "text": "Restarts the loop from its first iteration" },
        { "id": "d", "text": "Pauses the loop until a condition changes" }
      ],
      "correct": "b",
      "explanation": "continue jumps straight to the next iteration — for a for loop, that means running the update step and re-checking the condition — skipping any code below it for the current pass only."
    },
    {
      "id": "control-flow-break-continue-labels-q2",
      "type": "mcq",
      "prompt": "Inside a nested loop, what does a plain (unlabeled) break do?",
      "options": [
        { "id": "a", "text": "Exits every enclosing loop, inner and outer" },
        { "id": "b", "text": "Exits only the innermost loop it's written in" },
        { "id": "c", "text": "Exits only the outermost loop" },
        { "id": "d", "text": "It's a compile error inside nested loops" }
      ],
      "correct": "b",
      "explanation": "An unlabeled break only ever affects the loop it's directly written inside — the innermost one. To exit an outer loop from inside a nested one, you need a label."
    },
    {
      "id": "control-flow-break-continue-labels-q3",
      "type": "mcq",
      "prompt": "What does `break searchProjects;` do when searchProjects labels the outer of two nested loops?",
      "options": [
        { "id": "a", "text": "Exits only the inner loop, same as a plain break" },
        { "id": "b", "text": "Exits the outer loop directly, skipping any remaining inner and outer iterations" },
        { "id": "c", "text": "Throws a runtime exception" },
        { "id": "d", "text": "Restarts the outer loop from its beginning" }
      ],
      "correct": "b",
      "explanation": "A labeled break targets the labeled loop specifically — execution jumps past that loop entirely, which is exactly what's needed to abort a nested search the moment a match is found."
    }
  ]
}
```

## What's next

The module quiz below covers all four control-flow topics together — branching, switch, loops, and break/continue/labels — before you move on to **object-oriented basics**, where TaskFlow's tasks become real classes.
$md$, 20, $json$[{"id":"control-flow-break-continue-labels-q1","type":"mcq","correct":"b"},{"id":"control-flow-break-continue-labels-q2","type":"mcq","correct":"b"},{"id":"control-flow-break-continue-labels-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d4b4ea90-a676-573e-bfea-ce68a61665fe', '00000000-0000-0000-0000-000000000001', 'mcq', 'TaskFlow code compares two task status Strings with `status == "DONE"` instea...', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c4476d66-a618-5806-8d85-69dcda578ef1', 'd4b4ea90-a676-573e-bfea-ce68a61665fe', 1, $json${"prompt":"TaskFlow code compares two task status Strings with `status == \"DONE\"` instead of `status.equals(\"DONE\")`. What's the risk?","multiple":false,"options":[{"id":"a","text":"No risk — == and .equals() always behave identically for String","is_correct":false},{"id":"b","text":"== may return false for Strings with identical content if they aren't the same object in memory","is_correct":true},{"id":"c","text":"== throws a NullPointerException whenever used on a String","is_correct":false},{"id":"d","text":"It's a compile error to use == on String values","is_correct":false}],"explanation":"== compares object references, not content. Two String variables can hold the same text but be different objects, so == can return false when .equals() would correctly return true."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8bdf5881-1615-54ce-9d20-037270d4bed9', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why can `String label = score >= 5 ? "HIGH" : "LOW";` be written on one line,...', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('73718eac-b0f9-55dc-85e9-aa1b9468df76', '8bdf5881-1615-54ce-9d20-037270d4bed9', 1, $json${"prompt":"Why can `String label = score \u003e= 5 ? \"HIGH\" : \"LOW\";` be written on one line, unlike an equivalent if/else?","multiple":false,"options":[{"id":"a","text":"The ternary operator is a statement, just like if/else","is_correct":false},{"id":"b","text":"The ternary operator is an expression that evaluates to a value, so it can appear on the right side of an assignment","is_correct":true},{"id":"c","text":"String assignments always require a single line in Java","is_correct":false},{"id":"d","text":"It only works because both branches return the same literal length","is_correct":false}],"explanation":"condition ? a : b evaluates to a value in place, which is why it fits directly into an assignment. if/else is a statement — it controls flow but doesn't produce a value itself."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cd4c7e58-feb4-538c-b216-f7e9abf3aba4', '00000000-0000-0000-0000-000000000001', 'mcq', 'A classic switch case has code but no break, and its condition matches. What ...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f9cc534a-efe8-5089-aec5-948ed877f9d7', 'cd4c7e58-feb4-538c-b216-f7e9abf3aba4', 1, $json${"prompt":"A classic switch case has code but no break, and its condition matches. What happens next?","multiple":false,"options":[{"id":"a","text":"The switch exits immediately, identical to having a break","is_correct":false},{"id":"b","text":"Execution falls through into the following case's code, regardless of whether that case's label matches","is_correct":true},{"id":"c","text":"A runtime exception is thrown","is_correct":false},{"id":"d","text":"The switch skips to the default case","is_correct":false}],"explanation":"Classic switch has no implicit break. Without one, execution keeps running straight into the next case's statements — this is fall-through, and it's the single most common classic-switch bug."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9fb3fd35-4307-5dfe-b142-321a819a73db', '00000000-0000-0000-0000-000000000001', 'mcq', 'While scanning tasks nested inside projects with two for loops, a plain (unla...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('258d5e02-338b-5dc9-9770-c0bf30705b68', '9fb3fd35-4307-5dfe-b142-321a819a73db', 1, $json${"prompt":"While scanning tasks nested inside projects with two for loops, a plain (unlabeled) break inside the inner loop only stops the inner loop — the outer loop keeps going. What fixes this?","multiple":false,"options":[{"id":"a","text":"Using continue instead of break","is_correct":false},{"id":"b","text":"Labeling the outer loop and using break with that label from inside the inner loop","is_correct":true},{"id":"c","text":"Nothing — break always exits every enclosing loop","is_correct":false},{"id":"d","text":"Switching the inner loop to a while loop","is_correct":false}],"explanation":"An unlabeled break only exits the loop it's directly written inside. A label on the outer loop, combined with `break label;`, lets you exit both loops at once from deep inside the nested search."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('67269706-99c1-50c2-b370-ecb9e278afbe', '00000000-0000-0000-0000-000000000001', 'coding', 'TaskFlow needs to classify a task''s priority. Read a single integer from stdi...', 'beginner', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('da4c6f8d-01c1-5dd2-a1e4-16a678f6a289', '67269706-99c1-50c2-b370-ecb9e278afbe', 1, $json${"prompt":"TaskFlow needs to classify a task's priority. Read a single integer from stdin (1 through 5). Print exactly one word: \"LOW\" for 1 or 2, \"MEDIUM\" for 3 or 4, and \"HIGH\" for 5. No extra text.","languages":["java"],"starter_code":{"java":"import java.util.Scanner;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        int priority = scanner.nextInt();\n        // TODO: print LOW for 1-2, MEDIUM for 3-4, HIGH for 5\n\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"1","expected":"LOW","hidden":false,"weight":1},{"id":"t2","stdin":"2","expected":"LOW","hidden":false,"weight":1},{"id":"t3","stdin":"3","expected":"MEDIUM","hidden":true,"weight":1},{"id":"t4","stdin":"4","expected":"MEDIUM","hidden":true,"weight":1},{"id":"t5","stdin":"5","expected":"HIGH","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('46764cd7-ef3c-543b-932d-249ef63780ac', '00000000-0000-0000-0000-000000000001', 'subjective', 'In your own words: which single concept from this module (if/else and the ter...', 'beginner', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('08d54068-3917-5f6b-add0-d77655c23f23', '46764cd7-ef3c-543b-932d-249ef63780ac', 1, $json${"prompt":"In your own words: which single concept from this module (if/else and the ternary operator, classic vs. arrow switch, the four loop forms, or break/continue/labeled loops) felt least intuitive to you, and why? Be specific about what confused you — this answer feeds directly into what gets flagged for extra review.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('f48fa80e-73af-5632-96ef-4e9eee9795a4', '00000000-0000-0000-0000-000000000001', 'Module Assessment: Control Flow', 'java-mastery-control-flow-quiz', 'Quiz covering Control Flow.', 'mixed', 'published', 'module', '09768de8-c574-5406-ad53-eb82dda41f6f', 20, 70, 5, 11, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('e987896c-22e8-542c-9a32-02f5a194cc71', 'f48fa80e-73af-5632-96ef-4e9eee9795a4', 'd4b4ea90-a676-573e-bfea-ce68a61665fe', 'c4476d66-a618-5806-8d85-69dcda578ef1', 0, 1),
('1dc507a2-af1f-5e81-b3fb-0b3c724e6e9b', 'f48fa80e-73af-5632-96ef-4e9eee9795a4', '8bdf5881-1615-54ce-9d20-037270d4bed9', '73718eac-b0f9-55dc-85e9-aa1b9468df76', 1, 1),
('312aa916-feeb-52ae-9496-2dd716078070', 'f48fa80e-73af-5632-96ef-4e9eee9795a4', 'cd4c7e58-feb4-538c-b216-f7e9abf3aba4', 'f9cc534a-efe8-5089-aec5-948ed877f9d7', 2, 2),
('e8f03c53-581a-59a0-9801-4d06c6c0ad20', 'f48fa80e-73af-5632-96ef-4e9eee9795a4', '9fb3fd35-4307-5dfe-b142-321a819a73db', '258d5e02-338b-5dc9-9770-c0bf30705b68', 3, 2),
('6beb7ac1-60cb-5148-9656-69338a352d98', 'f48fa80e-73af-5632-96ef-4e9eee9795a4', '67269706-99c1-50c2-b370-ecb9e278afbe', 'da4c6f8d-01c1-5dd2-a1e4-16a678f6a289', 4, 3),
('a085863a-eed9-5ad3-8d4b-a42fec9e8298', 'f48fa80e-73af-5632-96ef-4e9eee9795a4', '46764cd7-ef3c-543b-932d-249ef63780ac', '08d54068-3917-5f6b-add0-d77655c23f23', 5, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('09768de8-c574-5406-ad53-eb82dda41f6f', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '0a1568fb-eae1-5692-9d3e-8035568fb4d8', 'Module Assessment: Control Flow', 'assessment', 4, 20, 'f48fa80e-73af-5632-96ef-4e9eee9795a4')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: OOP Basics
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('786686a6-acde-511a-bc38-d9ee94637e39', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'OOP Basics', 3)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('394d0139-5549-525b-b69c-add83f522748', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '786686a6-acde-511a-bc38-d9ee94637e39', 'Classes and Objects', 'notes', 0, $md$Every TaskFlow task so far has been loose data — a `String` here, an `int` there, passed around independently. A **class** bundles related data (fields) and behavior (methods) into one reusable blueprint. An **object** is a specific instance created from that blueprint, with its own copy of the fields. This is the shift from "a bunch of variables that happen to describe a task" to "an actual `Task`."

## Defining a class

```java
public class Main {
    public static void main(String[] args) {
        Task schemaTask = new Task("Design database schema", 6);
        Task testTask = new Task("Write integration tests", 4);

        System.out.println(schemaTask.name + " — " + schemaTask.estimatedHours + "h");
        System.out.println(testTask.name + " — " + testTask.estimatedHours + "h");
    }
}

class Task {
    String name;
    int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }
}
```

`class Task { ... }` defines the blueprint: two fields (`name`, `estimatedHours`) and a **constructor** — a special method with the same name as the class and no return type, called automatically by `new` to set up a fresh object. Inside the constructor, `this.name` refers to the field, while plain `name` refers to the constructor's parameter; `this` is what disambiguates them when the names collide, which they usually do on purpose for readability.

A Java source file can hold more than one top-level class, but only one of them may be `public`, and it must match the filename — that's why `Main` is `public` here and `Task` isn't. This is exactly the pattern you'll use throughout this module: one runnable `Main` alongside the class or classes it's demonstrating, all in a single file.

`new Task("Design database schema", 6)` does three things: allocates memory for a new `Task` object, runs the constructor to initialize its fields, and returns a reference to that object, which gets stored in `schemaTask`.

## Objects have both state and behavior

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Deploy to production", 3);
        task.printSummary();
    }
}

class Task {
    String name;
    int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    void printSummary() {
        System.out.println("[" + estimatedHours + "h] " + name);
    }
}
```

`printSummary()` is an **instance method** — it operates on the fields of whichever `Task` object it's called on (`task.printSummary()` uses `task`'s own `name` and `estimatedHours`). This is the core idea of OOP: instead of writing a free-standing function that takes a task's data as parameters, the behavior lives *with* the data it acts on.

## Each object has its own independent state

```java
public class Main {
    public static void main(String[] args) {
        Task task1 = new Task("Design schema", 6);
        Task task2 = new Task("Design schema", 6);

        task1.estimatedHours = 8; // mutate task1 only

        System.out.println("task1 hours: " + task1.estimatedHours);
        System.out.println("task2 hours: " + task2.estimatedHours);
        System.out.println("Same object? " + (task1 == task2));
    }
}

class Task {
    String name;
    int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }
}
```

`task1` and `task2` were built from identical arguments, but they are two separate objects with two separate copies of `name` and `estimatedHours` — changing `task1.estimatedHours` has no effect on `task2`. `task1 == task2` prints `false`: for objects, `==` compares **identity** (are these two variables pointing at the same object?), not the content of their fields. That's a preview of a distinction the encapsulation lesson builds on directly.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-basics-classes-and-objects-q1",
      "type": "mcq",
      "prompt": "What is the relationship between a class and an object?",
      "options": [
        { "id": "a", "text": "They are the same thing, just different names" },
        { "id": "b", "text": "A class is the blueprint; an object is a specific instance created from that blueprint" },
        { "id": "c", "text": "An object defines the structure, and a class is a copy of it" },
        { "id": "d", "text": "A class can only ever produce one object" }
      ],
      "correct": "b",
      "explanation": "A class describes what fields and methods every instance will have. Each call to new creates a distinct object — an instance — with its own independent copy of those fields."
    },
    {
      "id": "oop-basics-classes-and-objects-q2",
      "type": "mcq",
      "prompt": "What does `new Task(\"Design schema\", 6)` actually do?",
      "options": [
        { "id": "a", "text": "Only calls the constructor; no memory is allocated" },
        { "id": "b", "text": "Allocates memory for a new object, runs the constructor to initialize its fields, and returns a reference to it" },
        { "id": "c", "text": "Copies an existing Task object's fields into a new variable" },
        { "id": "d", "text": "Declares the Task class for the first time" }
      ],
      "correct": "b",
      "explanation": "new is the operator that creates an object: it allocates space for the new instance, invokes the matching constructor to set up its initial state, and hands back a reference you can store in a variable."
    },
    {
      "id": "oop-basics-classes-and-objects-q3",
      "type": "mcq",
      "prompt": "task1 and task2 are two separate Task objects created with identical constructor arguments. What does task1 == task2 evaluate to?",
      "options": [
        { "id": "a", "text": "true, because their field values are identical" },
        { "id": "b", "text": "false, because == compares object identity, not field content, and they are two distinct objects" },
        { "id": "c", "text": "It causes a compile error" },
        { "id": "d", "text": "It depends on the order the objects were created" }
      ],
      "correct": "b",
      "explanation": "For objects, == checks whether two references point to the exact same object in memory. Two separately-constructed objects are never == to each other, even with identical field values."
    }
  ]
}
```

## What's next

`name` and `estimatedHours` are currently plain public fields — any code anywhere can set `estimatedHours` to a negative number with no pushback. The next lesson covers **encapsulation**: making fields private and controlling access through methods, so a class can protect its own invariants.
$md$, 20, $json$[{"id":"oop-basics-classes-and-objects-q1","type":"mcq","correct":"b"},{"id":"oop-basics-classes-and-objects-q2","type":"mcq","correct":"b"},{"id":"oop-basics-classes-and-objects-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ff53edc9-0957-5907-9066-bb2a3e1bea7d', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '786686a6-acde-511a-bc38-d9ee94637e39', 'Encapsulation', 'notes', 1, $md$The previous lesson's `Task` had public fields — any code, anywhere, could write `task.estimatedHours = -5;` and the class would have no way to stop it. **Encapsulation** means making fields `private` and exposing controlled access through public methods, so the class itself is the only code that can put its fields in an invalid state.

## private fields, public getters and setters

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Refactor auth module", 5);

        task.setEstimatedHours(8);
        System.out.println(task.getName() + ": " + task.getEstimatedHours() + "h");

        task.setEstimatedHours(-3); // invalid — rejected, value stays unchanged
        System.out.println("After invalid update: " + task.getEstimatedHours() + "h");
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        setEstimatedHours(estimatedHours);
    }

    public String getName() {
        return name;
    }

    public int getEstimatedHours() {
        return estimatedHours;
    }

    public void setEstimatedHours(int estimatedHours) {
        if (estimatedHours < 0) {
            System.out.println("Rejected: estimated hours cannot be negative");
            return;
        }
        this.estimatedHours = estimatedHours;
    }
}
```

`private` means only code inside the `Task` class itself can access `name` and `estimatedHours` directly — `task.estimatedHours` from `Main` would no longer even compile. Instead, `getEstimatedHours()` (a **getter**) and `setEstimatedHours(...)` (a **setter**) are the only doors in and out, and the setter can enforce a rule the field alone never could: no negative hours. Notice the constructor calls `setEstimatedHours(estimatedHours)` instead of assigning the field directly, so brand-new objects get the same validation as later updates — one rule, enforced everywhere, instead of duplicated in two places.

This is why direct public field access is considered a design smell: it lets any caller put the object into a state the class never intended to allow, and it means the class can never change how a value is stored or validated later without breaking every piece of code that touched the field directly. A setter is a seam you can add logic to later without changing anyone's calling code.

## Validating on write, not just accepting

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("  ", 4);
        System.out.println("Name was rejected, defaulted to: \"" + task.getName() + "\"");

        task.setName("Write API docs");
        System.out.println("Name updated to: \"" + task.getName() + "\"");
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        setName(name);
        this.estimatedHours = estimatedHours;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        if (name == null || name.trim().isEmpty()) {
            this.name = "Untitled task";
            return;
        }
        this.name = name.trim();
    }
}
```

`setName` rejects blank or `null` names, falling back to a sensible default instead of letting an empty task title slip into the system. This kind of validation is exactly what public fields can't provide — a field assignment (`task.name = "";`) has no way to run a check.

## Read-only fields: a getter with no setter

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task(101, "Migrate database", 6);
        System.out.println("Task #" + task.getId() + ": " + task.getName());
        // task.id = 202; // would not compile: id is private and has no setter
    }
}

class Task {
    private final int id;
    private String name;
    private int estimatedHours;

    Task(int id, String name, int estimatedHours) {
        this.id = id;
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    public int getId() {
        return id;
    }

    public String getName() {
        return name;
    }
}
```

Encapsulation isn't only about validation — it's also about deciding what's mutable at all. `id` is `private final` and set once in the constructor, with only a getter and no setter: it's readable from outside the class but permanently fixed once the object exists, which is exactly right for something like a database-assigned identifier that should never change after creation.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-basics-encapsulation-q1",
      "type": "mcq",
      "prompt": "Why does putting validation logic in a setter (like rejecting negative hours) work better than relying on callers to check values themselves?",
      "options": [
        { "id": "a", "text": "It doesn't — setters and public fields provide identical guarantees" },
        { "id": "b", "text": "The validation runs every time the field changes, from any caller, so the rule can never be bypassed or forgotten" },
        { "id": "c", "text": "Setters are faster to execute than direct field assignment" },
        { "id": "d", "text": "Only setters are allowed to be public in Java" }
      ],
      "correct": "b",
      "explanation": "A setter centralizes the rule inside the class. Every caller, including the constructor, goes through the same check — there's no path to an invalid value that skips validation, unlike relying on each caller to remember to check."
    },
    {
      "id": "oop-basics-encapsulation-q2",
      "type": "mcq",
      "prompt": "A field is declared `private int estimatedHours;` with no direct field access from outside the class. What happens if code outside Task writes `task.estimatedHours = 10;`?",
      "options": [
        { "id": "a", "text": "It works exactly like a public field" },
        { "id": "b", "text": "It compiles but silently does nothing" },
        { "id": "c", "text": "It fails to compile — private fields are only accessible from within the same class" },
        { "id": "d", "text": "It throws a runtime exception" }
      ],
      "correct": "c",
      "explanation": "private restricts access to code inside the declaring class. Any access attempt from outside — including a direct field write — is a compile-time error, not a runtime one."
    },
    {
      "id": "oop-basics-encapsulation-q3",
      "type": "mcq",
      "prompt": "A class exposes getId() but no setId(). What does that design communicate?",
      "options": [
        { "id": "a", "text": "id is a bug and should have a setter added" },
        { "id": "b", "text": "id is intentionally read-only from outside the class — readable, but not meant to change after construction" },
        { "id": "c", "text": "id must be a static field" },
        { "id": "d", "text": "Getters always require a matching setter to compile" }
      ],
      "correct": "b",
      "explanation": "Encapsulation lets a class expose exactly the access it wants — a getter with no setter is a deliberate way to make a value externally readable but immutable once set, which is common for identifiers assigned at creation time."
    }
  ]
}
```

## What's next

The next lesson covers `this` in more depth — including constructor delegation — plus the difference between **static** members (shared across every instance) and **instance** members (one copy per object), using a running count of every `Task` ever created.
$md$, 20, $json$[{"id":"oop-basics-encapsulation-q1","type":"mcq","correct":"b"},{"id":"oop-basics-encapsulation-q2","type":"mcq","correct":"c"},{"id":"oop-basics-encapsulation-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8962bd3a-5dbd-5dc6-862b-15927bb81474', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '786686a6-acde-511a-bc38-d9ee94637e39', 'this, plus static vs. Instance Members', 'notes', 2, $md$Every field and method you've written so far has been an **instance** member — it belongs to a specific object, and each object gets its own copy. `static` members belong to the *class itself*, shared by every instance. `this` is the keyword that refers to "the current object" from inside an instance method or constructor — you've already seen it disambiguate a constructor parameter from a same-named field; there's more to both ideas.

## A static counter shared across every instance

```java
public class Main {
    public static void main(String[] args) {
        Task task1 = new Task("Design schema");
        Task task2 = new Task("Build API");
        Task task3 = new Task("Write tests");

        System.out.println("Tasks created so far: " + Task.getTaskCount());
    }
}

class Task {
    private static int taskCount = 0;

    private String name;

    Task(String name) {
        this.name = name; // this.name is the field; name is the parameter
        taskCount++;
    }

    public static int getTaskCount() {
        return taskCount;
    }
}
```

`taskCount` is `static`, so there is exactly **one** copy of it, shared by every `Task` object — not one per instance. Each constructor call increments the same shared counter, which is why `getTaskCount()` correctly reports `3` after three objects are created. `getTaskCount()` is also `static`: it's called as `Task.getTaskCount()`, through the class name, not through any particular object — it doesn't need `this` because it doesn't operate on any single instance's data.

## `this(...)`: one constructor calling another

```java
public class Main {
    public static void main(String[] args) {
        Task defaultTask = new Task("Untitled");
        Task fullTask = new Task("Deploy to prod", 3);

        System.out.println(defaultTask.describe());
        System.out.println(fullTask.describe());
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name) {
        this(name, 1); // delegates to the other constructor with a default estimate
    }

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    String describe() {
        return name + " (" + estimatedHours + "h)";
    }
}
```

`this(name, 1)` — called as the *first statement* of a constructor — invokes another constructor of the same class instead of duplicating its logic. This is **constructor chaining**: `Task(String name)` doesn't repeat the field assignments; it just supplies a default `estimatedHours` and hands off to the two-argument constructor that already knows how to do the real setup. This keeps validation and initialization logic in one place, the same principle the encapsulation lesson applied to setters.

## static methods vs. instance methods

```java
public class Main {
    public static void main(String[] args) {
        double average = Task.averageHours(6, 4, 9);
        System.out.println("Average estimate: " + average + "h");
    }
}

class Task {
    static double averageHours(int a, int b, int c) {
        return (a + b + c) / 3.0;
    }
}
```

`averageHours` doesn't read or write any particular `Task` object's fields — it's a pure calculation that only depends on its arguments, so it's declared `static` and called through the class name, `Task.averageHours(...)`, with no object required at all. This is the litmus test for `static`: if a method or field's value doesn't depend on which object you're looking at, it belongs on the class, not the instance. `this` is never available inside a `static` method, precisely because there's no guaranteed "current object" to refer to.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-basics-this-and-static-q1",
      "type": "mcq",
      "prompt": "A class has `private static int taskCount = 0;` incremented in every constructor call. After creating 5 Task objects, what does Task.getTaskCount() return, assuming getTaskCount() just returns taskCount?",
      "options": [
        { "id": "a", "text": "0, because static fields never change" },
        { "id": "b", "text": "5 — every instance shares the same single copy of a static field" },
        { "id": "c", "text": "It depends on which Task instance calls it" },
        { "id": "d", "text": "1, because each new object resets the counter" }
      ],
      "correct": "b",
      "explanation": "A static field has exactly one copy, shared across every instance of the class. Each constructor call increments that single shared value, so after 5 objects it correctly reflects 5."
    },
    {
      "id": "oop-basics-this-and-static-q2",
      "type": "mcq",
      "prompt": "What does `this(name, 1);` as the first line of a constructor do?",
      "options": [
        { "id": "a", "text": "Creates a brand-new, separate Task object" },
        { "id": "b", "text": "Calls another constructor of the same class, passing name and 1 as its arguments" },
        { "id": "c", "text": "Assigns 1 to a field named this" },
        { "id": "d", "text": "It's a syntax error — this cannot be called like a method" }
      ],
      "correct": "b",
      "explanation": "this(...) as a constructor's first statement delegates to another constructor overload in the same class, letting one constructor reuse another's initialization logic instead of duplicating it."
    },
    {
      "id": "oop-basics-this-and-static-q3",
      "type": "mcq",
      "prompt": "Why can't a static method use `this`?",
      "options": [
        { "id": "a", "text": "this is only a naming convention with no real meaning" },
        { "id": "b", "text": "A static method belongs to the class, not to any particular object, so there's no 'current instance' for this to refer to" },
        { "id": "c", "text": "this can be used in static methods, this is a trick question" },
        { "id": "d", "text": "static methods can't access any fields at all" }
      ],
      "correct": "b",
      "explanation": "this always refers to the object a method was called on. static methods are invoked through the class itself, with no associated instance, so there is nothing for this to point to."
    }
  ]
}
```

## What's next

The final lesson in this module steps back from any single class to look at **packages** — how Java organizes classes into namespaces, and why splitting TaskFlow's growing codebase into packages like `core`, `service`, and `util` starts to matter well before it feels necessary.
$md$, 20, $json$[{"id":"oop-basics-this-and-static-q1","type":"mcq","correct":"b"},{"id":"oop-basics-this-and-static-q2","type":"mcq","correct":"b"},{"id":"oop-basics-this-and-static-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5bfbc648-6b2c-511c-82cf-5268ad481445', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '786686a6-acde-511a-bc38-d9ee94637e39', 'Packages and Project Structure', 'notes', 3, $md$Every class in this course so far has lived in Java's unnamed **default package** — fine for a single-file example, but untenable for a real project. A **package** is a namespace: a way of grouping related classes together, avoiding name collisions, and controlling which classes are visible to which other classes as a codebase grows past a handful of files.

## The package declaration

A package is declared with a `package` statement as the very first non-comment line of a `.java` file — before any `import` or class definition:

```
package com.taskflow.core;

public class Task {
    // fields, constructor, methods...
}
```

`com.taskflow.core` is just a dotted name — by convention, reversed-domain-style (`com.taskflow`) followed by a module name (`core`). Once declared, every class in that file belongs to the `com.taskflow.core` package, and any other class that wants to use it either needs an `import com.taskflow.core.Task;` statement, or must refer to it by its **fully-qualified name**, `com.taskflow.core.Task`, directly:

```java
public class Main {
    public static void main(String[] args) {
        // Without an import, a class can still be referenced by its fully-qualified
        // name — this is exactly what import java.util.Scanner; saves you from typing:
        java.util.Scanner scanner = new java.util.Scanner(System.in);
        System.out.println("Scanner ready via its fully-qualified name — no import needed");
        scanner.close();
    }
}
```

This is the same mechanism you've been using every time you wrote `import java.util.Scanner;` — `Scanner` lives in the `java.util` package, and the import is just a shorthand so you can write `Scanner` instead of `java.util.Scanner` everywhere in the file.

## Folder structure mirrors the package name exactly

A package isn't just a label — the compiler and `java` command expect the **folder structure on disk to match the package name**, with dots replaced by path separators:

```
src/
└── com/
    └── taskflow/
        ├── core/
        │   ├── Task.java        → package com.taskflow.core;
        │   └── User.java        → package com.taskflow.core;
        ├── service/
        │   └── TaskValidator.java → package com.taskflow.service;
        │                             (imports com.taskflow.core.Task)
        └── util/
            └── DateHelper.java   → package com.taskflow.util;
```

`Task.java`, declaring `package com.taskflow.core;`, must live at `src/com/taskflow/core/Task.java` — not anywhere else. This isn't a style convention the compiler is lenient about; a mismatched folder path is a build error. Classes within the same package can reference each other directly with no `import` needed at all; classes in different packages need an explicit `import` (or a fully-qualified name), and the referenced class needs at least package-visible (or `public`) access.

## Why organize TaskFlow into packages at all

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Ship release notes", 2);
        TaskValidator validator = new TaskValidator();

        System.out.println("Valid: " + validator.isValid(task));
    }
}

// In a real multi-file TaskFlow project, Task would live in com.taskflow.core —
// the fundamental domain objects with no dependencies on the rest of the app.
class Task {
    String name;
    int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }
}

// ...and TaskValidator would live in com.taskflow.service, importing
// com.taskflow.core.Task — service classes depend on core, never the reverse.
class TaskValidator {
    boolean isValid(Task task) {
        return task.estimatedHours > 0 && !task.name.isBlank();
    }
}
```

A handful of classes in one file is manageable without packages — this course's examples have gotten away with it so far. Real TaskFlow has dozens of classes: `Task`, `User`, `Project`, `Team` as core domain objects; `TaskValidator`, `NotificationService`, `AssignmentService` as business logic; `DateHelper`, `StringFormatter` as shared utilities. Splitting these into `core`, `service`, and `util` packages does three concrete things as the codebase grows: it prevents name collisions (two unrelated `Validator` classes in different packages don't conflict), it documents intent (a `core` class with no imports from `service` signals "this doesn't depend on business logic"), and it lets you restrict visibility — a class or method left without an access modifier is package-private, visible only inside its own package, which is a real tool for hiding internal helper classes from the rest of the app.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-basics-packages-q1",
      "type": "mcq",
      "prompt": "Where must the package declaration appear in a .java file?",
      "options": [
        { "id": "a", "text": "Anywhere in the file, order doesn't matter" },
        { "id": "b", "text": "As the first non-comment line, before any import or class definition" },
        { "id": "c", "text": "Only inside the class body" },
        { "id": "d", "text": "After all import statements" }
      ],
      "correct": "b",
      "explanation": "The package statement, when present, must be the first non-comment line in the file — it declares which namespace every class in that file belongs to before anything else is defined."
    },
    {
      "id": "oop-basics-packages-q2",
      "type": "mcq",
      "prompt": "A class declares `package com.taskflow.core;`. Where must its source file live on disk, relative to the source root?",
      "options": [
        { "id": "a", "text": "Anywhere — the package statement is purely documentation" },
        { "id": "b", "text": "At com/taskflow/core/, mirroring the package name with dots replaced by path separators" },
        { "id": "c", "text": "In a single flat folder named com.taskflow.core" },
        { "id": "d", "text": "In a folder named core only" }
      ],
      "correct": "b",
      "explanation": "The compiler and the java launcher require the folder structure to mirror the package name exactly, dots becoming path separators — a mismatch is a build error, not a warning."
    },
    {
      "id": "oop-basics-packages-q3",
      "type": "mcq",
      "prompt": "As TaskFlow grows to dozens of classes, what's a concrete benefit of splitting them into core/service/util packages instead of leaving everything in one namespace?",
      "options": [
        { "id": "a", "text": "It makes the code run faster at execution time" },
        { "id": "b", "text": "It prevents name collisions, documents intent, and lets package-private visibility hide internal helpers from the rest of the app" },
        { "id": "c", "text": "It's required — Java refuses to compile more than 10 classes in one package" },
        { "id": "d", "text": "It removes the need for constructors" }
      ],
      "correct": "b",
      "explanation": "Packages are an organizational and visibility tool, not a performance one: they avoid naming conflicts between unrelated classes, signal dependency direction (core has no business-logic imports), and let package-private classes stay hidden outside their own package."
    }
  ]
}
```

## What's next

With classes, encapsulation, this/static, and packages in hand, you've built real TaskFlow objects for the first time — but every `Task` so far has stood alone. The next module, **advanced OOP**, covers inheritance, polymorphism, abstract classes and interfaces, and the equals/hashCode/toString contract — the tools for building a family of related task types instead of one flat class.
$md$, 20, $json$[{"id":"oop-basics-packages-q1","type":"mcq","correct":"b"},{"id":"oop-basics-packages-q2","type":"mcq","correct":"b"},{"id":"oop-basics-packages-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Advanced OOP
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('6af27360-9589-5cf3-9394-55c5a590d09e', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Advanced OOP', 4)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('82f62a23-4d33-5c7a-9f1d-470961db37b7', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '6af27360-9589-5cf3-9394-55c5a590d09e', 'Inheritance and super', 'notes', 0, $md$Every `Task` so far has been the same shape. Real TaskFlow tasks aren't uniform — an urgent task needs an escalation contact that a normal task doesn't. **Inheritance** lets one class (a subclass) build on another (a superclass), reusing its fields and methods and adding its own on top, instead of copy-pasting `Task` and modifying the copy.

## extends and super(...)

```java
public class Main {
    public static void main(String[] args) {
        Task normalTask = new Task("Update changelog", 2);
        UrgentTask urgentTask = new UrgentTask("Fix production outage", 1, "oncall@taskflow.dev");

        System.out.println(normalTask.getName() + " — " + normalTask.getEstimatedHours() + "h");
        System.out.println(urgentTask.getName() + " — " + urgentTask.getEstimatedHours()
                + "h, escalate to " + urgentTask.getEscalationContact());
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    public String getName() {
        return name;
    }

    public int getEstimatedHours() {
        return estimatedHours;
    }
}

class UrgentTask extends Task {
    private String escalationContact;

    UrgentTask(String name, int estimatedHours, String escalationContact) {
        super(name, estimatedHours); // must be the first statement in the subclass constructor
        this.escalationContact = escalationContact;
    }

    public String getEscalationContact() {
        return escalationContact;
    }
}
```

`class UrgentTask extends Task` declares an **is-a** relationship: every `UrgentTask` is a `Task`, plus something extra. `Task`'s fields are `private`, so `UrgentTask` can't touch `name` or `estimatedHours` directly — instead, `super(name, estimatedHours)` calls `Task`'s constructor to initialize the inherited part of the object. `super(...)` must be the **first statement** in the subclass constructor, because the superclass portion of the object has to be fully constructed before the subclass adds anything on top of it — the compiler enforces this with a hard error, not a warning.

## Inherited methods, used for free

```java
public class Main {
    public static void main(String[] args) {
        UrgentTask task = new UrgentTask("Database failover", 1, "oncall@taskflow.dev");
        task.notifyOnCall();
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    public String getName() {
        return name;
    }
}

class UrgentTask extends Task {
    private String escalationContact;

    UrgentTask(String name, int estimatedHours, String escalationContact) {
        super(name, estimatedHours);
        this.escalationContact = escalationContact;
    }

    void notifyOnCall() {
        // getName() is inherited from Task — UrgentTask never had to redefine it
        System.out.println("Paging " + escalationContact + " about: " + getName());
    }
}
```

`UrgentTask` never declares `getName()` — it doesn't need to. Every `public` (and `protected`) method on `Task` is automatically available on `UrgentTask` too, called exactly as if it had been declared there. This is the payoff of inheritance: shared behavior is written once, in the superclass, and every subclass gets it without repetition.

## super.method(): reaching the parent's version

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Renew SSL cert", 1);
        UrgentTask urgent = new UrgentTask("Payment gateway down", 1, "oncall@taskflow.dev");

        System.out.println(task.describe());
        System.out.println(urgent.describe());
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    String describe() {
        return name + " (" + estimatedHours + "h)";
    }
}

class UrgentTask extends Task {
    private String escalationContact;

    UrgentTask(String name, int estimatedHours, String escalationContact) {
        super(name, estimatedHours);
        this.escalationContact = escalationContact;
    }

    @Override
    String describe() {
        return super.describe() + " [URGENT — escalate to " + escalationContact + "]";
    }
}
```

`UrgentTask` **overrides** `describe()` here — redefining a method it inherited, rather than adding a new one. `super.describe()` inside the override calls `Task`'s original version explicitly, so `UrgentTask` can build on the parent's output instead of duplicating it. `@Override` is optional but strongly recommended: it tells the compiler "I intend to override an inherited method," and the compiler will flag an error if the signature doesn't actually match anything in the superclass — catching typos that would otherwise silently create an unrelated new method instead of overriding.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-advanced-inheritance-and-super-q1",
      "type": "mcq",
      "prompt": "Where must a call to super(...) appear in a subclass constructor?",
      "options": [
        { "id": "a", "text": "Anywhere, order doesn't matter" },
        { "id": "b", "text": "As the first statement — the superclass portion of the object must be initialized before the subclass adds to it" },
        { "id": "c", "text": "As the last statement" },
        { "id": "d", "text": "It's optional and can be omitted even when the superclass has no no-argument constructor" }
      ],
      "correct": "b",
      "explanation": "The compiler requires super(...) to be the first statement in a subclass constructor, since the inherited part of the object has to exist before subclass-specific initialization runs on top of it."
    },
    {
      "id": "oop-advanced-inheritance-and-super-q2",
      "type": "mcq",
      "prompt": "class UrgentTask extends Task declares what kind of relationship?",
      "options": [
        { "id": "a", "text": "A has-a relationship — UrgentTask contains a Task" },
        { "id": "b", "text": "An is-a relationship — every UrgentTask is also a Task, plus additional behavior" },
        { "id": "c", "text": "No relationship; extends only affects imports" },
        { "id": "d", "text": "UrgentTask replaces Task entirely at compile time" }
      ],
      "correct": "b",
      "explanation": "extends establishes inheritance, an is-a relationship: a UrgentTask object is also a valid Task — it inherits Task's public and protected members and can be used anywhere a Task is expected."
    },
    {
      "id": "oop-advanced-inheritance-and-super-q3",
      "type": "mcq",
      "prompt": "Inside an overriding method, what does super.describe() do?",
      "options": [
        { "id": "a", "text": "Calls the overriding method's own version again, causing infinite recursion" },
        { "id": "b", "text": "Calls the superclass's original implementation of describe(), rather than the override" },
        { "id": "c", "text": "It's a compile error to call super inside an override" },
        { "id": "d", "text": "Creates a new Task object" }
      ],
      "correct": "b",
      "explanation": "super.method() explicitly invokes the superclass's version of a method from within an override, letting the subclass build on the parent's behavior instead of duplicating or completely replacing it."
    }
  ]
}
```

## What's next

The next lesson goes deeper into overriding — plus its easily-confused cousin, **overloading** — and shows how a `Task[]` holding a mix of `Task` and `UrgentTask` objects can call one overridden method and get different behavior depending on each object's actual runtime type.
$md$, 20, $json$[{"id":"oop-advanced-inheritance-and-super-q1","type":"mcq","correct":"b"},{"id":"oop-advanced-inheritance-and-super-q2","type":"mcq","correct":"b"},{"id":"oop-advanced-inheritance-and-super-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('173a7428-a1ef-5cbe-9917-609db63903b1', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '6af27360-9589-5cf3-9394-55c5a590d09e', 'Overriding vs. Overloading, and Polymorphism', 'notes', 1, $md$"Overriding" and "overloading" sound alike and get confused constantly, but they're different mechanisms solving different problems. Overriding is what makes **polymorphism** work — the ability to call one method through a supertype reference and get behavior that depends on the object's real, runtime type.

## Overriding: redefining an inherited method

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Write release notes", 2);
        System.out.println(task); // implicitly calls toString()
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    @Override
    public String toString() {
        return "Task{name='" + name + "', estimatedHours=" + estimatedHours + "}";
    }
}
```

Every class in Java implicitly extends `Object`, which defines a default `toString()` that produces something unhelpful like `Task@1b6d3586`. **Overriding** replaces that inherited implementation with your own — same method name, same parameter list, same return type, just a new body. `System.out.println(task)` calls `task.toString()` automatically whenever an object is used where a `String` is expected, which is why overriding `toString()` pays off immediately: every place that prints a `Task` gets the readable version for free.

## Overloading: same name, different parameters

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Fix login bug", 3);

        task.reassign("Priya");
        task.reassign("Priya", "Backend Team");

        System.out.println(task);
    }
}

class Task {
    private String name;
    private int estimatedHours;
    private String assignee;
    private String team;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    void reassign(String assignee) {
        this.assignee = assignee;
        this.team = null;
        System.out.println("Reassigned to " + assignee);
    }

    void reassign(String assignee, String team) {
        this.assignee = assignee;
        this.team = team;
        System.out.println("Reassigned to " + assignee + " on " + team);
    }

    @Override
    public String toString() {
        return "Task{name='" + name + "', assignee='" + assignee + "', team='" + team + "'}";
    }
}
```

**Overloading** is defining multiple methods with the *same name* but *different parameter lists* in the same class — here, two versions of `reassign`, one taking just an assignee, one taking an assignee and a team. The compiler picks which one to call based on the arguments you pass at the call site, resolved entirely at **compile time**. This is fundamentally different from overriding: overloading is about giving one class several ways to call a similarly-named operation; overriding is about a subclass replacing a method it inherited.

| | Overloading | Overriding |
|---|---|---|
| Where | Same class (or subclass adding a new signature) | Subclass redefining an inherited method |
| Signature | Must differ (parameters) | Must match exactly |
| Resolved | Compile time, by argument types | Runtime, by the object's actual type |

## Polymorphism: one call, type-dependent behavior

```java
public class Main {
    public static void main(String[] args) {
        Task[] tasks = {
            new Task("Update dependencies", 2),
            new UrgentTask("Payment gateway down", 1, "oncall@taskflow.dev"),
            new Task("Write onboarding docs", 4)
        };

        for (Task t : tasks) {
            System.out.println(t.describe()); // dispatches to the actual runtime type's version
        }
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    String describe() {
        return name + " (" + estimatedHours + "h)";
    }
}

class UrgentTask extends Task {
    private String escalationContact;

    UrgentTask(String name, int estimatedHours, String escalationContact) {
        super(name, estimatedHours);
        this.escalationContact = escalationContact;
    }

    @Override
    String describe() {
        return super.describe() + " [URGENT]";
    }
}
```

`Task[] tasks` holds a mix of `Task` and `UrgentTask` objects — legal because `UrgentTask` **is a** `Task`. The loop calls `t.describe()` through the `Task` type of the array, but at each iteration, Java dispatches to whichever `describe()` actually belongs to that object's **real** runtime type: the plain `Task` entries print without `[URGENT]`, the `UrgentTask` entry prints with it, even though every element in the loop is typed as `Task`. This is polymorphism: the same line of code, `t.describe()`, produces different behavior depending on what `t` actually points to — decided at runtime, not compile time. It's what lets you write one loop that correctly handles every kind of task TaskFlow will ever add, without an `instanceof` check for each one.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-advanced-overriding-overloading-polymorphism-q1",
      "type": "mcq",
      "prompt": "What distinguishes method overloading from method overriding?",
      "options": [
        { "id": "a", "text": "They are the same thing" },
        { "id": "b", "text": "Overloading is multiple methods with the same name but different parameters in one class; overriding is a subclass redefining an inherited method with the exact same signature" },
        { "id": "c", "text": "Overloading only works with static methods" },
        { "id": "d", "text": "Overriding requires different parameter lists, just like overloading" }
      ],
      "correct": "b",
      "explanation": "Overloading differentiates methods by parameter list within the same class. Overriding requires an identical signature, and only happens across an inheritance relationship, replacing the superclass's behavior."
    },
    {
      "id": "oop-advanced-overriding-overloading-polymorphism-q2",
      "type": "mcq",
      "prompt": "When is it decided which overloaded reassign(...) method a call like task.reassign(\"Priya\") invokes?",
      "options": [
        { "id": "a", "text": "At runtime, based on the object's actual type" },
        { "id": "b", "text": "At compile time, based on the number and types of arguments passed" },
        { "id": "c", "text": "Randomly, whichever overload is declared first" },
        { "id": "d", "text": "It's ambiguous and always a compile error" }
      ],
      "correct": "b",
      "explanation": "Overload resolution happens at compile time: the compiler matches the call site's argument types and count against the available overloads and picks the matching one before the program ever runs."
    },
    {
      "id": "oop-advanced-overriding-overloading-polymorphism-q3",
      "type": "mcq",
      "prompt": "A Task[] array holds a mix of Task and UrgentTask objects. Calling t.describe() inside a loop over that array prints different output for the UrgentTask entries than the plain Task entries. Why?",
      "options": [
        { "id": "a", "text": "The array type is checked at compile time only; describe() always runs Task's version" },
        { "id": "b", "text": "Java dispatches describe() based on each object's actual runtime type, not its declared array type — this is polymorphism" },
        { "id": "c", "text": "It's undefined behavior and shouldn't be relied on" },
        { "id": "d", "text": "UrgentTask objects can't be stored in a Task[] array" }
      ],
      "correct": "b",
      "explanation": "Even though the array and loop variable are typed as Task, method calls on overridden methods are dispatched based on the object's real, runtime type — each element runs its own version of describe()."
    }
  ]
}
```

## What's next

The next lesson covers **abstract classes and interfaces** — two different ways to define a contract that multiple classes can share, tied to how TaskFlow sends notifications through different channels.
$md$, 25, $json$[{"id":"oop-advanced-overriding-overloading-polymorphism-q1","type":"mcq","correct":"b"},{"id":"oop-advanced-overriding-overloading-polymorphism-q2","type":"mcq","correct":"b"},{"id":"oop-advanced-overriding-overloading-polymorphism-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('77fefa82-493e-59cd-b93d-fd05d437a5a0', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '6af27360-9589-5cf3-9394-55c5a590d09e', 'Abstract Classes and Interfaces', 'notes', 2, $md$Inheritance so far has meant "reuse a concrete class's implementation." Sometimes you want to describe a **contract** — a set of behaviors something must support — without committing to how it's implemented, or without forcing unrelated classes into the same inheritance tree. Java gives you two tools for this: **abstract classes** and **interfaces**.

## Interfaces: a pure contract

```java
public class Main {
    public static void main(String[] args) {
        User user = new User("Priya");
        user.notify("You've been assigned: Fix login bug");
    }
}

interface Notifiable {
    void notify(String message); // abstract — every implementer must define this

    default void notifyUrgently(String message) {
        notify("URGENT: " + message); // default method — shared, but overridable
    }
}

class User implements Notifiable {
    private String username;

    User(String username) {
        this.username = username;
    }

    @Override
    public void notify(String message) {
        System.out.println("[to " + username + "] " + message);
    }
}
```

`interface Notifiable` declares `notify(String message)` with no body — any class that `implements Notifiable` **must** provide one, or it won't compile. This is a pure capability contract: "anything `Notifiable` can be told something," with zero assumption about how. `notifyUrgently` is a **default method** (added in Java 8) — it has a body, so implementers get it for free without writing it themselves, though they can still override it if they need different behavior.

## Abstract classes: partial implementation

```java
public class Main {
    public static void main(String[] args) {
        NotificationChannel channel = new EmailChannel("oncall@taskflow.dev");
        channel.dispatch("Database failover triggered");
    }
}

abstract class NotificationChannel {
    private String destination;

    NotificationChannel(String destination) {
        this.destination = destination;
    }

    // Concrete method — shared by every channel, no need to reimplement it
    void dispatch(String message) {
        System.out.println("Dispatching to " + destination + "...");
        send(message);
    }

    // Abstract method — each channel must define how it actually sends
    abstract void send(String message);
}

class EmailChannel extends NotificationChannel {
    EmailChannel(String destination) {
        super(destination);
    }

    @Override
    void send(String message) {
        System.out.println("EMAIL: " + message);
    }
}
```

`abstract class NotificationChannel` mixes both worlds: `dispatch(...)` is a normal concrete method with a body, shared by every subclass exactly as written; `send(...)` is `abstract` — no body, and every concrete subclass must supply one, same as an interface method. The difference from an interface is that `NotificationChannel` also has state (`destination`) and a constructor, and it can share real, reusable logic (`dispatch`'s two-line implementation) rather than just declaring a contract. `new NotificationChannel("...")` would be a compile error — an abstract class can never be instantiated directly, only through a concrete subclass like `EmailChannel`.

## Choosing between them

| | Abstract class | Interface |
|---|---|---|
| Instantiable? | Never | Never |
| Fields with state? | Yes | No instance fields (only constants) |
| Constructor? | Yes | No |
| A class can extend/implement how many? | One abstract class (single inheritance) | Any number of interfaces |
| Use when... | Related classes share real implementation and state, not just a signature | Unrelated classes need to share one capability, regardless of their place in the class hierarchy |

`Task` and `UrgentTask` sharing a constructor and fields — that's the abstract-class shape. `User`, `Team`, and `UrgentTask` all being able to receive a notification, despite having nothing else in common — that's the interface shape, and it's exactly why a class can implement several interfaces at once but extend only one class:

```java
public class Main {
    public static void main(String[] args) {
        UrgentTask task = new UrgentTask("Payment gateway down", "oncall@taskflow.dev");
        task.notify("New urgent task assigned");
        task.log("Task created");
    }
}

interface Notifiable {
    void notify(String message);
}

interface Loggable {
    void log(String entry);
}

class UrgentTask implements Notifiable, Loggable {
    private String name;
    private String escalationContact;

    UrgentTask(String name, String escalationContact) {
        this.name = name;
        this.escalationContact = escalationContact;
    }

    @Override
    public void notify(String message) {
        System.out.println("[to " + escalationContact + "] " + message);
    }

    @Override
    public void log(String entry) {
        System.out.println("[LOG] " + name + ": " + entry);
    }
}
```

`UrgentTask implements Notifiable, Loggable` picks up both contracts at once — something no `extends` clause could do, since Java only allows extending one superclass. Interfaces let unrelated capabilities compose freely; abstract classes let closely related classes share real code.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-advanced-abstract-and-interfaces-q1",
      "type": "mcq",
      "prompt": "Can you write `new NotificationChannel(\"oncall@taskflow.dev\")` if NotificationChannel is declared abstract?",
      "options": [
        { "id": "a", "text": "Yes, abstract only affects subclassing, not instantiation" },
        { "id": "b", "text": "No — abstract classes can never be instantiated directly, only through a concrete subclass" },
        { "id": "c", "text": "Yes, but only if the class has no abstract methods" },
        { "id": "d", "text": "It depends on whether the constructor is public" }
      ],
      "correct": "b",
      "explanation": "An abstract class is explicitly incomplete — it may have unimplemented (abstract) methods — so the compiler forbids instantiating it directly. Only a concrete subclass that implements every abstract method can be instantiated."
    },
    {
      "id": "oop-advanced-abstract-and-interfaces-q2",
      "type": "mcq",
      "prompt": "How many interfaces can a single class implement, compared to how many classes it can extend?",
      "options": [
        { "id": "a", "text": "Exactly one of each" },
        { "id": "b", "text": "Any number of interfaces, but only one superclass" },
        { "id": "c", "text": "Any number of both" },
        { "id": "d", "text": "Only one interface, but any number of superclasses" }
      ],
      "correct": "b",
      "explanation": "Java supports single inheritance of classes (extends one superclass) but multiple implementation of interfaces (implements as many as needed) — this is exactly why interfaces are the tool for giving unrelated classes a shared capability."
    },
    {
      "id": "oop-advanced-abstract-and-interfaces-q3",
      "type": "mcq",
      "prompt": "When should you reach for an abstract class instead of an interface?",
      "options": [
        { "id": "a", "text": "Never — interfaces should always be preferred in modern Java" },
        { "id": "b", "text": "When a group of closely related classes needs to share real implementation and instance state, not just a method signature" },
        { "id": "c", "text": "When you need a class to implement more than one contract at once" },
        { "id": "d", "text": "Abstract classes and interfaces are fully interchangeable, so it never matters" }
      ],
      "correct": "b",
      "explanation": "Abstract classes can hold constructors, fields, and concrete methods that subclasses inherit as-is — useful when related classes genuinely share implementation, not just a contract, which is exactly what interfaces can't provide."
    }
  ]
}
```

## What's next

The final lesson in this module covers the contract every Java object inherits — `equals()`, `hashCode()`, and `toString()` — including why overriding one without the other silently breaks `HashSet` and `HashMap`, plus **enums**, for a fixed, type-safe set of values like a task's status.
$md$, 25, $json$[{"id":"oop-advanced-abstract-and-interfaces-q1","type":"mcq","correct":"b"},{"id":"oop-advanced-abstract-and-interfaces-q2","type":"mcq","correct":"b"},{"id":"oop-advanced-abstract-and-interfaces-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('315ebf43-bd88-553d-af79-915e741258b6', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '6af27360-9589-5cf3-9394-55c5a590d09e', 'equals, hashCode, toString, and Enums', 'notes', 3, $md$Every class implicitly extends `Object`, which provides default `equals()` (identity comparison, same as `==`), `hashCode()` (an identity-based number), and `toString()` (an unhelpful `ClassName@hexhash`). Overriding these correctly — together — is one of the most consequential things a class can get right or wrong, because collections like `HashSet` and `HashMap` depend on them working as a pair.

## Overriding equals, hashCode, and toString together

```java
import java.util.Objects;

public class Main {
    public static void main(String[] args) {
        Task task1 = new Task(101, "Design schema");
        Task task2 = new Task(101, "Design schema");

        System.out.println("task1 == task2: " + (task1 == task2));           // false — different objects
        System.out.println("task1.equals(task2): " + task1.equals(task2));   // true — same id
        System.out.println("Same hashCode: " + (task1.hashCode() == task2.hashCode()));
        System.out.println(task1);
    }
}

class Task {
    private int id;
    private String name;

    Task(int id, String name) {
        this.id = id;
        this.name = name;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (!(obj instanceof Task)) return false;
        Task other = (Task) obj;
        return id == other.id;
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }

    @Override
    public String toString() {
        return "Task#" + id + " (" + name + ")";
    }
}
```

`equals()` here defines *logical* equality: two `Task` objects are equal if their `id` matches, regardless of whether they're the same object in memory. `==` still reports `false` (different objects), while `.equals()` correctly reports `true`. `hashCode()` is overridden to match: `Objects.hash(id)` produces a number derived from the same field `equals()` uses, so two objects that are `.equals()` to each other are **guaranteed** to have the same `hashCode()` too — that guarantee is the whole contract, and it's not optional.

## Why the contract matters: HashSet needs both

```java
import java.util.HashSet;
import java.util.Objects;
import java.util.Set;

public class Main {
    public static void main(String[] args) {
        Set<Task> seen = new HashSet<>();
        seen.add(new Task(101, "Design schema"));
        seen.add(new Task(101, "Design schema")); // logically the same task
        seen.add(new Task(102, "Build API"));

        System.out.println("Unique tasks tracked: " + seen.size()); // 2, not 3
    }
}

class Task {
    private int id;
    private String name;

    Task(int id, String name) {
        this.id = id;
        this.name = name;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (!(obj instanceof Task)) return false;
        Task other = (Task) obj;
        return id == other.id;
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }
}
```

`HashSet` uses `hashCode()` first to pick a bucket, then `equals()` to check for a match within that bucket — both steps have to agree for de-duplication to work. With both overridden consistently, adding the same logical task twice correctly collapses to one entry: `seen.size()` is `2`.

## The broken version: equals without hashCode

```java
import java.util.HashSet;
import java.util.Set;

public class Main {
    public static void main(String[] args) {
        Set<Task> seen = new HashSet<>();
        seen.add(new Task(101, "Design schema"));
        seen.add(new Task(101, "Design schema")); // logically the same task

        // hashCode() was never overridden, so these two objects still get
        // different (identity-based) hash codes — HashSet buckets them
        // separately and never even calls equals() to compare them.
        System.out.println("Unique tasks tracked: " + seen.size()); // 2, not 1!
    }
}

class Task {
    private int id;
    private String name;

    Task(int id, String name) {
        this.id = id;
        this.name = name;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (!(obj instanceof Task)) return false;
        Task other = (Task) obj;
        return id == other.id;
        // hashCode() is NOT overridden here — still Object's identity-based version
    }
}
```

This compiles fine — overriding `equals()` alone is legal Java, just broken in practice. Because `hashCode()` still returns a different value for each object, `HashSet` sorts the two logically-equal `Task`s into different buckets and never calls `equals()` to compare them at all — de-duplication silently fails. This is exactly why the rule is: **if you override `equals()`, you must override `hashCode()` to match**, or any hash-based collection built on that class will misbehave in ways that are easy to miss in a quick test and painful to debug in production.

## Enums: a fixed, type-safe set of values

```java
public class Main {
    public static void main(String[] args) {
        TaskStatus status = TaskStatus.IN_PROGRESS;

        System.out.println("Status: " + status);
        System.out.println("Is done? " + (status == TaskStatus.DONE));

        for (TaskStatus s : TaskStatus.values()) {
            System.out.println(" - " + s + " (ordinal " + s.ordinal() + ")");
        }
    }
}

enum TaskStatus {
    TODO, IN_PROGRESS, DONE
}
```

`enum TaskStatus` declares exactly three possible values — no other `TaskStatus` can ever exist, which the compiler enforces. This beats using a raw `String` for status: `"DONE"` vs `"Done"` vs `"done"` are three different strings but should mean one thing, and a typo like `"DEON"` compiles fine as a `String` but would never compile as `TaskStatus.DEON`. Enum values compare safely with `==` (each value is a single shared constant, so identity comparison is correct and preferred over `.equals()`), and `values()` / `ordinal()` are built in for free — `values()` returns every constant in declaration order, `ordinal()` gives each one's position.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-advanced-equals-hashcode-enums-q1",
      "type": "mcq",
      "prompt": "A class overrides equals() to compare by id, but does not override hashCode(). What breaks?",
      "options": [
        { "id": "a", "text": "Nothing — equals() alone is sufficient for all use cases" },
        { "id": "b", "text": "HashSet/HashMap can silently fail to detect logically-equal objects as duplicates, because it buckets by hashCode first and may never call equals()" },
        { "id": "c", "text": "The class fails to compile" },
        { "id": "d", "text": "equals() itself stops working correctly" }
      ],
      "correct": "b",
      "explanation": "Hash-based collections use hashCode() to pick a bucket before checking equals() within it. If equal objects (per equals()) don't share a hashCode, they can land in different buckets and never be compared — breaking de-duplication and lookups."
    },
    {
      "id": "oop-advanced-equals-hashcode-enums-q2",
      "type": "mcq",
      "prompt": "What must be true for two objects if a.equals(b) returns true, per the equals/hashCode contract?",
      "options": [
        { "id": "a", "text": "a == b must also be true" },
        { "id": "b", "text": "a.hashCode() must equal b.hashCode()" },
        { "id": "c", "text": "a and b must be the exact same object in memory" },
        { "id": "d", "text": "There is no required relationship between equals() and hashCode()" }
      ],
      "correct": "b",
      "explanation": "The contract requires that equal objects (per equals()) produce equal hash codes. The reverse isn't required — unequal objects can share a hash code (a collision) — but equal objects sharing different hash codes breaks hash-based collections."
    },
    {
      "id": "oop-advanced-equals-hashcode-enums-q3",
      "type": "mcq",
      "prompt": "Why compare enum values with == instead of .equals()?",
      "options": [
        { "id": "a", "text": "== does not work on enums at all" },
        { "id": "b", "text": "Each enum constant is a single shared instance, so == correctly and safely compares them by identity" },
        { "id": "c", "text": ".equals() is always faster for enums" },
        { "id": "d", "text": "== on enums performs a String comparison under the hood" }
      ],
      "correct": "b",
      "explanation": "Enum constants are singletons — there is exactly one TaskStatus.DONE object for the entire program — so == correctly identifies matches and is the idiomatic, null-safe way to compare enum values."
    },
    {
      "id": "oop-advanced-equals-hashcode-enums-q4",
      "type": "mcq",
      "prompt": "What's an advantage of using an enum TaskStatus { TODO, IN_PROGRESS, DONE } over representing status as a String?",
      "options": [
        { "id": "a", "text": "Enums use less memory than any String" },
        { "id": "b", "text": "The compiler guarantees only the declared values can ever exist — a typo like \"DEON\" simply won't compile" },
        { "id": "c", "text": "Enums can hold an unlimited, dynamically-changing set of values" },
        { "id": "d", "text": "There is no real advantage; they're interchangeable" }
      ],
      "correct": "b",
      "explanation": "A String field allows any text, including typos or inconsistent casing, all of which compile without complaint. An enum restricts the value to a fixed, compiler-checked set — invalid values are caught before the program ever runs."
    }
  ]
}
```

## What's next

The module quiz below checks your understanding of inheritance, overriding/overloading/polymorphism, abstract classes vs. interfaces, and the equals/hashCode/enum material together, before you move on to **arrays and strings** — TaskFlow's data structures in depth.
$md$, 25, $json$[{"id":"oop-advanced-equals-hashcode-enums-q1","type":"mcq","correct":"b"},{"id":"oop-advanced-equals-hashcode-enums-q2","type":"mcq","correct":"b"},{"id":"oop-advanced-equals-hashcode-enums-q3","type":"mcq","correct":"b"},{"id":"oop-advanced-equals-hashcode-enums-q4","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b0d2bfd8-a23f-5702-bea4-e400e4c26af8', '00000000-0000-0000-0000-000000000001', 'mcq', 'UrgentTask extends Task. Where must the call to super(...) appear inside Urge...', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dc3c0e33-b1a8-5035-be02-b12a9c36dbb7', 'b0d2bfd8-a23f-5702-bea4-e400e4c26af8', 1, $json${"prompt":"UrgentTask extends Task. Where must the call to super(...) appear inside UrgentTask's constructor?","multiple":false,"options":[{"id":"a","text":"As the first statement in the constructor","is_correct":true},{"id":"b","text":"As the last statement in the constructor","is_correct":false},{"id":"c","text":"Anywhere, order doesn't matter","is_correct":false},{"id":"d","text":"It's never required, even when Task has no no-argument constructor","is_correct":false}],"explanation":"The superclass portion of an object must be fully initialized before the subclass adds anything on top, so super(...) is required to be the first statement in a subclass constructor."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d7d1493d-5bdb-5c77-a6d2-d95c5ff2b5cc', '00000000-0000-0000-0000-000000000001', 'mcq', 'What''s the key difference in how overriding and overloading are resolved?', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('337de8ba-9eb4-574f-8cbb-3026842143c4', 'd7d1493d-5bdb-5c77-a6d2-d95c5ff2b5cc', 1, $json${"prompt":"What's the key difference in how overriding and overloading are resolved?","multiple":false,"options":[{"id":"a","text":"Both are resolved identically, at compile time","is_correct":false},{"id":"b","text":"Overloading is resolved at compile time by argument types; overriding is resolved at runtime by the object's actual type","is_correct":true},{"id":"c","text":"Overriding is resolved at compile time; overloading is resolved at runtime","is_correct":false},{"id":"d","text":"Neither is ever resolved until the JVM shuts down","is_correct":false}],"explanation":"Overload resolution picks a method signature at compile time based on argument types. Overridden methods are dispatched at runtime based on the real type of the object a reference points to — this is what makes polymorphism work."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dce24e07-ca7c-569f-904b-afb7e6267146', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why can a class implement multiple interfaces but extend only one abstract (o...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8df2fd55-bbec-5bd7-b7d8-78fa4aa6ba72', 'dce24e07-ca7c-569f-904b-afb7e6267146', 1, $json${"prompt":"Why can a class implement multiple interfaces but extend only one abstract (or any) class?","multiple":false,"options":[{"id":"a","text":"Interfaces and abstract classes are functionally identical, this is arbitrary","is_correct":false},{"id":"b","text":"Java supports multiple implementation of interfaces but only single inheritance of classes, by design","is_correct":true},{"id":"c","text":"A class can actually extend multiple classes too, this is a common misconception","is_correct":false},{"id":"d","text":"Interfaces can only be implemented one at a time as well","is_correct":false}],"explanation":"Java deliberately allows a class to implement any number of interfaces (composing multiple capabilities) while restricting it to a single superclass (avoiding the ambiguity of multiple concrete implementation inheritance)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('49bcb612-5f6f-5ac7-9c2b-af39cfedf300', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Task class overrides equals() to compare by id but leaves hashCode() as Obj...', 'advanced', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('39a36c81-6172-5507-b012-3acbca6cbbd3', '49bcb612-5f6f-5ac7-9c2b-af39cfedf300', 1, $json${"prompt":"A Task class overrides equals() to compare by id but leaves hashCode() as Object's default. Two logically-equal Task objects are added to a HashSet. What happens?","multiple":false,"options":[{"id":"a","text":"The HashSet correctly recognizes them as duplicates and stores only one","is_correct":false},{"id":"b","text":"Both get added — different default hashCodes route them to different buckets, so equals() is never even called to compare them","is_correct":true},{"id":"c","text":"The program throws an exception at runtime","is_correct":false},{"id":"d","text":"It fails to compile, since equals() requires a matching hashCode() override","is_correct":false}],"explanation":"HashSet buckets by hashCode() first. Without a matching override, two equals()-equal objects can still get different hash codes, land in different buckets, and never be compared — silently breaking de-duplication."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('da525952-fc78-5a88-af51-c0b6da84ed99', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why is it both safe and idiomatic to compare two TaskStatus enum values with ...', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2ed180a4-44b0-5517-b0f2-e847100544fc', 'da525952-fc78-5a88-af51-c0b6da84ed99', 1, $json${"prompt":"Why is it both safe and idiomatic to compare two TaskStatus enum values with ==, unlike comparing two String values?","multiple":false,"options":[{"id":"a","text":"== on enums secretly calls .equals() internally, so they're identical","is_correct":false},{"id":"b","text":"Each enum constant is a single shared instance for the whole program, so identity comparison correctly reflects value equality","is_correct":true},{"id":"c","text":"It isn't actually safe; == should always be avoided for enums too","is_correct":false},{"id":"d","text":"Enums are primitives under the hood, like int","is_correct":false}],"explanation":"There is exactly one object per enum constant (e.g., one single TaskStatus.DONE), so reference equality (==) and logical equality coincide — unlike String, where two equal-content objects can be different instances."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('01439230-4f48-51a7-839b-1d1cb87d2663', '00000000-0000-0000-0000-000000000001', 'coding', 'TaskFlow scores task priority. Read two integers from a single line of input,...', 'intermediate', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4a3141aa-72e1-5171-b89b-7bfd4ba3d86e', '01439230-4f48-51a7-839b-1d1cb87d2663', 1, $json${"prompt":"TaskFlow scores task priority. Read two integers from a single line of input, space-separated: estimated hours, and an urgent flag (1 for urgent, 0 for not). Print a single integer: the effective priority score, computed as hours, plus 10 more if the task is urgent. Print only that number, with no extra text.","languages":["java"],"starter_code":{"java":"import java.util.Scanner;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        int hours = scanner.nextInt();\n        int urgentFlag = scanner.nextInt();\n        // TODO: print hours, plus 10 more if urgentFlag == 1\n\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"5 1","expected":"15","hidden":false,"weight":1},{"id":"t2","stdin":"5 0","expected":"5","hidden":false,"weight":1},{"id":"t3","stdin":"3 1","expected":"13","hidden":true,"weight":1},{"id":"t4","stdin":"8 0","expected":"8","hidden":true,"weight":1},{"id":"t5","stdin":"0 1","expected":"10","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1ef71467-8d61-58dc-bf48-4d3b4512f5d8', '00000000-0000-0000-0000-000000000001', 'subjective', 'In your own words: which single concept from this module (inheritance and sup...', 'beginner', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('731a2e10-588e-5679-b03c-b594d43b8cd6', '1ef71467-8d61-58dc-bf48-4d3b4512f5d8', 1, $json${"prompt":"In your own words: which single concept from this module (inheritance and super, overriding vs. overloading and polymorphism, abstract classes vs. interfaces, or the equals/hashCode/enum contract) felt least intuitive to you, and why? Be specific about what confused you — this answer feeds directly into what gets flagged for extra review.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('d1ad889f-b019-5951-9bae-b619e1513b1d', '00000000-0000-0000-0000-000000000001', 'Module Assessment: Advanced OOP', 'java-mastery-oop-advanced-quiz', 'Quiz covering Advanced OOP.', 'mixed', 'published', 'module', 'cbf1b277-064a-5167-8366-a90b978345ac', 25, 70, 5, 13, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('87c9e591-9364-5b8a-af9f-baefb56b69a3', 'd1ad889f-b019-5951-9bae-b619e1513b1d', 'b0d2bfd8-a23f-5702-bea4-e400e4c26af8', 'dc3c0e33-b1a8-5035-be02-b12a9c36dbb7', 0, 1),
('4d351d22-49a8-59fc-959a-218292984d0e', 'd1ad889f-b019-5951-9bae-b619e1513b1d', 'd7d1493d-5bdb-5c77-a6d2-d95c5ff2b5cc', '337de8ba-9eb4-574f-8cbb-3026842143c4', 1, 2),
('b543f4d0-1458-5325-89a8-24ac4b6c6db2', 'd1ad889f-b019-5951-9bae-b619e1513b1d', 'dce24e07-ca7c-569f-904b-afb7e6267146', '8df2fd55-bbec-5bd7-b7d8-78fa4aa6ba72', 2, 2),
('550cc09c-c84e-5034-afad-a5e2f70b9f68', 'd1ad889f-b019-5951-9bae-b619e1513b1d', '49bcb612-5f6f-5ac7-9c2b-af39cfedf300', '39a36c81-6172-5507-b012-3acbca6cbbd3', 3, 2),
('8cad8659-d0f3-5108-96d0-770dcecdf34f', 'd1ad889f-b019-5951-9bae-b619e1513b1d', 'da525952-fc78-5a88-af51-c0b6da84ed99', '2ed180a4-44b0-5517-b0f2-e847100544fc', 4, 1),
('c02f94fa-688c-5872-a980-dcc4c425f841', 'd1ad889f-b019-5951-9bae-b619e1513b1d', '01439230-4f48-51a7-839b-1d1cb87d2663', '4a3141aa-72e1-5171-b89b-7bfd4ba3d86e', 5, 3),
('89aefb88-640f-582b-bafa-b456aefa95d3', 'd1ad889f-b019-5951-9bae-b619e1513b1d', '1ef71467-8d61-58dc-bf48-4d3b4512f5d8', '731a2e10-588e-5679-b03c-b594d43b8cd6', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('cbf1b277-064a-5167-8366-a90b978345ac', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '6af27360-9589-5cf3-9394-55c5a590d09e', 'Module Assessment: Advanced OOP', 'assessment', 4, 25, 'd1ad889f-b019-5951-9bae-b619e1513b1d')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Arrays & Strings
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('9acdce49-6a77-5258-919e-724f9604bafe', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Arrays & Strings', 5)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b260bb08-68d3-5410-a2df-5c501c021922', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '9acdce49-6a77-5258-919e-724f9604bafe', 'Arrays: Fixed-Size Collections', 'notes', 0, $md$Every TaskFlow feature so far has worked with one value at a time — one task name, one estimate. Real programs need to hold many related values together. An **array** is Java's most basic way to do that: a fixed-size, ordered block of memory holding values of the same type.

## Declaring and creating arrays

```java
public class Main {
    public static void main(String[] args) {
        // Declare and create in one step, with an initializer list
        String[] taskNames = { "Design database schema", "Build REST API", "Write tests" };

        // Declare a fixed size, filled with default values
        double[] estimateHours = new double[3];
        estimateHours[0] = 6.0;
        estimateHours[1] = 10.5;
        estimateHours[2] = 3.0;

        System.out.println("First task: " + taskNames[0]);
        System.out.println("First estimate: " + estimateHours[0] + "h");
    }
}
```

`String[] taskNames` declares an array of `String` — the `[]` can go after the type (`String[] taskNames`, the conventional style) or after the name (`String taskNames[]`, legacy C-style, rarely used in modern Java). `new double[3]` allocates space for exactly 3 `double`s — **array size is fixed at creation time**; you cannot grow or shrink it afterward. Indexing is zero-based: `taskNames[0]` is the first element, `taskNames[2]` is the third and last.

## Default values

When you create an array with `new` but no initializer list, every slot gets a type-appropriate default — not `null` for primitives, an actual zero-equivalent:

```java
public class Main {
    public static void main(String[] args) {
        int[] priorities = new int[4];      // all 0
        boolean[] completed = new boolean[4]; // all false
        double[] hours = new double[4];     // all 0.0
        String[] owners = new String[4];    // all null — String is a reference type

        System.out.println("Default priority: " + priorities[0]);
        System.out.println("Default completed: " + completed[0]);
        System.out.println("Default owner: " + owners[0]);
    }
}
```

Numeric primitive arrays default to `0` (or `0.0`), `boolean` defaults to `false`, and array elements of any **reference type** (`String`, or any object type) default to `null` — there's no "empty" object to fall back to, so the slot simply points at nothing until you assign it.

## `.length` and `ArrayIndexOutOfBoundsException`

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design database schema", "Build REST API", "Write tests" };

        System.out.println("Task count: " + taskNames.length);

        for (int i = 0; i < taskNames.length; i++) {
            System.out.println((i + 1) + ". " + taskNames[i]);
        }

        try {
            System.out.println(taskNames[3]); // valid indices are 0, 1, 2
        } catch (ArrayIndexOutOfBoundsException e) {
            System.out.println("Caught: " + e.getMessage());
        }
    }
}
```

`.length` is a **field**, not a method — no parentheses, unlike `String`'s `.length()`. Valid indices for an array of size `n` run from `0` to `n - 1`; reaching outside that range throws `ArrayIndexOutOfBoundsException` at runtime rather than failing to compile, since the compiler can't generally prove an index stays in bounds. Using `array.length` as the loop bound (rather than a hardcoded number) is the standard way to avoid this bug entirely.

## Arrays hold references, not copies

```java
public class Main {
    public static void main(String[] args) {
        int[] priorities = { 5, 8, 3 };
        int[] alias = priorities; // alias points to the SAME array

        alias[0] = 99;

        System.out.println("priorities[0]: " + priorities[0]); // 99 — same underlying array
    }
}
```

Assigning one array variable to another doesn't copy the elements — both variables reference the same block of memory, so a change through either name is visible through the other. To get an independent copy, use `java.util.Arrays.copyOf(priorities, priorities.length)` — covered when we reach the Collections module's deeper look at references and mutation.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "arrays-strings-arrays-q1",
      "type": "mcq",
      "prompt": "For an array declared as int[] scores = new int[5], what are the valid indices?",
      "options": [
        { "id": "a", "text": "1 through 5" },
        { "id": "b", "text": "0 through 4" },
        { "id": "c", "text": "0 through 5" },
        { "id": "d", "text": "-5 through 5" }
      ],
      "correct": "b",
      "explanation": "An array of size 5 has valid indices 0 through length - 1, i.e. 0 through 4. scores[5] would throw ArrayIndexOutOfBoundsException."
    },
    {
      "id": "arrays-strings-arrays-q2",
      "type": "mcq",
      "prompt": "What is the default value of each element in new String[3]?",
      "options": [
        { "id": "a", "text": "An empty string \"\"" },
        { "id": "b", "text": "null" },
        { "id": "c", "text": "0" },
        { "id": "d", "text": "A compile error, arrays of objects need an initializer" }
      ],
      "correct": "b",
      "explanation": "String is a reference type, so uninitialized array slots default to null, not an empty string. Numeric primitive arrays default to 0/0.0, and boolean defaults to false."
    },
    {
      "id": "arrays-strings-arrays-q3",
      "type": "mcq",
      "prompt": "Given int[] a = {1, 2, 3}; int[] b = a; b[0] = 100;, what is a[0] afterward?",
      "options": [
        { "id": "a", "text": "1, because b is an independent copy" },
        { "id": "b", "text": "100, because a and b reference the same underlying array" },
        { "id": "c", "text": "A runtime exception is thrown" },
        { "id": "d", "text": "0, arrays reset on reassignment" }
      ],
      "correct": "b",
      "explanation": "int[] b = a copies the reference, not the array's contents. Both variable names point at the same memory, so mutating through b is visible through a."
    }
  ]
}
```

## What's next

Arrays don't have to be one-dimensional. The next lesson covers **2D arrays** — grids of values, like a team member's assignment schedule across days of the week.
$md$, 20, $json$[{"id":"arrays-strings-arrays-q1","type":"mcq","correct":"b"},{"id":"arrays-strings-arrays-q2","type":"mcq","correct":"b"},{"id":"arrays-strings-arrays-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3041a729-7137-5c7e-b508-b852e3475407', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '9acdce49-6a77-5258-919e-724f9604bafe', '2D Arrays: Grids of Data', 'notes', 1, $md$A 1D array is a single row of values. Plenty of real data is naturally a **grid** — TaskFlow, for instance, needs to track which team member is assigned to which day of the week. A 2D array is Java's way to model that: an array of arrays.

## Declaring a 2D array

```java
public class Main {
    public static void main(String[] args) {
        // 3 team members (rows) x 5 workdays (columns): hours assigned each day
        int[][] schedule = new int[3][5];

        schedule[0][0] = 4; // member 0, Monday
        schedule[0][1] = 6; // member 0, Tuesday
        schedule[1][2] = 8; // member 1, Wednesday

        System.out.println("Member 0, Monday: " + schedule[0][0] + "h");
        System.out.println("Member 1, Wednesday: " + schedule[1][2] + "h");
        System.out.println("Member 2, Monday (default): " + schedule[2][0] + "h");
    }
}
```

`new int[3][5]` allocates a grid of 3 rows and 5 columns, all defaulted to `0`. `schedule[row][col]` accesses a single cell — the first index picks the row, the second picks the column within that row. Under the hood, a Java 2D array is literally an array of arrays: `schedule` is an `int[3][]` where each of the 3 elements is itself an `int[5]`.

## Initializing with literal values

```java
public class Main {
    public static void main(String[] args) {
        // Rows: Alice, Bob. Columns: Mon, Tue, Wed, Thu, Fri.
        int[][] hoursAssigned = {
            { 4, 6, 0, 8, 2 }, // Alice
            { 0, 5, 5, 5, 5 }  // Bob
        };

        System.out.println("Alice, Thursday: " + hoursAssigned[0][3] + "h");
        System.out.println("Bob, Monday: " + hoursAssigned[1][0] + "h");
        System.out.println("Rows (team members): " + hoursAssigned.length);
        System.out.println("Columns (days): " + hoursAssigned[0].length);
    }
}
```

Each inner `{ ... }` is one row. `hoursAssigned.length` gives the number of rows; `hoursAssigned[0].length` gives the number of columns in row 0 specifically — Java's 2D arrays are technically "jagged" arrays where each row is an independent array, so different rows are allowed to have different lengths (though in a well-formed grid, they typically match).

## Traversing with nested loops

```java
public class Main {
    public static void main(String[] args) {
        String[] members = { "Alice", "Bob" };
        String[] days = { "Mon", "Tue", "Wed", "Thu", "Fri" };
        int[][] hoursAssigned = {
            { 4, 6, 0, 8, 2 },
            { 0, 5, 5, 5, 5 }
        };

        for (int row = 0; row < hoursAssigned.length; row++) {
            int weeklyTotal = 0;
            for (int col = 0; col < hoursAssigned[row].length; col++) {
                weeklyTotal += hoursAssigned[row][col];
            }
            System.out.println(members[row] + ": " + weeklyTotal + "h this week");
        }

        System.out.println("--- Day-by-day breakdown ---");
        for (int col = 0; col < days.length; col++) {
            System.out.print(days[col] + ": ");
            for (int row = 0; row < hoursAssigned.length; row++) {
                System.out.print(members[row] + "=" + hoursAssigned[row][col] + "h ");
            }
            System.out.println();
        }
    }
}
```

The outer loop walks rows, the inner loop walks columns within that row — the standard pattern for visiting every cell exactly once. Which loop is outer versus inner just changes traversal order (row-by-row vs. column-by-column); the second block above swaps them to print a day-by-day view of the same grid instead of a member-by-member one.

## Enhanced for-loop over a 2D array

```java
public class Main {
    public static void main(String[] args) {
        int[][] hoursAssigned = {
            { 4, 6, 0, 8, 2 },
            { 0, 5, 5, 5, 5 }
        };

        int grandTotal = 0;
        for (int[] row : hoursAssigned) {       // each row is itself an int[]
            for (int hours : row) {             // each hours is a single int
                grandTotal += hours;
            }
        }

        System.out.println("Grand total across the team: " + grandTotal + "h");
    }
}
```

`for (int[] row : hoursAssigned)` reads naturally: for each row (an `int[]`) in the grid. Nesting a second enhanced for-loop inside it visits every individual cell without manually tracking indices — cleaner when you don't need the row/column numbers themselves, as here where only the sum matters.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "arrays-strings-two-dimensional-arrays-q1",
      "type": "mcq",
      "prompt": "For int[][] grid = new int[3][5], what does grid[1][4] refer to?",
      "options": [
        { "id": "a", "text": "Row 1, column 4 — a single int" },
        { "id": "b", "text": "An entire row, as an int[]" },
        { "id": "c", "text": "It's out of bounds and throws immediately" },
        { "id": "d", "text": "Row 4, column 1" }
      ],
      "correct": "a",
      "explanation": "grid[1][4] first selects row index 1 (valid: 0-2), then column index 4 within that row (valid: 0-4), yielding a single int. Both indices are in bounds."
    },
    {
      "id": "arrays-strings-two-dimensional-arrays-q2",
      "type": "mcq",
      "prompt": "In Java, what actually is a 2D array like int[][] grid under the hood?",
      "options": [
        { "id": "a", "text": "A single contiguous block that the compiler treats as flat" },
        { "id": "b", "text": "An array whose elements are themselves arrays (an array of int[])" },
        { "id": "c", "text": "A special built-in Matrix type" },
        { "id": "d", "text": "Identical to a List<List<Integer>>" }
      ],
      "correct": "b",
      "explanation": "Java has no true multidimensional array type — int[][] is an array of int[] references. This is why rows can have different lengths (a jagged array) and why grid.length gives row count while grid[0].length gives that row's column count."
    },
    {
      "id": "arrays-strings-two-dimensional-arrays-q3",
      "type": "mcq",
      "prompt": "In `for (int[] row : hoursAssigned) { for (int hours : row) { ... } }`, what type is `row`?",
      "options": [
        { "id": "a", "text": "int" },
        { "id": "b", "text": "int[] — one row of the grid" },
        { "id": "c", "text": "int[][] — the whole grid" },
        { "id": "d", "text": "This is a compile error" }
      ],
      "correct": "b",
      "explanation": "Since hoursAssigned is int[][] (an array of int[]), each element the outer enhanced for-loop yields is one int[] row. The inner loop then iterates the individual int values within that row."
    }
  ]
}
```

## What's next

Grids of numbers are useful, but TaskFlow deals constantly with text — task names, tags, descriptions. The next lesson digs into **Strings**: immutability, and the methods you'll use on them every day.
$md$, 20, $json$[{"id":"arrays-strings-two-dimensional-arrays-q1","type":"mcq","correct":"a"},{"id":"arrays-strings-two-dimensional-arrays-q2","type":"mcq","correct":"b"},{"id":"arrays-strings-two-dimensional-arrays-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9ed20644-6738-5265-9664-a742a5eb82b7', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '9acdce49-6a77-5258-919e-724f9604bafe', 'String Immutability & Common Methods', 'notes', 2, $md$You've been using `String` since the first lesson without a formal introduction. It's time for one — because one property of `String` shapes almost every method it has: **Strings are immutable**. Once created, a `String`'s characters never change.

## Immutability: every "modification" makes a new String

```java
public class Main {
    public static void main(String[] args) {
        String taskName = "design database schema";
        String capitalized = taskName.toUpperCase();

        System.out.println("Original: " + taskName);       // unchanged!
        System.out.println("Capitalized: " + capitalized); // the new String
    }
}
```

`taskName.toUpperCase()` does not modify `taskName` in place — `String` has no method that could, because its internal character data can never change after construction. Instead, it **returns a brand-new `String`** with the transformed content. This trips up beginners constantly: `taskName.toUpperCase();` on its own line, with the result discarded, does nothing observable at all. You must capture the return value, as `capitalized` does above.

## Core inspection methods

```java
public class Main {
    public static void main(String[] args) {
        String taskName = "Build REST API";

        System.out.println("Length: " + taskName.length());               // 15
        System.out.println("Substring(0,5): " + taskName.substring(0, 5)); // "Build"
        System.out.println("Substring(6): " + taskName.substring(6));     // "REST API"
        System.out.println("Index of 'REST': " + taskName.indexOf("REST")); // 6
        System.out.println("Index of 'xyz': " + taskName.indexOf("xyz"));   // -1, not found
        System.out.println("Contains 'API': " + taskName.contains("API"));  // true
    }
}
```

`length()` is a **method** here (unlike an array's `.length` field — a common early mix-up). `substring(start, end)` returns characters from `start` up to but *not including* `end`; `substring(start)` alone runs to the end of the string. `indexOf` returns the character position of the first match, or `-1` if the substring isn't present — always check for `-1` before trusting the result as a real index.

## `equals()` vs. `==` for Strings

```java
public class Main {
    public static void main(String[] args) {
        String a = "Deploy to prod";
        String b = "Deploy to prod";
        String c = new String("Deploy to prod");

        System.out.println("a == b: " + (a == b));           // true (string pool)
        System.out.println("a == c: " + (a == c));           // false! different objects
        System.out.println("a.equals(c): " + a.equals(c));   // true — compares content
    }
}
```

`==` on `String` compares **object references** (are these the same object in memory?), not content. Two string literals with the same text often *do* end up `==` equal, because Java pools literal strings for reuse — but that's an implementation detail you should never rely on, especially once strings come from `new String(...)`, user input, file reads, or concatenation at runtime, where pooling doesn't apply. **Always use `.equals()` to compare String content.** This is one of the most common real-world Java bugs.

## Changing case, and splitting a tag string

```java
public class Main {
    public static void main(String[] args) {
        String tags = "backend,urgent,api";

        System.out.println("Upper: " + tags.toUpperCase());
        System.out.println("Lower: " + tags.toLowerCase());

        String[] tagList = tags.split(",");
        System.out.println("Tag count: " + tagList.length);
        for (String tag : tagList) {
            System.out.println("- " + tag);
        }
    }
}
```

`split(",")` cuts a `String` into a `String[]` wherever the given regex-delimiter appears — here, a comma-separated tag list becomes an array of individual tags, ready to loop over. This is exactly how TaskFlow would parse a raw `"backend,urgent,api"` field pulled from a form or a file into structured data.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "arrays-strings-string-methods-q1",
      "type": "mcq",
      "prompt": "After String s = \"hello\"; s.toUpperCase();, what is s?",
      "options": [
        { "id": "a", "text": "\"HELLO\" — toUpperCase() modifies s in place" },
        { "id": "b", "text": "\"hello\" — unchanged, because Strings are immutable and the return value was discarded" },
        { "id": "c", "text": "A compile error" },
        { "id": "d", "text": "null" }
      ],
      "correct": "b",
      "explanation": "String methods never mutate the original — they return a new String. Since the result of toUpperCase() wasn't assigned to anything here, s is still \"hello\"."
    },
    {
      "id": "arrays-strings-string-methods-q2",
      "type": "mcq",
      "prompt": "Why should you use .equals() instead of == to compare String content?",
      "options": [
        { "id": "a", "text": "== always throws an exception on Strings" },
        { "id": "b", "text": "== compares object references, and two Strings with equal content aren't always the same object (e.g. one built with new String(...))" },
        { "id": "c", "text": ".equals() is faster than ==" },
        { "id": "d", "text": "There's no difference; both check content identically" }
      ],
      "correct": "b",
      "explanation": "== checks whether two references point at the same object. String literals may be pooled and share a reference, but strings built at runtime (new String(...), concatenation, input) typically are not, so relying on == is unreliable — .equals() checks actual character content."
    },
    {
      "id": "arrays-strings-string-methods-q3",
      "type": "mcq",
      "prompt": "What does \"Build REST API\".indexOf(\"xyz\") return?",
      "options": [
        { "id": "a", "text": "0" },
        { "id": "b", "text": "-1" },
        { "id": "c", "text": "Throws an exception" },
        { "id": "d", "text": "null" }
      ],
      "correct": "b",
      "explanation": "indexOf returns -1, not an exception or null, when the substring isn't found. Code that calls indexOf must check for -1 before treating the result as a valid position."
    }
  ]
}
```

## What's next

`+`-concatenating Strings works fine for a line or two, but doing it repeatedly in a loop is quietly wasteful. The next lesson covers `StringBuilder` and proper string formatting for building up TaskFlow reports.
$md$, 20, $json$[{"id":"arrays-strings-string-methods-q1","type":"mcq","correct":"b"},{"id":"arrays-strings-string-methods-q2","type":"mcq","correct":"b"},{"id":"arrays-strings-string-methods-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9dd38ed4-92fd-5882-98de-a4dc268bd936', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '9acdce49-6a77-5258-919e-724f9604bafe', 'StringBuilder & String Formatting', 'notes', 3, $md$The previous lesson established that every `String` "modification" actually builds a brand-new `String`. That's fine for one or two concatenations — but inside a loop, it becomes a real performance problem. This lesson covers the fix, plus proper formatted output.

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
$md$, 20, $json$[{"id":"arrays-strings-stringbuilder-and-formatting-q1","type":"mcq","correct":"b"},{"id":"arrays-strings-stringbuilder-and-formatting-q2","type":"mcq","correct":"b"},{"id":"arrays-strings-stringbuilder-and-formatting-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Exceptions
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('787aab16-66d4-5c26-abd9-7759bd92aa37', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Exceptions', 6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('aa6e7d97-661c-57b7-a214-e61a071929a1', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '787aab16-66d4-5c26-abd9-7759bd92aa37', 'Checked vs. Unchecked Exceptions & try/catch/finally', 'notes', 0, $md$Every program eventually meets bad input, a missing file, or a network failure. Java's answer is **exceptions**: objects that represent something going wrong, thrown at the point of failure and caught wherever it's handled — instead of every function returning an error code that callers might forget to check.

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
$md$, 20, $json$[{"id":"exceptions-try-catch-finally-q1","type":"mcq","correct":"b"},{"id":"exceptions-try-catch-finally-q2","type":"mcq","correct":"c"},{"id":"exceptions-try-catch-finally-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('522577fe-1de0-5732-ab3d-f3a17def238a', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '787aab16-66d4-5c26-abd9-7759bd92aa37', 'try-with-resources', 'notes', 1, $md$The previous lesson showed `finally` guaranteeing cleanup code runs. The single most common thing that cleanup does is **close a resource** — a file, a network connection, a database cursor. That pattern is so common Java has dedicated syntax for it: `try-with-resources`.

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
$md$, 20, $json$[{"id":"exceptions-try-with-resources-q1","type":"mcq","correct":"b"},{"id":"exceptions-try-with-resources-q2","type":"mcq","correct":"b"},{"id":"exceptions-try-with-resources-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('371822ca-7c83-54da-8b60-86aed32777a4', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '787aab16-66d4-5c26-abd9-7759bd92aa37', 'Custom Exceptions & Exception Chaining', 'notes', 2, $md$`IllegalArgumentException` is a reasonable general-purpose exception, but it says nothing specific about what went wrong in TaskFlow's domain. A **custom exception type** lets calling code catch and react to precisely the failure it cares about — "this task doesn't exist" is a very different problem from "this argument was invalid" in general.

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
$md$, 20, $json$[{"id":"exceptions-custom-exceptions-q1","type":"mcq","correct":"b"},{"id":"exceptions-custom-exceptions-q2","type":"mcq","correct":"b"},{"id":"exceptions-custom-exceptions-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('cb698ea8-d33c-58b5-b919-838231009764', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '787aab16-66d4-5c26-abd9-7759bd92aa37', 'Exception-Handling Best Practices', 'notes', 3, $md$Knowing the mechanics of `try`/`catch`/`throw` is only half the story. Exceptions can also be misused in ways that compile fine and quietly make a codebase worse. This lesson covers the habits that keep exception handling honest.

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
$md$, 20, $json$[{"id":"exceptions-best-practices-q1","type":"mcq","correct":"b"},{"id":"exceptions-best-practices-q2","type":"mcq","correct":"b"},{"id":"exceptions-best-practices-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dea26637-e61a-5ce8-83f0-b512b67f278f', '00000000-0000-0000-0000-000000000001', 'mcq', 'What determines whether an exception is checked or unchecked?', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('01054aaa-a2c6-58e1-9159-4756ad303abd', 'dea26637-e61a-5ce8-83f0-b512b67f278f', 1, $json${"prompt":"What determines whether an exception is checked or unchecked?","multiple":false,"options":[{"id":"a","text":"Whether it extends Exception (checked) vs. RuntimeException (unchecked)","is_correct":true},{"id":"b","text":"Whether it has a message string","is_correct":false},{"id":"c","text":"Whether it's thrown inside a try block","is_correct":false},{"id":"d","text":"Whether it's a custom exception or a built-in one","is_correct":false}],"explanation":"Extending RuntimeException (directly or transitively) makes an exception unchecked, meaning the compiler does not require it to be caught or declared. Extending Exception directly makes it checked."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0532da6f-642c-5ab9-8d9d-d03c672a157c', '00000000-0000-0000-0000-000000000001', 'mcq', 'A try block throws an exception that is NOT caught by any matching catch bloc...', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7b0ddcb0-7142-5cc0-8886-b10caeb9ed52', '0532da6f-642c-5ab9-8d9d-d03c672a157c', 1, $json${"prompt":"A try block throws an exception that is NOT caught by any matching catch block. Does the finally block still run?","multiple":false,"options":[{"id":"a","text":"No, finally is skipped entirely if nothing catches the exception","is_correct":false},{"id":"b","text":"Yes, finally always runs before the uncaught exception continues propagating up the call stack","is_correct":true},{"id":"c","text":"Only if the exception is a checked exception","is_correct":false},{"id":"d","text":"Only if System.exit() has not been called","is_correct":false}],"explanation":"finally runs in every case: normal completion, a caught exception, or an exception that propagates uncaught. It's the one block guaranteed to execute regardless of how the try block exits (short of the JVM itself terminating abruptly)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c271b05e-76df-5eca-92ac-9e3e63cd043b', '00000000-0000-0000-0000-000000000001', 'mcq', 'What must a class implement to be used inside try-with-resources parentheses?', 'intermediate', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('55ffc3a7-d47a-56a5-b348-d26419f0fd64', 'c271b05e-76df-5eca-92ac-9e3e63cd043b', 1, $json${"prompt":"What must a class implement to be used inside try-with-resources parentheses?","multiple":false,"options":[{"id":"a","text":"Serializable","is_correct":false},{"id":"b","text":"AutoCloseable","is_correct":true},{"id":"c","text":"Comparable","is_correct":false},{"id":"d","text":"Cloneable","is_correct":false}],"explanation":"Try-with-resources works with any type implementing AutoCloseable (which declares close()). The compiler guarantees close() is invoked automatically when the try block exits, normally or via an exception."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('69b7517d-9757-5c3f-9e45-56a08e6f61e5', '00000000-0000-0000-0000-000000000001', 'mcq', 'A method has catch (RuntimeException e) followed by catch (NumberFormatExcept...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0f59dcbc-ed93-5352-ae99-e5665b350aed', '69b7517d-9757-5c3f-9e45-56a08e6f61e5', 1, $json${"prompt":"A method has catch (RuntimeException e) followed by catch (NumberFormatException e) for the same try block. What happens?","multiple":false,"options":[{"id":"a","text":"It compiles and works fine — order never matters","is_correct":false},{"id":"b","text":"It's a compile error: NumberFormatException is a subtype of RuntimeException, so the second catch is unreachable","is_correct":true},{"id":"c","text":"The NumberFormatException catch silently takes priority at runtime","is_correct":false},{"id":"d","text":"It throws a runtime exception the first time a NumberFormatException occurs","is_correct":false}],"explanation":"Catch blocks are evaluated top to bottom. Since NumberFormatException IS-A RuntimeException, placing the broader RuntimeException catch first means the more specific catch below it can never be reached — Java rejects this at compile time."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('685fb195-ae98-5645-a11a-9ee0c3dfe1a1', '00000000-0000-0000-0000-000000000001', 'mcq', 'A TaskNotFoundException is constructed as new TaskNotFoundException("task mis...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3a1cf0ba-a995-5b03-8079-2a3454b9979f', '685fb195-ae98-5645-a11a-9ee0c3dfe1a1', 1, $json${"prompt":"A TaskNotFoundException is constructed as new TaskNotFoundException(\"task missing\", originalDbError), with originalDbError passed through to super(message, cause). What is the benefit?","multiple":false,"options":[{"id":"a","text":"It makes the exception checked instead of unchecked","is_correct":false},{"id":"b","text":"It preserves the original low-level failure as the cause, retrievable later via getCause(), so debugging can trace the full failure chain","is_correct":true},{"id":"c","text":"It suppresses the original exception so it never appears in logs","is_correct":false},{"id":"d","text":"It has no functional effect, only cosmetic","is_correct":false}],"explanation":"Exception chaining preserves the original cause instead of discarding it when translating a low-level failure into a higher-level, more meaningful exception type. getCause() and full chained stack traces make root-causing far easier."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('755e15fe-82ec-544b-9a04-9d50a1317d20', '00000000-0000-0000-0000-000000000001', 'coding', 'TaskFlow needs to validate an hours estimate coming from user input. Read a s...', 'intermediate', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b20cac43-c641-523b-93d2-10e7592238d3', '755e15fe-82ec-544b-9a04-9d50a1317d20', 1, $json${"prompt":"TaskFlow needs to validate an hours estimate coming from user input. Read a single integer from stdin representing estimated hours. If the value is negative, catch or detect that condition and print exactly INVALID (no other text). Otherwise, print exactly OK: \u003chours\u003e where \u003chours\u003e is the integer value, e.g. \"OK: 5\".","languages":["java"],"starter_code":{"java":"import java.util.Scanner;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        // Read one integer (hours). If it's negative, print INVALID.\n        // Otherwise print \"OK: \" followed by the hours value.\n\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"5","expected":"OK: 5","hidden":false,"weight":1},{"id":"t2","stdin":"-3","expected":"INVALID","hidden":false,"weight":1},{"id":"t3","stdin":"0","expected":"OK: 0","hidden":true,"weight":1},{"id":"t4","stdin":"100","expected":"OK: 100","hidden":true,"weight":1},{"id":"t5","stdin":"-1","expected":"INVALID","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('68452d95-9085-5505-b183-018218246dc3', '00000000-0000-0000-0000-000000000001', 'subjective', 'In your own words: which single concept from this module (checked vs. uncheck...', 'beginner', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('62d47a03-d32b-5b3a-ad3a-981b2bf8d341', '68452d95-9085-5505-b183-018218246dc3', 1, $json${"prompt":"In your own words: which single concept from this module (checked vs. unchecked exceptions, try-with-resources, custom exceptions and chaining, or exception-handling best practices) felt least intuitive to you, and why? Be specific about what confused you — this answer feeds directly into what gets flagged for extra review.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('e1cb9302-2278-550c-9ee5-1e43fbdd1d5d', '00000000-0000-0000-0000-000000000001', 'Module Assessment: Exceptions', 'java-mastery-exceptions-quiz', 'Quiz covering Exceptions.', 'mixed', 'published', 'module', '0343c192-9c30-5a27-945c-b33a46025af4', 25, 70, 5, 12, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('93f80f7a-97f9-5ab5-8a99-3bf63cf048a0', 'e1cb9302-2278-550c-9ee5-1e43fbdd1d5d', 'dea26637-e61a-5ce8-83f0-b512b67f278f', '01054aaa-a2c6-58e1-9159-4756ad303abd', 0, 1),
('d78c96fd-eb4c-5032-af06-6437e051fafd', 'e1cb9302-2278-550c-9ee5-1e43fbdd1d5d', '0532da6f-642c-5ab9-8d9d-d03c672a157c', '7b0ddcb0-7142-5cc0-8886-b10caeb9ed52', 1, 1),
('46e433bd-deab-5d5c-b6a4-e850be37118f', 'e1cb9302-2278-550c-9ee5-1e43fbdd1d5d', 'c271b05e-76df-5eca-92ac-9e3e63cd043b', '55ffc3a7-d47a-56a5-b348-d26419f0fd64', 2, 1),
('c12c5a5a-290b-58c5-9030-07fe68ecc23d', 'e1cb9302-2278-550c-9ee5-1e43fbdd1d5d', '69b7517d-9757-5c3f-9e45-56a08e6f61e5', '0f59dcbc-ed93-5352-ae99-e5665b350aed', 3, 2),
('4356c827-4b03-5db9-81c8-52fbfd6df291', 'e1cb9302-2278-550c-9ee5-1e43fbdd1d5d', '685fb195-ae98-5645-a11a-9ee0c3dfe1a1', '3a1cf0ba-a995-5b03-8079-2a3454b9979f', 4, 2),
('4c6be5dc-f844-5639-a023-dfb31992b365', 'e1cb9302-2278-550c-9ee5-1e43fbdd1d5d', '755e15fe-82ec-544b-9a04-9d50a1317d20', 'b20cac43-c641-523b-93d2-10e7592238d3', 5, 3),
('1fef8b39-dd62-5ba9-8f68-cc99663d57a9', 'e1cb9302-2278-550c-9ee5-1e43fbdd1d5d', '68452d95-9085-5505-b183-018218246dc3', '62d47a03-d32b-5b3a-ad3a-981b2bf8d341', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('0343c192-9c30-5a27-945c-b33a46025af4', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '787aab16-66d4-5c26-abd9-7759bd92aa37', 'Module Assessment: Exceptions', 'assessment', 4, 25, 'e1cb9302-2278-550c-9ee5-1e43fbdd1d5d')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Collections Framework
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('fffbddf7-506a-52e9-ad39-ee3687665870', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Collections Framework', 7)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('51526e38-4a17-5ef8-a561-b3e346b1e685', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'fffbddf7-506a-52e9-ad39-ee3687665870', 'The Collections Framework & List', 'notes', 0, $md$Arrays have a hard limit: fixed size, set once at creation. TaskFlow's real task list grows and shrinks constantly as tasks are created and completed. The **Collections Framework** — `java.util`'s family of `List`, `Set`, `Map`, and `Queue` — is Java's answer: resizable, richly-featured containers that replace hand-rolled array management.

## From a fixed array to a resizable List

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>();

        taskNames.add("Design database schema");
        taskNames.add("Build REST API");
        taskNames.add("Write tests");

        System.out.println("Task count: " + taskNames.size());
        System.out.println("First task: " + taskNames.get(0));

        taskNames.remove("Build REST API"); // removes by value
        System.out.println("After removal: " + taskNames);
    }
}
```

`List<String>` is an **interface** — the type you should declare variables as. `new ArrayList<>()` is the concrete implementation actually created; the `<>` (diamond operator) lets the compiler infer the generic type from the left side instead of repeating `<String>` twice. `add`, `get`, `remove`, and `size()` replace an array's fixed indexing and `.length` — and unlike an array, the list genuinely grows as you `add()` more elements. Printing a `List` directly (as in the last line) calls its built-in `toString()`, giving readable bracketed output like `[Design database schema, Write tests]`.

## `ArrayList` vs. `LinkedList`

Both implement `List` and support the exact same interface — the choice between them is about **performance characteristics**, not behavior:

| | `ArrayList` | `LinkedList` |
|---|---|---|
| Backed by | A resizable array | A doubly-linked chain of nodes |
| Random access (`get(i)`) | Fast — O(1) | Slow — O(n), must walk from an end |
| Insert/remove at the **start or middle** | Slow — O(n), must shift elements | Fast — O(1), if you already have the node |
| Insert/remove at the **end** | Fast (amortized) O(1) | Fast O(1) |
| Typical choice | The default for almost everything | Rare — only when you truly do frequent start/middle inserts and never need indexed access |

```java
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskQueueArray = new ArrayList<>();
        List<String> taskQueueLinked = new LinkedList<>();

        taskQueueArray.add("Design schema");
        taskQueueArray.add("Build API");
        taskQueueLinked.add("Design schema");
        taskQueueLinked.add("Build API");

        // Both support the same List operations — same interface, different internals.
        System.out.println("ArrayList get(0): " + taskQueueArray.get(0));
        System.out.println("LinkedList get(0): " + taskQueueLinked.get(0));

        taskQueueArray.add(0, "URGENT: Fix outage"); // insert at front — O(n) shift
        taskQueueLinked.add(0, "URGENT: Fix outage"); // insert at front — O(1) for LinkedList

        System.out.println("ArrayList after insert: " + taskQueueArray);
        System.out.println("LinkedList after insert: " + taskQueueLinked);
    }
}
```

In practice, **default to `ArrayList`** — it has better cache locality and faster indexed access, which covers the vast majority of real use cases including TaskFlow's task lists. Reach for `LinkedList` only when profiling shows you specifically need cheap insert/remove at arbitrary positions and rarely index by position.

## Iterating a List

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>();
        taskNames.add("Design schema");
        taskNames.add("Build API");
        taskNames.add("Write tests");

        // Enhanced for-loop: cleanest when you don't need the index
        for (String name : taskNames) {
            System.out.println("- " + name);
        }

        // Indexed loop: use when you need the position too
        for (int i = 0; i < taskNames.size(); i++) {
            System.out.println((i + 1) + ". " + taskNames.get(i));
        }
    }
}
```

The enhanced for-loop works on any `List` (and any `Collection`) exactly like it does on arrays. Reach for the indexed form only when the position itself matters — printing a numbered list, or needing to compare adjacent elements.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "collections-list-q1",
      "type": "mcq",
      "prompt": "What is the key advantage of List<String> over a plain String[] array?",
      "options": [
        { "id": "a", "text": "List elements can never be null" },
        { "id": "b", "text": "A List can grow and shrink dynamically; an array's size is fixed at creation" },
        { "id": "c", "text": "List indexing starts at 1 instead of 0" },
        { "id": "d", "text": "There is no real difference" }
      ],
      "correct": "b",
      "explanation": "Arrays are fixed-size once created. List implementations like ArrayList resize automatically as elements are added or removed — the core reason to reach for a List over a raw array for growing collections."
    },
    {
      "id": "collections-list-q2",
      "type": "mcq",
      "prompt": "Why should ArrayList be the default List choice for most use cases, over LinkedList?",
      "options": [
        { "id": "a", "text": "LinkedList doesn't implement the List interface" },
        { "id": "b", "text": "ArrayList offers fast O(1) indexed access and generally better performance for typical access patterns; LinkedList only wins for frequent insert/remove at arbitrary positions without indexed access" },
        { "id": "c", "text": "LinkedList cannot hold more than a fixed number of elements" },
        { "id": "d", "text": "ArrayList is always faster at every single operation" }
      ],
      "correct": "b",
      "explanation": "ArrayList's array-backed storage gives O(1) get(i) and good cache locality, covering most real workloads. LinkedList only pays off when you specifically need cheap insert/remove in the middle and rarely access by index."
    },
    {
      "id": "collections-list-q3",
      "type": "mcq",
      "prompt": "What does the diamond operator <> do in new ArrayList<>()?",
      "options": [
        { "id": "a", "text": "It's required syntax with no functional purpose" },
        { "id": "b", "text": "It lets the compiler infer the generic type argument from context (e.g. the declared variable type), avoiding repeating it" },
        { "id": "c", "text": "It marks the list as immutable" },
        { "id": "d", "text": "It sets the list's initial capacity to zero" }
      ],
      "correct": "b",
      "explanation": "The diamond operator (Java 7+) lets you write List<String> names = new ArrayList<>(); instead of repeating new ArrayList<String>() — the compiler infers String from the left-hand declaration."
    }
  ]
}
```

## What's next

`List` allows duplicates and preserves insertion order (mostly). The next lesson covers `Set` — for when you specifically need to guarantee no duplicates, like a list of unique team members assigned across tasks.
$md$, 20, $json$[{"id":"collections-list-q1","type":"mcq","correct":"b"},{"id":"collections-list-q2","type":"mcq","correct":"b"},{"id":"collections-list-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('baf51c13-7067-58bd-a716-a73d37dbff91', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'fffbddf7-506a-52e9-ad39-ee3687665870', 'Set: HashSet, LinkedHashSet, TreeSet', 'notes', 1, $md$A `List` happily holds duplicates. Sometimes that's wrong — if TaskFlow collects the names of every team member assigned across a project's tasks, the same person appears on multiple tasks, but the "who's on this project" view should list each name exactly once. That's exactly what `Set` guarantees.

## The core guarantee: no duplicates

```java
import java.util.HashSet;
import java.util.Set;

public class Main {
    public static void main(String[] args) {
        Set<String> assignedMembers = new HashSet<>();

        assignedMembers.add("Alice");
        assignedMembers.add("Bob");
        assignedMembers.add("Alice"); // duplicate — silently ignored
        assignedMembers.add("Carla");

        System.out.println("Unique members: " + assignedMembers.size()); // 3, not 4
        System.out.println("Contains Bob: " + assignedMembers.contains("Bob"));
    }
}
```

Calling `add()` with a value already in the `Set` is a no-op — it returns `false` (which you can check if you care whether the add actually happened) and the set's contents don't change. This is the whole point: dedup happens automatically, without you writing a manual "already in there?" check yourself.

## Three implementations, three ordering guarantees

```java
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.TreeSet;

public class Main {
    public static void main(String[] args) {
        Set<String> hashSet = new HashSet<>();       // no ordering guarantee
        Set<String> linkedHashSet = new LinkedHashSet<>(); // insertion order preserved
        Set<String> treeSet = new TreeSet<>();        // sorted order (natural ordering)

        String[] members = { "Carla", "Alice", "Bob", "Alice" };
        for (String m : members) {
            hashSet.add(m);
            linkedHashSet.add(m);
            treeSet.add(m);
        }

        System.out.println("HashSet (order not guaranteed): " + hashSet);
        System.out.println("LinkedHashSet (insertion order): " + linkedHashSet);
        System.out.println("TreeSet (sorted order): " + treeSet);
    }
}
```

`HashSet` gives no ordering guarantee at all — it's organized around hash codes for fast lookup, and iteration order can look arbitrary (and isn't guaranteed stable across JVM versions). `LinkedHashSet` adds a linked list alongside the hash table specifically to preserve insertion order — use it when you want dedup **and** a predictable iteration order matching how elements were added. `TreeSet` keeps elements sorted (using natural ordering via `Comparable`, or a custom `Comparator`) — here, alphabetically: `Alice, Bob, Carla`, regardless of insertion order.

## Choosing between them

```java
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.TreeSet;

public class Main {
    public static void main(String[] args) {
        // HashSet: fastest general-purpose choice when order truly doesn't matter.
        Set<String> tags = new HashSet<>();
        tags.add("backend");
        tags.add("urgent");

        // LinkedHashSet: dedup while preserving the order members were first seen.
        Set<String> firstSeenOrder = new LinkedHashSet<>();
        firstSeenOrder.add("Carla");
        firstSeenOrder.add("Alice");
        firstSeenOrder.add("Carla"); // already present, position doesn't move

        // TreeSet: dedup AND always-sorted output, e.g. an alphabetical roster.
        Set<String> roster = new TreeSet<>();
        roster.add("Zoe");
        roster.add("Amir");

        System.out.println("Tags: " + tags);
        System.out.println("First-seen order: " + firstSeenOrder);
        System.out.println("Sorted roster: " + roster);
    }
}
```

Rule of thumb: default to `HashSet` for raw performance when order is irrelevant; reach for `LinkedHashSet` when you need dedup plus a stable, predictable iteration order; reach for `TreeSet` when you need the contents sorted at all times, which also comes with useful range operations like `first()`, `last()`, and `headSet(...)` that plain `HashSet`/`LinkedHashSet` don't offer.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "collections-set-q1",
      "type": "mcq",
      "prompt": "What happens when you call add() on a Set with a value that's already present?",
      "options": [
        { "id": "a", "text": "It throws an exception" },
        { "id": "b", "text": "It's a no-op — the set's contents are unchanged, and add() returns false" },
        { "id": "c", "text": "It replaces the existing element and moves it to the end" },
        { "id": "d", "text": "It adds the value again, resulting in a duplicate" }
      ],
      "correct": "b",
      "explanation": "Set's defining guarantee is no duplicates. Adding an already-present element is silently ignored (add() returns false to signal nothing changed), rather than throwing or creating a duplicate entry."
    },
    {
      "id": "collections-set-q2",
      "type": "mcq",
      "prompt": "Which Set implementation guarantees iteration in the order elements were first inserted?",
      "options": [
        { "id": "a", "text": "HashSet" },
        { "id": "b", "text": "LinkedHashSet" },
        { "id": "c", "text": "TreeSet" },
        { "id": "d", "text": "None of them guarantee any order" }
      ],
      "correct": "b",
      "explanation": "LinkedHashSet maintains a linked list alongside its hash table specifically to preserve insertion order during iteration. HashSet gives no ordering guarantee, and TreeSet iterates in sorted order instead of insertion order."
    },
    {
      "id": "collections-set-q3",
      "type": "mcq",
      "prompt": "Which Set implementation would you choose to always iterate a roster of names in alphabetical order?",
      "options": [
        { "id": "a", "text": "HashSet" },
        { "id": "b", "text": "LinkedHashSet" },
        { "id": "c", "text": "TreeSet" },
        { "id": "d", "text": "Any of them work identically for this" }
      ],
      "correct": "c",
      "explanation": "TreeSet keeps its elements sorted at all times (by natural ordering or a supplied Comparator), so iterating it always yields sorted order — exactly what's needed for an alphabetical roster."
    }
  ]
}
```

## What's next

`Set` answers "is this value present." The next lesson covers `Map` — for when you need to associate a **key** with a **value**, like looking up a full `Task` by its ID.
$md$, 20, $json$[{"id":"collections-set-q1","type":"mcq","correct":"b"},{"id":"collections-set-q2","type":"mcq","correct":"b"},{"id":"collections-set-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('dcc44621-8d7e-5824-b303-3c3d949e05f2', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'fffbddf7-506a-52e9-ad39-ee3687665870', 'Map: HashMap, LinkedHashMap, TreeMap', 'notes', 2, $md$`List` and `Set` both hold single values. TaskFlow constantly needs the other shape of data: looking a `Task` up **by its ID**, instantly, without scanning a whole list. That's what `Map<K, V>` is for — a key-to-value lookup table.

## Basic Map operations

```java
import java.util.HashMap;
import java.util.Map;

public class Main {
    static class Task {
        String id;
        String name;
        double estimateHours;

        Task(String id, String name, double estimateHours) {
            this.id = id;
            this.name = name;
            this.estimateHours = estimateHours;
        }

        @Override
        public String toString() {
            return name + " (" + estimateHours + "h)";
        }
    }

    public static void main(String[] args) {
        Map<String, Task> tasksById = new HashMap<>();

        tasksById.put("T-101", new Task("T-101", "Design schema", 6.0));
        tasksById.put("T-102", new Task("T-102", "Build REST API", 10.5));

        Task lookup = tasksById.get("T-101");
        System.out.println("Found: " + lookup);

        System.out.println("Contains T-999: " + tasksById.containsKey("T-999"));
        System.out.println("Map size: " + tasksById.size());

        tasksById.remove("T-102");
        System.out.println("After removal, size: " + tasksById.size());
    }
}
```

`put(key, value)` inserts or overwrites an entry; `get(key)` returns the value, or `null` if the key isn't present; `containsKey(key)` checks presence without risking a `null`. This replaces having to loop through a `List<Task>` comparing `.id` fields on every lookup — a `Map` gives near-instant lookup by key regardless of how many entries it holds.

## Iterating entries

```java
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Map<String, Double> hoursByTaskId = new HashMap<>();
        hoursByTaskId.put("T-101", 6.0);
        hoursByTaskId.put("T-102", 10.5);
        hoursByTaskId.put("T-103", 3.0);

        // entrySet() gives both key and value together — the usual iteration style
        for (Map.Entry<String, Double> entry : hoursByTaskId.entrySet()) {
            System.out.println(entry.getKey() + " -> " + entry.getValue() + "h");
        }

        // keySet() / values() when you only need one side
        double total = 0;
        for (double hours : hoursByTaskId.values()) {
            total += hours;
        }
        System.out.println("Total hours: " + total);
    }
}
```

`entrySet()` is the standard way to walk both keys and values together in one pass. `keySet()` and `values()` give you just one side when that's all you need — looping `values()` to sum, as above, avoids the unnecessary overhead of also pulling out keys you won't use.

## `getOrDefault` and `computeIfAbsent`

```java
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Map<String, Integer> taskCountByOwner = new HashMap<>();
        taskCountByOwner.put("Alice", 3);

        // getOrDefault: read a key that might be missing, without a null check
        int bobCount = taskCountByOwner.getOrDefault("Bob", 0);
        System.out.println("Bob's task count: " + bobCount); // 0, not null

        // computeIfAbsent: initialize a value only if the key isn't already there
        Map<String, List<String>> tasksByOwner = new HashMap<>();
        tasksByOwner.computeIfAbsent("Alice", key -> new ArrayList<>()).add("Design schema");
        tasksByOwner.computeIfAbsent("Alice", key -> new ArrayList<>()).add("Write tests");
        tasksByOwner.computeIfAbsent("Bob", key -> new ArrayList<>()).add("Build API");

        System.out.println("Alice's tasks: " + tasksByOwner.get("Alice"));
        System.out.println("Bob's tasks: " + tasksByOwner.get("Bob"));
    }
}
```

`getOrDefault(key, fallback)` avoids a manual `containsKey` + `get` pair, or a `null` slipping through unnoticed. `computeIfAbsent(key, function)` is the idiomatic way to build up a "group by" structure like `Map<String, List<String>>`: the first time a key is seen it creates a new empty list via the given lambda, and every call after that reuses the existing one — no need to manually check "does this key have a list yet?" before every `add`.

## `HashMap` vs. `LinkedHashMap` vs. `TreeMap`

Exactly the same relationship as their `Set` counterparts: `HashMap` gives no ordering guarantee (fastest general case), `LinkedHashMap` preserves insertion order, `TreeMap` keeps entries sorted by key at all times.

```java
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeMap;

public class Main {
    public static void main(String[] args) {
        Map<String, Double> hashMap = new HashMap<>();
        Map<String, Double> linkedHashMap = new LinkedHashMap<>();
        Map<String, Double> treeMap = new TreeMap<>();

        String[] ids = { "T-103", "T-101", "T-102" };
        double[] hours = { 3.0, 6.0, 10.5 };
        for (int i = 0; i < ids.length; i++) {
            hashMap.put(ids[i], hours[i]);
            linkedHashMap.put(ids[i], hours[i]);
            treeMap.put(ids[i], hours[i]);
        }

        System.out.println("LinkedHashMap (insertion order): " + linkedHashMap);
        System.out.println("TreeMap (sorted by key): " + treeMap);
    }
}
```

For TaskFlow, `TreeMap<String, Task>` keyed by task ID is a natural fit whenever a report needs tasks listed in ID order without a separate sort step.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "collections-map-q1",
      "type": "mcq",
      "prompt": "What does map.get(key) return if the key is not present in the map?",
      "options": [
        { "id": "a", "text": "It throws a NoSuchElementException" },
        { "id": "b", "text": "null" },
        { "id": "c", "text": "An empty String" },
        { "id": "d", "text": "0" }
      ],
      "correct": "b",
      "explanation": "get() on a missing key returns null rather than throwing. This is exactly why getOrDefault(key, fallback) exists — to supply a non-null fallback without a manual containsKey check."
    },
    {
      "id": "collections-map-q2",
      "type": "mcq",
      "prompt": "What does tasksByOwner.computeIfAbsent(\"Alice\", key -> new ArrayList<>()) do if \"Alice\" already has a value in the map?",
      "options": [
        { "id": "a", "text": "It overwrites Alice's existing value with a new empty ArrayList" },
        { "id": "b", "text": "It returns the existing value unchanged, without creating a new list" },
        { "id": "c", "text": "It throws an exception because the key already exists" },
        { "id": "d", "text": "It adds a duplicate entry for the same key" }
      ],
      "correct": "b",
      "explanation": "computeIfAbsent only invokes the supplied function and inserts a new value when the key is absent. If the key is already present, it simply returns the existing value — this is what makes it safe to call repeatedly while building up a grouped structure."
    },
    {
      "id": "collections-map-q3",
      "type": "mcq",
      "prompt": "Which Map implementation would you choose to always iterate entries sorted by key?",
      "options": [
        { "id": "a", "text": "HashMap" },
        { "id": "b", "text": "LinkedHashMap" },
        { "id": "c", "text": "TreeMap" },
        { "id": "d", "text": "Any of them produce sorted order" }
      ],
      "correct": "c",
      "explanation": "TreeMap keeps its entries sorted by key at all times (natural ordering or a supplied Comparator). HashMap gives no ordering guarantee, and LinkedHashMap preserves insertion order rather than sorted order."
    }
  ]
}
```

## What's next

The last lesson in this module covers `Queue`/`Deque` for FIFO task processing, `Iterator` for safely removing elements while iterating, and `Comparable`/`Comparator` for sorting a `List<Task>` by priority.
$md$, 20, $json$[{"id":"collections-map-q1","type":"mcq","correct":"b"},{"id":"collections-map-q2","type":"mcq","correct":"b"},{"id":"collections-map-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6e4ffa74-ca92-5fe3-87ef-7ce87e2e683a', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'fffbddf7-506a-52e9-ad39-ee3687665870', 'Queue/Deque, Iterator, and Comparable vs. Comparator', 'notes', 3, $md$This last lesson covers three remaining tools that come up constantly once TaskFlow has real collections of tasks to manage: processing them in order with a `Queue`, safely removing while iterating, and sorting by priority.

## `Queue` and `Deque` with `ArrayDeque`

```java
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Queue;

public class Main {
    public static void main(String[] args) {
        // Queue: FIFO — first in, first out
        Queue<String> taskQueue = new ArrayDeque<>();
        taskQueue.offer("Design schema");  // enqueue (add to the back)
        taskQueue.offer("Build API");
        taskQueue.offer("Write tests");

        System.out.println("Next up: " + taskQueue.peek()); // look without removing
        while (!taskQueue.isEmpty()) {
            System.out.println("Processing: " + taskQueue.poll()); // dequeue (remove from the front)
        }

        // Deque: double-ended — push/pop from either end
        Deque<String> urgentStack = new ArrayDeque<>();
        urgentStack.push("Design schema");     // pushes to the front
        urgentStack.push("URGENT: Fix outage"); // most recent urgent item goes first
        System.out.println("Handle first: " + urgentStack.pop()); // LIFO — last in, first out
    }
}
```

`Queue` models FIFO processing: `offer()` adds to the back, `poll()` removes and returns from the front, `peek()` looks at the front without removing it. `ArrayDeque` is the standard modern choice backing both `Queue` and `Deque` — it's faster than the older `LinkedList` for this purpose and doesn't carry `LinkedList`'s extra per-node overhead. `Deque` ("double-ended queue") adds `push`/`pop` for stack-like LIFO behavior at the front, useful for TaskFlow modeling an "urgent tasks jump the line" stack layered on top of the normal FIFO queue.

## Safely removing while iterating: `Iterator.remove()`

```java
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>();
        taskNames.add("Design schema");
        taskNames.add("Build API");
        taskNames.add("Cancelled: old spec");
        taskNames.add("Write tests");

        // BAD (would throw ConcurrentModificationException):
        // for (String name : taskNames) {
        //     if (name.startsWith("Cancelled")) taskNames.remove(name);
        // }

        // GOOD: use the Iterator directly and call its own remove()
        Iterator<String> it = taskNames.iterator();
        while (it.hasNext()) {
            String name = it.next();
            if (name.startsWith("Cancelled")) {
                it.remove(); // safe — the iterator knows how to adjust itself
            }
        }

        System.out.println("After cleanup: " + taskNames);
    }
}
```

Modifying a `List` directly with `.remove()` while inside an enhanced for-loop (or otherwise iterating it) throws `ConcurrentModificationException` at runtime — the loop's internal iterator detects the list changed underneath it and refuses to continue with potentially corrupted state. `Iterator.remove()` is the safe alternative: it's a method on the iterator itself, so it can adjust its own internal position as part of the removal, instead of invalidating the iteration it's driving.

## `Comparable`: a type's natural ordering

```java
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Main {
    static class Task implements Comparable<Task> {
        String name;
        int priority; // higher number = higher priority

        Task(String name, int priority) {
            this.name = name;
            this.priority = priority;
        }

        @Override
        public int compareTo(Task other) {
            return Integer.compare(this.priority, other.priority); // ascending by priority
        }

        @Override
        public String toString() {
            return name + " (priority " + priority + ")";
        }
    }

    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Write tests", 4));
        tasks.add(new Task("Fix outage", 9));
        tasks.add(new Task("Design schema", 6));

        Collections.sort(tasks); // uses compareTo — Task's own "natural" ordering
        System.out.println("Sorted by natural order: " + tasks);
    }
}
```

Implementing `Comparable<Task>` gives a type a single, built-in "natural" ordering via `compareTo` — `Collections.sort(list)` (with no second argument) uses exactly that. `compareTo` returns negative if `this` sorts before `other`, positive if after, zero if equal; `Integer.compare(a, b)` is the standard safe way to compare two `int`s for this purpose instead of hand-rolling `a - b` (which can silently overflow for large values).

## `Comparator`: sorting a different way, without changing the class

```java
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class Main {
    static class Task {
        String name;
        int priority;
        double estimateHours;

        Task(String name, int priority, double estimateHours) {
            this.name = name;
            this.priority = priority;
            this.estimateHours = estimateHours;
        }

        @Override
        public String toString() {
            return name + " (priority " + priority + ", " + estimateHours + "h)";
        }
    }

    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Write tests", 4, 3.0));
        tasks.add(new Task("Fix outage", 9, 1.5));
        tasks.add(new Task("Design schema", 6, 6.0));

        // Sort by priority, descending — highest priority first
        tasks.sort(Comparator.comparing((Task t) -> t.priority).reversed());
        System.out.println("By priority (desc): " + tasks);

        // Sort by estimate hours, ascending, with priority as a tiebreaker
        tasks.sort(Comparator.comparingDouble((Task t) -> t.estimateHours)
                              .thenComparing(t -> t.priority));
        System.out.println("By hours, then priority: " + tasks);
    }
}
```

`Comparator` defines an ordering **externally**, without the class needing to implement anything — essential when `Task` has no single "natural" order, or when you need several different orderings for different reports. `Comparator.comparing(keyExtractor)` builds a comparator from a lambda that pulls out the field to sort by; `.reversed()` flips it; `.thenComparing(...)` adds a tiebreaker for when the primary key is equal. `list.sort(comparator)` sorts in place using it — this is the idiomatic modern way to sort by priority, by hours, or by any other field, all without touching the `Task` class itself.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "collections-queue-iterator-comparator-q1",
      "type": "mcq",
      "prompt": "In a Queue, what does poll() do?",
      "options": [
        { "id": "a", "text": "Adds an element to the back" },
        { "id": "b", "text": "Removes and returns the element at the front (FIFO order)" },
        { "id": "c", "text": "Looks at the front element without removing it" },
        { "id": "d", "text": "Removes and returns the element at the back" }
      ],
      "correct": "b",
      "explanation": "poll() removes and returns the head of the queue, implementing first-in-first-out processing. peek() looks at the head without removing it, and offer() adds to the tail."
    },
    {
      "id": "collections-queue-iterator-comparator-q2",
      "type": "mcq",
      "prompt": "Why does calling list.remove(x) directly inside an enhanced for-loop over that same list throw ConcurrentModificationException?",
      "options": [
        { "id": "a", "text": "It doesn't — this is always safe" },
        { "id": "b", "text": "The enhanced for-loop's internal iterator detects the list was structurally modified outside its own remove() method and refuses to continue" },
        { "id": "c", "text": "It only happens when the list has fewer than two elements" },
        { "id": "d", "text": "remove(x) is not a valid method on List" }
      ],
      "correct": "b",
      "explanation": "The enhanced for-loop uses an Iterator under the hood. Modifying the list directly changes its structure in a way the iterator didn't perform itself, so it throws rather than risk continuing over corrupted state. Iterator.remove() is safe because the iterator adjusts its own position as part of the removal."
    },
    {
      "id": "collections-queue-iterator-comparator-q3",
      "type": "mcq",
      "prompt": "What is the key difference between Comparable and Comparator?",
      "options": [
        { "id": "a", "text": "They are identical, just different names for the same interface" },
        { "id": "b", "text": "Comparable defines a class's own single natural ordering via compareTo; Comparator defines an ordering externally, and you can have as many different Comparators as needed" },
        { "id": "c", "text": "Comparator can only sort numbers, Comparable can sort anything" },
        { "id": "d", "text": "Comparable is only used for Lists, Comparator only for Sets" }
      ],
      "correct": "b",
      "explanation": "A class implements Comparable once to define its single natural ordering. Comparator lives outside the class entirely, so you can define multiple different orderings (by priority, by hours, etc.) without modifying the class at all."
    }
  ]
}
```

## What's next

That's the full Collections Framework toolkit — List, Set, Map, Queue/Deque, Iterator, and sorting. The module quiz below checks your understanding across all four lessons before you continue deeper into the course.
$md$, 25, $json$[{"id":"collections-queue-iterator-comparator-q1","type":"mcq","correct":"b"},{"id":"collections-queue-iterator-comparator-q2","type":"mcq","correct":"b"},{"id":"collections-queue-iterator-comparator-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e563881e-96d8-5d57-bd8e-24211adc071f', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which List implementation should you default to for most use cases, and why?', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c768f4c4-388c-5249-a524-5603b8b01575', 'e563881e-96d8-5d57-bd8e-24211adc071f', 1, $json${"prompt":"Which List implementation should you default to for most use cases, and why?","multiple":false,"options":[{"id":"a","text":"LinkedList, because it's always faster","is_correct":false},{"id":"b","text":"ArrayList, because it offers fast O(1) indexed access and good cache locality for typical access patterns","is_correct":true},{"id":"c","text":"Either one, they perform identically in every case","is_correct":false},{"id":"d","text":"Neither — arrays should always be used instead","is_correct":false}],"explanation":"ArrayList's array-backed storage gives fast indexed access and covers the large majority of real-world use cases. LinkedList only wins when you specifically need frequent insert/remove at arbitrary positions without indexed access."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('73ee4447-8bca-5e4e-9140-394c4dad9886', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the defining guarantee of any Set implementation?', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d1d517e7-49e3-55cb-b711-fdea022b1390', '73ee4447-8bca-5e4e-9140-394c4dad9886', 1, $json${"prompt":"What is the defining guarantee of any Set implementation?","multiple":false,"options":[{"id":"a","text":"Elements are always sorted","is_correct":false},{"id":"b","text":"No duplicate elements are allowed","is_correct":true},{"id":"c","text":"Elements are always accessible by index","is_correct":false},{"id":"d","text":"Insertion order is always preserved","is_correct":false}],"explanation":"Every Set implementation guarantees no duplicates. Ordering behavior (none, insertion order, sorted order) varies by implementation — HashSet, LinkedHashSet, TreeSet respectively — but dedup is the one guarantee they all share."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6f3fbba7-0713-5201-a062-3ae5426b97f1', '00000000-0000-0000-0000-000000000001', 'mcq', 'What problem does map.getOrDefault(key, fallback) solve compared to plain map...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('13fd16b6-d1be-5e9b-8faf-85ab964a65c0', '6f3fbba7-0713-5201-a062-3ae5426b97f1', 1, $json${"prompt":"What problem does map.getOrDefault(key, fallback) solve compared to plain map.get(key)?","multiple":false,"options":[{"id":"a","text":"It's faster than get() for large maps","is_correct":false},{"id":"b","text":"It avoids getting back null for a missing key, returning a supplied fallback value instead, without a manual containsKey check","is_correct":true},{"id":"c","text":"It removes the key after reading it","is_correct":false},{"id":"d","text":"It only works on TreeMap","is_correct":false}],"explanation":"get() returns null for a missing key, which callers must guard against. getOrDefault() supplies a safe fallback directly, removing the need for a manual containsKey + get pair."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0b7bcd03-55ea-5135-92a9-96be8ba8c197', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the safe way to remove elements from a List while iterating over it?', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('43e18c64-373f-5bd8-87fc-03ea2f54e9c0', '0b7bcd03-55ea-5135-92a9-96be8ba8c197', 1, $json${"prompt":"What is the safe way to remove elements from a List while iterating over it?","multiple":false,"options":[{"id":"a","text":"Call list.remove(element) directly inside an enhanced for-loop over the same list","is_correct":false},{"id":"b","text":"Use the list's own Iterator and call Iterator.remove(), which adjusts the iterator's internal state as part of the removal","is_correct":true},{"id":"c","text":"It's never safe to remove elements while iterating, under any circumstance","is_correct":false},{"id":"d","text":"Convert the list to an array first, always","is_correct":false}],"explanation":"Modifying a List directly during an enhanced for-loop throws ConcurrentModificationException. Iterator.remove() is safe specifically because it's a method on the iterator itself, which can keep its position consistent as it removes."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('72668068-a4ef-5988-86be-994b4020a6e6', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Task class needs to be sorted by priority in one report and by estimated ho...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('92bbc970-d041-5d42-bd55-6ae37c876f34', '72668068-a4ef-5988-86be-994b4020a6e6', 1, $json${"prompt":"A Task class needs to be sorted by priority in one report and by estimated hours in another. What's the appropriate approach?","multiple":false,"options":[{"id":"a","text":"Implement Comparable\u003cTask\u003e twice with two different compareTo methods","is_correct":false},{"id":"b","text":"Implement Comparable\u003cTask\u003e once for one natural ordering (e.g. priority), and use separate Comparator instances (e.g. via Comparator.comparing) for the other orderings needed","is_correct":true},{"id":"c","text":"Sorting by more than one field is not possible in Java","is_correct":false},{"id":"d","text":"Rewrite the Task class fields every time a new sort order is needed","is_correct":false}],"explanation":"A class can only implement Comparable once, giving it a single natural ordering. Additional orderings are supplied externally as Comparator instances passed to list.sort(comparator) or Collections.sort(list, comparator), without modifying the class."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('85734273-ff2f-5bf2-93f6-48f511598bcb', '00000000-0000-0000-0000-000000000001', 'coding', 'TaskFlow needs to sort a batch of task priorities. Read a single line of spac...', 'intermediate', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a5cf0168-b5da-508f-8fb4-4ad8cae9c3a4', '85734273-ff2f-5bf2-93f6-48f511598bcb', 1, $json${"prompt":"TaskFlow needs to sort a batch of task priorities. Read a single line of space-separated integers from stdin (the priority values). Print them sorted in ascending order, space-separated, on one line, with no leading or trailing spaces.","languages":["java"],"starter_code":{"java":"import java.util.ArrayList;\nimport java.util.Collections;\nimport java.util.List;\nimport java.util.Scanner;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        String line = scanner.nextLine();\n        // Split line on spaces, parse each as an int, sort ascending,\n        // then print them space-separated on one line.\n\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"5 3 8 1","expected":"1 3 5 8","hidden":false,"weight":1},{"id":"t2","stdin":"9","expected":"9","hidden":false,"weight":1},{"id":"t3","stdin":"2 2 1","expected":"1 2 2","hidden":true,"weight":1},{"id":"t4","stdin":"10 -3 4 0","expected":"-3 0 4 10","hidden":true,"weight":1},{"id":"t5","stdin":"7 6 5 4 3 2 1","expected":"1 2 3 4 5 6 7","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d10a4617-c76f-501b-86e6-7f3d763fa956', '00000000-0000-0000-0000-000000000001', 'subjective', 'In your own words: which single concept from this module (List/ArrayList vs. ...', 'beginner', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('47651d1c-d4f7-5aa0-b3d9-87b4950f1b6b', 'd10a4617-c76f-501b-86e6-7f3d763fa956', 1, $json${"prompt":"In your own words: which single concept from this module (List/ArrayList vs. LinkedList, Set implementations, Map and computeIfAbsent, or Queue/Deque/Iterator/ Comparator) felt least intuitive to you, and why? Be specific about what confused you — this answer feeds directly into what gets flagged for extra review.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('02b5321c-c926-5990-ab24-8b6053e3d8a9', '00000000-0000-0000-0000-000000000001', 'Module Assessment: Collections Framework', 'java-mastery-collections-quiz', 'Quiz covering Collections Framework.', 'mixed', 'published', 'module', '705367bc-31d7-5d5e-a5bf-3471cbc2b9f2', 25, 70, 5, 13, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('bab5c19b-044d-5866-ba07-6b91f167edfc', '02b5321c-c926-5990-ab24-8b6053e3d8a9', 'e563881e-96d8-5d57-bd8e-24211adc071f', 'c768f4c4-388c-5249-a524-5603b8b01575', 0, 1),
('9540ba07-36f3-5cbe-9d19-6fbcc41dbc57', '02b5321c-c926-5990-ab24-8b6053e3d8a9', '73ee4447-8bca-5e4e-9140-394c4dad9886', 'd1d517e7-49e3-55cb-b711-fdea022b1390', 1, 1),
('29ba9ad1-3061-5595-bd81-dfbf282a9dce', '02b5321c-c926-5990-ab24-8b6053e3d8a9', '6f3fbba7-0713-5201-a062-3ae5426b97f1', '13fd16b6-d1be-5e9b-8faf-85ab964a65c0', 2, 2),
('9b7c7678-170f-573d-9553-b62741f55adc', '02b5321c-c926-5990-ab24-8b6053e3d8a9', '0b7bcd03-55ea-5135-92a9-96be8ba8c197', '43e18c64-373f-5bd8-87fc-03ea2f54e9c0', 3, 2),
('6614a581-24f8-54d9-b1d0-7a5f2bfd1e71', '02b5321c-c926-5990-ab24-8b6053e3d8a9', '72668068-a4ef-5988-86be-994b4020a6e6', '92bbc970-d041-5d42-bd55-6ae37c876f34', 4, 2),
('1da08dae-cdba-5e69-802f-8654a21804ed', '02b5321c-c926-5990-ab24-8b6053e3d8a9', '85734273-ff2f-5bf2-93f6-48f511598bcb', 'a5cf0168-b5da-508f-8fb4-4ad8cae9c3a4', 5, 3),
('18465eea-c8bb-5f9f-bfce-3ae1f2b99328', '02b5321c-c926-5990-ab24-8b6053e3d8a9', 'd10a4617-c76f-501b-86e6-7f3d763fa956', '47651d1c-d4f7-5aa0-b3d9-87b4950f1b6b', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('705367bc-31d7-5d5e-a5bf-3471cbc2b9f2', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'fffbddf7-506a-52e9-ad39-ee3687665870', 'Module Assessment: Collections Framework', 'assessment', 4, 25, '02b5321c-c926-5990-ab24-8b6053e3d8a9')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Generics
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('715667db-8cab-51d1-8cb3-0a54b3c62662', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Generics', 8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('30ca9f1f-fbc3-572c-9807-9ed98266f6b0', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '715667db-8cab-51d1-8cb3-0a54b3c62662', 'Why Generics Exist & Generic Classes', 'notes', 0, $md$TaskFlow needs an in-memory store for `Task` objects. Then it needs one for `User` objects. Then `Project` objects. Writing `TaskRepository`, `UserRepository`, and `ProjectRepository` as three separate, nearly-identical classes is exactly the kind of duplication generics exist to eliminate — one `Repository<T>` class, parameterized by type, replaces all three.

## Life before generics: everything is `Object`

Before Java 5, a reusable container class had only one option for "any type": store everything as `Object`, the root of every class hierarchy, and cast back down when you retrieve it.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        // Pre-generics style: a raw, untyped store
        List rawStore = new ArrayList(); // no type parameter — raw type
        rawStore.add("Design database schema"); // a String
        rawStore.add(42);                        // an int, autoboxed to Integer — compiles fine!

        // The compiler has no idea what's actually in rawStore.
        // This cast looks reasonable but blows up at runtime:
        String taskName = (String) rawStore.get(1); // ClassCastException: Integer cannot be cast to String

        System.out.println(taskName);
    }
}
```

That program compiles cleanly and fails at **runtime** with a `ClassCastException`. This is the exact problem generics were built to solve: the mistake — putting an `Integer` where a `String` was expected — is a *programmer error* that should be caught by the compiler, not discovered when a user hits a crash in production. Notice this example never even reaches `main`'s last line safely; run it and watch it throw.

## `Repository<T>`: one class, any type

A **generic class** declares one or more **type parameters** — placeholder names, conventionally single uppercase letters like `T` (Type), `E` (Element), `K`/`V` (Key/Value) — in angle brackets after the class name. The type parameter stands in for a real type that's supplied when the class is used.

```java
import java.util.ArrayList;
import java.util.List;

public class Repository<T> {
    private final List<T> items = new ArrayList<>();

    public void add(T item) {
        items.add(item);
    }

    public T get(int index) {
        return items.get(index);
    }

    public int size() {
        return items.size();
    }

    public List<T> all() {
        return items;
    }
}
```

`Repository<T>` has no idea what `T` actually is when it's written — it just knows every `T` it stores will come back out as a `T`. The real type gets filled in wherever `Repository` is *used*:

```java
public class Main {
    public static void main(String[] args) {
        Repository<Task> taskRepo = new Repository<>();
        taskRepo.add(new Task("Design database schema", 6));
        taskRepo.add(new Task("Build REST API", 10));

        Repository<User> userRepo = new Repository<>();
        userRepo.add(new User("alice"));
        userRepo.add(new User("bob"));

        // No cast needed — get() already returns a Task, because this repo is Repository<Task>
        Task first = taskRepo.get(0);
        System.out.println("Task: " + first.getName() + " (" + first.getEstimateHours() + "h)");

        User firstUser = userRepo.get(0);
        System.out.println("User: " + firstUser.getUsername());
    }
}

class Task {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
}

class User {
    private final String username;

    public User(String username) {
        this.username = username;
    }

    public String getUsername() { return username; }
}
```

`Repository<Task>` and `Repository<User>` are both backed by the exact same class file — there's no code duplication — but the compiler treats them as distinct, incompatible types. Trying `taskRepo.add(new User("carol"))` is a **compile error**, not a runtime surprise. That's the whole win: the `ClassCastException` from the raw-type example above becomes impossible to write in the first place, because `taskRepo.get(0)` is statically known to return a `Task`, no cast required.

## Multiple type parameters

A class can declare more than one type parameter when it needs to relate two independent types — a cache keyed by task ID that stores `Task` objects, for instance, looks like `Cache<K, V>` (mirroring `java.util.Map<K, V>`, which is itself a generic class built the same way `Repository<T>` is here).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "generics-generic-classes-q1",
      "type": "mcq",
      "prompt": "What was the main problem with storing everything as Object before generics existed?",
      "options": [
        { "id": "a", "text": "Object-based code ran significantly slower" },
        { "id": "b", "text": "Type mismatches weren't caught until a cast failed at runtime with a ClassCastException" },
        { "id": "c", "text": "Object couldn't be stored in an ArrayList" },
        { "id": "d", "text": "It made the code shorter, which was considered bad practice" }
      ],
      "correct": "b",
      "explanation": "A raw List could hold any mix of types, and the compiler couldn't verify casts back to a specific type. The mistake surfaced as a runtime ClassCastException instead of a compile error."
    },
    {
      "id": "generics-generic-classes-q2",
      "type": "mcq",
      "prompt": "Given Repository<Task> taskRepo = new Repository<>();, what does taskRepo.get(0) return without any cast?",
      "options": [
        { "id": "a", "text": "Object, requiring a manual cast to Task" },
        { "id": "b", "text": "Task directly, because the compiler knows T is Task for this instance" },
        { "id": "c", "text": "A compile error, since get() is untyped" },
        { "id": "d", "text": "null, always" }
      ],
      "correct": "b",
      "explanation": "Once a type parameter is filled in (Repository<Task>), every method using T is treated as if T were literally Task — get() returns Task with no cast needed."
    },
    {
      "id": "generics-generic-classes-q3",
      "type": "mcq",
      "prompt": "Why does taskRepo.add(new User(\"carol\")) fail to compile when taskRepo is a Repository<Task>?",
      "options": [
        { "id": "a", "text": "Repository only allows one add() call total" },
        { "id": "b", "text": "User and Task are unrelated classes with no shared interface" },
        { "id": "c", "text": "The compiler enforces that add()'s parameter must match the concrete type T was bound to (Task), so a User is rejected" },
        { "id": "d", "text": "It doesn't fail — it compiles and throws at runtime instead" }
      ],
      "correct": "c",
      "explanation": "This is the entire point of generics: once Repository<Task> fixes T to Task, every T in the class (including add()'s parameter type) is enforced as Task at compile time, catching the mistake before the program ever runs."
    }
  ]
}
```

## What's next

`Repository<T>` works for storing and retrieving items, but what about operations that need to *compare* the items inside — finding the largest task by hours, for example? The next lesson covers generic methods and bounded type parameters, which let you say "T can be any type, as long as it supports comparison."
$md$, 20, $json$[{"id":"generics-generic-classes-q1","type":"mcq","correct":"b"},{"id":"generics-generic-classes-q2","type":"mcq","correct":"b"},{"id":"generics-generic-classes-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4ce46093-64f5-5149-95dc-8ed59bf9dea3', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '715667db-8cab-51d1-8cb3-0a54b3c62662', 'Generic Methods & Bounded Type Parameters', 'notes', 1, $md$A generic *class* like last lesson's `Repository<T>` fixes its type parameter for the whole object's lifetime. A generic **method** is narrower and more common in practice: a single method that introduces its own type parameter, usable with any type, independent of what class it lives in — even a plain `static` utility method.

## A generic method: finding the max

Suppose TaskFlow needs a utility that finds the highest-priority task in a list, or the user with the most tasks assigned, or the longest project name — the same "find the biggest one" logic, over and over, for different types. A generic method captures that once:

```java
import java.util.List;

public class Main {
    // <T extends Comparable<T>> declares the type parameter right before the return type
    public static <T extends Comparable<T>> T max(List<T> items) {
        T largest = items.get(0);
        for (T item : items) {
            if (item.compareTo(largest) > 0) {
                largest = item;
            }
        }
        return largest;
    }

    public static void main(String[] args) {
        List<Integer> hours = List.of(6, 10, 3, 8);
        System.out.println("Max hours: " + max(hours));

        List<String> taskNames = List.of("Design schema", "Build API", "Zebra sprint cleanup");
        System.out.println("Max name (alphabetically last): " + max(taskNames));
    }
}
```

`<T extends Comparable<T>>` is a **bounded type parameter**: it says "`T` can be any type, as long as that type implements `Comparable<T>`." Without the bound, `max` couldn't call `item.compareTo(largest)` at all — a plain `<T>` only guarantees `T` is *some* type, and the compiler has no way to know every possible type supports comparison. The bound is what unlocks calling comparison methods inside the generic code.

## Why the bound matters: what breaks without it

```java
import java.util.List;

public class Main {
    // No bound at all — T could be absolutely anything, even Object
    public static <T> T firstOf(List<T> items) {
        return items.get(0); // fine — no methods on T are called
    }

    // <T extends Comparable<T>> — the bound this lesson is about
    public static <T extends Comparable<T>> T max(List<T> items) {
        T largest = items.get(0);
        for (T item : items) {
            if (item.compareTo(largest) > 0) { // requires compareTo() to exist on T
                largest = item;
            }
        }
        return largest;
    }

    public static void main(String[] args) {
        List<String> priorities = List.of("LOW", "HIGH", "MEDIUM");
        System.out.println("First: " + firstOf(priorities));
        System.out.println("Max: " + max(priorities)); // String implements Comparable<String>
    }
}
```

`firstOf` needs no bound because it never calls a method on `T` — it just passes values through. `max` needs the bound because `compareTo` isn't a method every `Object` has; it only exists on types that declare `implements Comparable<T>`. Try removing `extends Comparable<T>` from `max`'s declaration and `item.compareTo(largest)` becomes a compile error: the compiler refuses to call a method it can't guarantee exists on an unbounded `T`.

## Applying `max` to TaskFlow's `Task` type

To make a custom class like `Task` usable with `max`, it needs to implement `Comparable<Task>` itself, defining what "bigger" means for a task:

```java
import java.util.List;

class Task implements Comparable<Task> {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }

    @Override
    public int compareTo(Task other) {
        return Integer.compare(this.estimateHours, other.estimateHours);
    }
}

public class Main {
    public static <T extends Comparable<T>> T max(List<T> items) {
        T largest = items.get(0);
        for (T item : items) {
            if (item.compareTo(largest) > 0) {
                largest = item;
            }
        }
        return largest;
    }

    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Design schema", 6),
            new Task("Build REST API", 10),
            new Task("Write tests", 4)
        );

        Task longest = max(tasks);
        System.out.println("Longest task: " + longest.getName() + " (" + longest.getEstimateHours() + "h)");
    }
}
```

Because `Task implements Comparable<Task>`, it satisfies `<T extends Comparable<T>>`, so `max(tasks)` compiles and runs correctly — the same generic method works for `Integer`, `String`, and now `Task`, with zero duplicated logic.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "generics-generic-methods-bounds-q1",
      "type": "mcq",
      "prompt": "What does <T extends Comparable<T>> guarantee about T inside the method body?",
      "options": [
        { "id": "a", "text": "T must be a subclass of a class literally named Comparable" },
        { "id": "b", "text": "T is guaranteed to have a compareTo(T) method available, because it implements Comparable<T>" },
        { "id": "c", "text": "T must be one of the primitive wrapper types like Integer" },
        { "id": "d", "text": "T is restricted to a maximum of one instance per method call" }
      ],
      "correct": "b",
      "explanation": "extends here means implements (Java uses extends for both class and interface bounds on type parameters). Bounding T by Comparable<T> guarantees compareTo() exists and can be called safely."
    },
    {
      "id": "generics-generic-methods-bounds-q2",
      "type": "mcq",
      "prompt": "Why would <T> max(List<T> items) fail to compile if it calls item.compareTo(largest) without a bound?",
      "options": [
        { "id": "a", "text": "compareTo is a static method and can't be called on instances" },
        { "id": "b", "text": "An unbounded T is only guaranteed to have the methods every Object has, and compareTo isn't one of them" },
        { "id": "c", "text": "List<T> cannot hold comparable types" },
        { "id": "d", "text": "It wouldn't fail — unbounded generics can call any method" }
      ],
      "correct": "b",
      "explanation": "Without a bound, the compiler only knows T is some type — it can't assume methods beyond what Object provides (toString, equals, hashCode, etc.). compareTo requires the Comparable bound to be callable."
    },
    {
      "id": "generics-generic-methods-bounds-q3",
      "type": "mcq",
      "prompt": "What must a custom class like Task do to be usable with a <T extends Comparable<T>> method?",
      "options": [
        { "id": "a", "text": "Nothing — all classes are Comparable by default" },
        { "id": "b", "text": "Override toString() only" },
        { "id": "c", "text": "Implement Comparable<Task> and define compareTo(Task other)" },
        { "id": "d", "text": "Mark all its fields as public" }
      ],
      "correct": "c",
      "explanation": "Comparable isn't automatic. A class opts in by declaring implements Comparable<Task> and providing a compareTo(Task) implementation that defines its natural ordering."
    }
  ]
}
```

## What's next

Generic methods handle "any type that supports X." The next lesson covers wildcards — `? extends` and `? super` — for when you're working with generic *collections* whose exact type parameter you don't need to know, only whether you're reading from or writing into them. It also covers type erasure, the runtime reality behind everything generics do at compile time.
$md$, 20, $json$[{"id":"generics-generic-methods-bounds-q1","type":"mcq","correct":"b"},{"id":"generics-generic-methods-bounds-q2","type":"mcq","correct":"b"},{"id":"generics-generic-methods-bounds-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('656a8db0-0faf-5df0-a5c0-426c7a007197', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '715667db-8cab-51d1-8cb3-0a54b3c62662', 'Wildcards & Type Erasure', 'notes', 2, $md$So far every generic has used a concrete type parameter: `Repository<Task>`, `List<Task>`. Sometimes a method doesn't care about the *exact* type parameter — it just needs "a list of tasks, or anything more specific" to read from, or "a list I can dump tasks into." That's what wildcards (`?`) are for.

## The problem wildcards solve

`List<Task>` and `List<UrgentTask>` (even if `UrgentTask extends Task`) are **not** related types as far as generics are concerned — this surprises almost everyone the first time. A method parameter typed `List<Task>` will reject a `List<UrgentTask>` argument outright:

```java
import java.util.List;

class Task {
    private final String name;
    public Task(String name) { this.name = name; }
    public String getName() { return name; }
}

class UrgentTask extends Task {
    public UrgentTask(String name) { super(name); }
}

public class Main {
    // This method only accepts exactly List<Task> — not List<UrgentTask>
    static void printNames(List<Task> tasks) {
        for (Task t : tasks) {
            System.out.println(t.getName());
        }
    }

    public static void main(String[] args) {
        List<Task> tasks = List.of(new Task("Design schema"));
        printNames(tasks); // fine

        List<UrgentTask> urgent = List.of(new UrgentTask("Fix prod outage"));
        // printNames(urgent); // COMPILE ERROR: List<UrgentTask> is not a List<Task>
        System.out.println("Urgent task: " + urgent.get(0).getName());
    }
}
```

Even though `UrgentTask` *is-a* `Task`, `List<UrgentTask>` is *not* a `List<Task>` — if it were allowed, you could add a plain `Task` into what's supposedly a `List<UrgentTask>` through a `List<Task>` reference, silently breaking the more specific guarantee. Wildcards exist to safely express "I'll accept a range of related types" without that hole.

## `? extends T` — for reading (producer)

```java
import java.util.List;

class Task {
    private final String name;
    public Task(String name) { this.name = name; }
    public String getName() { return name; }
}

class UrgentTask extends Task {
    public UrgentTask(String name) { super(name); }
}

public class Main {
    // "a List of some unknown type that IS-A Task" — read-only, safely
    static void printNames(List<? extends Task> tasks) {
        for (Task t : tasks) { // safe to read as Task
            System.out.println(t.getName());
        }
        // tasks.add(new Task("...")); // COMPILE ERROR — can't add, compiler doesn't know the exact type
    }

    public static void main(String[] args) {
        printNames(List.of(new Task("Design schema")));
        printNames(List.of(new UrgentTask("Fix prod outage"))); // now this compiles!
    }
}
```

`List<? extends Task>` accepts a `List<Task>`, `List<UrgentTask>`, or a `List` of any other `Task` subtype. In exchange, the compiler forbids adding anything to it (except `null`) — it doesn't know if the real underlying list is `List<UrgentTask>`, so it can't guarantee any `Task` you try to add would actually be an `UrgentTask`. This is a **producer**: it produces `Task` values out to you, safely, but you can't feed anything back in.

## `? super T` — for writing (consumer)

```java
import java.util.ArrayList;
import java.util.List;

class Task {
    private final String name;
    public Task(String name) { this.name = name; }
    public String getName() { return name; }
}

class UrgentTask extends Task {
    public UrgentTask(String name) { super(name); }
}

public class Main {
    // "a List that can hold Task or any of Task's ancestors" — write-only, safely
    static void addStandardTasks(List<? super Task> destination) {
        destination.add(new Task("Weekly status update"));
        destination.add(new Task("Backlog grooming"));
        // Task t = destination.get(0); // would only give back Object — reading loses type info
    }

    public static void main(String[] args) {
        List<Task> taskList = new ArrayList<>();
        addStandardTasks(taskList); // List<Task> matches List<? super Task>

        List<Object> objectList = new ArrayList<>();
        addStandardTasks(objectList); // List<Object> also matches — Object is a "super" of Task

        System.out.println("taskList size: " + taskList.size());
        System.out.println("objectList size: " + objectList.size());
    }
}
```

`List<? super Task>` accepts a `List<Task>`, `List<Object>`, or anything in between — any list that could legally hold a `Task`. It's a **consumer**: safe to add `Task` values into, but reading from it only gives you `Object` back, since the compiler can't know how specific the real list type is.

## PECS: Producer Extends, Consumer Super

That's the mnemonic Joshua Bloch coined in *Effective Java*: use `? extends T` when a parameter is a **source** you only read `T` values from; use `? super T` when it's a **destination** you only write `T` values into. If a method both reads and writes, use neither wildcard — take a plain `List<T>`.

## Type erasure: what happens at runtime

Everything above — `T`, `? extends Task`, `<T extends Comparable<T>>` — exists **only at compile time**. The Java compiler uses it to check your code, then erases it: at runtime, `Repository<Task>` and `Repository<User>` compile down to the exact same bytecode, just `Repository` operating on `Object` internally, with the compiler quietly inserting casts where needed.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> strings = new ArrayList<>();
        List<Integer> integers = new ArrayList<>();

        // At runtime, generic type info is erased — both are just "ArrayList"
        System.out.println(strings.getClass() == integers.getClass()); // true!
        System.out.println(strings.getClass().getName()); // java.util.ArrayList — no <String> in sight

        // This is exactly why the following DON'T compile / work as you might expect:
        // if (strings instanceof List<String>) { }   // COMPILE ERROR: can't check erased type at runtime
        // T[] arr = new T[10];                        // COMPILE ERROR: erasure means the JVM wouldn't know what array type to create

        // instanceof against the raw type still works fine, since that info does survive:
        System.out.println(strings instanceof List); // true
    }
}
```

Type erasure is why `new T[10]` inside a generic class is a compile error (the JVM would need a concrete component type to build an array, but `T` no longer exists at runtime) and why `instanceof List<String>` is illegal (the JVM can check "is this a `List`" but has no way to check what it was parameterized with — that information was erased when the class was compiled). It's also why generics are backward-compatible with pre-Java-5 code: erased generic bytecode looks just like old raw-type bytecode to the JVM.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "generics-wildcards-type-erasure-q1",
      "type": "mcq",
      "prompt": "A method needs to safely accept List<Task>, List<UrgentTask>, or any other Task subtype list, purely to read from it. Which parameter type is correct?",
      "options": [
        { "id": "a", "text": "List<Task>" },
        { "id": "b", "text": "List<? extends Task>" },
        { "id": "c", "text": "List<? super Task>" },
        { "id": "d", "text": "List<Object>" }
      ],
      "correct": "b",
      "explanation": "? extends Task (a producer, per PECS) accepts List<Task> and any subtype's list, and is safe for reading. List<Task> alone would reject List<UrgentTask> entirely."
    },
    {
      "id": "generics-wildcards-type-erasure-q2",
      "type": "mcq",
      "prompt": "Why can't you call .add(new Task(...)) on a parameter typed List<? extends Task>?",
      "options": [
        { "id": "a", "text": "extends wildcards make the list permanently empty" },
        { "id": "b", "text": "The compiler doesn't know the list's exact underlying type parameter, so it can't guarantee a Task you add would match it (e.g. the real list might be List<UrgentTask>)" },
        { "id": "c", "text": "add() doesn't exist on the List interface" },
        { "id": "d", "text": "It actually does compile fine" }
      ],
      "correct": "b",
      "explanation": "? extends T is read-only by design (the producer side of PECS) — allowing writes would risk inserting a Task into what might really be a List<UrgentTask> underneath, breaking type safety."
    },
    {
      "id": "generics-wildcards-type-erasure-q3",
      "type": "mcq",
      "prompt": "Why is `if (someList instanceof List<String>)` a compile error in Java?",
      "options": [
        { "id": "a", "text": "instanceof cannot be used with the List interface" },
        { "id": "b", "text": "Generic type parameters are erased at compile time, so the JVM has no <String> information left to check against at runtime" },
        { "id": "c", "text": "It should be written as someList.class == List<String>.class instead" },
        { "id": "d", "text": "List<String> checks are only allowed inside generic methods" }
      ],
      "correct": "b",
      "explanation": "Type erasure removes generic type parameters from bytecode — at runtime a List<String> and a List<Integer> are both just a plain List. There's nothing left for instanceof to check against, so the compiler rejects the expression outright."
    }
  ]
}
```

## What's next

That closes out generics. The next module moves to file I/O and NIO — reading and writing files, which is where TaskFlow's data starts persisting beyond a single program run.
$md$, 20, $json$[{"id":"generics-wildcards-type-erasure-q1","type":"mcq","correct":"b"},{"id":"generics-wildcards-type-erasure-q2","type":"mcq","correct":"b"},{"id":"generics-wildcards-type-erasure-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: File I/O & NIO
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('3ba16252-7402-5de5-b14c-40cced0b2022', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'File I/O & NIO', 9)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('347663b7-7881-53fa-8605-d8d30177b22b', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3ba16252-7402-5de5-b14c-40cced0b2022', 'File I/O Basics & Try-With-Resources', 'notes', 0, $md$Everything TaskFlow has done so far lives only in memory — the moment the program ends, every `Task` and `User` object vanishes. Real applications persist data, and the most basic way Java writes and reads text is `FileWriter` and `FileReader`.

## Writing a file with `FileWriter`

```java
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        String exportPath = "taskflow-export.txt";

        try (FileWriter writer = new FileWriter(exportPath)) {
            writer.write("Design database schema,6,HIGH\n");
            writer.write("Build REST API,10,HIGH\n");
            writer.write("Write tests,4,MEDIUM\n");
        }

        System.out.println("Export written to " + exportPath);
    }
}
```

`FileWriter` opens (or creates) a file and writes raw text to it. `throws IOException` on `main` is necessary because file operations can fail for reasons entirely outside your program's control — the disk is full, the path doesn't exist, permissions are wrong — and Java forces you to acknowledge that with a **checked exception**.

## Why `try-with-resources` matters

A `FileWriter` holds a real operating-system file handle open. Operating systems place a hard limit on how many file handles a process can have open simultaneously — leak enough of them (by forgetting to close files after use) and a long-running program eventually fails to open *any* file, including ones it desperately needs, like its own log file.

```java
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) {
        String exportPath = "taskflow-leaky.txt";

        // The manual, error-prone way — DON'T do this:
        FileWriter writer = null;
        try {
            writer = new FileWriter(exportPath);
            writer.write("Design database schema,6,HIGH\n");
            // If an exception is thrown here, the code below never runs, and the file handle leaks.
        } catch (IOException e) {
            System.out.println("Write failed: " + e.getMessage());
        } finally {
            // You have to remember this yourself, AND handle the fact that close() can also throw.
            if (writer != null) {
                try {
                    writer.close();
                } catch (IOException e) {
                    System.out.println("Close failed: " + e.getMessage());
                }
            }
        }

        System.out.println("Done (the hard way)");
    }
}
```

That's a lot of ceremony just to guarantee a file gets closed — and it's easy to get wrong (forget the `finally`, forget the null check, forget `close()` itself can throw). `try-with-resources`, shown in the first example, replaces all of it: any resource declared in the `try (...)` parentheses is **automatically closed** when the block exits, whether it exits normally or via an exception. It works for any class implementing `java.io.Closeable` (or the broader `AutoCloseable`), which includes `FileWriter`, `FileReader`, and every stream class in `java.io`.

## Reading it back with `FileReader`

```java
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        String path = "taskflow-roundtrip.txt";

        try (FileWriter writer = new FileWriter(path)) {
            writer.write("Design database schema,6,HIGH\n");
            writer.write("Build REST API,10,HIGH\n");
        }

        StringBuilder contents = new StringBuilder();
        try (FileReader reader = new FileReader(path)) {
            int character;
            // read() returns one char at a time as an int, or -1 at end of stream
            while ((character = reader.read()) != -1) {
                contents.append((char) character);
            }
        }

        System.out.print(contents);
    }
}
```

`FileReader.read()` returns one character at a time as an `int` (the `char` value, or `-1` once the stream is exhausted — `-1` can't be confused with a real character because `char` values are never negative). Reading one character at a time works, but it's slow for anything beyond tiny files — that's exactly the problem the next lesson's `BufferedReader` solves.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "io-nio-file-io-try-with-resources-q1",
      "type": "mcq",
      "prompt": "What's the real risk of forgetting to close a FileWriter?",
      "options": [
        { "id": "a", "text": "The written data is silently discarded" },
        { "id": "b", "text": "The program crashes immediately" },
        { "id": "c", "text": "The underlying OS file handle stays open, and enough leaks can exhaust the process's file handle limit" },
        { "id": "d", "text": "Nothing — Java automatically closes files during garbage collection at a predictable time" }
      ],
      "correct": "c",
      "explanation": "Operating systems cap how many file handles a process can hold open at once. Leaked handles from unclosed files accumulate and eventually block the program from opening any file at all — garbage collection timing is not predictable enough to rely on for cleanup."
    },
    {
      "id": "io-nio-file-io-try-with-resources-q2",
      "type": "mcq",
      "prompt": "What does try-with-resources guarantee compared to manual try/finally?",
      "options": [
        { "id": "a", "text": "It guarantees the resource is closed automatically when the block exits, whether normally or via exception, with no explicit close() call or null-check needed" },
        { "id": "b", "text": "It prevents any exception from ever being thrown inside the block" },
        { "id": "c", "text": "It only works with FileWriter, not other resource types" },
        { "id": "d", "text": "It makes file writes synchronous when they'd otherwise be asynchronous" }
      ],
      "correct": "a",
      "explanation": "Any resource implementing Closeable/AutoCloseable declared in the try(...) parentheses is closed automatically on exit from the block, replacing the error-prone manual finally + null-check + nested try/catch pattern."
    },
    {
      "id": "io-nio-file-io-try-with-resources-q3",
      "type": "mcq",
      "prompt": "Why does FileReader.read() return an int rather than a char?",
      "options": [
        { "id": "a", "text": "So it can return -1 to signal end-of-stream, a value no valid char can represent" },
        { "id": "b", "text": "int and char are interchangeable in Java, so it makes no difference" },
        { "id": "c", "text": "Because reading always returns two characters packed together" },
        { "id": "d", "text": "To support Unicode characters larger than a char can hold" }
      ],
      "correct": "a",
      "explanation": "char is always non-negative, so read() uses the wider int return type specifically to be able to return -1 as an unambiguous end-of-stream sentinel that no real character value could ever collide with."
    }
  ]
}
```

## What's next

Reading one character (or one byte) at a time is correct but slow. The next lesson introduces `BufferedReader` and `BufferedWriter`, which batch reads and writes internally for a dramatic performance difference on anything beyond trivially small files.
$md$, 20, $json$[{"id":"io-nio-file-io-try-with-resources-q1","type":"mcq","correct":"c"},{"id":"io-nio-file-io-try-with-resources-q2","type":"mcq","correct":"a"},{"id":"io-nio-file-io-try-with-resources-q3","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4e710b81-5cb5-5b7f-92b3-b8cb2765bf50', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3ba16252-7402-5de5-b14c-40cced0b2022', 'BufferedReader & BufferedWriter', 'notes', 1, $md$Every `FileReader.read()` call and every `FileWriter.write()` call is, underneath, a request to the operating system — and system calls are expensive relative to in-memory work. Reading a 10,000-line file one character at a time means potentially tens of thousands of system calls. `BufferedReader` and `BufferedWriter` fix this by batching.

## Why buffering matters

A **buffer** is just an in-memory chunk (an array) that sits between your code and the OS. `BufferedReader` reads a large block of the file into that buffer in one system call, then serves your individual `read()`/`readLine()` calls out of memory until the buffer runs dry — at which point it refills with one more system call. `BufferedWriter` works the same way in reverse: your `write()` calls accumulate in the buffer and get flushed to disk in large batches instead of one tiny write per call.

```java
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        String path = "taskflow-buffered-export.txt";

        // Wrap a FileWriter in a BufferedWriter — writes accumulate in memory,
        // flushed to disk in large batches instead of one system call per write().
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(path))) {
            writer.write("Design database schema,6,HIGH");
            writer.newLine(); // portable newline — matches the OS convention
            writer.write("Build REST API,10,HIGH");
            writer.newLine();
            writer.write("Write tests,4,MEDIUM");
            writer.newLine();
        }

        System.out.println("Wrote buffered export to " + path);
    }
}
```

`writer.newLine()` is preferred over hardcoding `"\n"` because it writes whatever line separator the host OS actually uses (`\n` on Linux/macOS, `\r\n` on Windows) — a small but real portability detail.

## Reading line-by-line with `BufferedReader.readLine()`

```java
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        String path = "taskflow-buffered-roundtrip.txt";

        try (BufferedWriter writer = new BufferedWriter(new FileWriter(path))) {
            writer.write("Design database schema,6,HIGH");
            writer.newLine();
            writer.write("Build REST API,10,HIGH");
            writer.newLine();
            writer.write("Write tests,4,MEDIUM");
            writer.newLine();
        }

        int totalHours = 0;
        try (BufferedReader reader = new BufferedReader(new FileReader(path))) {
            String line;
            // readLine() returns null once the stream is exhausted — the loop condition below
            // both assigns line AND checks for that sentinel in one expression
            while ((line = reader.readLine()) != null) {
                String[] fields = line.split(",");
                String name = fields[0];
                int hours = Integer.parseInt(fields[1]);
                String priority = fields[2];

                System.out.println(name + " -> " + hours + "h (" + priority + ")");
                totalHours += hours;
            }
        }

        System.out.println("Total estimated hours: " + totalHours);
    }
}
```

`readLine()` returns an entire line as a `String`, with the line terminator already stripped, or `null` at end of stream — `null` here plays the same role `-1` played for `FileReader.read()`: an unambiguous sentinel a real line can never equal (an empty line comes back as `""`, not `null`). This `while ((line = reader.readLine()) != null)` pattern is the standard idiom for reading a whole file line by line in Java; you'll see it constantly.

## Layered streams: the decorator pattern in practice

`new BufferedReader(new FileReader(path))` is two objects layered together: the inner `FileReader` talks to the actual file, and the outer `BufferedReader` wraps it, adding buffering and `readLine()` without `FileReader` itself needing to change. This is Java's I/O library applying the **decorator pattern** throughout — small, focused stream classes that wrap each other to add capability, rather than one giant class doing everything. You'll see this same wrap-around-a-stream shape again with things like `BufferedInputStream` wrapping a `FileInputStream` for binary data.

## Closing writers still matters — buffering doesn't remove that

Buffering changes *when* data physically reaches the disk, not *whether* it needs to. A `BufferedWriter` accumulates written text in its internal buffer and only flushes it out to the underlying `FileWriter` once that buffer fills up — or when `close()` (or an explicit `flush()`) runs. Skip the `try-with-resources` block, or crash before it exits, and whatever's still sitting in the buffer never makes it to disk at all, even though your code technically "wrote" it. This is a sharper version of the same resource-leak problem the previous lesson covered with `FileWriter`: with buffering in the mix, an unclosed writer doesn't just leak a handle, it can silently drop data that was never flushed.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "io-nio-buffered-reader-writer-q1",
      "type": "mcq",
      "prompt": "Why is BufferedReader typically faster than reading directly with FileReader.read()?",
      "options": [
        { "id": "a", "text": "It compresses the file contents before reading" },
        { "id": "b", "text": "It reads large chunks into an in-memory buffer with fewer system calls, serving individual read requests from memory instead of hitting the OS every time" },
        { "id": "c", "text": "It skips characters it considers unimportant" },
        { "id": "d", "text": "It reads the file in a separate background thread automatically" }
      ],
      "correct": "b",
      "explanation": "System calls are relatively expensive. Buffering amortizes that cost across many reads/writes by batching data transfer into large chunks instead of one system call per character."
    },
    {
      "id": "io-nio-buffered-reader-writer-q2",
      "type": "mcq",
      "prompt": "What does BufferedReader.readLine() return once the end of the file is reached?",
      "options": [
        { "id": "a", "text": "An empty string \"\"" },
        { "id": "b", "text": "-1" },
        { "id": "c", "text": "null" },
        { "id": "d", "text": "It throws an exception" }
      ],
      "correct": "c",
      "explanation": "readLine() returns null at end-of-stream, distinct from an empty line (which returns \"\"). The common while ((line = reader.readLine()) != null) idiom relies on this."
    },
    {
      "id": "io-nio-buffered-reader-writer-q3",
      "type": "mcq",
      "prompt": "In `new BufferedReader(new FileReader(path))`, what role does the outer BufferedReader play?",
      "options": [
        { "id": "a", "text": "It replaces FileReader entirely and ignores it" },
        { "id": "b", "text": "It wraps FileReader, adding buffering and line-based reading, without FileReader itself changing" },
        { "id": "c", "text": "It converts the file to binary format" },
        { "id": "d", "text": "It opens a second, independent connection to the file" }
      ],
      "correct": "b",
      "explanation": "This is Java I/O's decorator pattern: FileReader handles the raw connection to the file, and BufferedReader wraps it to add buffering and convenience methods like readLine() on top."
    }
  ]
}
```

## What's next

`FileReader`/`FileWriter`/`BufferedReader`/`BufferedWriter` are all part of the original `java.io` package. The next lesson covers `java.nio.file` — the modern, more capable file API introduced in Java 7 (NIO.2), and when it's preferable to the classic `java.io.File`.
$md$, 20, $json$[{"id":"io-nio-buffered-reader-writer-q1","type":"mcq","correct":"b"},{"id":"io-nio-buffered-reader-writer-q2","type":"mcq","correct":"c"},{"id":"io-nio-buffered-reader-writer-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('48087965-9a03-5c91-9008-5b228e573a75', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3ba16252-7402-5de5-b14c-40cced0b2022', 'java.nio.file: Path and Files', 'notes', 2, $md$`java.io.File`, from the very first Java release, represents a filesystem path — but its API is thin and its error handling is famously bad (many operations just return `false` on failure instead of telling you *why*). Java 7 introduced `java.nio.file` (often called "NIO.2") as a modern replacement: the `Path` interface plus the `Files` utility class, with richer operations and exceptions that actually explain what went wrong.

## `Path` and the old `File` API, side by side

```java
import java.io.File;
import java.nio.file.Path;
import java.nio.file.Paths;

public class Main {
    public static void main(String[] args) {
        // The old way: java.io.File
        File oldStyle = new File("taskflow-exports/2024/report.txt");
        System.out.println("Old API name: " + oldStyle.getName());
        System.out.println("Old API parent: " + oldStyle.getParent());

        // The modern way: java.nio.file.Path
        Path modern = Paths.get("taskflow-exports", "2024", "report.txt");
        System.out.println("Modern API: " + modern);
        System.out.println("Modern file name: " + modern.getFileName());
        System.out.println("Modern parent: " + modern.getParent());
    }
}
```

`Paths.get(...)` builds a `Path` from one or more path segments, joining them with the correct OS-specific separator automatically — you never hardcode `/` or `\`. `Path` itself is just an immutable representation of a location; the actual filesystem operations (does it exist, read it, write it, delete it) live on the separate `Files` utility class, which is the biggest structural difference from `File`, where all of that was methods on the `File` object itself.

## `Files.exists`, `Files.write`, `Files.readAllLines`

Because these lesson code boxes run in a sandboxed environment without a persistent filesystem across separate runs, this example is self-contained: it creates a temp file with `Files.createTempFile`, writes to it, reads it back, and prints the result — all within one program execution, so you see real, live filesystem behavior every time you run it.

```java
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

public class Main {
    public static void main(String[] args) throws IOException {
        Path tempFile = Files.createTempFile("taskflow-export", ".csv");

        System.out.println("Exists before write? " + Files.exists(tempFile));

        List<String> lines = List.of(
            "Design database schema,6,HIGH",
            "Build REST API,10,HIGH",
            "Write tests,4,MEDIUM"
        );

        // Files.write can take a List<String> directly — one write call, no manual loop
        Files.write(tempFile, lines, StandardCharsets.UTF_8);

        System.out.println("Exists after write? " + Files.exists(tempFile));
        System.out.println("File size in bytes: " + Files.size(tempFile));

        // Files.readAllLines reads the whole file into a List<String> in one call
        List<String> readBack = Files.readAllLines(tempFile, StandardCharsets.UTF_8);

        int totalHours = 0;
        for (String line : readBack) {
            String[] fields = line.split(",");
            totalHours += Integer.parseInt(fields[1]);
        }

        System.out.println("Lines read back: " + readBack.size());
        System.out.println("Total estimated hours: " + totalHours);

        Files.delete(tempFile); // clean up
        System.out.println("Exists after delete? " + Files.exists(tempFile));
    }
}
```

`Files.write` and `Files.readAllLines` handle the entire buffering/closing/looping dance from the previous two lessons in a single method call each — for small-to-medium files where loading everything into memory at once is fine, this is dramatically less boilerplate than the manual `BufferedReader`/`BufferedWriter` approach. For very large files that shouldn't be loaded entirely into memory, `Files.newBufferedReader`/`Files.newBufferedWriter` give you back a `BufferedReader`/`BufferedWriter` built on a `Path`, so you're not forced to choose one style forever.

## Checking and appending

```java
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.List;

public class Main {
    public static void main(String[] args) throws IOException {
        Path tempFile = Files.createTempFile("taskflow-log", ".txt");

        Files.write(tempFile, List.of("Task created: Design schema"), StandardCharsets.UTF_8);

        // StandardOpenOption.APPEND adds to the end instead of overwriting
        Files.write(
            tempFile,
            List.of("Task created: Build REST API"),
            StandardCharsets.UTF_8,
            StandardOpenOption.APPEND
        );

        List<String> allLines = Files.readAllLines(tempFile);
        System.out.println("Total log lines: " + allLines.size());
        for (String line : allLines) {
            System.out.println(line);
        }

        Files.delete(tempFile);
    }
}
```

Without `StandardOpenOption.APPEND`, each `Files.write` call overwrites the file from scratch — this is a common surprise for anyone expecting `write` to behave like appending to a log by default.

## Why NIO.2 is generally preferred now

`java.io.File` is still around (plenty of older code and some libraries still use it), but for new code `java.nio.file` is the better default: better exceptions (`Files.readAllLines` throws a specific, descriptive `IOException` rather than `File`'s pattern of silently returning `false`/`null` on failure), a richer `Files` API (symbolic links, file attributes, directory walking, atomic moves), and `Path`'s cleaner separation between "a location" (`Path`) and "operations on that location" (`Files`).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "io-nio-nio-file-path-q1",
      "type": "mcq",
      "prompt": "What is the key structural difference between java.io.File and java.nio.file.Path?",
      "options": [
        { "id": "a", "text": "Path can only represent directories, not files" },
        { "id": "b", "text": "File bundles both the path representation and filesystem operations into one class; Path represents only the location, with operations moved to the separate Files utility class" },
        { "id": "c", "text": "Path is only usable on Linux, not Windows" },
        { "id": "d", "text": "There is no real difference — Path is just a renamed File" }
      ],
      "correct": "b",
      "explanation": "File conflates 'a path' and 'operations on that path' into one object. NIO.2 splits these: Path is an immutable location, and Files holds the static utility methods (exists, write, readAllLines, delete, etc.) that act on a Path."
    },
    {
      "id": "io-nio-nio-file-path-q2",
      "type": "mcq",
      "prompt": "Calling Files.write(path, lines) a second time on the same path, without any StandardOpenOption, does what?",
      "options": [
        { "id": "a", "text": "Appends the new lines to the end of the existing file" },
        { "id": "b", "text": "Throws an exception because the file already exists" },
        { "id": "c", "text": "Overwrites the file's previous contents from scratch" },
        { "id": "d", "text": "Merges the two sets of lines alphabetically" }
      ],
      "correct": "c",
      "explanation": "The default behavior of Files.write is to create or overwrite the file. Appending requires explicitly passing StandardOpenOption.APPEND."
    },
    {
      "id": "io-nio-nio-file-path-q3",
      "type": "mcq",
      "prompt": "Why is java.nio.file generally preferred over java.io.File for new code?",
      "options": [
        { "id": "a", "text": "java.io.File has been fully removed from modern Java" },
        { "id": "b", "text": "It offers richer functionality (symbolic links, file attributes, atomic moves) and better error reporting via descriptive exceptions instead of silent false/null returns" },
        { "id": "c", "text": "java.nio.file is faster purely because it has a shorter package name" },
        { "id": "d", "text": "java.io.File cannot read text files at all" }
      ],
      "correct": "b",
      "explanation": "java.io.File is still present for compatibility, but NIO.2's Files/Path API gives clearer failure signals (specific exceptions instead of a bare false or null) and covers more filesystem operations."
    }
  ]
}
```

## What's next

That's file I/O covered from the classic streams up through the modern NIO.2 API. The next module shifts to functional programming in Java: lambda expressions, method references, and the Stream API — tools that transform how you process collections like TaskFlow's lists of tasks.
$md$, 20, $json$[{"id":"io-nio-nio-file-path-q1","type":"mcq","correct":"b"},{"id":"io-nio-nio-file-path-q2","type":"mcq","correct":"c"},{"id":"io-nio-nio-file-path-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Lambdas & the Stream API
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('503925bd-1831-50e2-8467-8f19bc854a15', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Lambdas & the Stream API', 10)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2de1c32b-6c5f-519e-b112-3906d2a252ed', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '503925bd-1831-50e2-8467-8f19bc854a15', 'Functional Interfaces & Lambda Expressions', 'notes', 0, $md$Java 8 added the ability to pass a *chunk of behavior* — not just a value — as an argument to a method. That capability is built entirely on top of an existing Java concept: an interface with exactly one abstract method, called a **functional interface**.

## Functional interfaces: an interface with one job

```java
@FunctionalInterface
interface TaskFilter {
    boolean matches(Task task);
}

class Task {
    private final String name;
    private final int estimateHours;
    private final String priority;

    public Task(String name, int estimateHours, String priority) {
        this.name = name;
        this.estimateHours = estimateHours;
        this.priority = priority;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
    public String getPriority() { return priority; }
}

public class Main {
    static void printMatching(Task task, TaskFilter filter) {
        if (filter.matches(task)) {
            System.out.println("Matched: " + task.getName());
        } else {
            System.out.println("No match: " + task.getName());
        }
    }

    public static void main(String[] args) {
        Task urgent = new Task("Fix prod outage", 2, "HIGH");

        // An anonymous inner class implementing TaskFilter — the pre-lambda way
        TaskFilter isHighPriority = new TaskFilter() {
            @Override
            public boolean matches(Task task) {
                return task.getPriority().equals("HIGH");
            }
        };

        printMatching(urgent, isHighPriority);
    }
}
```

`@FunctionalInterface` is an optional but recommended annotation: it tells the compiler "this interface must have exactly one abstract method," and the compiler enforces it, catching a mistake (like accidentally adding a second abstract method) immediately instead of it silently breaking lambda usage elsewhere. `TaskFilter` has exactly one: `matches`. The anonymous inner class above works, but it's seven lines of ceremony to express one line of actual logic (`task.getPriority().equals("HIGH")`).

## The same thing as a lambda

```java
@FunctionalInterface
interface TaskFilter {
    boolean matches(Task task);
}

class Task {
    private final String name;
    private final int estimateHours;
    private final String priority;

    public Task(String name, int estimateHours, String priority) {
        this.name = name;
        this.estimateHours = estimateHours;
        this.priority = priority;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
    public String getPriority() { return priority; }
}

public class Main {
    static void printMatching(Task task, TaskFilter filter) {
        if (filter.matches(task)) {
            System.out.println("Matched: " + task.getName());
        } else {
            System.out.println("No match: " + task.getName());
        }
    }

    public static void main(String[] args) {
        Task urgent = new Task("Fix prod outage", 2, "HIGH");
        Task minor = new Task("Update changelog", 1, "LOW");

        // Same logic, expressed as a lambda: (parameters) -> expression
        TaskFilter isHighPriority = task -> task.getPriority().equals("HIGH");

        printMatching(urgent, isHighPriority);
        printMatching(minor, isHighPriority);
    }
}
```

`task -> task.getPriority().equals("HIGH")` is a **lambda expression**: the parameter (`task`) on the left of `->`, the body (an expression that becomes the return value) on the right. The compiler knows this lambda must implement `TaskFilter.matches(Task)` because of the variable's declared type (`TaskFilter isHighPriority = ...`) — that's how it infers `task`'s type without you writing `Task task` explicitly. No class name, no `@Override`, no boilerplate — just the behavior itself.

## Built-in functional interfaces you already know

Java ships common functional interfaces in `java.lang` and `java.util.function` so you rarely need to declare your own like `TaskFilter` above (it's here for teaching purposes — in real code, `java.util.function.Predicate<Task>` does the identical job):

```java
import java.util.List;
import java.util.Comparator;

class Task {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
}

public class Main {
    public static void main(String[] args) {
        // Runnable — zero args, no return value
        Runnable logStartup = () -> System.out.println("TaskFlow worker starting...");
        logStartup.run();

        // Comparator<Task> — two args, returns an int (a functional interface from java.util)
        Comparator<Task> byHours = (a, b) -> Integer.compare(a.getEstimateHours(), b.getEstimateHours());

        List<Task> tasks = new java.util.ArrayList<>(List.of(
            new Task("Build REST API", 10),
            new Task("Write tests", 4),
            new Task("Design schema", 6)
        ));
        tasks.sort(byHours);

        for (Task t : tasks) {
            System.out.println(t.getName() + " - " + t.getEstimateHours() + "h");
        }
    }
}
```

`Comparator<Task>` is a functional interface (one abstract method: `compare`) that already existed before Java 8 — lambdas just made it dramatically less verbose to implement inline, which is why `.sort(...)` calls with a lambda comparator are everywhere in modern Java code.

## Multi-statement lambda bodies

When a lambda needs more than one expression, wrap the body in `{ }` and use an explicit `return`:

```java
public class Main {
    interface HoursValidator {
        boolean isValid(int hours);
    }

    public static void main(String[] args) {
        HoursValidator validator = hours -> {
            if (hours <= 0) {
                return false;
            }
            return hours <= 40; // no single task should be estimated over a 40-hour work week
        };

        System.out.println(validator.isValid(6));
        System.out.println(validator.isValid(-2));
        System.out.println(validator.isValid(80));
    }
}
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "streams-lambdas-functional-interfaces-lambdas-q1",
      "type": "mcq",
      "prompt": "What makes an interface eligible to be implemented by a lambda expression?",
      "options": [
        { "id": "a", "text": "It must be marked public" },
        { "id": "b", "text": "It must have exactly one abstract method (a functional interface)" },
        { "id": "c", "text": "It must extend Runnable" },
        { "id": "d", "text": "It must contain only static methods" }
      ],
      "correct": "b",
      "explanation": "A lambda expression provides the implementation for exactly one method, so it can only stand in for an interface with exactly one abstract method — a functional interface. Default and static methods on the interface don't count against that limit."
    },
    {
      "id": "streams-lambdas-functional-interfaces-lambdas-q2",
      "type": "mcq",
      "prompt": "In `TaskFilter isHighPriority = task -> task.getPriority().equals(\"HIGH\");`, how does the compiler know the type of `task`?",
      "options": [
        { "id": "a", "text": "It defaults to Object" },
        { "id": "b", "text": "It's inferred from TaskFilter's single abstract method signature, matches(Task task), because the variable is declared as TaskFilter" },
        { "id": "c", "text": "You must always write the type explicitly in a lambda, so this example is actually invalid" },
        { "id": "d", "text": "It's inferred from the return type of the expression" }
      ],
      "correct": "b",
      "explanation": "This is called target typing: the compiler looks at the functional interface the lambda is being assigned to (TaskFilter, whose one method takes a Task) and infers the lambda parameter's type from that method's signature."
    },
    {
      "id": "streams-lambdas-functional-interfaces-lambdas-q3",
      "type": "mcq",
      "prompt": "When must a lambda body use { } with an explicit return statement instead of a bare expression?",
      "options": [
        { "id": "a", "text": "Always — bare expressions are never allowed in lambdas" },
        { "id": "b", "text": "When the lambda's logic requires more than a single expression, e.g. an if/else or multiple statements" },
        { "id": "c", "text": "Only when the lambda has zero parameters" },
        { "id": "d", "text": "Only for lambdas assigned to Comparator" }
      ],
      "correct": "b",
      "explanation": "A single-expression lambda body implicitly returns that expression's value. Once you need multiple statements or branching logic, you switch to a block body with braces and an explicit return."
    }
  ]
}
```

## What's next

Lambdas that just call one existing method — like `task -> task.getName()` — have an even shorter form: method references. The next lesson shows the same logic written both ways, side by side.
$md$, 20, $json$[{"id":"streams-lambdas-functional-interfaces-lambdas-q1","type":"mcq","correct":"b"},{"id":"streams-lambdas-functional-interfaces-lambdas-q2","type":"mcq","correct":"b"},{"id":"streams-lambdas-functional-interfaces-lambdas-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3eb171f4-a554-5aec-a551-889991564ffb', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '503925bd-1831-50e2-8467-8f19bc854a15', 'Method References', 'notes', 1, $md$A lot of lambdas do nothing but call one existing method and pass along their arguments — `task -> task.getName()` is just "call `getName()` on whatever's passed in." When a lambda is *that* thin, Java lets you skip writing it out entirely and reference the method directly. That's a **method reference**, written `Type::method`.

## `Class::instanceMethod` — same logic, shorter

```java
import java.util.List;
import java.util.function.Function;

class Task {
    private final String name;
    public Task(String name) { this.name = name; }
    public String getName() { return name; }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(new Task("Design schema"), new Task("Build API"));

        // As a lambda: takes a Task, calls getName() on it
        Function<Task, String> asLambda = task -> task.getName();

        // As a method reference: the exact same behavior, referencing the method itself
        Function<Task, String> asMethodRef = Task::getName;

        for (Task t : tasks) {
            System.out.println("Lambda: " + asLambda.apply(t));
            System.out.println("Method ref: " + asMethodRef.apply(t));
        }
    }
}
```

`Task::getName` means "for whatever object gets passed in, call `.getName()` on it" — the object being operated on becomes the implicit argument. This form (`Class::instanceMethod`) applies whenever the lambda's single parameter is exactly the thing the method is called on, with no other arguments manipulated.

## `instance::instanceMethod` — a bound reference

```java
import java.util.List;
import java.util.function.Predicate;

class Task {
    private final String name;
    private final String priority;
    public Task(String name, String priority) {
        this.name = name;
        this.priority = priority;
    }
    public String getName() { return name; }
    public String getPriority() { return priority; }
}

class PriorityMatcher {
    private final String targetPriority;
    public PriorityMatcher(String targetPriority) {
        this.targetPriority = targetPriority;
    }
    public boolean matches(Task task) {
        return task.getPriority().equals(targetPriority);
    }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Fix prod outage", "HIGH"),
            new Task("Update changelog", "LOW"),
            new Task("Security patch", "HIGH")
        );

        PriorityMatcher highMatcher = new PriorityMatcher("HIGH");

        // As a lambda: calls matches() on a specific, already-existing object (highMatcher)
        Predicate<Task> asLambda = task -> highMatcher.matches(task);

        // As a method reference: instance::method, since highMatcher already exists
        Predicate<Task> asMethodRef = highMatcher::matches;

        for (Task t : tasks) {
            if (asMethodRef.test(t)) {
                System.out.println("High priority: " + t.getName());
            }
        }
    }
}
```

`highMatcher::matches` is a **bound** method reference: `highMatcher` is a specific, already-created object, and the reference always calls `matches` on that exact instance. Compare to `Task::getName` above, which was **unbound** — the object to call it on arrives later, as the lambda's argument.

## `Class::new` — a constructor reference

```java
import java.util.List;
import java.util.function.Function;
import java.util.stream.Collectors;

class Task {
    private final String name;
    public Task(String name) { this.name = name; }
    public String getName() { return name; }

    @Override
    public String toString() { return "Task[" + name + "]"; }
}

public class Main {
    public static void main(String[] args) {
        List<String> names = List.of("Design schema", "Build API", "Write tests");

        // As a lambda: takes a String, constructs a new Task from it
        Function<String, Task> asLambda = name -> new Task(name);

        // As a method reference: Class::new — the constructor itself, referenced directly
        Function<String, Task> asMethodRef = Task::new;

        List<Task> tasks = names.stream()
            .map(asMethodRef)
            .collect(Collectors.toList());

        for (Task t : tasks) {
            System.out.println(t);
        }
    }
}
```

`Task::new` references `Task`'s constructor as a function — call it with a `String`, get back a new `Task`. This is a very common pattern when converting a `List<String>` (or any raw data) into a `List` of domain objects using `Stream.map(...)`, covered in the next lesson.

## When to use a method reference vs. a lambda

Method references are a pure readability tool — they compile to functionally identical bytecode as the equivalent lambda. Use one when the lambda would do nothing but forward its argument(s) to an existing method or constructor unchanged; reach for a full lambda the moment there's any actual logic (a condition, a transformation, multiple statements) in the body, since forcing that into a method reference usually means writing an awkward extra helper method just to have something to reference.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "streams-lambdas-method-references-q1",
      "type": "mcq",
      "prompt": "What does the method reference Task::getName represent?",
      "options": [
        { "id": "a", "text": "A call to getName() on a specific, already-existing Task object" },
        { "id": "b", "text": "An unbound reference — for whatever Task object is passed in later, call getName() on it" },
        { "id": "c", "text": "A constructor reference for the Task class" },
        { "id": "d", "text": "A static method named getName on the Task class" }
      ],
      "correct": "b",
      "explanation": "Class::instanceMethod is unbound — the instance to call the method on is supplied later, as the functional interface's argument, not fixed at the point the reference is written."
    },
    {
      "id": "streams-lambdas-method-references-q2",
      "type": "mcq",
      "prompt": "Given `PriorityMatcher highMatcher = new PriorityMatcher(\"HIGH\");`, what does highMatcher::matches represent?",
      "options": [
        { "id": "a", "text": "A bound reference — matches() is always called on the specific highMatcher object" },
        { "id": "b", "text": "The same as PriorityMatcher::matches, with no difference" },
        { "id": "c", "text": "A constructor reference" },
        { "id": "d", "text": "An error, since instance::method is not valid syntax" }
      ],
      "correct": "a",
      "explanation": "instance::method is a bound reference: the object (highMatcher) is fixed at the point the reference is created, and every call goes to that same instance — unlike Class::instanceMethod, where the instance arrives as an argument."
    },
    {
      "id": "streams-lambdas-method-references-q3",
      "type": "mcq",
      "prompt": "What does Task::new represent when used as a Function<String, Task>?",
      "options": [
        { "id": "a", "text": "A reference to a static method named new" },
        { "id": "b", "text": "A constructor reference — call it with a String argument to get back a newly constructed Task" },
        { "id": "c", "text": "It always creates a Task with default values, ignoring arguments" },
        { "id": "d", "text": "A syntax error — new cannot be referenced this way" }
      ],
      "correct": "b",
      "explanation": "Class::new is a constructor reference. Applied through a Function<String, Task>, calling .apply(name) constructs a new Task(name) — commonly used inside .map() when converting raw values into domain objects."
    }
  ]
}
```

## What's next

Method references show up constantly inside `Stream` pipelines. The next lesson covers the Stream API itself — `filter`, `map`, `collect`, `reduce`, and `sorted` — for processing TaskFlow's collections declaratively instead of with manual loops.
$md$, 15, $json$[{"id":"streams-lambdas-method-references-q1","type":"mcq","correct":"b"},{"id":"streams-lambdas-method-references-q2","type":"mcq","correct":"a"},{"id":"streams-lambdas-method-references-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a0c44f8f-b8f5-5965-880f-606956e9e658', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '503925bd-1831-50e2-8467-8f19bc854a15', 'The Stream API', 'notes', 2, $md$A `Stream` is a pipeline for processing a sequence of elements — filter some out, transform the rest, and collect or reduce the result — expressed declaratively (*what* you want) instead of imperatively (a manual loop describing *how* to get it, step by step). Streams don't store data themselves; they're a view over a source (usually a collection) that you build a pipeline on top of.

## `filter`, `map`, `collect` — the core trio

```java
import java.util.List;
import java.util.stream.Collectors;

class Task {
    private final String name;
    private final int estimateHours;
    private final String priority;

    public Task(String name, int estimateHours, String priority) {
        this.name = name;
        this.estimateHours = estimateHours;
        this.priority = priority;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
    public String getPriority() { return priority; }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Fix prod outage", 2, "HIGH"),
            new Task("Update changelog", 1, "LOW"),
            new Task("Security patch", 4, "HIGH"),
            new Task("Refactor auth module", 8, "MEDIUM")
        );

        // filter() keeps elements matching a Predicate; map() transforms each element;
        // collect() gathers the results back into a concrete collection
        List<String> highPriorityNames = tasks.stream()
            .filter(task -> task.getPriority().equals("HIGH"))
            .map(Task::getName)
            .collect(Collectors.toList());

        System.out.println(highPriorityNames);
    }
}
```

`.stream()` turns the `List<Task>` into a `Stream<Task>`. `.filter(...)` takes a `Predicate<Task>` (a lambda returning `boolean`) and keeps only matching elements. `.map(...)` takes a `Function<Task, String>` (here, the `Task::getName` method reference from the last lesson) and transforms each remaining `Task` into a `String`. `.collect(Collectors.toList())` runs the whole pipeline and gathers the output into a real `List<String>`. Nothing runs until `collect` is called — streams are **lazy**, building up a plan of operations that only executes when a terminal operation like `collect` triggers it.

## `sorted()`

```java
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

class Task {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }

    @Override
    public String toString() { return name + " (" + estimateHours + "h)"; }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Build REST API", 10),
            new Task("Write tests", 4),
            new Task("Design schema", 6)
        );

        List<Task> byHoursAscending = tasks.stream()
            .sorted(Comparator.comparingInt(Task::getEstimateHours))
            .collect(Collectors.toList());

        System.out.println("Ascending: " + byHoursAscending);

        List<Task> byHoursDescending = tasks.stream()
            .sorted(Comparator.comparingInt(Task::getEstimateHours).reversed())
            .collect(Collectors.toList());

        System.out.println("Descending: " + byHoursDescending);
    }
}
```

`sorted()` returns a new sorted stream without mutating the original list — a stream pipeline never touches its source collection, it only reads from it. `Comparator.comparingInt(Task::getEstimateHours)` builds a `Comparator<Task>` from a method reference extracting the value to compare on; `.reversed()` flips any comparator's order.

## `reduce()` — combining everything into one value

```java
import java.util.List;

class Task {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public int getEstimateHours() { return estimateHours; }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Build REST API", 10),
            new Task("Write tests", 4),
            new Task("Design schema", 6)
        );

        // reduce(identity, accumulator): start at 0, combine each element into the running total
        int totalHours = tasks.stream()
            .map(Task::getEstimateHours)
            .reduce(0, (runningTotal, hours) -> runningTotal + hours);

        System.out.println("Total estimated hours: " + totalHours);

        // For plain sums, IntStream's built-in sum() is even more direct:
        int totalHoursAlt = tasks.stream()
            .mapToInt(Task::getEstimateHours) // map() to a primitive int stream
            .sum();

        System.out.println("Total (via mapToInt/sum): " + totalHoursAlt);
    }
}
```

`reduce(identity, accumulator)` folds a stream down to a single value: `identity` (`0`) is the starting point, and `accumulator` combines the running result with each element in turn. It's the general-purpose tool — for the specific, extremely common case of summing numbers, `mapToInt(...)` converts to a primitive `IntStream`, which has a direct `.sum()` (avoiding the overhead of boxing every value to `Integer`, which the `Integer`-based `Stream<Integer>` version would otherwise incur).

## Chaining it all together

```java
import java.util.List;
import java.util.stream.Collectors;

class Task {
    private final String name;
    private final int estimateHours;
    private final String priority;

    public Task(String name, int estimateHours, String priority) {
        this.name = name;
        this.estimateHours = estimateHours;
        this.priority = priority;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
    public String getPriority() { return priority; }

    @Override
    public String toString() { return name + " (" + estimateHours + "h)"; }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Fix prod outage", 2, "HIGH"),
            new Task("Update changelog", 1, "LOW"),
            new Task("Security patch", 4, "HIGH"),
            new Task("Refactor auth module", 8, "MEDIUM")
        );

        List<String> report = tasks.stream()
            .filter(task -> task.getPriority().equals("HIGH"))
            .sorted((a, b) -> Integer.compare(a.getEstimateHours(), b.getEstimateHours()))
            .map(Task::toString)
            .collect(Collectors.toList());

        System.out.println("HIGH priority tasks, by hours ascending:");
        report.forEach(System.out::println);
    }
}
```

Each stage — `filter`, `sorted`, `map` — returns a new stream, so calls chain fluently into a single pipeline that reads top to bottom as a description of the transformation, with `collect` as the one terminal operation at the end that actually triggers all of it to run.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "streams-lambdas-stream-api-q1",
      "type": "mcq",
      "prompt": "When does a stream pipeline like tasks.stream().filter(...).map(...) actually execute?",
      "options": [
        { "id": "a", "text": "Immediately, as soon as .stream() is called" },
        { "id": "b", "text": "As soon as .filter() runs" },
        { "id": "c", "text": "Only when a terminal operation like collect() or reduce() is called — streams are lazy until then" },
        { "id": "d", "text": "On a background thread automatically" }
      ],
      "correct": "c",
      "explanation": "filter() and map() are intermediate operations that just build up a pipeline description. Nothing actually runs over the data until a terminal operation (collect, reduce, forEach, sum, etc.) is invoked."
    },
    {
      "id": "streams-lambdas-stream-api-q2",
      "type": "mcq",
      "prompt": "What does tasks.stream().map(Task::getEstimateHours).reduce(0, (total, hours) -> total + hours) compute?",
      "options": [
        { "id": "a", "text": "The average of all estimateHours values" },
        { "id": "b", "text": "The sum of all estimateHours values, starting from 0" },
        { "id": "c", "text": "The maximum estimateHours value" },
        { "id": "d", "text": "The count of tasks" }
      ],
      "correct": "b",
      "explanation": "reduce(0, accumulator) starts with identity value 0 and repeatedly combines it with each stream element using the accumulator function, here effectively summing all the hours values."
    },
    {
      "id": "streams-lambdas-stream-api-q3",
      "type": "mcq",
      "prompt": "Does calling tasks.stream().sorted(...) modify the original tasks list?",
      "options": [
        { "id": "a", "text": "Yes, it sorts the list in place" },
        { "id": "b", "text": "No — sorted() returns a new sorted stream, leaving the original source collection unchanged" },
        { "id": "c", "text": "Only if tasks is declared with var" },
        { "id": "d", "text": "It throws an exception if the list isn't already sorted" }
      ],
      "correct": "b",
      "explanation": "Stream operations never mutate their source. sorted() (like filter and map) produces a new stream; the underlying List<Task> tasks was created from is left exactly as it was."
    }
  ]
}
```

## What's next

Stream pipelines that search for something — like finding a specific task by name — often come up empty. The next lesson covers `Optional`, Java's type-safe alternative to returning `null` for "nothing found."
$md$, 25, $json$[{"id":"streams-lambdas-stream-api-q1","type":"mcq","correct":"c"},{"id":"streams-lambdas-stream-api-q2","type":"mcq","correct":"b"},{"id":"streams-lambdas-stream-api-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e1dcf5c8-6d9f-513d-a7f9-a4815c6b670a', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '503925bd-1831-50e2-8467-8f19bc854a15', 'Optional', 'notes', 3, $md$"Find the task named X" is a search that might fail — the task might not exist. The traditional Java answer is to return `null` when nothing's found, but `null` is a landmine: nothing in a method's signature warns a caller that it might come back, so a missed `null` check surfaces later as a `NullPointerException`, often far from where the actual problem originated. `Optional<T>` makes "this might have nothing in it" part of the type itself, impossible to ignore silently.

## The problem with returning `null`

```java
import java.util.List;

class Task {
    private final String name;
    public Task(String name) { this.name = name; }
    public String getName() { return name; }
}

public class Main {
    // Nothing in this signature warns the caller that null is a possible return value
    static Task findByName(List<Task> tasks, String name) {
        for (Task t : tasks) {
            if (t.getName().equals(name)) {
                return t;
            }
        }
        return null;
    }

    public static void main(String[] args) {
        List<Task> tasks = List.of(new Task("Design schema"), new Task("Build API"));

        Task found = findByName(tasks, "Nonexistent task");
        // Forgetting a null check here is a NullPointerException waiting to happen:
        // System.out.println(found.getName()); // would throw NPE

        if (found != null) {
            System.out.println("Found: " + found.getName());
        } else {
            System.out.println("Not found");
        }
    }
}
```

That works, but it relies entirely on the caller *remembering* to check for `null` — the compiler gives no help and no warning either way.

## `Optional.ofNullable` and the same search, rewritten

```java
import java.util.List;
import java.util.Optional;

class Task {
    private final String name;
    public Task(String name) { this.name = name; }
    public String getName() { return name; }
}

public class Main {
    // The return type itself now documents that "nothing found" is a real possibility
    static Optional<Task> findByName(List<Task> tasks, String name) {
        for (Task t : tasks) {
            if (t.getName().equals(name)) {
                return Optional.of(t); // Optional.of() — value is known non-null
            }
        }
        return Optional.empty(); // explicitly "nothing here", instead of null
    }

    public static void main(String[] args) {
        List<Task> tasks = List.of(new Task("Design schema"), new Task("Build API"));

        Optional<Task> maybeFound = findByName(tasks, "Design schema");
        Optional<Task> maybeMissing = findByName(tasks, "Nonexistent task");

        System.out.println("Found is present: " + maybeFound.isPresent());
        System.out.println("Missing is present: " + maybeMissing.isPresent());
    }
}
```

`Optional.of(value)` wraps a value that's known to be non-null (it throws immediately if you pass `null` — a fast, obvious failure instead of a delayed one). `Optional.empty()` explicitly represents "nothing here." `Optional.ofNullable(value)` is the third option, used when the value itself might legitimately be `null` and you want that automatically converted into an empty `Optional`:

```java
import java.util.Optional;

public class Main {
    public static void main(String[] args) {
        String maybeNullName = null;

        // ofNullable: wraps a possibly-null value, becomes empty if it IS null
        Optional<String> wrapped = Optional.ofNullable(maybeNullName);
        System.out.println("Present: " + wrapped.isPresent());

        String actualName = "Design schema";
        Optional<String> wrapped2 = Optional.ofNullable(actualName);
        System.out.println("Present: " + wrapped2.isPresent());
    }
}
```

## Consuming an `Optional`: `map`, `orElse`, `ifPresent`

```java
import java.util.List;
import java.util.Optional;

class Task {
    private final String name;
    private final int estimateHours;
    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }
    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
}

public class Main {
    static Optional<Task> findByName(List<Task> tasks, String name) {
        return tasks.stream()
            .filter(t -> t.getName().equals(name))
            .findFirst(); // findFirst() itself already returns an Optional<Task>
    }

    public static void main(String[] args) {
        List<Task> tasks = List.of(new Task("Design schema", 6), new Task("Build API", 10));

        Optional<Task> found = findByName(tasks, "Design schema");
        Optional<Task> missing = findByName(tasks, "Nonexistent task");

        // map() transforms the value inside, only if present — a no-op on an empty Optional
        Optional<String> foundSummary = found.map(t -> t.getName() + " (" + t.getEstimateHours() + "h)");
        Optional<String> missingSummary = missing.map(t -> t.getName() + " (" + t.getEstimateHours() + "h)");

        // orElse() supplies a fallback value when the Optional is empty
        System.out.println(foundSummary.orElse("No summary available"));
        System.out.println(missingSummary.orElse("No summary available"));

        // ifPresent() runs a lambda only when a value exists — no manual null check needed
        found.ifPresent(t -> System.out.println("Located task: " + t.getName()));
        missing.ifPresent(t -> System.out.println("This line never prints"));

        System.out.println("Missing search had a value: " + missing.isPresent());
    }
}
```

`map()` on an `Optional` mirrors `map()` on a `Stream`: transform the contents if there's something to transform, otherwise stay empty and skip the lambda entirely — `missingSummary` above never actually runs the `t -> ...` lambda, because `missing` was empty. `orElse(fallback)` unwraps the `Optional`, substituting `fallback` if it was empty. `ifPresent(consumer)` is the imperative-style escape hatch: run this code only if a value exists, otherwise do nothing — replacing `if (found != null) { ... }` with something the compiler-checked type system actually models.

`Optional` is meant for **return types**, signaling "this might not have a result" — it's generally discouraged as a field type or a method parameter type, since those already have simpler ways (like just checking for `null`, or not allowing it in the first place) to express the same thing.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "streams-lambdas-optional-q1",
      "type": "mcq",
      "prompt": "What problem does Optional<T> as a return type solve compared to returning null?",
      "options": [
        { "id": "a", "text": "It makes the method run faster" },
        { "id": "b", "text": "It makes 'this might have no result' part of the method's signature, so the compiler and the caller can't silently ignore the possibility the way they can with null" },
        { "id": "c", "text": "It automatically retries the search until a value is found" },
        { "id": "d", "text": "It converts every result into a String" }
      ],
      "correct": "b",
      "explanation": "A method returning Task can secretly return null with no signal in its signature. A method returning Optional<Task> documents 'may be empty' directly in the type, and consuming it via map/orElse/ifPresent naturally handles the empty case instead of relying on the caller remembering a null check."
    },
    {
      "id": "streams-lambdas-optional-q2",
      "type": "mcq",
      "prompt": "What is the difference between Optional.of(value) and Optional.ofNullable(value)?",
      "options": [
        { "id": "a", "text": "They are identical in every case" },
        { "id": "b", "text": "Optional.of throws immediately if value is null; Optional.ofNullable instead returns an empty Optional when value is null" },
        { "id": "c", "text": "Optional.of is only for primitive types" },
        { "id": "d", "text": "Optional.ofNullable can only be called on Strings" }
      ],
      "correct": "b",
      "explanation": "Optional.of(value) asserts the value is definitely non-null and throws a NullPointerException immediately if that assertion is wrong. Optional.ofNullable(value) is the safe version for a value that might genuinely be null, converting that case into Optional.empty() instead of throwing."
    },
    {
      "id": "streams-lambdas-optional-q3",
      "type": "mcq",
      "prompt": "Given `Optional<Task> missing = Optional.empty();`, what does missing.map(t -> t.getName()) return?",
      "options": [
        { "id": "a", "text": "null" },
        { "id": "b", "text": "It throws a NullPointerException" },
        { "id": "c", "text": "An empty Optional<String> — the lambda is never invoked on an empty Optional" },
        { "id": "d", "text": "Optional.of(\"\")" }
      ],
      "correct": "c",
      "explanation": "map() on Optional is a no-op when the Optional is empty: it skips calling the lambda entirely and simply returns another empty Optional, propagating the absence rather than crashing."
    }
  ]
}
```

## What's next

That covers functional interfaces, lambdas, method references, the Stream API, and Optional — the full functional-programming toolkit this module set out to build. The module quiz below checks your understanding across all four lessons.
$md$, 20, $json$[{"id":"streams-lambdas-optional-q1","type":"mcq","correct":"b"},{"id":"streams-lambdas-optional-q2","type":"mcq","correct":"b"},{"id":"streams-lambdas-optional-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e16325a2-19e1-555c-b37c-e524ce7358f5', '00000000-0000-0000-0000-000000000001', 'mcq', 'What defines a functional interface in Java?', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5cccf75b-6bf9-5a15-9aed-574b861e9a93', 'e16325a2-19e1-555c-b37c-e524ce7358f5', 1, $json${"prompt":"What defines a functional interface in Java?","multiple":false,"options":[{"id":"a","text":"It has exactly one abstract method","is_correct":true},{"id":"b","text":"It has no methods at all","is_correct":false},{"id":"c","text":"It is annotated @FunctionalInterface, and that annotation alone is what makes it one","is_correct":false},{"id":"d","text":"It must be declared inside another interface","is_correct":false}],"explanation":"A functional interface has exactly one abstract method, which is what makes it possible for a lambda expression to implement it. @FunctionalInterface is an optional annotation that asks the compiler to enforce this — it documents the intent, it doesn't create it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f05a0f64-5d8f-513b-a4d4-082d6c1efe7a', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the difference between the method references Task::getName and someTa...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ca7e455a-99aa-54e7-a69f-d66ffc2d3ff2', 'f05a0f64-5d8f-513b-a4d4-082d6c1efe7a', 1, $json${"prompt":"What is the difference between the method references Task::getName and someTask::getPriority (where someTask is an existing Task variable)?","multiple":false,"options":[{"id":"a","text":"Task::getName is unbound (the instance arrives as the lambda's argument); someTask::getPriority is bound to that specific already-existing object","is_correct":true},{"id":"b","text":"There is no difference — both forms behave identically","is_correct":false},{"id":"c","text":"Task::getName only works inside streams, someTask::getPriority only works outside them","is_correct":false},{"id":"d","text":"someTask::getPriority is invalid syntax","is_correct":false}],"explanation":"Class::instanceMethod (Task::getName) is unbound: the object to call the method on is supplied later. instance::instanceMethod (someTask::getPriority) is bound: it always operates on that one specific, already-created object."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5d7e62f5-bed2-5229-859e-26c32e5e3192', '00000000-0000-0000-0000-000000000001', 'mcq', 'Given `tasks.stream().filter(t -> t.getPriority().equals("HIGH"))` with no te...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('6d4dd4d3-9cd1-5ea8-b9e6-1fcc153b9cf9', '5d7e62f5-bed2-5229-859e-26c32e5e3192', 1, $json${"prompt":"Given `tasks.stream().filter(t -\u003e t.getPriority().equals(\"HIGH\"))` with no terminal operation called afterward, what happens?","multiple":false,"options":[{"id":"a","text":"The filter runs immediately over every task","is_correct":false},{"id":"b","text":"Nothing happens yet — filter() only builds up the pipeline; it isn't executed until a terminal operation like collect() or forEach() is called","is_correct":true},{"id":"c","text":"It throws an exception because a stream must always end in collect()","is_correct":false},{"id":"d","text":"It returns a List\u003cTask\u003e directly","is_correct":false}],"explanation":"Streams are lazy. Intermediate operations like filter() and map() just describe the pipeline; nothing actually iterates the source until a terminal operation triggers execution."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00fc6ac3-fc74-54ca-9431-0bb2240f483f', '00000000-0000-0000-0000-000000000001', 'mcq', 'A pipeline needs to combine every Task''s estimateHours into a single running ...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b98bf518-b284-5ccb-a237-599e897f0280', '00fc6ac3-fc74-54ca-9431-0bb2240f483f', 1, $json${"prompt":"A pipeline needs to combine every Task's estimateHours into a single running total (an int). Which terminal operation is designed for that?","multiple":false,"options":[{"id":"a","text":"collect(Collectors.toList())","is_correct":false},{"id":"b","text":"sorted()","is_correct":false},{"id":"c","text":"reduce(0, (total, hours) -\u003e total + hours), typically after mapping each Task to its hours","is_correct":true},{"id":"d","text":"filter()","is_correct":false}],"explanation":"reduce() folds a stream down to a single combined value using an identity starting point and an accumulator function — exactly the shape needed for a running total. collect(Collectors.toList()) instead gathers elements into a new collection, not a single scalar."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a7b8c067-04d7-5899-af98-ed983a57e386', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why is Optional<Task> generally preferred over returning a possibly-null Task...', 'advanced', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d9beff42-9c39-5050-ab6a-eb6a7ddaaf87', 'a7b8c067-04d7-5899-af98-ed983a57e386', 1, $json${"prompt":"Why is Optional\u003cTask\u003e generally preferred over returning a possibly-null Task from a search method?","multiple":false,"options":[{"id":"a","text":"Optional makes the method run faster than returning null","is_correct":false},{"id":"b","text":"Optional forces the 'might be empty' case into the method's return type, so callers use map/orElse/ifPresent instead of silently forgetting a null check","is_correct":true},{"id":"c","text":"Optional\u003cTask\u003e and Task are interchangeable, so it makes no real difference","is_correct":false},{"id":"d","text":"Returning null is illegal in modern Java","is_correct":false}],"explanation":"Optional communicates possible absence directly through the type system. A caller working with Optional\u003cTask\u003e is guided toward handling the empty case (via orElse, ifPresent, map) rather than relying on discipline to remember a null check on a plain Task return."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('90721500-189b-5464-98d7-27b2632592be', '00000000-0000-0000-0000-000000000001', 'coding', 'TaskFlow needs to report total hours spent on tasks above a certain size. Rea...', 'intermediate', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c53c2ca6-22b0-5d9d-8177-aa4ddfa8a95d', '90721500-189b-5464-98d7-27b2632592be', 1, $json${"prompt":"TaskFlow needs to report total hours spent on tasks above a certain size. Read a single integer threshold from the first line of input. Read the second line as a space-separated list of integers (task hours). Using a Stream with a filter and a sum, print a single integer: the sum of only the hours strictly greater than the threshold, with no extra text.","languages":["java"],"starter_code":{"java":"import java.util.Scanner;\nimport java.util.ArrayList;\nimport java.util.List;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        int threshold = Integer.parseInt(scanner.nextLine().trim());\n        String[] tokens = scanner.nextLine().trim().split(\"\\\\s+\");\n\n        List\u003cInteger\u003e hours = new ArrayList\u003c\u003e();\n        for (String token : tokens) {\n            hours.add(Integer.parseInt(token));\n        }\n\n        // TODO: use hours.stream() with .filter() and .mapToInt(...).sum()\n        // to print the sum of only the values strictly greater than threshold.\n\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"5\n6 3 8 2 10\n","expected":"24","hidden":false,"weight":1},{"id":"t2","stdin":"0\n1 2 3\n","expected":"6","hidden":false,"weight":1},{"id":"t3","stdin":"100\n10 20 30\n","expected":"0","hidden":true,"weight":1},{"id":"t4","stdin":"5\n5 5 5\n","expected":"0","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('52de115e-8af8-563a-b40f-16377ac270df', '00000000-0000-0000-0000-000000000001', 'subjective', 'In your own words: which concept from this module (functional interfaces and ...', 'beginner', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('67176ec1-92ce-5097-8a33-960a6cace809', '52de115e-8af8-563a-b40f-16377ac270df', 1, $json${"prompt":"In your own words: which concept from this module (functional interfaces and lambdas, method references, the Stream API, or Optional) felt least intuitive, and why? Be specific — this feeds directly into what gets flagged for review.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which topic you're actually shakiest on, not to test recall."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('dc637973-d4f2-5b72-a15a-e7c7d2eccbf2', '00000000-0000-0000-0000-000000000001', 'Module Assessment: Lambdas & the Stream API', 'java-mastery-streams-lambdas-quiz', 'Quiz covering Lambdas & the Stream API.', 'mixed', 'published', 'module', '9948e0bc-3c89-504d-90f5-43db14dd925f', 25, 70, 5, 14, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('928af280-03ac-569d-851a-4cfdfe7150b9', 'dc637973-d4f2-5b72-a15a-e7c7d2eccbf2', 'e16325a2-19e1-555c-b37c-e524ce7358f5', '5cccf75b-6bf9-5a15-9aed-574b861e9a93', 0, 1),
('8d849132-5c7b-5479-882f-7ab16e5cd0c5', 'dc637973-d4f2-5b72-a15a-e7c7d2eccbf2', 'f05a0f64-5d8f-513b-a4d4-082d6c1efe7a', 'ca7e455a-99aa-54e7-a69f-d66ffc2d3ff2', 1, 2),
('4368f16e-b8cf-50b3-9387-bb869d3e90b8', 'dc637973-d4f2-5b72-a15a-e7c7d2eccbf2', '5d7e62f5-bed2-5229-859e-26c32e5e3192', '6d4dd4d3-9cd1-5ea8-b9e6-1fcc153b9cf9', 2, 2),
('2c9e61d7-b72b-5caf-b28c-895ec61df666', 'dc637973-d4f2-5b72-a15a-e7c7d2eccbf2', '00fc6ac3-fc74-54ca-9431-0bb2240f483f', 'b98bf518-b284-5ccb-a237-599e897f0280', 3, 2),
('a4f5820e-fd61-5a01-b4e7-e2ca183cbd42', 'dc637973-d4f2-5b72-a15a-e7c7d2eccbf2', 'a7b8c067-04d7-5899-af98-ed983a57e386', 'd9beff42-9c39-5050-ab6a-eb6a7ddaaf87', 4, 2),
('2acf4e54-7d5d-51ca-9337-b9425d1554d2', 'dc637973-d4f2-5b72-a15a-e7c7d2eccbf2', '90721500-189b-5464-98d7-27b2632592be', 'c53c2ca6-22b0-5d9d-8177-aa4ddfa8a95d', 5, 3),
('c15422ab-81c2-5400-ad29-e24f8d722d50', 'dc637973-d4f2-5b72-a15a-e7c7d2eccbf2', '52de115e-8af8-563a-b40f-16377ac270df', '67176ec1-92ce-5097-8a33-960a6cace809', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('9948e0bc-3c89-504d-90f5-43db14dd925f', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '503925bd-1831-50e2-8467-8f19bc854a15', 'Module Assessment: Lambdas & the Stream API', 'assessment', 4, 25, 'dc637973-d4f2-5b72-a15a-e7c7d2eccbf2')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Concurrency
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('3c0af571-5278-514d-b5e2-0c8a2fc060b7', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Concurrency', 11)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('86f4c625-e4a6-5fc3-8486-ff7abfcbb7ff', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3c0af571-5278-514d-b5e2-0c8a2fc060b7', 'Threads and Runnable Basics', 'notes', 0, $md$Every TaskFlow program you've written so far runs on a single thread: one instruction after another, top to bottom. That's fine for small examples, but real TaskFlow workloads don't look like that — imagine a nightly job that has to process a batch of 10,000 overdue tasks (recalculating priority, sending reminder emails, updating status). Doing that one task at a time, waiting for each to finish before starting the next, wastes the CPU's other cores sitting idle while each individual task is mostly waiting on I/O anyway. **Concurrency** is how Java lets a program make progress on more than one unit of work at a time.

## Concurrency vs. parallelism

These two words get used interchangeably, but they mean different things. **Concurrency** is about *structure*: a program is concurrent if it's composed of multiple independent tasks that can be worked on out of order or in overlapping time windows — even on a single CPU core, by rapidly switching between them. **Parallelism** is about *execution*: tasks are parallel if they are literally running at the same physical instant, which requires multiple CPU cores. A single-core machine can still run concurrent code (the OS time-slices between threads), but it can never truly run two threads in parallel. Java's threading APIs give you concurrency; whether the JVM turns that into real parallelism depends on how many cores the underlying hardware has. In practice, for TaskFlow's batch job, you write it as concurrent (independent per-task units of work) and let the JVM and OS exploit however many cores are actually available.

## Creating and starting a Thread

Java models a thread of execution with the `Thread` class. The simplest way to give it work to do is to hand it a `Runnable` — a functional interface with a single method, `void run()`:

```java
public class Main {
    public static void main(String[] args) {
        Runnable processTask = () -> {
            System.out.println("Processing task on: " + Thread.currentThread().getName());
        };

        Thread worker = new Thread(processTask, "task-worker-1");
        worker.start();

        try {
            worker.join(); // wait for the worker thread to finish before continuing
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        System.out.println("Main thread continues after worker finished.");
    }
}
```

A few pieces worth calling out:

- `new Thread(processTask, "task-worker-1")` wraps the `Runnable` in a `Thread` object and gives it a name — useful for debugging when you have many threads running at once.
- `worker.start()` is what actually creates a new OS-level thread and begins running `run()` concurrently with `main`. **Calling `worker.run()` directly instead of `start()` is a common mistake** — that just calls the method like any other, on the current thread, with no concurrency at all.
- `worker.join()` blocks the calling thread (here, `main`) until `worker` finishes. Without it, `main` could reach the end of the program before the worker thread ever gets scheduled to run, and you might not see its output at all.
- `Thread.currentThread()` returns a reference to whichever thread is currently executing that line — inside the lambda, that's `worker`, not `main`.

## Running several TaskFlow jobs concurrently

Here's the batch-processing scenario made concrete: three independent tasks, each simulated by a short unit of "work," run on their own threads instead of sequentially. Because thread scheduling order between the three worker threads is not guaranteed, this example joins every thread before printing anything from the workers' *results* — the workers themselves don't print in the middle, only the main thread prints a final, deterministic summary after all of them are done:

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        String[] taskNames = { "Design database schema", "Build REST API", "Write tests" };
        int[] results = new int[taskNames.length];
        List<Thread> workers = new ArrayList<>();

        for (int i = 0; i < taskNames.length; i++) {
            final int index = i;
            Thread worker = new Thread(() -> {
                // Simulate work: compute something and store it, don't print from here.
                results[index] = taskNames[index].length();
            });
            workers.add(worker);
            worker.start();
        }

        // Join every worker before reading results — guarantees all writes finished.
        for (Thread worker : workers) {
            worker.join();
        }

        int totalCharacters = 0;
        for (int i = 0; i < taskNames.length; i++) {
            System.out.println(taskNames[i] + " -> " + results[i] + " characters");
            totalCharacters += results[i];
        }
        System.out.println("Total: " + totalCharacters);
    }
}
```

Notice the pattern: each thread only writes to its own slot in `results` (`results[index]`), so there's no shared mutable state being written by two threads at once, and the `main` thread only reads `results` after every worker has been joined. That combination is what makes the output deterministic on every run, even though the JVM is free to schedule the three worker threads in any order or interleaving it likes. The next lesson covers what goes wrong when two threads *do* write to the same shared state without this kind of coordination.

## Why not just use more threads for everything?

Creating a `Thread` per unit of work is fine for a handful of tasks, but it doesn't scale: each OS thread costs real memory (a stack, typically at least half a megabyte) and real scheduling overhead. Spinning up 10,000 raw `Thread` objects for that overdue-tasks batch job would likely exhaust memory or thrash the OS scheduler before it exhausted the actual work. That's the motivation for thread pools, covered in the `ExecutorService` lesson later in this module — they let you reuse a small, bounded number of threads across a much larger number of tasks.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-threads-and-runnable-q1",
      "type": "mcq",
      "prompt": "What's the difference between concurrency and parallelism?",
      "options": [
        { "id": "a", "text": "They are the same thing, just different names for multithreading" },
        { "id": "b", "text": "Concurrency is about structuring a program as independent tasks that can overlap; parallelism is about those tasks literally executing at the same instant on multiple cores" },
        { "id": "c", "text": "Parallelism only applies to Java, concurrency only applies to other languages" },
        { "id": "d", "text": "Concurrency requires multiple CPU cores; parallelism does not" }
      ],
      "correct": "b",
      "explanation": "Concurrency is a structural property of the program (independent tasks that can be interleaved); parallelism is a runtime property that requires multiple cores actually executing simultaneously. Concurrent code can run on one core via time-slicing without ever being parallel."
    },
    {
      "id": "concurrency-threads-and-runnable-q2",
      "type": "mcq",
      "prompt": "What happens if you call worker.run() instead of worker.start()?",
      "options": [
        { "id": "a", "text": "It throws an IllegalStateException" },
        { "id": "b", "text": "It behaves identically to start() but is slightly slower" },
        { "id": "c", "text": "run() executes like a normal method call on the current thread — no new thread is created, so there's no concurrency" },
        { "id": "d", "text": "It starts the thread but does not run any code until join() is called" }
      ],
      "correct": "c",
      "explanation": "start() is the only method that actually creates a new OS thread and schedules run() to execute on it. Calling run() directly just invokes that method synchronously on whichever thread called it."
    },
    {
      "id": "concurrency-threads-and-runnable-q3",
      "type": "mcq",
      "prompt": "In the batch-processing example, why does every result print in the same order on every run despite thread scheduling being nondeterministic?",
      "options": [
        { "id": "a", "text": "Because Thread objects always execute in the order they were created" },
        { "id": "b", "text": "Because each worker writes only to its own array slot, and all workers are joined before the main thread reads any results and prints" },
        { "id": "c", "text": "Because println is thread-safe, which guarantees ordering" },
        { "id": "d", "text": "It doesn't — the output order is actually random" }
      ],
      "correct": "b",
      "explanation": "Determinism here comes from the coordination pattern, not luck: no shared slot is written by more than one thread, and join() guarantees every write has completed before main reads results[] and prints in a fixed, sequential order."
    }
  ]
}
```

## What's next

Sharing state safely between threads — not just writing to separate array slots — is where concurrency gets genuinely tricky. The next lesson demonstrates a real race condition and fixes it with `synchronized`.
$md$, 20, $json$[{"id":"concurrency-threads-and-runnable-q1","type":"mcq","correct":"b"},{"id":"concurrency-threads-and-runnable-q2","type":"mcq","correct":"c"},{"id":"concurrency-threads-and-runnable-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ff6bacd6-ae8d-5dde-b163-dea29b427211', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3c0af571-5278-514d-b5e2-0c8a2fc060b7', 'synchronized and Race Conditions', 'notes', 1, $md$The previous lesson's example avoided a whole category of bug by having each thread write only to its own array slot. Real TaskFlow code isn't always that lucky — sometimes multiple threads genuinely need to update the *same* shared value, like a running counter of how many tasks a batch job has completed so far. That's where **race conditions** come from, and where `synchronized` earns its keep.

## What a race condition actually is

A race condition happens when two or more threads access shared mutable state, at least one of them writes to it, and the final result depends on the unpredictable timing of how their operations interleave. The classic example is `count++`. It looks like a single atomic operation, but it's actually three separate steps at the instruction level:

1. **Read** the current value of `count` from memory.
2. **Modify** it — compute `current value + 1`.
3. **Write** the new value back to memory.

If two threads both execute `count++` at "the same time," the CPU can interleave their three steps. Imagine `count` starts at 5:

- Thread A reads `count` (5).
- Thread B reads `count` (5) — before A has written anything back.
- Thread A computes `5 + 1 = 6` and writes `6`.
- Thread B computes `5 + 1 = 6` (using the stale value it read) and writes `6`.

Two increments happened, but `count` only went from 5 to 6 instead of 7 — one update was silently lost. This is exactly the kind of bug that's maddening in production: it doesn't happen every time, only under the "wrong" timing, so it can pass every manual test and still corrupt data under real concurrent load.

## Demonstrating the race condition

```java
public class Main {
    public static void main(String[] args) throws InterruptedException {
        Counter counter = new Counter();
        int incrementsPerThread = 100_000;

        Runnable incrementTask = () -> {
            for (int i = 0; i < incrementsPerThread; i++) {
                counter.incrementUnsafe();
            }
        };

        Thread t1 = new Thread(incrementTask);
        Thread t2 = new Thread(incrementTask);
        t1.start();
        t2.start();
        t1.join();
        t2.join();

        int expected = incrementsPerThread * 2;
        System.out.println("Expected: " + expected);
        System.out.println("Actual is less than or equal to expected: " + (counter.getCount() <= expected));
    }
}

class Counter {
    private int count = 0;

    void incrementUnsafe() {
        count++; // read-modify-write, NOT atomic — this is the race
    }

    int getCount() {
        return count;
    }
}
```

Notice this example doesn't print `counter.getCount()` directly — the whole point is that its exact value is *not* deterministic (it will typically be some number less than 200,000, but exactly how much less varies run to run and machine to machine). Instead it prints a comparison (`<= expected`) that is always `true` regardless of how badly the race lost updates, keeping the visible output identical on every run while still demonstrating that the race exists.

## Fixing it with synchronized

The `synchronized` keyword makes a block of code (or an entire method) **mutually exclusive**: only one thread can be executing inside a `synchronized` block guarded by a given object's lock at any moment. Every Java object has an intrinsic lock (also called a monitor) built in; `synchronized` acquires and releases it automatically.

```java
public class Main {
    public static void main(String[] args) throws InterruptedException {
        SafeCounter counter = new SafeCounter();
        int incrementsPerThread = 100_000;

        Runnable incrementTask = () -> {
            for (int i = 0; i < incrementsPerThread; i++) {
                counter.incrementSafe();
            }
        };

        Thread t1 = new Thread(incrementTask);
        Thread t2 = new Thread(incrementTask);
        t1.start();
        t2.start();
        t1.join();
        t2.join();

        System.out.println("Final count: " + counter.getCount()); // always exactly 200000
    }
}

class SafeCounter {
    private int count = 0;

    synchronized void incrementSafe() {
        count++; // only one thread executes this at a time
    }

    synchronized int getCount() {
        return count;
    }
}
```

With `incrementSafe()` declared `synchronized`, each call to `count++` fully completes (read, modify, write) before another thread is allowed to enter the method — the three-step race from before can no longer interleave. This version reliably prints `200000` every single time, because the lock forces the two threads' increments to happen one after another rather than overlapping. `getCount()` is also synchronized so a reader can't observe a half-written value, though for a single `int` field that specific case is less of a concern than for larger, multi-field state.

## synchronized blocks vs. synchronized methods

You don't have to synchronize an entire method — a `synchronized (someObject) { ... }` block locks on just the critical section, which can be narrower and more efficient if a method does other work that doesn't touch shared state:

```java
public class Main {
    public static void main(String[] args) throws InterruptedException {
        TaskFlowStats stats = new TaskFlowStats();

        Runnable recordTask = () -> {
            for (int i = 0; i < 1000; i++) {
                stats.recordCompletion(2); // 2 hours per completed task
            }
        };

        Thread t1 = new Thread(recordTask);
        Thread t2 = new Thread(recordTask);
        t1.start();
        t2.start();
        t1.join();
        t2.join();

        System.out.println("Completed: " + stats.getCompletedCount());
        System.out.println("Total hours: " + stats.getTotalHours());
    }
}

class TaskFlowStats {
    private final Object lock = new Object();
    private int completedCount = 0;
    private int totalHours = 0;

    void recordCompletion(int hours) {
        synchronized (lock) {
            completedCount++;
            totalHours += hours;
        }
    }

    int getCompletedCount() {
        synchronized (lock) {
            return completedCount;
        }
    }

    int getTotalHours() {
        synchronized (lock) {
            return totalHours;
        }
    }
}
```

Using a dedicated private `lock` object (rather than `this`) is a common defensive pattern: it guarantees nothing outside the class can accidentally synchronize on the same lock and create unexpected contention or deadlocks. Both `completedCount` and `totalHours` are updated together inside the same `synchronized` block, so a reader thread never sees one field updated without the other — that's the real value of grouping related state under one lock.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-synchronized-and-race-conditions-q1",
      "type": "mcq",
      "prompt": "Why is count++ not atomic even though it looks like a single operation?",
      "options": [
        { "id": "a", "text": "It's actually three separate steps — read the current value, compute the increment, write the new value back — and another thread can interleave between them" },
        { "id": "b", "text": "Because int is not a primitive type in Java" },
        { "id": "c", "text": "It is atomic; race conditions on count++ are a myth" },
        { "id": "d", "text": "Because ++ always triggers a full garbage collection cycle" }
      ],
      "correct": "a",
      "explanation": "count++ compiles to a read, a modify, and a write. Without synchronization, two threads can both read the same stale value before either writes back, silently losing one of the two increments."
    },
    {
      "id": "concurrency-synchronized-and-race-conditions-q2",
      "type": "mcq",
      "prompt": "What does declaring a method synchronized guarantee?",
      "options": [
        { "id": "a", "text": "The method will run faster because the JVM optimizes it" },
        { "id": "b", "text": "Only one thread at a time can be executing inside that method on a given object's lock, so its operations can't interleave with another thread's call to a method synchronized on the same lock" },
        { "id": "c", "text": "The method's return value is cached across calls" },
        { "id": "d", "text": "The method can no longer throw exceptions" }
      ],
      "correct": "b",
      "explanation": "synchronized enforces mutual exclusion on the associated lock (an object's intrinsic monitor by default). Other threads trying to enter a block synchronized on the same lock must wait until the current thread exits it."
    },
    {
      "id": "concurrency-synchronized-and-race-conditions-q3",
      "type": "mcq",
      "prompt": "Why might a class use a dedicated private Object lock field instead of synchronizing on `this`?",
      "options": [
        { "id": "a", "text": "synchronized(this) is a compile error" },
        { "id": "b", "text": "A private lock object guarantees no external code can accidentally synchronize on the same lock, avoiding unexpected contention or deadlocks from outside the class" },
        { "id": "c", "text": "Private lock objects execute faster than synchronizing on this" },
        { "id": "d", "text": "It has no practical difference; it's purely stylistic" }
      ],
      "correct": "b",
      "explanation": "this is publicly reachable by anyone with a reference to the object, so external code could synchronize on it too, creating surprising coupling. A private lock field is only ever visible to the class itself."
    }
  ]
}
```

## What's next

Manually creating and synchronizing raw threads doesn't scale past a handful of tasks. The next lesson introduces `ExecutorService`, a managed thread pool that TaskFlow can submit jobs to instead.
$md$, 20, $json$[{"id":"concurrency-synchronized-and-race-conditions-q1","type":"mcq","correct":"a"},{"id":"concurrency-synchronized-and-race-conditions-q2","type":"mcq","correct":"b"},{"id":"concurrency-synchronized-and-race-conditions-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9f28e2da-cf59-5af7-bd2f-4a1da74cd6bd', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3c0af571-5278-514d-b5e2-0c8a2fc060b7', 'ExecutorService, Callable, and Future', 'notes', 2, $md$The first lesson in this module flagged the problem: creating a raw `Thread` per unit of work doesn't scale, because every OS thread costs real memory and scheduling overhead. If TaskFlow needs to process 10,000 overdue tasks, you don't want 10,000 threads fighting over the CPU at once. What you actually want is a small, fixed pool of worker threads that pulls jobs off a queue and reuses itself for the next job when it finishes the current one. That's exactly what `ExecutorService` gives you.

## Why thread pools exist

Two problems drive the design: **reuse** and **bounded resource usage**. Creating and destroying an OS thread is expensive relative to the work it might do; a pool amortizes that cost by keeping a fixed set of threads alive and handing them job after job. Bounding the pool size also protects the rest of the system — instead of letting 10,000 tasks spin up 10,000 threads and exhaust memory, a pool of, say, 8 threads processes them 8 at a time, queuing the rest until a worker frees up.

## Submitting work to an ExecutorService

```java
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        ExecutorService pool = Executors.newFixedThreadPool(4);

        String[] taskNames = {
            "Design database schema", "Build REST API", "Write tests", "Deploy to staging"
        };

        for (String taskName : taskNames) {
            pool.submit(() -> {
                // "Process" the task — in real TaskFlow this might recalculate
                // priority, send a reminder, or update a status field.
                System.out.println("Would process: " + taskName.length() + " chars"); // not deterministic output order
            });
        }

        pool.shutdown();
        pool.awaitTermination(5, TimeUnit.SECONDS);
        System.out.println("Batch submitted and pool shut down.");
    }
}
```

`Executors.newFixedThreadPool(4)` creates a pool of exactly 4 worker threads that stay alive and get reused across all four submitted jobs. `pool.submit(Runnable)` hands a job to the pool without blocking the caller — it returns immediately and the job runs whenever a worker thread is free. `pool.shutdown()` tells the pool to stop accepting new jobs and to shut its threads down once the queued work finishes; `awaitTermination` blocks (with a timeout) until that happens. Note the comment on the print line: with four jobs interleaved across four threads, the *order* those lines print in isn't guaranteed — this specific example is here to show the submission pattern, not to demonstrate deterministic output (the next example fixes that).

## Callable and Future: getting a result back

`Runnable.run()` returns nothing and can't throw a checked exception. `Callable<V>` is `Runnable`'s more capable sibling — its single method `V call()` returns a value and is allowed to throw. Submitting a `Callable` to an `ExecutorService` gives you back a `Future<V>`, a handle representing a result that may not exist yet:

```java
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class Main {
    public static void main(String[] args) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(3);

        String[] taskNames = {
            "Design database schema", "Build REST API", "Write tests"
        };

        List<Future<Integer>> futures = new ArrayList<>();
        for (String taskName : taskNames) {
            Callable<Integer> processTask = () -> {
                // Simulate computing an estimate in hours based on task complexity.
                return taskName.length() / 3;
            };
            futures.add(pool.submit(processTask));
        }

        int totalEstimatedHours = 0;
        for (int i = 0; i < futures.size(); i++) {
            int hours = futures.get(i).get(); // blocks until that task's result is ready
            System.out.println(taskNames[i] + " -> estimated " + hours + "h");
            totalEstimatedHours += hours;
        }

        System.out.println("Total estimated hours: " + totalEstimatedHours);
        pool.shutdown();
    }
}
```

`Future.get()` blocks the calling thread until that specific job finishes, then returns its result (or rethrows its exception, wrapped in an `ExecutionException`, if the job failed). Because the loop that prints results calls `futures.get(i).get()` **in the original task order** — not whichever job happens to finish first — the printed output is deterministic and identical every run, even though the three `Callable`s might actually complete on the pool's threads in any order.

## Choosing a pool size and shutting down cleanly

`Executors` offers a few common factory presets:

| Factory method | Behavior |
|---|---|
| `newFixedThreadPool(n)` | Exactly `n` threads, reused for all submitted work — good default for CPU-bound or bounded work |
| `newCachedThreadPool()` | Creates threads as needed, reuses idle ones, can grow unbounded — risky under sustained heavy load |
| `newSingleThreadExecutor()` | Exactly one worker thread — jobs run one at a time, in submission order |

Always call `shutdown()` (or `shutdownNow()` to cancel in-flight work) when a pool is no longer needed — an `ExecutorService` that's never shut down keeps its threads alive indefinitely, which is a resource leak in a long-running application like a server.

```java
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        ExecutorService pool = Executors.newSingleThreadExecutor();
        try {
            pool.submit(() -> System.out.println("Single-threaded job ran."));
        } finally {
            pool.shutdown();
        }
    }
}
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-executorservice-callable-future-q1",
      "type": "mcq",
      "prompt": "Why use a thread pool instead of creating a new Thread for every task?",
      "options": [
        { "id": "a", "text": "Thread pools make individual tasks run faster" },
        { "id": "b", "text": "Thread pools reuse a bounded set of threads instead of paying thread-creation cost per task and risking unbounded resource usage" },
        { "id": "c", "text": "Raw Thread objects cannot call methods that return a value" },
        { "id": "d", "text": "There is no real difference; it's just a style preference" }
      ],
      "correct": "b",
      "explanation": "Thread creation and teardown is relatively expensive, and an unbounded number of live threads can exhaust memory or overwhelm the OS scheduler. A pool caps how many threads exist while still processing arbitrarily many tasks."
    },
    {
      "id": "concurrency-executorservice-callable-future-q2",
      "type": "mcq",
      "prompt": "What's the key difference between Runnable and Callable<V>?",
      "options": [
        { "id": "a", "text": "Callable can be submitted to an ExecutorService, Runnable cannot" },
        { "id": "b", "text": "Callable's call() method returns a value and can throw a checked exception; Runnable's run() returns void and cannot throw checked exceptions" },
        { "id": "c", "text": "Runnable always runs faster than Callable" },
        { "id": "d", "text": "Callable is only usable with newSingleThreadExecutor" }
      ],
      "correct": "b",
      "explanation": "Both are functional interfaces submittable to an ExecutorService, but Callable<V> exists specifically to produce a result (via Future<V>) and to propagate checked exceptions, which Runnable cannot do."
    },
    {
      "id": "concurrency-executorservice-callable-future-q3",
      "type": "mcq",
      "prompt": "What does future.get() do?",
      "options": [
        { "id": "a", "text": "Returns immediately with null if the task hasn't finished yet" },
        { "id": "b", "text": "Cancels the task and returns its partial result" },
        { "id": "c", "text": "Blocks the calling thread until that task completes, then returns its result (or throws if the task failed)" },
        { "id": "d", "text": "Starts the task, which does not begin running until get() is called" }
      ],
      "correct": "c",
      "explanation": "Future.get() is a blocking call — it waits for the specific task behind that Future to finish, then hands back its result. An overload with a timeout is also available if you don't want to block indefinitely."
    }
  ]
}
```

## What's next

`Future.get()` is a blocking way to wait for a result. The next lesson covers `CompletableFuture`, which lets you chain async work without blocking, plus a look at thread-safe collections like `ConcurrentHashMap`.
$md$, 20, $json$[{"id":"concurrency-executorservice-callable-future-q1","type":"mcq","correct":"b"},{"id":"concurrency-executorservice-callable-future-q2","type":"mcq","correct":"b"},{"id":"concurrency-executorservice-callable-future-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2582346e-a845-5855-8af6-ca7d1a13cd3d', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3c0af571-5278-514d-b5e2-0c8a2fc060b7', 'CompletableFuture and Concurrent Collections', 'notes', 3, $md$`Future.get()` works, but it's a blocking call — the thread that calls it just sits there waiting. `CompletableFuture` is a richer version of `Future` that lets you describe a *pipeline* of async work — "when this finishes, then do that" — without ever having to block a thread just to chain the next step.

## Chaining work with thenApply

```java
import java.util.concurrent.CompletableFuture;

public class Main {
    public static void main(String[] args) {
        String taskName = "Design database schema";

        CompletableFuture<Integer> estimateHours = CompletableFuture
            .supplyAsync(() -> taskName.length()) // runs async, returns a value
            .thenApply(charCount -> charCount / 3); // transforms the result once it's ready

        int hours = estimateHours.join(); // blocks only here, at the very end, to print
        System.out.println(taskName + " -> estimated " + hours + "h");
    }
}
```

`CompletableFuture.supplyAsync(Supplier<T>)` runs the given supplier on a background thread (by default, the common `ForkJoinPool`) and returns a `CompletableFuture<T>` representing its eventual result. `.thenApply(Function<T, R>)` registers a transformation to run *once that result is available* — it doesn't block the calling thread to do so, it just describes what should happen next. Only `.join()` (or `.get()`) actually blocks, and in this example that block only happens once, right before printing, to keep the final output deterministic.

## Composing multiple async steps with thenCompose

`.thenApply` is for transforming a value. `.thenCompose` is for chaining a step that *itself* returns another `CompletableFuture` — flattening what would otherwise be a `CompletableFuture<CompletableFuture<T>>` into a single `CompletableFuture<T>`:

```java
import java.util.concurrent.CompletableFuture;

public class Main {
    public static void main(String[] args) {
        CompletableFuture<Integer> pipeline = fetchTaskEstimate("Build REST API")
            .thenCompose(hours -> applyTeamMultiplier(hours, 3)); // chains a second async step

        System.out.println("Final person-hours: " + pipeline.join());
    }

    static CompletableFuture<Integer> fetchTaskEstimate(String taskName) {
        return CompletableFuture.supplyAsync(() -> taskName.length() / 3);
    }

    static CompletableFuture<Integer> applyTeamMultiplier(int hours, int teamSize) {
        return CompletableFuture.supplyAsync(() -> hours * teamSize);
    }
}
```

If `applyTeamMultiplier` had instead been called from inside `.thenApply`, the result would be a `CompletableFuture<CompletableFuture<Integer>>` — a future wrapping another future, which is awkward to use. `.thenCompose` unwraps that automatically, which is the same relationship `flatMap` has to `map` on a `Stream` or `Optional`.

## Combining independent futures

`.thenCombine` merges the results of two independent `CompletableFuture`s once both are done:

```java
import java.util.concurrent.CompletableFuture;

public class Main {
    public static void main(String[] args) {
        CompletableFuture<Integer> designEstimate =
            CompletableFuture.supplyAsync(() -> "Design database schema".length() / 3);
        CompletableFuture<Integer> apiEstimate =
            CompletableFuture.supplyAsync(() -> "Build REST API".length() / 3);

        CompletableFuture<Integer> combined = designEstimate.thenCombine(
            apiEstimate,
            (designHours, apiHours) -> designHours + apiHours
        );

        System.out.println("Combined estimate: " + combined.join() + "h");
    }
}
```

Both `designEstimate` and `apiEstimate` can run concurrently on separate background threads; `thenCombine` waits for both and then applies the given function to their two results — a natural fit for TaskFlow scenarios like "fetch two independent estimates, then sum them," without manually managing two `Thread` objects and joining both.

## ConcurrentHashMap vs. a synchronized HashMap

Regular `HashMap` is not thread-safe — concurrent reads and writes from multiple threads can corrupt its internal structure, not just race on a value. One historical fix is `Collections.synchronizedMap(new HashMap<>())`, which wraps every single method call in a lock on the whole map — safe, but it means only one thread can touch the map at all, at any time, even for two unrelated keys.

`ConcurrentHashMap` is built for concurrent access from the ground up: it allows multiple threads to read and write different parts of the map simultaneously, using much finer-grained internal locking instead of one lock for the entire map.

```java
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        Map<String, Integer> taskStatusCounts = new ConcurrentHashMap<>();
        taskStatusCounts.put("DONE", 0);
        taskStatusCounts.put("IN_PROGRESS", 0);
        taskStatusCounts.put("TODO", 0);

        ExecutorService pool = Executors.newFixedThreadPool(4);
        String[] statuses = { "DONE", "IN_PROGRESS", "TODO", "DONE", "DONE", "IN_PROGRESS" };

        for (String status : statuses) {
            pool.submit(() -> taskStatusCounts.merge(status, 1, Integer::sum));
        }

        pool.shutdown();
        pool.awaitTermination(5, TimeUnit.SECONDS);

        // Print in a fixed, known key order so output is deterministic regardless of
        // internal map iteration order (which ConcurrentHashMap does not guarantee).
        System.out.println("DONE: " + taskStatusCounts.get("DONE"));
        System.out.println("IN_PROGRESS: " + taskStatusCounts.get("IN_PROGRESS"));
        System.out.println("TODO: " + taskStatusCounts.get("TODO"));
    }
}
```

`merge(key, 1, Integer::sum)` is itself an atomic operation on `ConcurrentHashMap` — it reads the current value (or uses `1` if absent) and combines it with the new value in one indivisible step, avoiding the exact same read-modify-write race from the previous lesson, but scoped per-key instead of needing a single lock around the whole map. Note the example prints each status by name explicitly, rather than iterating the map — `HashMap` and `ConcurrentHashMap` never guarantee iteration order, so printing via iteration would make the output's line order unpredictable even though the counts themselves are correct.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-completablefuture-concurrent-collections-q1",
      "type": "mcq",
      "prompt": "What is thenCompose for, that thenApply can't do as cleanly?",
      "options": [
        { "id": "a", "text": "thenCompose runs code synchronously instead of on a background thread" },
        { "id": "b", "text": "thenCompose chains a step that itself returns a CompletableFuture, flattening the result instead of nesting one future inside another" },
        { "id": "c", "text": "thenCompose is just a faster alias for thenApply" },
        { "id": "d", "text": "thenCompose can only be used with Callable, not Supplier" }
      ],
      "correct": "b",
      "explanation": "If the next step already returns a CompletableFuture<T>, chaining it with thenApply would produce a nested CompletableFuture<CompletableFuture<T>>. thenCompose flattens that into a single CompletableFuture<T>, the same relationship flatMap has to map."
    },
    {
      "id": "concurrency-completablefuture-concurrent-collections-q2",
      "type": "mcq",
      "prompt": "Why is ConcurrentHashMap generally preferred over Collections.synchronizedMap(new HashMap<>()) under heavy concurrent access?",
      "options": [
        { "id": "a", "text": "synchronizedMap is not actually thread-safe" },
        { "id": "b", "text": "ConcurrentHashMap uses finer-grained internal locking, letting multiple threads operate on different parts of the map at once, instead of one lock guarding the entire map for every operation" },
        { "id": "c", "text": "ConcurrentHashMap guarantees a specific iteration order, synchronizedMap does not" },
        { "id": "d", "text": "There is no meaningful difference between the two" }
      ],
      "correct": "b",
      "explanation": "synchronizedMap wraps every call in one lock on the whole map, serializing all access. ConcurrentHashMap is designed for concurrency internally, allowing much higher throughput when multiple threads touch different keys at once."
    },
    {
      "id": "concurrency-completablefuture-concurrent-collections-q3",
      "type": "mcq",
      "prompt": "In the ConcurrentHashMap example, why does the code print each status count by an explicit key lookup instead of iterating over the map?",
      "options": [
        { "id": "a", "text": "ConcurrentHashMap cannot be iterated at all" },
        { "id": "b", "text": "Map iteration order is not guaranteed, so iterating could print the counts in an unpredictable line order across runs even though the values themselves are correct" },
        { "id": "c", "text": "get() is faster than any form of iteration" },
        { "id": "d", "text": "merge() removes entries after they are read once" }
      ],
      "correct": "b",
      "explanation": "Neither HashMap nor ConcurrentHashMap guarantees a stable iteration order. Looking up each known key explicitly, in a fixed sequence, keeps the printed output deterministic regardless of the map's internal ordering."
    }
  ]
}
```

## What's next

This module's quiz mixes multiple-choice theory with a hands-on coding question that uses an `ExecutorService` internally, then reflects on which concurrency concept felt least intuitive.
$md$, 20, $json$[{"id":"concurrency-completablefuture-concurrent-collections-q1","type":"mcq","correct":"b"},{"id":"concurrency-completablefuture-concurrent-collections-q2","type":"mcq","correct":"b"},{"id":"concurrency-completablefuture-concurrent-collections-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a4a4c9c3-2802-5757-8be9-5cc47d3163b2', '00000000-0000-0000-0000-000000000001', 'mcq', 'A single-core machine runs a program with three worker threads. Can that prog...', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5d772e08-32e0-5e9d-940f-587fa462b528', 'a4a4c9c3-2802-5757-8be9-5cc47d3163b2', 1, $json${"prompt":"A single-core machine runs a program with three worker threads. Can that program be concurrent? Can it be parallel?","multiple":false,"options":[{"id":"a","text":"Concurrent, yes — the OS can time-slice between the three threads. Parallel, no — only one instruction from any thread can execute at the exact same physical instant on one core.","is_correct":true},{"id":"b","text":"Neither concurrent nor parallel is possible on a single core","is_correct":false},{"id":"c","text":"Both concurrent and parallel, since Thread objects guarantee true simultaneous execution","is_correct":false},{"id":"d","text":"Parallel, yes — but not concurrent","is_correct":false}],"explanation":"Concurrency is a structural property (independent tasks that can interleave); parallelism requires multiple cores actually executing at the same instant. A single core can be concurrent via time-slicing but can never be truly parallel."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('349f283d-1fe1-5632-acb1-973a491d6478', '00000000-0000-0000-0000-000000000001', 'mcq', 'Two threads both execute balance++ on a shared int field with no synchronizat...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4abb2dc4-f3db-5541-8023-b06e10ab71bb', '349f283d-1fe1-5632-acb1-973a491d6478', 1, $json${"prompt":"Two threads both execute balance++ on a shared int field with no synchronization. What is the root cause of the race condition?","multiple":false,"options":[{"id":"a","text":"int is not a valid type for shared fields","is_correct":false},{"id":"b","text":"balance++ is really a read, a modify, and a write, and the JVM offers no guarantee those three steps from one thread won't interleave with another thread's three steps on the same field","is_correct":true},{"id":"c","text":"Java caches variable values per-thread with no way to synchronize them","is_correct":false},{"id":"d","text":"The ++ operator only works correctly on final fields","is_correct":false},{"id":"e","text":"It's not actually a race condition, that's a myth about Java","is_correct":false}],"explanation":"The three-step read-modify-write nature of ++ is the whole story: without a lock, two threads can interleave those steps and one thread's update is silently lost."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00d71267-fa3c-5ae4-b2c7-72b054f4ae9e', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does synchronized guarantee about two methods on the same object, both m...', 'intermediate', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('590beead-b031-562b-b5d7-eb52ba876658', '00d71267-fa3c-5ae4-b2c7-72b054f4ae9e', 1, $json${"prompt":"What does synchronized guarantee about two methods on the same object, both marked synchronized?","multiple":false,"options":[{"id":"a","text":"They run in parallel on separate cores for speed","is_correct":false},{"id":"b","text":"Only one of them can be executing on that object at a time — the second caller blocks until the first exits","is_correct":true},{"id":"c","text":"They are automatically retried if they throw an exception","is_correct":false},{"id":"d","text":"Nothing — synchronized only affects static methods","is_correct":false}],"explanation":"synchronized methods on the same object share that object's intrinsic lock. Only one thread can hold the lock at a time, so calls to any synchronized method on that object are mutually exclusive."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c86e4fda-2fc3-5fcb-bf4b-baf102c5c79b', '00000000-0000-0000-0000-000000000001', 'mcq', 'TaskFlow needs to process 50,000 queued tasks. Why is submitting them to a fi...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cdb151cf-88d5-5e3f-8d0f-674a21e75448', 'c86e4fda-2fc3-5fcb-bf4b-baf102c5c79b', 1, $json${"prompt":"TaskFlow needs to process 50,000 queued tasks. Why is submitting them to a fixed-size ExecutorService a better default than creating 50,000 raw Thread objects?","multiple":false,"options":[{"id":"a","text":"Raw threads cannot return a result at all, under any circumstances","is_correct":false},{"id":"b","text":"A bounded pool reuses a small number of threads and queues excess work, avoiding the memory and scheduling overhead of 50,000 live OS threads at once","is_correct":true},{"id":"c","text":"ExecutorService tasks run without any actual threads being created","is_correct":false},{"id":"d","text":"There's no practical difference; both approaches scale identically","is_correct":false},{"id":"e","text":"Raw Thread objects are deprecated in modern Java","is_correct":false}],"explanation":"Each OS thread costs memory (a stack) and scheduling overhead. A bounded pool processes a large backlog with a small, fixed number of live threads, queuing the rest — this is precisely the reuse-and-bounded-resource-usage argument for thread pools."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f1b508d7-8219-568c-8d37-140ced7317dc', '00000000-0000-0000-0000-000000000001', 'mcq', 'What''s the key advantage of chaining work with CompletableFuture''s thenApply/...', 'advanced', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d6b8bdec-9d14-572e-8b88-0482898df8a7', 'f1b508d7-8219-568c-8d37-140ced7317dc', 1, $json${"prompt":"What's the key advantage of chaining work with CompletableFuture's thenApply/thenCompose over calling Future.get() and then doing the next step manually?","multiple":false,"options":[{"id":"a","text":"thenApply and thenCompose describe the next step to run once a result is ready without blocking the calling thread to wait for it, unlike get() which blocks immediately","is_correct":true},{"id":"b","text":"CompletableFuture cannot throw exceptions, making it strictly safer","is_correct":false},{"id":"c","text":"thenApply runs on the same thread as the original computation, guaranteeing ordering","is_correct":false},{"id":"d","text":"There's no real difference — CompletableFuture is just a renamed Future","is_correct":false}],"explanation":"Future.get() blocks the calling thread right away. CompletableFuture lets you describe a pipeline of dependent steps that run as results become available, only blocking (if ever) at the very end when you need the final value."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('90573eb6-5ddc-5d0a-9fe6-0ea4cd9952aa', '00000000-0000-0000-0000-000000000001', 'coding', 'TaskFlow needs to compute the sum of squares of a list of numeric task weight...', 'intermediate', 4, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a6e07c45-959f-5041-b22a-f4639b40ef64', '90573eb6-5ddc-5d0a-9fe6-0ea4cd9952aa', 1, $json${"prompt":"TaskFlow needs to compute the sum of squares of a list of numeric task weights using a thread pool. Read an integer N, then read N integers (whitespace/newline separated). Submit each number as a separate Callable\u003cInteger\u003e task to an ExecutorService that computes its square. Collect every Future, sum all the squared results (joining all tasks before summing so the result is deterministic), and print a single integer: the total sum. Print nothing else.","languages":["java"],"starter_code":{"java":"import java.util.ArrayList;\nimport java.util.List;\nimport java.util.Scanner;\nimport java.util.concurrent.Callable;\nimport java.util.concurrent.ExecutorService;\nimport java.util.concurrent.Executors;\nimport java.util.concurrent.Future;\n\npublic class Main {\n    public static void main(String[] args) throws Exception {\n        Scanner scanner = new Scanner(System.in);\n        int n = scanner.nextInt();\n\n        ExecutorService pool = Executors.newFixedThreadPool(4);\n        List\u003cFuture\u003cInteger\u003e\u003e futures = new ArrayList\u003c\u003e();\n\n        // TODO: for each of the n integers read from input, submit a Callable\u003cInteger\u003e\n        // to the pool that computes its square, collecting each Future in `futures`.\n\n        // TODO: sum every future's result (future.get() blocks until that task is done)\n        // and print the total sum, with no extra text.\n\n        pool.shutdown();\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"3\n1 2 3","expected":"14","hidden":false,"weight":1},{"id":"t2","stdin":"4\n2 2 2 2","expected":"16","hidden":true,"weight":1},{"id":"t3","stdin":"1\n5","expected":"25","hidden":true,"weight":1},{"id":"t4","stdin":"5\n1 2 3 4 5","expected":"55","hidden":true,"weight":1},{"id":"t5","stdin":"2\n0 0","expected":"0","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('552430d7-4d1c-567c-a296-83f10fc59fb7', '00000000-0000-0000-0000-000000000001', 'subjective', 'In your own words: which concept from this module (raw Threads and Runnable, ...', 'beginner', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9f81bdbe-9d56-5c06-b2f2-bec35b22a36e', '552430d7-4d1c-567c-a296-83f10fc59fb7', 1, $json${"prompt":"In your own words: which concept from this module (raw Threads and Runnable, race conditions and synchronized, ExecutorService/Callable/Future, or CompletableFuture and concurrent collections) felt least intuitive, and why? Be specific — this feeds directly into what gets flagged for review.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which concurrency concept you're actually shakiest on."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('77e4cb74-4288-50db-87a8-21a334ad3c45', '00000000-0000-0000-0000-000000000001', 'Module Assessment: Concurrency', 'java-mastery-concurrency-quiz', 'Quiz covering Concurrency.', 'mixed', 'published', 'module', '251087ea-6107-56ba-b92b-4029033f24dc', 30, 70, 5, 14, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('6d70e163-bc75-5054-b0b5-9a85eb97f742', '77e4cb74-4288-50db-87a8-21a334ad3c45', 'a4a4c9c3-2802-5757-8be9-5cc47d3163b2', '5d772e08-32e0-5e9d-940f-587fa462b528', 0, 1),
('89cf5f34-6452-582e-a623-4cdb293401c2', '77e4cb74-4288-50db-87a8-21a334ad3c45', '349f283d-1fe1-5632-acb1-973a491d6478', '4abb2dc4-f3db-5541-8023-b06e10ab71bb', 1, 2),
('fc4621d3-6078-5228-a5dd-dd06bbae6266', '77e4cb74-4288-50db-87a8-21a334ad3c45', '00d71267-fa3c-5ae4-b2c7-72b054f4ae9e', '590beead-b031-562b-b5d7-eb52ba876658', 2, 1),
('7ab6cd1d-d5d9-5920-a288-0d7a9791c730', '77e4cb74-4288-50db-87a8-21a334ad3c45', 'c86e4fda-2fc3-5fcb-bf4b-baf102c5c79b', 'cdb151cf-88d5-5e3f-8d0f-674a21e75448', 3, 2),
('06546bfb-29f3-5a57-9732-b32b6fabba25', '77e4cb74-4288-50db-87a8-21a334ad3c45', 'f1b508d7-8219-568c-8d37-140ced7317dc', 'd6b8bdec-9d14-572e-8b88-0482898df8a7', 4, 2),
('ee8efd95-0f04-5d1d-9039-bb923679ae6c', '77e4cb74-4288-50db-87a8-21a334ad3c45', '90573eb6-5ddc-5d0a-9fe6-0ea4cd9952aa', 'a6e07c45-959f-5041-b22a-f4639b40ef64', 5, 4),
('59ed8814-6e64-56bc-8c36-daf28fe6ee7e', '77e4cb74-4288-50db-87a8-21a334ad3c45', '552430d7-4d1c-567c-a296-83f10fc59fb7', '9f81bdbe-9d56-5c06-b2f2-bec35b22a36e', 6, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('251087ea-6107-56ba-b92b-4029033f24dc', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3c0af571-5278-514d-b5e2-0c8a2fc060b7', 'Module Assessment: Concurrency', 'assessment', 4, 30, '77e4cb74-4288-50db-87a8-21a334ad3c45')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: JVM & Memory Internals
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('d0c7a70b-3a84-5e6a-8575-aff49f4781ad', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'JVM & Memory Internals', 12)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('7c9f4112-6572-53be-bd83-7b08e667b140', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'd0c7a70b-3a84-5e6a-8575-aff49f4781ad', 'JVM Architecture and Class Loading', 'notes', 0, $md$You've been running `.java` files all course without thinking much about what happens between "hit Run" and "output appears." Every TaskFlow program you write goes through the same pipeline: source code becomes bytecode, bytecode gets loaded into the JVM, and only then does anything actually execute. Understanding that pipeline is genuinely useful — it explains real errors you'll hit (`NoClassDefFoundError`, `OutOfMemoryError`) and is a near-guaranteed interview topic.

## From source to bytecode to execution

```
Main.java  --javac-->  Main.class (bytecode)  --JVM loads-->  runs on the JVM
```

`javac` compiles human-readable `.java` source into `.class` files containing **bytecode** — a compact, platform-independent instruction set that isn't tied to any specific CPU. That's the "write once, run anywhere" trick from the very first lesson of this course: the same `.class` file runs unmodified on any machine that has a compatible JVM, because the JVM (not your CPU) is what actually understands bytecode.

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("This line only runs after Main.class has been loaded into the JVM.");
    }
}
```

Compiling this produces `Main.class`. Running it with `java Main` doesn't just "start executing" — the JVM has to first find, load, and prepare that class before a single instruction of `main` runs.

## What class loading actually does

"Class loading" is really three distinct phases, run in order, for each class the JVM needs:

1. **Loading** — the JVM's classloader locates the `.class` file (on disk, in a JAR, wherever the classpath points) and reads its bytecode into memory, creating a `Class` object that represents that type at runtime.
2. **Linking** — this itself breaks into three sub-steps: **verification** (the JVM checks the bytecode is structurally valid and doesn't violate Java's safety rules — you can't fake your way past this by hand-editing a `.class` file), **preparation** (static fields are allocated and set to their default values — `0`, `null`, `false` — not their actual initializers yet), and **resolution** (symbolic references to other classes are resolved).
3. **Initialization** — static initializer blocks and static field initializers actually run, top to bottom, in the order they appear in the source. This is the point where a `static int MAX = 50;` field actually becomes `50` instead of its preparation-phase default of `0`.

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("Before touching TaskConfig: " + "nothing loaded yet for that class");
        System.out.println("MAX_TASKS_PER_USER = " + TaskConfig.MAX_TASKS_PER_USER);
    }
}

class TaskConfig {
    static final int MAX_TASKS_PER_USER;

    static {
        System.out.println("TaskConfig static initializer running now — initialization phase.");
        MAX_TASKS_PER_USER = 50;
    }
}
```

`TaskConfig` isn't loaded, linked, or initialized until the first line of code that actually references it runs (`TaskConfig.MAX_TASKS_PER_USER`) — this is called **lazy initialization**, and it's why the "static initializer running" line prints *after* the first `println`, not before. Java classes are loaded on demand, not all up front when the program starts.

## Classloaders: who loads what

The JVM doesn't use just one classloader — it delegates through a hierarchy, and each layer is responsible for a different source of classes:

| Classloader | Loads |
|---|---|
| **Bootstrap** | Core JDK classes (`java.lang.*`, `java.util.*`) — written in native code, the root of the hierarchy |
| **Platform / Extension** | Java platform modules beyond the absolute core |
| **Application (System)** | Your own compiled classes and any third-party JARs on the classpath |

Each classloader (except Bootstrap) first delegates to its parent before trying to load a class itself — this **parent-delegation model** is why you can't accidentally shadow `java.lang.String` with your own class named `String`: the request for `String` gets delegated all the way up to Bootstrap before your application classloader ever gets a chance, and Bootstrap finds and returns the real one first.

## Runtime data areas — a preview

Once a class is loaded and initialized, running its code needs memory, organized into a few distinct regions the JVM manages: the **heap** (where objects live, shared across all threads), the **stack** (one per thread, holding local variables and method call frames), and the **method area / metaspace** (holding loaded class metadata itself — the structure of `TaskConfig`, not any particular `TaskConfig` instance). The next lesson digs into the stack/heap split in detail, since that distinction is what actually determines an object's lifetime and how far a reference to it can travel.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jvm-memory-jvm-architecture-and-class-loading-q1",
      "type": "mcq",
      "prompt": "What are the three phases of class loading, in order?",
      "options": [
        { "id": "a", "text": "Compilation, execution, garbage collection" },
        { "id": "b", "text": "Loading, linking (verification, preparation, resolution), initialization" },
        { "id": "c", "text": "Initialization, loading, verification" },
        { "id": "d", "text": "Bytecode generation, JIT compilation, interpretation" }
      ],
      "correct": "b",
      "explanation": "Loading reads the bytecode and creates a Class object; linking verifies it, allocates static fields at their default values, and resolves references; initialization then runs static initializers and assigns real values to static fields."
    },
    {
      "id": "jvm-memory-jvm-architecture-and-class-loading-q2",
      "type": "mcq",
      "prompt": "Why does a class's static initializer not run until the class is first actively referenced, rather than at program startup?",
      "options": [
        { "id": "a", "text": "Because Java classes have no concept of static initializers" },
        { "id": "b", "text": "Java uses lazy class loading — a class is loaded, linked, and initialized on first active use, not all at once when the JVM starts" },
        { "id": "c", "text": "Because static blocks are optional and the JVM skips them unless explicitly told to run them" },
        { "id": "d", "text": "It's an implementation bug that Java has never fixed" }
      ],
      "correct": "b",
      "explanation": "The JVM loads classes on demand — the first time code actually touches a class (constructing it, accessing a static field, calling a static method) triggers loading, linking, and initialization for that class if it hasn't happened already."
    },
    {
      "id": "jvm-memory-jvm-architecture-and-class-loading-q3",
      "type": "mcq",
      "prompt": "What does the parent-delegation model of classloaders prevent?",
      "options": [
        { "id": "a", "text": "It prevents the JVM from ever loading more than one class at a time" },
        { "id": "b", "text": "It prevents your own class from accidentally shadowing a core JDK class of the same name, since the request is delegated up to Bootstrap first" },
        { "id": "c", "text": "It prevents static initializers from ever running more than once" },
        { "id": "d", "text": "It prevents bytecode verification from happening" }
      ],
      "correct": "b",
      "explanation": "Each classloader asks its parent to try loading a class before attempting itself. Since Bootstrap sits at the top and owns java.lang.*, it always resolves a request for java.lang.String before your own application classloader is even consulted."
    }
  ]
}
```

## What's next

The next lesson zooms into the two most important runtime data areas: the **stack** and the **heap** — where your local variables live versus where your `Task` and `User` objects actually live.
$md$, 20, $json$[{"id":"jvm-memory-jvm-architecture-and-class-loading-q1","type":"mcq","correct":"b"},{"id":"jvm-memory-jvm-architecture-and-class-loading-q2","type":"mcq","correct":"b"},{"id":"jvm-memory-jvm-architecture-and-class-loading-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('dc976001-cf60-5e38-bbd2-b541d0656779', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'd0c7a70b-3a84-5e6a-8575-aff49f4781ad', 'Stack vs. Heap', 'notes', 1, $md$Every time TaskFlow code calls a method or creates an object, that data has to live somewhere in memory. Java splits that "somewhere" into two very differently-behaved regions: the **stack** and the **heap**. Knowing which one a piece of data lives in explains a lot of Java's behavior that otherwise looks mysterious — why passing an object to a method lets you mutate it, why a `NullPointerException` doesn't mean the variable itself vanished, and why deeply recursive methods eventually blow up with `StackOverflowError`.

## The stack: local variables and method calls, per thread

Each thread gets its **own stack**, and every method call pushes a new **stack frame** onto it — a frame holding that method's local variables, its parameters, and where to return to when it finishes. When the method returns, its frame is popped and everything in it is gone. This is fast and simple precisely because it's so short-lived and strictly ordered (last-in, first-out).

```java
public class Main {
    public static void main(String[] args) {
        int estimateHours = 6; // lives in main's stack frame
        printDoubled(estimateHours);
        System.out.println("Back in main, estimateHours is still: " + estimateHours);
    }

    static void printDoubled(int hours) {
        int doubled = hours * 2; // lives in printDoubled's own stack frame
        System.out.println("Doubled: " + doubled);
    }
}
```

`estimateHours` and `hours` are separate variables in separate stack frames — even though `hours` starts out with a copy of `estimateHours`'s value, changing `hours` inside `printDoubled` has zero effect on `estimateHours` back in `main`. This is what it means to say primitives are **passed by value**: the method gets a copy of the value, not a way to reach back and modify the caller's variable.

## The heap: where objects actually live

`new` always allocates an object **on the heap** — a single shared region of memory that every thread in the JVM can see (unlike the stack, which is per-thread and private). What lives on the *stack* for an object isn't the object itself, it's a **reference** — essentially an address pointing at the real data sitting on the heap.

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Design database schema", 6); // task (the reference) is on the stack;
                                                             // the Task object itself is on the heap
        System.out.println("Before: " + task.getEstimateHours() + "h");

        markUrgent(task);
        System.out.println("After: " + task.getEstimateHours() + "h"); // reflects the mutation!
    }

    static void markUrgent(Task t) {
        t.setEstimateHours(t.getEstimateHours() + 2); // extra buffer time for urgent tasks
    }
}

class Task {
    private String name;
    private int estimateHours;

    Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    int getEstimateHours() { return estimateHours; }
    void setEstimateHours(int hours) { this.estimateHours = hours; }
}
```

This is the flip side of the previous example: `markUrgent`'s parameter `t` is a *copy of the reference*, but both `task` (in `main`) and `t` (in `markUrgent`) point at the exact same `Task` object on the heap. Mutating that object through `t` is visible through `task` too, because there's only ever one `Task` object — just two references pointing at it. This is why people sometimes loosely say Java is "pass by reference" for objects, though the more precise statement is that Java is **always pass by value — it's just that for objects, the value being passed is a reference**, not the object itself.

## Lifetimes: why this distinction matters

A stack frame's lifetime is tied exactly to its method call — created on call, destroyed on return, no exceptions. A heap object's lifetime is tied to **reachability**: it stays alive for as long as anything, anywhere, still holds a reference to it, no matter which method created it or whether that method has already returned. That's precisely how a `Task` object can be created inside one method, stored in a list, and still be alive and usable long after the method that created it has returned — the object itself never lived on that method's stack frame in the first place, only a reference to it did.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = buildInitialTasks();
        // buildInitialTasks() has already returned — its stack frame is gone —
        // but every Task object it created is still alive on the heap, reachable via `tasks`.
        for (Task t : tasks) {
            System.out.println(t.getEstimateHours() + "h");
        }
    }

    static List<Task> buildInitialTasks() {
        List<Task> local = new ArrayList<>(); // local (the reference) dies when this method returns
        local.add(new Task("Design database schema", 6)); // the Task objects do NOT die with it
        local.add(new Task("Build REST API", 10));
        return local;
    }
}
```

The next lesson covers exactly how the JVM decides an object is no longer reachable and reclaims its heap memory — that's garbage collection.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jvm-memory-stack-vs-heap-q1",
      "type": "mcq",
      "prompt": "Where does a local int variable live, and where does an object created with new live?",
      "options": [
        { "id": "a", "text": "Both live on the heap" },
        { "id": "b", "text": "The int lives on the calling thread's stack, in its method's frame; the object lives on the shared heap, with only a reference to it stored on the stack" },
        { "id": "c", "text": "Both live on the stack" },
        { "id": "d", "text": "The int lives on the heap; the object lives on the stack" }
      ],
      "correct": "b",
      "explanation": "Primitive locals are stored directly in their method's stack frame. Objects always live on the heap; what a stack frame or field holds for an object is a reference (an address), not the object's data itself."
    },
    {
      "id": "jvm-memory-stack-vs-heap-q2",
      "type": "mcq",
      "prompt": "A method receives a Task object as a parameter and calls t.setEstimateHours(...) on it. Why is that mutation visible to the caller after the method returns, even though Java is pass-by-value?",
      "options": [
        { "id": "a", "text": "Java is actually pass-by-reference for objects, contradicting pass-by-value entirely" },
        { "id": "b", "text": "The method receives a copy of the reference, but that copy still points at the same single Task object on the heap — mutating the object through either reference is visible through both" },
        { "id": "c", "text": "It isn't visible; the caller's object is unaffected" },
        { "id": "d", "text": "setEstimateHours implicitly creates a new object and reassigns the caller's variable" }
      ],
      "correct": "b",
      "explanation": "Java always passes by value. For an object, the value being copied is the reference itself — so caller and callee end up with two references pointing at the one shared heap object, and mutating through either is visible through both."
    },
    {
      "id": "jvm-memory-stack-vs-heap-q3",
      "type": "mcq",
      "prompt": "A method creates a list, adds several objects to it, and returns the list. Why are those objects still usable after the method returns, even though the method's stack frame is gone?",
      "options": [
        { "id": "a", "text": "The objects are copied into the caller's stack frame automatically" },
        { "id": "b", "text": "The objects themselves were never stored on that method's stack frame — they live on the heap, and remain reachable through the returned list reference regardless of which stack frame created them" },
        { "id": "c", "text": "It's undefined behavior that happens to work in practice" },
        { "id": "d", "text": "The method's stack frame is not actually destroyed until the program exits" }
      ],
      "correct": "b",
      "explanation": "Only the local reference variable inside the method lived on its stack frame — that frame is gone after return. The objects it pointed to live on the heap and stay alive as long as something reachable (here, the returned list) still references them."
    }
  ]
}
```

## What's next

The next lesson explains **garbage collection**: how the JVM figures out an object is unreachable and reclaims its heap memory, so you never have to manually free anything like you would in C or C++.
$md$, 20, $json$[{"id":"jvm-memory-stack-vs-heap-q1","type":"mcq","correct":"b"},{"id":"jvm-memory-stack-vs-heap-q2","type":"mcq","correct":"b"},{"id":"jvm-memory-stack-vs-heap-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3d834d8c-3d05-59a3-87da-96bcf33442f4', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'd0c7a70b-3a84-5e6a-8575-aff49f4781ad', 'Garbage Collection Basics', 'notes', 2, $md$In C or C++, you're responsible for manually freeing every object you allocate — forget to, and the program leaks memory forever; free it too early or twice, and you get corruption or a crash. Java sidesteps that entire category of bug with **garbage collection (GC)**: a background process built into the JVM that automatically finds objects nothing can reach anymore and reclaims their heap memory, without you ever calling `free()`.

## What "unreachable" means

An object is **reachable** if there's a chain of references leading to it starting from a **GC root** — things like local variables currently on some thread's stack, static fields, or objects a live thread is actively holding onto. An object becomes **unreachable** the moment no such chain exists anymore — nothing, anywhere in the running program, can get to it.

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Design database schema", 6);
        System.out.println("Task exists: " + task.getName());

        task = null; // the Task object is now unreachable — nothing references it anymore
        // It is eligible for garbage collection starting now. Exactly *when* the JVM
        // reclaims it is not something your code controls or can rely on.

        System.out.println("Reference cleared; the object may be collected at any point from here on.");
    }
}

class Task {
    private String name;
    private int estimateHours;

    Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    String getName() { return name; }
    int getEstimateHours() { return estimateHours; }
}
```

Setting `task = null` doesn't destroy the `Task` object immediately — it just removes the one reference this code held. The object becomes *eligible* for collection, and the JVM's garbage collector decides, on its own schedule, when to actually reclaim that memory. This is exactly why Java has no `free()` or `delete` keyword: you never manually decide when an object dies, you only ever control whether anything still references it.

## Generational garbage collection, conceptually

Most production JVM garbage collectors are **generational**, based on an empirically observed pattern called the *weak generational hypothesis*: most objects die young. Short-lived objects (a loop's temporary variable, a request-scoped object) vastly outnumber long-lived ones (a cache, a singleton config object), so the heap is split into generations that get collected with different strategies and different frequencies:

| Generation | Holds | Collected |
|---|---|---|
| **Young generation** | Newly allocated objects | Frequently, and cheaply — most objects here die almost immediately and are reclaimed fast |
| **Old generation** (tenured) | Objects that have survived several young-generation collections | Less often, but each collection is more expensive since it scans a larger, longer-lived set of objects |

An object starts in the young generation. If it survives enough collection cycles there (because something is still holding a reference to it), it gets **promoted** ("tenured") into the old generation. This split lets the collector spend most of its effort on the young generation, where it reclaims the most memory for the least work, and touch the old generation much more rarely.

```java
public class Main {
    public static void main(String[] args) {
        // Most of these Task objects die almost immediately — classic young-generation churn.
        int totalNameLength = 0;
        for (int i = 0; i < 5; i++) {
            Task shortLived = new Task("Task #" + i, i + 1);
            totalNameLength += shortLived.getName().length();
            // shortLived goes out of scope at the end of each loop iteration —
            // unreachable almost as soon as it was created.
        }
        System.out.println("Total name length across short-lived tasks: " + totalNameLength);
    }
}

class Task {
    private String name;
    private int estimateHours;

    Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    String getName() { return name; }
}
```

Each loop iteration's `shortLived` object becomes unreachable the instant the next iteration reassigns the variable (or the loop ends) — exactly the churn pattern generational GC is optimized for.

## Why GC exists at all

Manual memory management (C/C++'s `malloc`/`free`) trades control for risk: use-after-free bugs, double-frees, and memory leaks from a forgotten `free()` call are a huge, historically expensive source of security vulnerabilities and crashes. Garbage collection removes that entire failure mode by making memory safety an automatic, JVM-enforced guarantee — you can never accidentally free memory something is still using, and you can never (in the classic C sense) forget to free it, because the JVM tracks reachability for you. The tradeoff is that GC costs some CPU time and can introduce brief pauses while it runs — a cost most applications happily accept in exchange for never debugging a use-after-free crash.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jvm-memory-garbage-collection-basics-q1",
      "type": "mcq",
      "prompt": "What makes an object eligible for garbage collection?",
      "options": [
        { "id": "a", "text": "The programmer calls a free() or delete method on it" },
        { "id": "b", "text": "It becomes unreachable — no chain of references from any GC root (stack variables, static fields, etc.) leads to it anymore" },
        { "id": "c", "text": "It has existed for more than one second" },
        { "id": "d", "text": "Its constructor finishes running" }
      ],
      "correct": "b",
      "explanation": "Java tracks reachability, not a manual free call. An object becomes eligible for collection the moment nothing in the running program can reach it through any chain of references starting from a GC root."
    },
    {
      "id": "jvm-memory-garbage-collection-basics-q2",
      "type": "mcq",
      "prompt": "What is the core idea behind generational garbage collection?",
      "options": [
        { "id": "a", "text": "All objects are collected together in a single pass, regardless of age" },
        { "id": "b", "text": "Most objects die young, so the heap is split into a frequently-collected young generation and a less-often-collected old generation for long-lived, promoted objects" },
        { "id": "c", "text": "Objects are grouped by which class created them" },
        { "id": "d", "text": "The old generation is collected more often than the young generation" }
      ],
      "correct": "b",
      "explanation": "Generational GC is based on the observation that most objects are short-lived. Collecting the young generation frequently reclaims the most memory for the least effort; objects that survive multiple young-gen collections get promoted to the old generation, which is collected far less often."
    },
    {
      "id": "jvm-memory-garbage-collection-basics-q3",
      "type": "mcq",
      "prompt": "Why does Java not have a free() or delete keyword like C or C++?",
      "options": [
        { "id": "a", "text": "Because Java programs never allocate heap memory" },
        { "id": "b", "text": "Because the garbage collector automatically reclaims unreachable objects, removing manual memory management and the use-after-free/double-free bug classes that come with it" },
        { "id": "c", "text": "Because Java objects are always allocated on the stack, not the heap" },
        { "id": "d", "text": "Because free() exists but is deprecated and unused" }
      ],
      "correct": "b",
      "explanation": "Garbage collection makes reachability-based memory reclamation automatic and JVM-enforced, eliminating the entire class of bugs that come from manually deciding when to free memory."
    }
  ]
}
```

## What's next

Garbage collection handles unreachable objects automatically — but code can still accidentally keep objects reachable forever, which leaks memory despite having a GC. The next lesson covers those patterns, plus the string constant pool.
$md$, 20, $json$[{"id":"jvm-memory-garbage-collection-basics-q1","type":"mcq","correct":"b"},{"id":"jvm-memory-garbage-collection-basics-q2","type":"mcq","correct":"b"},{"id":"jvm-memory-garbage-collection-basics-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('71518a94-74e0-5e4e-8954-66f1942b3617', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'd0c7a70b-3a84-5e6a-8575-aff49f4781ad', 'Common Memory Leaks in Java, and the String Pool', 'notes', 3, $md$Java has a garbage collector, so it seems like "memory leak" shouldn't be a thing that happens — and yet Java programs leak memory constantly in production. The GC only reclaims **unreachable** objects; it has no idea whether you actually still need something you're still holding a reference to. A "Java memory leak" almost always means: code is unintentionally keeping a reference alive long after the object should have been forgotten.

## Leak pattern #1: a static collection that only grows

`static` fields are GC roots — they're reachable for the entire lifetime of the JVM. A static collection that objects get added to but never removed from is one of the most common real-world Java leaks:

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        for (int i = 0; i < 5; i++) {
            TaskCache.recordProcessed(new Task("Task #" + i, i + 1));
        }
        System.out.println("Tasks recorded in cache: " + TaskCache.size());
        // In a real long-running server, this loop runs forever as tasks are processed,
        // and TaskCache.processedTasks grows without bound — a classic unbounded-cache leak.
    }
}

class TaskCache {
    private static final List<Task> processedTasks = new ArrayList<>();

    static void recordProcessed(Task task) {
        processedTasks.add(task); // added forever, never removed — this is the leak
    }

    static int size() {
        return processedTasks.size();
    }
}

class Task {
    private String name;
    private int estimateHours;

    Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }
}
```

Every `Task` ever passed to `recordProcessed` stays reachable through `TaskCache.processedTasks` forever, because it's a `static` field — reachable for the JVM's entire lifetime — and nothing ever removes old entries. In a real server processing thousands of tasks a day, this list grows without bound until the JVM runs out of heap and throws `OutOfMemoryError`. The fix is usually a bounded cache with an eviction policy (size limit, time-to-live) instead of an unbounded `List` — the GC can only reclaim what actually becomes unreachable, and a growing static collection never does.

## Leak pattern #2: unclosed resources

Objects that wrap external resources (files, database connections, network sockets) often hold onto native memory or OS handles that the garbage collector doesn't know how to release on its own — the GC can eventually collect the Java object itself, but that doesn't guarantee the underlying OS-level resource gets freed promptly, or ever, if the object lingers.

```java
import java.io.FileReader;
import java.io.IOException;

public class Main {
    public static void main(String[] args) {
        // Illustrative shape only — no file exists in this sandbox, so this would throw
        // if actually run; the point is the resource-handling pattern.
        readTaskExportLeaky("tasks-export.csv");
        readTaskExportSafely("tasks-export.csv");
    }

    // LEAKY: if an exception happens between open and close, close() is never reached.
    static void readTaskExportLeaky(String path) {
        try {
            FileReader reader = new FileReader(path);
            // ... read the file ...
            reader.close();
        } catch (IOException e) {
            // reader was never closed if the exception happened after opening it
        }
    }

    // SAFE: try-with-resources guarantees close() runs, even if an exception is thrown.
    static void readTaskExportSafely(String path) {
        try (FileReader reader = new FileReader(path)) {
            // ... read the file ...
        } catch (IOException e) {
            // reader.close() has already been called automatically by this point
        }
    }
}
```

`try-with-resources` (any resource implementing `AutoCloseable`, which includes `FileReader`, database `Connection`s, and sockets) guarantees `close()` runs when the block exits — normally or via an exception — which is why it's the standard, "day one" way to handle any closeable resource in modern Java, not an optional nicety.

## The string constant pool and .intern()

String literals get special treatment for memory efficiency: the JVM maintains a **string constant pool**, a cache of unique `String` values, so that identical string literals across your whole program share the exact same object instead of each being a separate allocation.

```java
public class Main {
    public static void main(String[] args) {
        String a = "Design database schema"; // literal — goes into (or reuses from) the pool
        String b = "Design database schema"; // same literal — reuses the exact same pooled object
        String c = new String("Design database schema"); // new String() forces a fresh heap object

        System.out.println("a == b: " + (a == b));               // true — same pooled reference
        System.out.println("a == c: " + (a == c));               // false — c is a distinct heap object
        System.out.println("a.equals(c): " + a.equals(c));       // true — same content

        String d = c.intern(); // returns the pooled instance for this content
        System.out.println("a == d: " + (a == d));               // true — d now points at the pooled string
    }
}
```

`==` on objects compares **references** (are these the same object?), while `.equals()` compares **content** (do these represent the same value?) — this is the single most common `String` bug for anyone new to Java, and it's exactly why this course has consistently used `.equals()` for string comparisons throughout. String literals (`"..."`) are automatically pooled and compare `==`-equal when identical; `new String(...)` deliberately bypasses the pool to create a distinct object, even with identical content. `.intern()` looks up (or adds) the equivalent pooled string and returns that shared reference — it's rarely needed in everyday TaskFlow code, but it's useful when you're deduplicating a large number of repeated string values (e.g. thousands of `Task` objects that all share a small set of status strings) and want them to share memory instead of each holding its own copy.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jvm-memory-memory-leaks-and-string-pool-q1",
      "type": "mcq",
      "prompt": "Why can a static List that objects are only ever added to cause a memory leak, despite Java having a garbage collector?",
      "options": [
        { "id": "a", "text": "static fields are exempt from garbage collection entirely, as a JVM bug" },
        { "id": "b", "text": "static fields are reachable for the entire lifetime of the JVM, so every object added to the list stays reachable — and therefore un-collectible — forever, since nothing removes them" },
        { "id": "c", "text": "ArrayList objects are always garbage collected immediately regardless of references" },
        { "id": "d", "text": "It can't — static collections are always safe" }
      ],
      "correct": "b",
      "explanation": "The GC only reclaims unreachable objects. A static field is reachable as long as the JVM is running, so anything only ever added to (never removed from) a static collection is kept alive indefinitely — a classic real-world leak, even with automatic GC."
    },
    {
      "id": "jvm-memory-memory-leaks-and-string-pool-q2",
      "type": "mcq",
      "prompt": "Why is try-with-resources preferred over manually calling close() at the end of a try block?",
      "options": [
        { "id": "a", "text": "It runs faster than a manual close() call" },
        { "id": "b", "text": "It guarantees close() is called even if an exception is thrown partway through the block, whereas a manual close() at the end of the try body can be skipped entirely if an exception occurs first" },
        { "id": "c", "text": "It removes the need to handle IOException at all" },
        { "id": "d", "text": "It's purely a stylistic preference with no functional difference" }
      ],
      "correct": "b",
      "explanation": "A manual close() placed at the end of a try block is never reached if an earlier line throws — leaving the resource open. try-with-resources calls close() automatically on the way out of the block regardless of how it exits."
    },
    {
      "id": "jvm-memory-memory-leaks-and-string-pool-q3",
      "type": "mcq",
      "prompt": "Given String a = \"X\"; String b = new String(\"X\");, what does a == b evaluate to, and why?",
      "options": [
        { "id": "a", "text": "true, because both hold the text \"X\"" },
        { "id": "b", "text": "false — new String(\"X\") deliberately creates a distinct heap object outside the string constant pool, even though its content equals the pooled literal" },
        { "id": "c", "text": "It throws a compile error" },
        { "id": "d", "text": "true, because Java automatically interns every String" }
      ],
      "correct": "b",
      "explanation": "== compares references, not content. String literals are pooled and share one instance, but new String(...) explicitly allocates a fresh object — so a == b is false even though a.equals(b) is true."
    }
  ]
}
```

## What's next

That closes out JVM and memory internals. The next module moves to **JDBC** — how Java programs talk to a relational database like the one backing TaskFlow itself.
$md$, 20, $json$[{"id":"jvm-memory-memory-leaks-and-string-pool-q1","type":"mcq","correct":"b"},{"id":"jvm-memory-memory-leaks-and-string-pool-q2","type":"mcq","correct":"b"},{"id":"jvm-memory-memory-leaks-and-string-pool-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: JDBC
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('21c030ba-f5d0-5868-8173-da49499df3a3', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'JDBC', 13)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9b73e783-4b83-5567-b6a2-33f20b98184d', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '21c030ba-f5d0-5868-8173-da49499df3a3', 'JDBC Basics and Connection', 'notes', 0, $md$Everything TaskFlow does eventually needs to persist somewhere — tasks, users, projects, teams all live in a relational database, not in memory. **JDBC** (Java Database Connectivity) is the standard Java API for talking to a relational database, and it's worth understanding even if you later use a higher-level tool on top of it, because those tools are almost always built on JDBC underneath.

A note before diving in: **this lesson's code examples describe the JDBC pattern rather than being runnable against a real database in this sandbox.** Every other module in this course runs your code for real against a live JDK — this module is the one exception, because connecting to an actual PostgreSQL or MySQL instance isn't available here. Read these as accurate, realistic Java you'd write in a real TaskFlow backend, not as something to hit Run on and expect output from.

## JDBC is a standard API, not a database

JDBC itself is just a set of interfaces (`Connection`, `Statement`, `ResultSet`, and so on) defined in `java.sql`. Every actual database vendor (PostgreSQL, MySQL, Oracle, SQLite...) ships a **driver** — a concrete implementation of those interfaces that knows how to speak that specific database's wire protocol. Your application code is written against the JDBC interfaces, not against any particular driver, so swapping databases in theory means swapping the driver dependency, not rewriting your data-access code.

## The core flow: DriverManager → Connection → Statement → ResultSet → close

```java
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class Main {
    public static void main(String[] args) {
        // Illustrative only — requires a real database URL, username, and password to run.
        String url = "jdbc:postgresql://localhost:5432/taskflow";
        String username = "taskflow_app";
        String password = System.getenv("DB_PASSWORD");

        try (Connection connection = DriverManager.getConnection(url, username, password);
             Statement statement = connection.createStatement();
             ResultSet resultSet = statement.executeQuery(
                 "SELECT id, name, estimate_hours FROM tasks WHERE status = 'TODO'")) {

            while (resultSet.next()) {
                int id = resultSet.getInt("id");
                String name = resultSet.getString("name");
                int estimateHours = resultSet.getInt("estimate_hours");
                System.out.println(id + ": " + name + " (" + estimateHours + "h)");
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to load TODO tasks", e);
        }
    }
}
```

Walking the flow that every JDBC program follows:

1. **`DriverManager.getConnection(url, username, password)`** opens a `Connection` — a live, stateful session with the database, identified by a JDBC URL (`jdbc:<database-type>://<host>:<port>/<database-name>`). Opening a connection is relatively expensive: it involves a real network handshake and authentication, which matters a lot once you get to connection pooling later in this module.
2. **`connection.createStatement()`** creates a `Statement`, the object you use to actually send SQL to the database.
3. **`statement.executeQuery(sql)`** runs a `SELECT` and returns a `ResultSet` — a cursor over the rows the query matched, not the rows themselves all loaded into memory at once.
4. **`while (resultSet.next())`** advances the cursor one row at a time; `resultSet.next()` returns `false` once there are no more rows, which is what ends the loop. Each `getXxx("column_name")` call reads one column's value from the *current* row.
5. **`try (...)`** — `Connection`, `Statement`, and `ResultSet` are all `AutoCloseable`, and try-with-resources (from the previous module) closes all three, in reverse order, whether the block finishes normally or throws. Every one of them holds a real, finite resource (a network connection, database-side cursor state) that must be released.

## Reading the username/password out of environment variables

Notice `password` in the example comes from `System.getenv("DB_PASSWORD")`, not a literal string in the source. Database credentials hardcoded into source code are both a security risk (anyone with source access has production credentials) and an operational headache (changing a password means redeploying code) — production JDBC code always reads connection details from configuration or environment variables, never from a string literal.

## Statement vs. PreparedStatement — a preview

The example above used a plain `Statement` with a fixed query string containing no user input, which is fine for a static query like this. The moment a query needs to include a value that came from outside your program — a task ID from a request, a search term a user typed — string-concatenating that value into SQL is a serious security hole. The next lesson covers `PreparedStatement`, which is what you should reach for whenever a query needs a parameter, and exactly why it closes that hole.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jdbc-jdbc-basics-and-connection-q1",
      "type": "mcq",
      "prompt": "What is JDBC, precisely?",
      "options": [
        { "id": "a", "text": "A specific database product bundled with the JDK" },
        { "id": "b", "text": "A standard set of Java interfaces for relational database access, implemented by vendor-specific drivers for each actual database" },
        { "id": "c", "text": "A build tool for compiling database schemas" },
        { "id": "d", "text": "A replacement for SQL that doesn't require writing queries" }
      ],
      "correct": "b",
      "explanation": "JDBC defines interfaces like Connection, Statement, and ResultSet in java.sql. Each database vendor ships a driver implementing those interfaces against its own wire protocol, so application code targets the standard interfaces rather than a specific database."
    },
    {
      "id": "jdbc-jdbc-basics-and-connection-q2",
      "type": "mcq",
      "prompt": "What does resultSet.next() do inside a while loop reading query results?",
      "options": [
        { "id": "a", "text": "Loads the entire result set into a List and returns it" },
        { "id": "b", "text": "Advances the cursor to the next row, returning true if a row exists there and false once rows are exhausted, which is what ends the loop" },
        { "id": "c", "text": "Executes the next SQL statement in the file" },
        { "id": "d", "text": "Closes the ResultSet after reading the current row" }
      ],
      "correct": "b",
      "explanation": "ResultSet is a cursor, not a pre-loaded collection. next() moves it forward one row and returns whether a row is there; the getXxx(...) calls then read columns from whichever row the cursor currently points at."
    },
    {
      "id": "jdbc-jdbc-basics-and-connection-q3",
      "type": "mcq",
      "prompt": "Why does the example read the database password from System.getenv(\"DB_PASSWORD\") instead of a string literal?",
      "options": [
        { "id": "a", "text": "String literals cannot hold passwords in Java" },
        { "id": "b", "text": "Hardcoded credentials in source code are a security risk and force a redeploy any time the password changes; reading from the environment keeps secrets out of source and configurable per environment" },
        { "id": "c", "text": "getenv() is required by the JDBC specification" },
        { "id": "d", "text": "It has no real benefit over a literal, it's just convention" }
      ],
      "correct": "b",
      "explanation": "Credentials committed to source code are visible to anyone with repo access and can't be rotated without a code change. Reading them from environment variables or a secrets manager is standard production practice."
    }
  ]
}
```

## What's next

The next lesson covers `PreparedStatement` — parameterized queries that are both safer and, for repeated queries, more efficient than building SQL strings by hand.
$md$, 20, $json$[{"id":"jdbc-jdbc-basics-and-connection-q1","type":"mcq","correct":"b"},{"id":"jdbc-jdbc-basics-and-connection-q2","type":"mcq","correct":"b"},{"id":"jdbc-jdbc-basics-and-connection-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0929d9e4-ab90-5d85-8dbe-d7e10997e245', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '21c030ba-f5d0-5868-8173-da49499df3a3', 'PreparedStatement and ResultSet', 'notes', 1, $md$As with the previous lesson, **these examples describe the JDBC pattern and would need a real database connection to actually execute** — treat them as accurate reference code, not something to run here.

The moment a query needs a value from outside your program — a task name a user typed, an ID from a request — how you build that query stops being a style choice and becomes a security decision. This lesson shows both ways side by side.

## The vulnerable version: string concatenation

```java
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class Main {
    // VULNERABLE — never write JDBC code like this.
    static void findTaskByNameUnsafe(Connection connection, String userSuppliedName) throws SQLException {
        String sql = "SELECT id, status FROM tasks WHERE name = '" + userSuppliedName + "'";

        try (Statement statement = connection.createStatement();
             ResultSet resultSet = statement.executeQuery(sql)) {
            while (resultSet.next()) {
                System.out.println(resultSet.getInt("id") + ": " + resultSet.getString("status"));
            }
        }
    }
}
```

If `userSuppliedName` is a normal task name like `"Design database schema"`, this works fine. But it's built by pasting *unvalidated, untrusted text* directly into a SQL string. A malicious value like:

```
' OR '1'='1
```

turns the query into `SELECT id, status FROM tasks WHERE name = '' OR '1'='1'` — a condition that's always true, returning every row in the table instead of matching a specific name. A more damaging payload could chain a second statement or extract data the caller was never supposed to see. This is **SQL injection**, and string-concatenated queries are exactly how it happens — the database has no way to tell "this is part of the SQL structure" apart from "this is a piece of untrusted data" once they've been mashed into one string.

## The safe version: PreparedStatement with `?` placeholders

```java
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class Main {
    // SAFE — the standard way to write any query that includes a variable value.
    static void findTaskByNameSafe(Connection connection, String userSuppliedName) throws SQLException {
        String sql = "SELECT id, status FROM tasks WHERE name = ?";

        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, userSuppliedName); // 1-indexed, not 0-indexed

            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    System.out.println(resultSet.getInt("id") + ": " + resultSet.getString("status"));
                }
            }
        }
    }
}
```

The `?` is a **placeholder**, not text substitution. `connection.prepareStatement(sql)` sends the query's fixed structure to the database *first*, separately from any values; `statement.setString(1, userSuppliedName)` then binds a value into that placeholder as pure data, never as SQL syntax. Even a malicious value like `' OR '1'='1` gets treated as a literal string to search for — the database looks for a task literally named `' OR '1'='1`, finds nothing, and returns zero rows. There's no way for bound parameter data to alter the query's structure, because the structure was already fixed before any data was attached. Note the parameter index is **1-based**: `setString(1, ...)` sets the first `?` in the SQL, not the second.

## Multiple parameters, and the other setXxx methods

```java
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class Main {
    static void findTasksByStatusAndMinHours(
            Connection connection, String status, int minHours) throws SQLException {
        String sql = "SELECT id, name, estimate_hours FROM tasks WHERE status = ? AND estimate_hours >= ?";

        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);   // first ? — a String
            statement.setInt(2, minHours);    // second ? — an int

            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    System.out.println(
                        resultSet.getString("name") + " — " + resultSet.getInt("estimate_hours") + "h");
                }
            }
        }
    }
}
```

Each `setXxx` method (`setString`, `setInt`, `setBoolean`, `setDate`, and so on) matches a Java type to the correct JDBC/SQL type binding for that placeholder position — using the right one matters both for correctness and so the driver sends the value in the format the database expects. `?` placeholders are numbered left to right through the SQL string, independent of which method is used to set each one.

## Inserts and updates with PreparedStatement

`PreparedStatement` isn't just for `SELECT` — the same parameterized approach applies to `INSERT` and `UPDATE`, using `executeUpdate()` instead of `executeQuery()` since those statements don't return a `ResultSet`:

```java
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

public class Main {
    static int insertTask(Connection connection, String name, int estimateHours, String status) throws SQLException {
        String sql = "INSERT INTO tasks (name, estimate_hours, status) VALUES (?, ?, ?)";

        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, name);
            statement.setInt(2, estimateHours);
            statement.setString(3, status);
            return statement.executeUpdate(); // returns the number of rows affected
        }
    }
}
```

`executeUpdate()` returns the number of rows the statement affected (here, `1` for a successful single-row insert) rather than a `ResultSet` — a useful sanity check that the write actually happened as expected.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jdbc-preparedstatement-and-resultset-q1",
      "type": "mcq",
      "prompt": "Why does building a query with string concatenation like \"... WHERE name = '\" + userInput + \"'\" allow SQL injection?",
      "options": [
        { "id": "a", "text": "It doesn't — this is only a risk with executeUpdate(), not executeQuery()" },
        { "id": "b", "text": "Once user-supplied text is pasted directly into the SQL string, the database can no longer distinguish the query's intended structure from attacker-controlled data — malicious input can alter the query's logic" },
        { "id": "c", "text": "String concatenation in Java always throws a SecurityException" },
        { "id": "d", "text": "It's only a risk if the value contains a semicolon" }
      ],
      "correct": "b",
      "explanation": "Concatenation merges structure and data into one string before the database ever sees it. A value like ' OR '1'='1 becomes part of the query's logic rather than a literal value to search for, which is exactly what SQL injection exploits."
    },
    {
      "id": "jdbc-preparedstatement-and-resultset-q2",
      "type": "mcq",
      "prompt": "How does PreparedStatement prevent the same kind of injection?",
      "options": [
        { "id": "a", "text": "It escapes single quotes in the SQL string before sending it" },
        { "id": "b", "text": "The query's fixed structure is sent to the database separately from bound parameter values, so a value like ' OR '1'='1 is always treated as literal data to search for, never as SQL syntax" },
        { "id": "c", "text": "It disallows any special characters in input, throwing an exception if found" },
        { "id": "d", "text": "It runs the query twice and compares results for tampering" }
      ],
      "correct": "b",
      "explanation": "prepareStatement sends the SQL shape first; setString/setInt then bind values into placeholders as pure data. Because the structure was already fixed before any value arrived, bound data can never change what the query does."
    },
    {
      "id": "jdbc-preparedstatement-and-resultset-q3",
      "type": "mcq",
      "prompt": "In statement.setString(1, value), what does the 1 refer to?",
      "options": [
        { "id": "a", "text": "The zero-based index of the first ? placeholder, so 1 actually refers to the second placeholder" },
        { "id": "b", "text": "The 1-based position of the ? placeholder in the SQL string being bound — the first ? is 1, not 0" },
        { "id": "c", "text": "The database connection number" },
        { "id": "d", "text": "The row number being updated" }
      ],
      "correct": "b",
      "explanation": "JDBC parameter indices are 1-based, not 0-based like most Java array/list indexing — a common source of off-by-one bugs for anyone used to 0-based indexing elsewhere in the language."
    }
  ]
}
```

## What's next

The final lesson in this module covers connection pooling and ties PreparedStatement's injection prevention together with why both are considered non-negotiable, day-one production practices.
$md$, 20, $json$[{"id":"jdbc-preparedstatement-and-resultset-q1","type":"mcq","correct":"b"},{"id":"jdbc-preparedstatement-and-resultset-q2","type":"mcq","correct":"b"},{"id":"jdbc-preparedstatement-and-resultset-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d20dbe1f-a252-5286-bd9a-41d510c55c8b', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '21c030ba-f5d0-5868-8173-da49499df3a3', 'Connection Pooling & Why These Practices Are Non-Negotiable', 'notes', 2, $md$The previous two lessons covered the mechanics: `Connection` → `PreparedStatement` → `ResultSet`, and why parameterized queries prevent SQL injection. This lesson ties them together with the one piece still missing — what happens when TaskFlow needs to serve *many* concurrent requests, each needing a database connection — and makes the case for why none of this is optional polish.

**Note:** like the previous two JDBC lessons, the code in this lesson describes the pattern you'd write in a real application connected to a real database. It isn't runnable in this course's sandboxed code boxes, which don't have a live database attached.

## Why `DriverManager.getConnection` per request doesn't scale

Opening a raw TCP connection to a database, authenticating, and negotiating a session is *expensive* — tens of milliseconds, sometimes more. If TaskFlow's web server opens a brand-new `Connection` for every incoming HTTP request and closes it when the request finishes, every single request pays that setup cost:

```java
// Naive — opens and tears down a full DB connection on every call.
// Fine for a one-off script, disastrous under real concurrent load.
public Task findTask(String taskId) throws SQLException {
    try (Connection conn = DriverManager.getConnection(DB_URL, USER, PASS);
         PreparedStatement stmt = conn.prepareStatement(
             "SELECT id, name, estimate_hours FROM tasks WHERE id = ?")) {
        stmt.setString(1, taskId);
        try (ResultSet rs = stmt.executeQuery()) {
            if (rs.next()) {
                return new Task(rs.getString("id"), rs.getString("name"), rs.getInt("estimate_hours"));
            }
            return null;
        }
    }
}
```

Under light load this "works." Under real traffic — dozens of concurrent TaskFlow users hitting the API — the connection-setup overhead alone can dominate response time, and most databases also cap the number of simultaneous connections they'll accept, so a burst of traffic can simply start failing to connect at all.

## Connection pooling

A **connection pool** (HikariCP is the de facto standard in the Java ecosystem) opens a fixed number of connections once, up front, and hands them out to application code on request — "borrow a connection, use it, give it back" instead of "open a connection, use it, close it forever." The pool keeps connections warm and reuses them:

```java
// Shape of pooled access — HikariCP is configured once at application startup:
//
// HikariConfig config = new HikariConfig();
// config.setJdbcUrl(DB_URL);
// config.setUsername(USER);
// config.setPassword(PASS);
// config.setMaximumPoolSize(10);
// HikariDataSource dataSource = new HikariDataSource(config);
//
// Application code then borrows a Connection from the pool instead of
// DriverManager — everything downstream (PreparedStatement, ResultSet,
// try-with-resources) looks identical to before:
public Task findTask(DataSource dataSource, String taskId) throws SQLException {
    try (Connection conn = dataSource.getConnection(); // borrowed from the pool, not freshly opened
         PreparedStatement stmt = conn.prepareStatement(
             "SELECT id, name, estimate_hours FROM tasks WHERE id = ?")) {
        stmt.setString(1, taskId);
        try (ResultSet rs = stmt.executeQuery()) {
            return rs.next()
                ? new Task(rs.getString("id"), rs.getString("name"), rs.getInt("estimate_hours"))
                : null;
        }
    }
}
```

The crucial detail: **`conn.close()` inside a pooled `try-with-resources` doesn't actually close the underlying TCP connection** — the pool intercepts it and returns the connection to the pool for reuse. Application code doesn't need to know or care that pooling is happening; it still opens and "closes" a `Connection` per unit of work, exactly like the unpooled version. The pool is configured once, centrally, at application startup.

## Sizing a pool

A pool's `maximumPoolSize` isn't "as high as possible" — each pooled connection holds real resources on both the application and database side, and a database has its own hard connection limit shared across every application instance talking to it. A common starting formula (from HikariCP's own guidance) is roughly `connections = ((core_count * 2) + effective_spindle_count)` for the database server, then dividing that budget across however many application instances connect to it — the exact number matters less here than the principle: **pool size is a deliberately tuned, finite resource, not an unlimited convenience**.

## Why PreparedStatement + pooling are both "day one," not later

It's tempting to treat parameterized queries and connection pooling as things you "add later once the app needs to scale." Both are cheap to do correctly from the start and expensive to retrofit:

- **PreparedStatement** costs nothing extra to use over string-concatenated SQL — the syntax is barely different — but retrofitting it into a codebase already full of string-built queries means re-auditing every single query for injection risk, one at a time, under time pressure, usually only after a security review flags it.
- **Connection pooling** is a few lines of setup at application startup. Retrofitting it into a codebase full of scattered `DriverManager.getConnection()` calls means finding and rewriting every one of them, plus debugging whatever connection-exhaustion incidents happened before someone noticed the pattern didn't scale.

Both are the same shape of decision: cheap now, expensive later, and neither one is "premature optimization" — they're baseline correctness and baseline scalability for anything beyond a throwaway script.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "jdbc-connection-pooling-and-injection-recap-q1",
      "type": "mcq",
      "prompt": "Why is calling DriverManager.getConnection() for every incoming request a problem under real traffic?",
      "options": [
        { "id": "a", "text": "It's actually fine at any scale — this is a myth" },
        { "id": "b", "text": "Opening a fresh database connection is expensive (setup + auth), and most databases also cap total simultaneous connections" },
        { "id": "c", "text": "DriverManager can only be called once per application" },
        { "id": "d", "text": "It causes a compile error under concurrent load" }
      ],
      "correct": "b",
      "explanation": "Each new connection pays real setup cost, and databases enforce a maximum connection count — under concurrent traffic, per-request connections both slow every request down and risk hitting that cap."
    },
    {
      "id": "jdbc-connection-pooling-and-injection-recap-q2",
      "type": "mcq",
      "prompt": "When code using a pooled DataSource calls conn.close() inside a try-with-resources block, what actually happens?",
      "options": [
        { "id": "a", "text": "The underlying TCP connection is torn down immediately, same as an unpooled connection" },
        { "id": "b", "text": "Nothing — close() is silently ignored for pooled connections" },
        { "id": "c", "text": "The pool intercepts the call and returns the connection to the pool for reuse, rather than closing it" },
        { "id": "d", "text": "It throws an exception, since pooled connections cannot be closed" }
      ],
      "correct": "c",
      "explanation": "Pooled connections implement close() to mean \"return to the pool,\" not \"disconnect.\" Application code keeps using the same try-with-resources pattern; the pooling behavior is transparent to it."
    },
    {
      "id": "jdbc-connection-pooling-and-injection-recap-q3",
      "type": "mcq",
      "prompt": "Why are PreparedStatement and connection pooling both described as 'day one' practices rather than later optimizations?",
      "options": [
        { "id": "a", "text": "Because Java requires them by law for any database code to compile" },
        { "id": "b", "text": "Because both are cheap to adopt from the start but expensive to retrofit across an entire existing codebase later" },
        { "id": "c", "text": "Because they only matter for applications with more than one million users" },
        { "id": "d", "text": "Neither actually matters in practice — this is overcaution" }
      ],
      "correct": "b",
      "explanation": "Both cost almost nothing to build in from the start. Retrofitting them means auditing or rewriting every existing call site later, usually under pressure after an incident — the same class of tradeoff as most 'do it right the first time' engineering advice."
    }
  ]
}
```

## What's next

That closes out JDBC and database access. The next module, **Design Patterns**, moves from data access back to structuring the code itself — recurring, named solutions to recurring design problems, several of which you've already used informally earlier in this course without naming them.
$md$, 20, $json$[{"id":"jdbc-connection-pooling-and-injection-recap-q1","type":"mcq","correct":"b"},{"id":"jdbc-connection-pooling-and-injection-recap-q2","type":"mcq","correct":"c"},{"id":"jdbc-connection-pooling-and-injection-recap-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Design Patterns
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('b9291cb7-99ee-5957-824b-9b8fb8918b66', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Design Patterns', 14)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('35753afb-b20a-51d5-a38e-e1d32dc149b8', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'b9291cb7-99ee-5957-824b-9b8fb8918b66', 'SOLID Principles', 'notes', 0, $md$Design patterns are named, reusable solutions to problems that show up again and again in object-oriented code. Before you can recognize a pattern, though, it helps to know the five principles that patterns are usually solving for — collectively nicknamed **SOLID**. As TaskFlow has grown across this course, some of its classes have started to strain in predictable ways: one class doing too much, a method that needs editing every time a new task type shows up, a subclass that quietly breaks what callers expect. SOLID names those problems precisely enough that you can spot them before they cause a bug.

## Single Responsibility Principle (SRP)

A class should have **one reason to change**. When a class bundles together unrelated responsibilities, a change to any one of them risks breaking (or forces a re-test of) all the others.

```java
public class Main {
    public static void main(String[] args) {
        TaskManager manager = new TaskManager();
        manager.addTask("Design database schema");
        manager.addTask("Build REST API");
        manager.printReport();
        manager.emailReport("lead@taskflow.dev");
    }
}

class TaskManager {
    private final java.util.List<String> tasks = new java.util.ArrayList<>();

    public void addTask(String name) {
        tasks.add(name);
    }

    public void printReport() {
        System.out.println("=== Task Report ===");
        for (String task : tasks) {
            System.out.println("- " + task);
        }
    }

    public void emailReport(String address) {
        // Pretend this opens a network connection and sends mail
        System.out.println("Emailing report to " + address + "...");
    }
}
```

`TaskManager` has three reasons to change: how tasks are stored, how a report is formatted, and how mail gets sent. A change to the email provider now risks a merge conflict with, and a re-test of, code that has nothing to do with email. Splitting it fixes that:

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        TaskManager manager = new TaskManager();
        manager.addTask("Design database schema");
        manager.addTask("Build REST API");

        TaskReportFormatter formatter = new TaskReportFormatter();
        String report = formatter.format(manager.getTasks());
        System.out.println(report);

        TaskReportMailer mailer = new TaskReportMailer();
        mailer.send(report, "lead@taskflow.dev");
    }
}

class TaskManager {
    private final List<String> tasks = new ArrayList<>();

    public void addTask(String name) {
        tasks.add(name);
    }

    public List<String> getTasks() {
        return tasks;
    }
}

class TaskReportFormatter {
    public String format(List<String> tasks) {
        StringBuilder sb = new StringBuilder("=== Task Report ===\n");
        for (String task : tasks) {
            sb.append("- ").append(task).append("\n");
        }
        return sb.toString();
    }
}

class TaskReportMailer {
    public void send(String report, String address) {
        // Pretend this opens a network connection and sends mail
        System.out.println("Emailing report to " + address + "...");
    }
}
```

Each class now has exactly one reason to change: `TaskManager` for storage rules, `TaskReportFormatter` for report layout, `TaskReportMailer` for how mail gets delivered. None of them needs to know about the other two's internals.

## Open/Closed Principle (OCP)

A class should be **open for extension, closed for modification** — you should be able to add new behavior without editing, and re-testing, code that already works.

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("Bug score: " + priorityScore("BUG"));
        System.out.println("Feature score: " + priorityScore("FEATURE"));
    }

    static int priorityScore(String taskType) {
        if (taskType.equals("BUG")) {
            return 90;
        } else if (taskType.equals("FEATURE")) {
            return 50;
        } else if (taskType.equals("CHORE")) {
            return 20;
        }
        // Every new task type means editing this method again
        return 0;
    }
}
```

Every new task type means opening `priorityScore` and adding another `else if` — touching code that was already working, with the risk of breaking an existing branch by accident. An OCP-friendly version pushes each rule into its own class:

```java
public class Main {
    public static void main(String[] args) {
        PriorityRule bugRule = new BugPriorityRule();
        PriorityRule featureRule = new FeaturePriorityRule();

        System.out.println("Bug score: " + bugRule.score());
        System.out.println("Feature score: " + featureRule.score());
    }
}

interface PriorityRule {
    int score();
}

class BugPriorityRule implements PriorityRule {
    @Override
    public int score() {
        return 90;
    }
}

class FeaturePriorityRule implements PriorityRule {
    @Override
    public int score() {
        return 50;
    }
}

// Adding a new task type is a new class — BugPriorityRule and
// FeaturePriorityRule are never touched again.
class ChorePriorityRule implements PriorityRule {
    @Override
    public int score() {
        return 20;
    }
}
```

Adding a `SecurityPriorityRule` later needs zero changes to `BugPriorityRule` or `FeaturePriorityRule` — only a new file. That's what "closed for modification" buys you: existing, tested behavior can't regress from a change made somewhere else.

## Liskov Substitution Principle (LSP)

Any subtype must be usable anywhere its base type is expected, without breaking the caller's reasonable assumptions. If `RecurringTask extends Task` overrides `markComplete()` to throw an exception because "recurring tasks never complete," any code that loops over a `List<Task>` calling `markComplete()` polymorphically now breaks the moment it happens to hit a `RecurringTask` — the subtype silently violates a contract the base type promised. LSP says: don't override a method to do less than, or something incompatible with, what callers of the base type reasonably expect it to do.

## Interface Segregation Principle (ISP)

Many small, focused interfaces beat one fat interface that forces implementers to stub out methods they'll never use. A single `TaskOperations` interface with `assign()`, `archive()`, `exportToPdf()`, and `syncToCalendar()` forces a minimal `ReadOnlyTaskView` implementation to provide dummy, do-nothing bodies for three methods it will never call. Splitting it into `Assignable`, `Archivable`, `Exportable`, and `CalendarSyncable` lets each class implement only the capabilities it genuinely has.

## Dependency Inversion Principle (DIP)

High-level modules shouldn't depend directly on low-level modules — both should depend on abstractions. A `TaskService` that directly `new`s up a `PostgresTaskRepository` is welded to Postgres. A `TaskService` that instead depends on a `TaskRepository` interface (with `PostgresTaskRepository` as one implementation) can be tested against an in-memory fake and swapped to a different database without touching a single line of `TaskService`. This is the principle the Factory and Strategy patterns later in this module lean on directly.

## Why this matters beyond the acronym

SOLID is the theory; the rest of this module is concrete patterns that put it into practice. Singleton and Factory (next lesson) are about controlling *how* objects get created. Builder and Observer are about constructing complex objects cleanly and reacting to their changes without tight coupling. Strategy — the module's last lesson — is Open/Closed applied directly to swappable algorithms. Recognizing SOLID violations is what tells you *when* to reach for one of these patterns in the first place.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-solid-principles-q1",
      "type": "mcq",
      "prompt": "A TaskManager class handles task storage, formats printable reports, AND sends emails. Which SOLID principle does this violate?",
      "options": [
        { "id": "a", "text": "Liskov Substitution Principle" },
        { "id": "b", "text": "Single Responsibility Principle" },
        { "id": "c", "text": "Interface Segregation Principle" },
        { "id": "d", "text": "Dependency Inversion Principle" }
      ],
      "correct": "b",
      "explanation": "SRP says a class should have one reason to change. Storage, report formatting, and emailing are three unrelated reasons to change, bundled into one class."
    },
    {
      "id": "design-patterns-solid-principles-q2",
      "type": "mcq",
      "prompt": "What does it concretely mean for a priorityScore(String taskType) method with an if/else-if chain to violate the Open/Closed Principle?",
      "options": [
        { "id": "a", "text": "It runs slower than a switch statement" },
        { "id": "b", "text": "Adding a new task type requires editing and re-testing the existing method rather than adding new code" },
        { "id": "c", "text": "It cannot be called from more than one place" },
        { "id": "d", "text": "It uses String comparison instead of an enum" }
      ],
      "correct": "b",
      "explanation": "OCP wants classes open for extension but closed for modification. Every new task type forces you back into the same method, risking regressions in branches that already worked."
    },
    {
      "id": "design-patterns-solid-principles-q3",
      "type": "mcq",
      "prompt": "A RecurringTask subclass overrides markComplete() to throw an exception, since recurring tasks conceptually never finish. Code elsewhere loops over a List<Task> calling markComplete() on each one polymorphically and now crashes on any RecurringTask. Which principle is being violated?",
      "options": [
        { "id": "a", "text": "Liskov Substitution Principle — the subtype isn't safely substitutable for its base type" },
        { "id": "b", "text": "Single Responsibility Principle" },
        { "id": "c", "text": "Open/Closed Principle" },
        { "id": "d", "text": "None — this is normal polymorphism" }
      ],
      "correct": "a",
      "explanation": "LSP requires that a subtype behave in a way that doesn't break reasonable assumptions callers make about the base type. Throwing from an overridden method that callers expect to succeed is a classic LSP violation."
    },
    {
      "id": "design-patterns-solid-principles-q4",
      "type": "mcq",
      "prompt": "A TaskService class calls `new PostgresTaskRepository()` directly inside its own constructor. Which principle would fix this, and how?",
      "options": [
        { "id": "a", "text": "Interface Segregation — split TaskService into smaller interfaces" },
        { "id": "b", "text": "Dependency Inversion — have TaskService depend on a TaskRepository interface instead of the concrete Postgres class" },
        { "id": "c", "text": "Single Responsibility — rename the class" },
        { "id": "d", "text": "Liskov Substitution — make PostgresTaskRepository final" }
      ],
      "correct": "b",
      "explanation": "DIP says high-level code (TaskService) should depend on an abstraction (TaskRepository), not a concrete low-level implementation. That's what makes it possible to test TaskService against an in-memory fake or swap databases later."
    }
  ]
}
```

## What's next

Next up: the **DRY** principle — the companion rule to SOLID that governs duplication *between* classes, and the last piece of theory before this module turns to concrete patterns.
$md$, 25, $json$[{"id":"design-patterns-solid-principles-q1","type":"mcq","correct":"b"},{"id":"design-patterns-solid-principles-q2","type":"mcq","correct":"b"},{"id":"design-patterns-solid-principles-q3","type":"mcq","correct":"a"},{"id":"design-patterns-solid-principles-q4","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4669924c-9d85-586c-9edd-b4d4489dc746', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'b9291cb7-99ee-5957-824b-9b8fb8918b66', 'DRY Principle', 'notes', 1, $md$SOLID tells you how to shape individual classes. DRY is the principle that governs everything *between* them: as TaskFlow grew, the same validation rule or the same message-formatting logic started showing up in more than one place, copy-pasted rather than shared. DRY — **Don't Repeat Yourself** — is the discipline that catches that before it becomes a bug.

## What DRY actually means

Every piece of *knowledge* in a system should have a single, unambiguous, authoritative representation.

> The key word is **knowledge**, not just code. Two blocks of code can look identical by coincidence and not be a DRY violation — and two blocks that look nothing alike can still be expressing the same rule twice.

In TaskFlow terms, "knowledge" covers things like: what makes a task title valid, how a due date gets formatted for display, which fields a `Task` record has, and what "overdue" means. If that last one is decided in one place today and reimplemented slightly differently somewhere else next sprint, TaskFlow now has two different opinions about which tasks are overdue.

## Why repetition is dangerous

| Problem | What it looks like in TaskFlow |
|---|---|
| Hard to maintain | The overdue-date rule changes; you update it in `TaskManager` and forget the copy in `TaskExportService` |
| Bug magnet | One copy of the title-validation check gets a blank-string fix, the other doesn't |
| Bloated codebase | The same ten-line validation block, copy-pasted into every place a task gets created |
| Poor test coverage | Each copy needs its own tests, and they rarely all get written or kept in sync |

## The Rule of Three

Don't extract on the first duplicate — wait until you see the same logic **three times** before pulling it out into its own class or method.

- Two occurrences might be coincidence, or might diverge on purpose later.
- Three occurrences is a pattern, not a coincidence — that's the signal to extract.

Extracting too early is its own trap, covered below.

## Applying DRY: task validation

TaskFlow creates tasks from three different entry points — the UI-backed `TaskManager`, a bulk `TaskImportService` for CSV uploads, and a `TaskApiHandler` for the public API. Each one grew its own copy of "is this task valid":

```java
// TaskManager.addTask(...)
if (title == null || title.isBlank()) {
    throw new IllegalArgumentException("Task title cannot be blank");
}

// TaskImportService.importRow(...) — same rule, written again
if (title == null || title.trim().isEmpty()) {
    throw new IllegalArgumentException("Row has blank title");
}

// TaskApiHandler.createTask(...) — a third copy, and it's missing the null check
if (title.isEmpty()) {
    throw new IllegalArgumentException("title is required");
}
```

Three copies of the same knowledge — "a task title must be non-null and non-blank" — and they've already drifted: the API handler's version throws a `NullPointerException` instead of a clear error if `title` is `null`. That's exactly the bug DRY is meant to prevent. Extract it once:

```java
public class TaskValidator {
    public static void validateTitle(String title) {
        if (title == null || title.isBlank()) {
            throw new IllegalArgumentException("Task title cannot be blank");
        }
    }
}
```

Now `TaskManager`, `TaskImportService`, and `TaskApiHandler` all call `TaskValidator.validateTitle(title)`. Fix the rule once — say, adding a max-length check — and all three callers pick it up automatically, with no risk of one being missed.

## A second example: task notifications

`TaskReminderService`, `OverdueAlertService`, and `AssignmentNotifier` all send messages to users, and all three had grown their own copy of "build a message string, then call the notification API":

```
TaskReminderService  → formats its own message, calls NotificationApi directly
OverdueAlertService  → formats its own (slightly different) message, calls NotificationApi directly
AssignmentNotifier   → formats its own message, calls NotificationApi directly
```

Splitting the shared knowledge out into two focused classes fixes it:

```
TaskMessageFormatter → formats a message from a Task and a reason
NotificationSender   → sends a formatted message via the notification API

TaskReminderService, OverdueAlertService, AssignmentNotifier
  → each calls TaskMessageFormatter, then NotificationSender
```

The payoff shows up the next time TaskFlow changes: swap notification providers, and `NotificationSender` is the only class that changes. Change the message template, and `TaskMessageFormatter` is the only class that changes. Add a `TaskCompletedNotifier` next quarter, and it costs zero changes to the three services that already exist.

## When repetition is okay

DRY is easy to over-apply. A few cases where duplication is the right call:

**Premature abstraction.** Don't extract the first time you see similar-looking code — let a real pattern show up first (see the Rule of Three above). As Sandi Metz puts it: "duplication is far cheaper than the wrong abstraction." A `TaskValidator` built after seeing three real call sites will fit all three; one built after seeing one call site is a guess.

**Tests.** A test for `TaskValidator.validateTitle` should read top-to-bottom without jumping into a shared helper to understand what it's asserting. A little repeated setup across tests is a fair trade for tests that are easy to read in isolation.

**Trivial code.** `dueDate.isBefore(LocalDate.now())` doesn't need a `DateUtils.isPast(dueDate)` wrapper — the abstraction costs more to look up than the line it replaces saves.

## The mental trigger

Before copy-pasting a block of logic, ask: *if this rule changes tomorrow, will I remember every place it lives?* If the honest answer is no, that's the signal to extract it — not on principle, but because a "no" there is how TaskFlow ends up with three different definitions of "overdue."

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-dry-principle-q1",
      "type": "mcq",
      "prompt": "TaskManager, TaskImportService, and TaskApiHandler each independently reimplement the 'title must not be blank' check, and one of the three copies is missing the null check the others have. What does DRY say should have prevented this?",
      "options": [
        { "id": "a", "text": "The check should have a single authoritative implementation that all three callers use" },
        { "id": "b", "text": "Each entry point should validate differently since they receive input differently" },
        { "id": "c", "text": "Validation should be removed from TaskApiHandler entirely" },
        { "id": "d", "text": "This isn't a DRY violation because the code isn't character-for-character identical" }
      ],
      "correct": "a",
      "explanation": "DRY is about knowledge, not literal text — 'a task title must be non-null and non-blank' is one piece of knowledge that was expressed three times and drifted. A single TaskValidator.validateTitle fixes it once for every caller."
    },
    {
      "id": "design-patterns-dry-principle-q2",
      "type": "mcq",
      "prompt": "According to the Rule of Three, when should you extract a piece of duplicated logic into its own class or method?",
      "options": [
        { "id": "a", "text": "Immediately, the first time you notice any two blocks that look similar" },
        { "id": "b", "text": "Only after the same logic has shown up a third time, since two occurrences may be coincidental or meant to diverge" },
        { "id": "c", "text": "Never — extraction always adds unnecessary indirection" },
        { "id": "d", "text": "Only if the duplicated block is longer than 20 lines" }
      ],
      "correct": "b",
      "explanation": "Two occurrences might be coincidence or deliberate divergence; a third occurrence is what confirms a real, stable pattern worth extracting."
    },
    {
      "id": "design-patterns-dry-principle-q3",
      "type": "mcq",
      "prompt": "TaskReminderService, OverdueAlertService, and AssignmentNotifier are refactored so each one calls a shared TaskMessageFormatter and NotificationSender instead of formatting and sending messages independently. What is the main benefit?",
      "options": [
        { "id": "a", "text": "The code runs faster at runtime" },
        { "id": "b", "text": "Swapping the notification provider or changing the message template now requires a change in exactly one place instead of three" },
        { "id": "c", "text": "It removes the need for any of the three services to exist" },
        { "id": "d", "text": "It makes the three services implement the same interface" }
      ],
      "correct": "b",
      "explanation": "The point of extracting shared knowledge into TaskMessageFormatter and NotificationSender is that a change to formatting or to the sending mechanism now propagates automatically to every caller instead of needing to be repeated in each service."
    },
    {
      "id": "design-patterns-dry-principle-q4",
      "type": "mcq",
      "prompt": "Which of these is a case where DRY should NOT be applied, per Sandi Metz's 'duplication is far cheaper than the wrong abstraction'?",
      "options": [
        { "id": "a", "text": "Three separate services all reimplementing the same overdue-task calculation" },
        { "id": "b", "text": "Extracting a shared TaskValidator after seeing the same title check written three times" },
        { "id": "c", "text": "Building a shared abstraction after seeing only one call site, guessing at what the other future call sites might need" },
        { "id": "d", "text": "Extracting NotificationSender after three services duplicated the same API call" }
      ],
      "correct": "c",
      "explanation": "Abstracting from a single call site is premature abstraction — you're guessing at a shape instead of letting a real, repeated pattern reveal it. That guess is usually wrong and costs more to unwind than the duplication would have."
    }
  ]
}
```

## What's next

Next up: the **Singleton** and **Factory** patterns — two ways of controlling how TaskFlow objects get created, starting with a `TaskIdGenerator` that must only ever exist once.
$md$, 20, $json$[{"id":"design-patterns-dry-principle-q1","type":"mcq","correct":"a"},{"id":"design-patterns-dry-principle-q2","type":"mcq","correct":"b"},{"id":"design-patterns-dry-principle-q3","type":"mcq","correct":"b"},{"id":"design-patterns-dry-principle-q4","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9606212e-e7f8-53a1-9471-8213019e605a', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'b9291cb7-99ee-5957-824b-9b8fb8918b66', 'Singleton and Factory Patterns', 'notes', 2, $md$Singleton and Factory are both **creational** patterns — they're about controlling *how* objects come into existence, rather than what they do once they exist.

## The Singleton pattern

A Singleton guarantees a class has exactly one instance, accessible globally. TaskFlow needs this for a `TaskIdGenerator`: if two instances existed, they could hand out the same ID to two different tasks, corrupting data. Only one generator should ever exist for the whole running application.

```java
public class Main {
    public static void main(String[] args) {
        TaskIdGenerator gen1 = TaskIdGenerator.getInstance();
        TaskIdGenerator gen2 = TaskIdGenerator.getInstance();

        System.out.println("Same instance? " + (gen1 == gen2));
        System.out.println("Next ID: " + gen1.nextId());
        System.out.println("Next ID: " + gen2.nextId());
    }
}

class TaskIdGenerator {
    private static TaskIdGenerator instance;
    private int counter = 0;

    private TaskIdGenerator() {
        // private constructor prevents `new TaskIdGenerator()` from outside
    }

    public static TaskIdGenerator getInstance() {
        if (instance == null) {
            instance = new TaskIdGenerator();
        }
        return instance;
    }

    public synchronized int nextId() {
        counter++;
        return counter;
    }
}
```

This works fine in a single-threaded example like this one, but `getInstance()` itself is **not thread-safe**. Two threads can both pass the `instance == null` check before either finishes assigning it, and each ends up constructing its own separate `TaskIdGenerator` — silently breaking the "exactly one instance" guarantee. It's a bug that only shows up under real concurrent load, never in a simple demo like this.

A clean, thread-safe fix is the **static holder idiom**:

```java
public class Main {
    public static void main(String[] args) {
        TaskIdGenerator gen1 = TaskIdGenerator.getInstance();
        TaskIdGenerator gen2 = TaskIdGenerator.getInstance();

        System.out.println("Same instance? " + (gen1 == gen2));
        System.out.println("Next ID: " + gen1.nextId());
        System.out.println("Next ID: " + gen2.nextId());
    }
}

class TaskIdGenerator {
    private int counter = 0;

    private TaskIdGenerator() {
    }

    // The JVM guarantees a class is loaded (and its static fields
    // initialized) lazily, on first access, and exactly once — even
    // under concurrent access. No synchronized keyword needed here.
    private static class Holder {
        private static final TaskIdGenerator INSTANCE = new TaskIdGenerator();
    }

    public static TaskIdGenerator getInstance() {
        return Holder.INSTANCE;
    }

    public synchronized int nextId() {
        counter++;
        return counter;
    }
}
```

`Holder` isn't loaded until `getInstance()` is first called, so construction is still lazy — but class loading itself is synchronized by the JVM's classloader, so the instance gets built exactly once no matter how many threads call `getInstance()` concurrently, with no explicit `synchronized` on the getter and no double-checked-locking subtlety to get wrong. If construction is cheap and laziness doesn't matter, an even simpler fix is eager initialization — `private static final TaskIdGenerator INSTANCE = new TaskIdGenerator();` directly on the field — which is thread-safe by that same class-loading guarantee, just less lazy.

## The Factory pattern

A Factory centralizes object-creation logic, especially useful when the concrete type to build depends on runtime input. TaskFlow has `BugTask`, `FeatureTask`, and `ChoreTask` — all `Task` subtypes with different default behavior — and a `TaskFactory` picks the right one based on a type string.

```java
public class Main {
    public static void main(String[] args) {
        Task bug = TaskFactory.createTask("BUG", "Fix login crash", 3);
        Task feature = TaskFactory.createTask("FEATURE", "Add dark mode", 8);
        Task chore = TaskFactory.createTask("CHORE", "Update dependencies", 1);

        for (Task t : new Task[] { bug, feature, chore }) {
            System.out.println(t.describe());
        }
    }
}

abstract class Task {
    protected final String name;
    protected final int estimateHours;

    protected Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public abstract String describe();
}

class BugTask extends Task {
    BugTask(String name, int estimateHours) {
        super(name, estimateHours);
    }

    @Override
    public String describe() {
        return "[BUG, P0 by default] " + name + " (" + estimateHours + "h)";
    }
}

class FeatureTask extends Task {
    FeatureTask(String name, int estimateHours) {
        super(name, estimateHours);
    }

    @Override
    public String describe() {
        return "[FEATURE] " + name + " (" + estimateHours + "h)";
    }
}

class ChoreTask extends Task {
    ChoreTask(String name, int estimateHours) {
        super(name, estimateHours);
    }

    @Override
    public String describe() {
        return "[CHORE, low priority] " + name + " (" + estimateHours + "h)";
    }
}

class TaskFactory {
    public static Task createTask(String type, String name, int estimateHours) {
        switch (type) {
            case "BUG":
                return new BugTask(name, estimateHours);
            case "FEATURE":
                return new FeatureTask(name, estimateHours);
            case "CHORE":
                return new ChoreTask(name, estimateHours);
            default:
                throw new IllegalArgumentException("Unknown task type: " + type);
        }
    }
}
```

Callers never call `new BugTask(...)` directly — they ask the factory for a `Task` by type and get back the right concrete subtype, already correctly configured. This decouples "what kind of task am I creating" from "how does the rest of the app use a `Task`" — callers only ever depend on the `Task` abstraction, which is Dependency Inversion in action. Notice the `switch` inside the factory is the one place OCP is deliberately relaxed: the factory itself *does* need editing when a new task type is added, but that's a single, contained location instead of `instanceof` checks and `new` calls scattered across the codebase.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-singleton-factory-q1",
      "type": "mcq",
      "prompt": "Why is the naive lazy Singleton's getInstance() method not thread-safe?",
      "options": [
        { "id": "a", "text": "It never actually creates an instance" },
        { "id": "b", "text": "Two threads can both see instance == null before either finishes assigning it, creating two separate instances" },
        { "id": "c", "text": "The private constructor throws an exception under concurrency" },
        { "id": "d", "text": "Static fields cannot be read by more than one thread" }
      ],
      "correct": "b",
      "explanation": "Without synchronization, the null-check and the assignment aren't atomic together — two threads can race through the check before either one finishes construction, breaking the single-instance guarantee."
    },
    {
      "id": "design-patterns-singleton-factory-q2",
      "type": "mcq",
      "prompt": "Why does TaskIdGenerator's constructor need to be private?",
      "options": [
        { "id": "a", "text": "Private constructors compile faster" },
        { "id": "b", "text": "It prevents any code outside the class from calling `new TaskIdGenerator()` and creating additional instances" },
        { "id": "c", "text": "Java requires all Singleton constructors to be private by law" },
        { "id": "d", "text": "It has no real effect — it's just a convention" }
      ],
      "correct": "b",
      "explanation": "The whole point of a Singleton is that the only way to obtain an instance is through getInstance(). A public constructor would let any caller bypass that and create extra instances."
    },
    {
      "id": "design-patterns-singleton-factory-q3",
      "type": "mcq",
      "prompt": "What does the static holder idiom rely on to be thread-safe without an explicit synchronized keyword?",
      "options": [
        { "id": "a", "text": "The JVM's guarantee that a class's static fields are initialized lazily and exactly once, even under concurrent access" },
        { "id": "b", "text": "The garbage collector pausing all other threads during initialization" },
        { "id": "c", "text": "Random chance — it isn't actually guaranteed to be safe" },
        { "id": "d", "text": "The final keyword on the outer class" }
      ],
      "correct": "a",
      "explanation": "The JVM's classloader synchronizes class initialization internally, so the nested Holder class's static field is set up exactly once no matter how many threads call getInstance() at the same time."
    },
    {
      "id": "design-patterns-singleton-factory-q4",
      "type": "mcq",
      "prompt": "What's the main benefit of routing Task creation through TaskFactory.createTask(...) instead of calling `new BugTask(...)`, `new FeatureTask(...)`, etc. directly throughout the codebase?",
      "options": [
        { "id": "a", "text": "It makes the Task subclasses run faster" },
        { "id": "b", "text": "It centralizes the type-to-subclass decision in one place, so callers only depend on the Task abstraction" },
        { "id": "c", "text": "It removes the need for inheritance entirely" },
        { "id": "d", "text": "It automatically makes Task thread-safe" }
      ],
      "correct": "b",
      "explanation": "Callers ask for a Task by type and never need to know which concrete subclass they got. If a new task type is added, only the factory changes — call sites elsewhere in the app stay untouched."
    }
  ]
}
```

## What's next

Next: **Builder** and **Observer** — a fluent way to construct a `Task` with many optional fields, and a way for other parts of TaskFlow to react when a task's status changes.
$md$, 25, $json$[{"id":"design-patterns-singleton-factory-q1","type":"mcq","correct":"b"},{"id":"design-patterns-singleton-factory-q2","type":"mcq","correct":"b"},{"id":"design-patterns-singleton-factory-q3","type":"mcq","correct":"a"},{"id":"design-patterns-singleton-factory-q4","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('76d11bd8-6c59-5344-a242-c73bdb389cc8', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'b9291cb7-99ee-5957-824b-9b8fb8918b66', 'Builder and Observer Patterns', 'notes', 3, $md$Builder is another creational pattern, this time solving a *construction* problem. Observer is a **behavioral** pattern — it's about how objects react to each other's changes over time, rather than how they get built.

## The problem Builder solves: telescoping constructors

TaskFlow's real `Task` has a lot of optional fields beyond `name` and `estimateHours`: priority, assignee, status, due date, and more. A common first instinct is a chain of overloaded constructors, each delegating to a bigger one:

```java
public class Main {
    public static void main(String[] args) {
        Task t1 = new Task("Design schema", 6);
        Task t2 = new Task("Design schema", 6, "HIGH");
        Task t3 = new Task("Design schema", 6, "HIGH", "alice");

        System.out.println(t1.name + ", " + t1.priority + ", " + t1.assignee);
        System.out.println(t3.name + ", " + t3.priority + ", " + t3.assignee);
    }
}

class Task {
    String name;
    int estimateHours;
    String priority;
    String assignee;

    Task(String name, int estimateHours) {
        this(name, estimateHours, "MEDIUM");
    }

    Task(String name, int estimateHours, String priority) {
        this(name, estimateHours, priority, "unassigned");
    }

    Task(String name, int estimateHours, String priority, String assignee) {
        this.name = name;
        this.estimateHours = estimateHours;
        this.priority = priority;
        this.assignee = assignee;
    }
}
```

This works for four fields, but every additional optional field (`status`, `dueDate`, `project`, `tags`...) multiplies the plausible constructor combinations. Worse, a call like `new Task("x", 6, "HIGH", "alice")` tells a reader nothing about which positional argument means what.

The **Builder** pattern fixes both problems:

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task.Builder("Design schema", 6)
                .priority("HIGH")
                .assignee("alice")
                .status("IN_PROGRESS")
                .build();

        System.out.println(task.name + " | " + task.priority + " | "
                + task.assignee + " | " + task.status);
    }
}

class Task {
    final String name;
    final int estimateHours;
    final String priority;
    final String assignee;
    final String status;

    private Task(Builder builder) {
        this.name = builder.name;
        this.estimateHours = builder.estimateHours;
        this.priority = builder.priority;
        this.assignee = builder.assignee;
        this.status = builder.status;
    }

    static class Builder {
        private final String name;
        private final int estimateHours;
        private String priority = "MEDIUM";
        private String assignee = "unassigned";
        private String status = "TODO";

        public Builder(String name, int estimateHours) {
            this.name = name;
            this.estimateHours = estimateHours;
        }

        public Builder priority(String priority) {
            this.priority = priority;
            return this;
        }

        public Builder assignee(String assignee) {
            this.assignee = assignee;
            return this;
        }

        public Builder status(String status) {
            this.status = status;
            return this;
        }

        public Task build() {
            return new Task(this);
        }
    }
}
```

`name` and `estimateHours` are required, passed straight to the Builder's own constructor. Everything else is optional with a sensible default, and read as a self-documenting method call — `.priority("HIGH")` is unambiguous in a way a bare `"HIGH"` positional argument never was. Each builder method returns `this`, which is what makes the calls chain fluently. The outer `Task` constructor is `private`: the only way to obtain a `Task` is through the Builder, so it's impossible to construct one in a half-initialized state.

## The Observer pattern

Observer lets objects (**observers**, or listeners) subscribe to another object's (the **subject**'s) state changes, without the subject knowing anything concrete about who's listening. When a TaskFlow task's status changes, several unrelated things should happen — logging, notifying the assignee, refreshing a dashboard — without `Task` itself knowing about logging, notifications, or dashboards.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        Task task = new Task("Deploy to prod");
        task.addListener(new LoggingListener());
        task.addListener(new NotificationListener("alice"));

        task.setStatus("IN_PROGRESS");
        task.setStatus("DONE");
    }
}

interface TaskListener {
    void onStatusChanged(Task task, String oldStatus, String newStatus);
}

class Task {
    private final String name;
    private String status = "TODO";
    private final List<TaskListener> listeners = new ArrayList<>();

    Task(String name) {
        this.name = name;
    }

    public void addListener(TaskListener listener) {
        listeners.add(listener);
    }

    public void setStatus(String newStatus) {
        String oldStatus = this.status;
        this.status = newStatus;
        for (TaskListener listener : listeners) {
            listener.onStatusChanged(this, oldStatus, newStatus);
        }
    }

    public String getName() {
        return name;
    }
}

class LoggingListener implements TaskListener {
    @Override
    public void onStatusChanged(Task task, String oldStatus, String newStatus) {
        System.out.println("[LOG] " + task.getName() + ": " + oldStatus + " -> " + newStatus);
    }
}

class NotificationListener implements TaskListener {
    private final String username;

    NotificationListener(String username) {
        this.username = username;
    }

    @Override
    public void onStatusChanged(Task task, String oldStatus, String newStatus) {
        if (newStatus.equals("DONE")) {
            System.out.println("[NOTIFY " + username + "] " + task.getName() + " is done!");
        }
    }
}
```

`Task` only knows about the `TaskListener` interface — never about `LoggingListener` or `NotificationListener` specifically. New listener types (a dashboard updater, a Slack integration) can be added later without touching `Task` at all. That's Open/Closed again, this time applied to a runtime-event scenario instead of a creation scenario.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-builder-observer-q1",
      "type": "mcq",
      "prompt": "What problem does the Builder pattern solve compared to a chain of overloaded constructors?",
      "options": [
        { "id": "a", "text": "It makes object construction faster at runtime" },
        { "id": "b", "text": "It avoids the exponential growth of constructor overloads and makes optional-field calls self-documenting" },
        { "id": "c", "text": "It removes the need for a class to have any fields" },
        { "id": "d", "text": "It allows fields to be reassigned after construction" }
      ],
      "correct": "b",
      "explanation": "Telescoping constructors multiply combinatorially as optional fields are added, and positional arguments are unreadable. Builder methods are named, chainable, and only set what's explicitly called."
    },
    {
      "id": "design-patterns-builder-observer-q2",
      "type": "mcq",
      "prompt": "Why is Task's own constructor declared private in the Builder example?",
      "options": [
        { "id": "a", "text": "Private constructors run faster" },
        { "id": "b", "text": "So the only way to obtain a Task instance is through Builder.build(), preventing a half-initialized Task" },
        { "id": "c", "text": "Java requires it whenever a nested class exists" },
        { "id": "d", "text": "It has no effect since Builder is in the same file" }
      ],
      "correct": "b",
      "explanation": "Making the constructor private forces every caller through the Builder's fluent API, guaranteeing a Task is always fully and consistently constructed before it's usable."
    },
    {
      "id": "design-patterns-builder-observer-q3",
      "type": "mcq",
      "prompt": "In the Observer example, what does Task depend on to notify listeners of a status change?",
      "options": [
        { "id": "a", "text": "The concrete LoggingListener and NotificationListener classes directly" },
        { "id": "b", "text": "Only the TaskListener interface — it has no knowledge of any specific listener implementation" },
        { "id": "c", "text": "A hardcoded email address" },
        { "id": "d", "text": "Reflection to discover listener classes at runtime" }
      ],
      "correct": "b",
      "explanation": "Task calls onStatusChanged on every registered TaskListener without knowing or caring which concrete class implements it — new listener types can be added without ever modifying Task."
    }
  ]
}
```

## What's next

Last lesson in this module: the **Strategy** pattern, for swapping how TaskFlow sorts and prioritizes a task list at runtime.
$md$, 25, $json$[{"id":"design-patterns-builder-observer-q1","type":"mcq","correct":"b"},{"id":"design-patterns-builder-observer-q2","type":"mcq","correct":"b"},{"id":"design-patterns-builder-observer-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0bc8fd5e-b5a6-5503-b293-2ca1aea25943', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'b9291cb7-99ee-5957-824b-9b8fb8918b66', 'Strategy Pattern', 'notes', 4, $md$Strategy encapsulates a family of interchangeable algorithms behind one common interface, so the algorithm in use can be swapped at runtime without touching the code that uses it.

## The problem: hardcoded sorting logic

TaskFlow needs to sort a task list different ways depending on context — sometimes by urgency, sometimes by due date. A natural first attempt bakes the choice into an `if`/`else` inside one method:

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Design schema", 5, 3));
        tasks.add(new Task("Fix login bug", 1, 9));
        tasks.add(new Task("Write docs", 8, 1));

        sortTasks(tasks, "URGENCY");
        printTasks(tasks);

        sortTasks(tasks, "DUE_DATE");
        printTasks(tasks);
    }

    static void sortTasks(List<Task> tasks, String mode) {
        if (mode.equals("URGENCY")) {
            tasks.sort((a, b) -> b.urgency - a.urgency);
        } else if (mode.equals("DUE_DATE")) {
            tasks.sort((a, b) -> a.dueInDays - b.dueInDays);
        }
        // A third sort mode means editing this method again
    }

    static void printTasks(List<Task> tasks) {
        for (Task t : tasks) {
            System.out.println(t.name + " (urgency=" + t.urgency + ", due in " + t.dueInDays + "d)");
        }
        System.out.println("---");
    }
}

class Task {
    String name;
    int dueInDays;
    int urgency;

    Task(String name, int dueInDays, int urgency) {
        this.name = name;
        this.dueInDays = dueInDays;
        this.urgency = urgency;
    }
}
```

This is the same Open/Closed problem from the SOLID lesson, applied to sorting: every new sort mode means editing `sortTasks` and risking the existing branches.

## The Strategy fix: pluggable PriorityStrategy

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Design schema", 5, 3));
        tasks.add(new Task("Fix login bug", 1, 9));
        tasks.add(new Task("Write docs", 8, 1));

        TaskSorter sorter = new TaskSorter(new ByUrgency());
        sorter.sort(tasks);
        printTasks(tasks);

        sorter.setStrategy(new ByDueDate());
        sorter.sort(tasks);
        printTasks(tasks);
    }

    static void printTasks(List<Task> tasks) {
        for (Task t : tasks) {
            System.out.println(t.name + " (urgency=" + t.urgency + ", due in " + t.dueInDays + "d)");
        }
        System.out.println("---");
    }
}

interface PriorityStrategy {
    void sort(List<Task> tasks);
}

class ByUrgency implements PriorityStrategy {
    @Override
    public void sort(List<Task> tasks) {
        tasks.sort((a, b) -> b.urgency - a.urgency);
    }
}

class ByDueDate implements PriorityStrategy {
    @Override
    public void sort(List<Task> tasks) {
        tasks.sort((a, b) -> a.dueInDays - b.dueInDays);
    }
}

class TaskSorter {
    private PriorityStrategy strategy;

    TaskSorter(PriorityStrategy strategy) {
        this.strategy = strategy;
    }

    public void setStrategy(PriorityStrategy strategy) {
        this.strategy = strategy;
    }

    public void sort(List<Task> tasks) {
        strategy.sort(tasks);
    }
}

class Task {
    String name;
    int dueInDays;
    int urgency;

    Task(String name, int dueInDays, int urgency) {
        this.name = name;
        this.dueInDays = dueInDays;
        this.urgency = urgency;
    }
}
```

`TaskSorter` never encodes any sorting logic itself — it just delegates to whichever `PriorityStrategy` it currently holds. Swapping behavior at runtime is a `setStrategy(...)` call, not a code change. A later `ByEstimateHours` strategy is a new class; `ByUrgency` and `ByDueDate` are never touched — Open/Closed again.

## Strategy is already in the standard library

`List.sort(Comparator)` *is* the Strategy pattern: `Comparator<T>` is the strategy interface, and every lambda you pass to `.sort(...)` is an inline strategy implementation.

```java
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Design schema", 5, 3));
        tasks.add(new Task("Fix login bug", 1, 9));
        tasks.add(new Task("Write docs", 5, 1));

        // Comparator IS the Strategy interface from the standard library.
        tasks.sort(Comparator.comparingInt((Task t) -> t.dueInDays)
                .thenComparingInt(t -> -t.urgency));

        for (Task t : tasks) {
            System.out.println(t.name + " (due in " + t.dueInDays + "d, urgency=" + t.urgency + ")");
        }
    }
}

class Task {
    String name;
    int dueInDays;
    int urgency;

    Task(String name, int dueInDays, int urgency) {
        this.name = name;
        this.dueInDays = dueInDays;
        this.urgency = urgency;
    }
}
```

`Comparator.comparing(...)` and `.thenComparing(...)` compose two strategies (sort by due date, break ties by urgency) without writing a `PriorityStrategy` hierarchy at all. It's worth recognizing the pattern when the standard library already implements it for you — reaching for `Comparator` composition is usually simpler than hand-rolling your own strategy interface, and it's the same idea underneath.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-strategy-pattern-q1",
      "type": "mcq",
      "prompt": "What is the core idea of the Strategy pattern?",
      "options": [
        { "id": "a", "text": "Encapsulate interchangeable algorithms behind a common interface so they can be swapped at runtime" },
        { "id": "b", "text": "Ensure a class has only one instance" },
        { "id": "c", "text": "Notify a list of subscribers whenever state changes" },
        { "id": "d", "text": "Centralize object construction behind a factory method" }
      ],
      "correct": "a",
      "explanation": "Strategy is about swappable behavior: a context class (like TaskSorter) holds a reference to an interface (PriorityStrategy) and delegates to whichever concrete implementation is currently plugged in."
    },
    {
      "id": "design-patterns-strategy-pattern-q2",
      "type": "mcq",
      "prompt": "In the TaskSorter example, how do you change from sorting by urgency to sorting by due date at runtime?",
      "options": [
        { "id": "a", "text": "Edit the sort() method to add an else-if branch" },
        { "id": "b", "text": "Call sorter.setStrategy(new ByDueDate())" },
        { "id": "c", "text": "Create a brand-new Task class" },
        { "id": "d", "text": "Recompile the program with a different sort mode constant" }
      ],
      "correct": "b",
      "explanation": "setStrategy swaps which PriorityStrategy object TaskSorter delegates to — no source code changes needed, which is the whole point of the pattern."
    },
    {
      "id": "design-patterns-strategy-pattern-q3",
      "type": "mcq",
      "prompt": "Which standard library type is described in this lesson as an existing implementation of the Strategy pattern?",
      "options": [
        { "id": "a", "text": "Comparator<T>" },
        { "id": "b", "text": "Scanner" },
        { "id": "c", "text": "ArrayList<T>" },
        { "id": "d", "text": "Optional<T>" }
      ],
      "correct": "a",
      "explanation": "Comparator<T> is the strategy interface, and every lambda or Comparator.comparing(...) call you pass to List.sort() is a concrete, swappable strategy implementation."
    }
  ]
}
```

## What's next

The module wraps up with a graded quiz covering SOLID, Singleton, Factory, Builder, Observer, and Strategy.
$md$, 20, $json$[{"id":"design-patterns-strategy-pattern-q1","type":"mcq","correct":"a"},{"id":"design-patterns-strategy-pattern-q2","type":"mcq","correct":"b"},{"id":"design-patterns-strategy-pattern-q3","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('08bf5b62-d5d5-5486-9f6d-d2d868ce9f6e', '00000000-0000-0000-0000-000000000001', 'mcq', 'A TaskService class both saves tasks to the database AND formats them into HT...', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cd8545a0-4222-5179-844d-7e84db07c7b2', '08bf5b62-d5d5-5486-9f6d-d2d868ce9f6e', 1, $json${"prompt":"A TaskService class both saves tasks to the database AND formats them into HTML for email notifications. Which SOLID principle does this violate?","multiple":false,"options":[{"id":"a","text":"Single Responsibility Principle — the class has two reasons to change (persistence logic and presentation logic)","is_correct":true},{"id":"b","text":"Liskov Substitution Principle","is_correct":false},{"id":"c","text":"Interface Segregation Principle","is_correct":false},{"id":"d","text":"It doesn't violate any SOLID principle","is_correct":false}],"explanation":"A class with two unrelated responsibilities has two independent reasons to change — a hallmark SRP violation. Persistence and presentation should live in separate classes."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4fa10f57-2733-5b56-a534-47e3463c8c75', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why is a naive lazy Singleton (checking `if (instance == null) instance = new...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a2a95af2-bf41-51d4-8a41-8e94c61a10ad', '4fa10f57-2733-5b56-a534-47e3463c8c75', 1, $json${"prompt":"Why is a naive lazy Singleton (checking `if (instance == null) instance = new Thing();` with no synchronization) unsafe under concurrency?","multiple":false,"options":[{"id":"a","text":"It isn't unsafe — Singletons are always thread-safe by design","is_correct":false},{"id":"b","text":"Two threads can both see instance as null at the same time and each construct a separate instance, breaking the single-instance guarantee","is_correct":true},{"id":"c","text":"Java forbids static fields from being null","is_correct":false},{"id":"d","text":"Singleton and thread-safety are unrelated concepts","is_correct":false}],"explanation":"The null-check-then-create sequence isn't atomic. Two threads can both pass the null check before either finishes constructing, producing two 'singleton' instances — exactly the race condition the concurrency module covered."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a8035bac-b6be-5f66-929e-0960a36c8401', '00000000-0000-0000-0000-000000000001', 'mcq', 'What problem does the Factory pattern solve?', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1a7ef695-84c5-5520-a249-0b812eef988d', 'a8035bac-b6be-5f66-929e-0960a36c8401', 1, $json${"prompt":"What problem does the Factory pattern solve?","multiple":false,"options":[{"id":"a","text":"It centralizes object-creation logic so calling code doesn't need to know which concrete subtype to instantiate","is_correct":true},{"id":"b","text":"It makes classes immutable","is_correct":false},{"id":"c","text":"It replaces the need for constructors entirely","is_correct":false},{"id":"d","text":"It's only useful for creating Singletons","is_correct":false}],"explanation":"A Factory encapsulates the decision of which concrete class to instantiate, so callers depend on an interface/supertype and a creation method rather than on every concrete subtype's constructor directly."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0151b94d-c022-54bd-b65a-9dd19064dfc3', '00000000-0000-0000-0000-000000000001', 'mcq', 'What problem does the Builder pattern solve that a class with many optional c...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('852d9d62-7c3a-566b-a505-e3ae14a556aa', '0151b94d-c022-54bd-b65a-9dd19064dfc3', 1, $json${"prompt":"What problem does the Builder pattern solve that a class with many optional constructor parameters runs into?","multiple":false,"options":[{"id":"a","text":"It avoids 'telescoping constructors' — many overloaded constructors for every combination of optional fields — by letting callers set only the fields they care about, fluently, before building","is_correct":true},{"id":"b","text":"It makes a class's fields public","is_correct":false},{"id":"c","text":"It eliminates the need for a class to have any fields","is_correct":false},{"id":"d","text":"It's required for every Java class regardless of parameter count","is_correct":false}],"explanation":"Builder trades a combinatorial explosion of overloaded constructors for one fluent, readable construction path, especially valuable once several fields are optional."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('16d6ec98-3c35-5d2e-a272-6188f028f58b', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the Observer pattern, what is the relationship between the subject (e.g. a...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fb57d7f1-80c0-5026-8a32-01cfaae9e0fc', '16d6ec98-3c35-5d2e-a272-6188f028f58b', 1, $json${"prompt":"In the Observer pattern, what is the relationship between the subject (e.g. a Task) and its observers (e.g. TaskListeners)?","multiple":false,"options":[{"id":"a","text":"The subject holds a list of observers and notifies all of them when relevant state changes, without needing to know what each observer does with that notification","is_correct":true},{"id":"b","text":"Each observer directly modifies the subject's private fields","is_correct":false},{"id":"c","text":"Only one observer may be registered at a time","is_correct":false},{"id":"d","text":"Observers poll the subject continuously instead of being notified","is_correct":false}],"explanation":"Observer decouples the subject from the specific reactions its observers take — the subject just announces \"this changed,\" and each observer decides independently how to react."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('91fafda2-8ce5-5df3-9dcd-7ce2b50dd8fa', '00000000-0000-0000-0000-000000000001', 'mcq', 'How does the Strategy pattern improve on a method full of if/else branches ch...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b9b87123-e4ae-51af-8bb6-2664977d0cd5', '91fafda2-8ce5-5df3-9dcd-7ce2b50dd8fa', 1, $json${"prompt":"How does the Strategy pattern improve on a method full of if/else branches choosing behavior by a type flag?","multiple":false,"options":[{"id":"a","text":"It encapsulates each behavior as its own class implementing a common interface, so adding a new behavior means adding a new class instead of editing an existing method (Open/Closed in practice)","is_correct":true},{"id":"b","text":"It removes the need for interfaces entirely","is_correct":false},{"id":"c","text":"It only works with numeric comparisons","is_correct":false},{"id":"d","text":"It requires fewer classes than an if/else chain","is_correct":false}],"explanation":"Strategy turns \"which behavior\" into \"which object,\" letting new behaviors be added as new classes without touching the code that uses them — a direct, practical example of the Open/Closed Principle from this module's first lesson."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('396c021d-b45f-50ed-a30b-f29d1e4cc806', '00000000-0000-0000-0000-000000000001', 'coding', 'Using a Builder-style class, construct a simple report line. Read a task name...', 'intermediate', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2739bfa6-0c28-5700-bcd6-661283b17d06', '396c021d-b45f-50ed-a30b-f29d1e4cc806', 1, $json${"prompt":"Using a Builder-style class, construct a simple report line. Read a task name and an integer hours value from one line of stdin, space-separated (the name has no spaces). Build the output using method chaining on a small builder class with methods like withName(...) and withHours(...) and a build() method that returns a formatted String, then print exactly: \"\u003cname\u003e: \u003chours\u003eh\" (e.g. \"Deploy: 6h\").","languages":["java"],"starter_code":{"java":"import java.util.Scanner;\n\npublic class Main {\n    static class ReportBuilder {\n        private String name;\n        private int hours;\n\n        ReportBuilder withName(String name) {\n            this.name = name;\n            return this;\n        }\n\n        ReportBuilder withHours(int hours) {\n            this.hours = hours;\n            return this;\n        }\n\n        String build() {\n            return name + \": \" + hours + \"h\";\n        }\n    }\n\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        // Read a task name and an integer hours value from one line, then\n        // use ReportBuilder via method chaining to build and print the report line.\n\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"Deploy 6","expected":"Deploy: 6h","hidden":false,"weight":1},{"id":"t2","stdin":"Design 3","expected":"Design: 3h","hidden":true,"weight":1},{"id":"t3","stdin":"Review 0","expected":"Review: 0h","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('64c0a9a2-a8ce-5372-939c-15154794ffd5', '00000000-0000-0000-0000-000000000001', 'subjective', 'In your own words: which pattern from this module (Singleton, Factory, Builde...', 'beginner', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c17867cb-996f-5dba-959a-0fd1b61bdcd3', '64c0a9a2-a8ce-5372-939c-15154794ffd5', 1, $json${"prompt":"In your own words: which pattern from this module (Singleton, Factory, Builder, Observer, or Strategy) felt least intuitive, and why? Be specific about what confused you — this feeds directly into what gets flagged for review.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific reflection rather than a single correct answer — the goal is to surface which pattern you're actually shakiest on."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('10a89080-de59-5f60-8894-11a9d66cbc03', '00000000-0000-0000-0000-000000000001', 'Module Assessment: Design Patterns', 'java-mastery-design-patterns-quiz', 'Quiz covering Design Patterns.', 'mixed', 'published', 'module', 'a9bbee92-e1fd-5232-a35a-bbc6b1b98f5f', 25, 70, 5, 15, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('94451266-31e8-50cf-a816-3d71bb08747b', '10a89080-de59-5f60-8894-11a9d66cbc03', '08bf5b62-d5d5-5486-9f6d-d2d868ce9f6e', 'cd8545a0-4222-5179-844d-7e84db07c7b2', 0, 1),
('2c145a53-008b-5696-8f11-957cab6cd9d2', '10a89080-de59-5f60-8894-11a9d66cbc03', '4fa10f57-2733-5b56-a534-47e3463c8c75', 'a2a95af2-bf41-51d4-8a41-8e94c61a10ad', 1, 2),
('00d90ca9-8b38-5b4d-9948-ca68459936c1', '10a89080-de59-5f60-8894-11a9d66cbc03', 'a8035bac-b6be-5f66-929e-0960a36c8401', '1a7ef695-84c5-5520-a249-0b812eef988d', 2, 1),
('b61b629f-8e98-5740-abb5-77fb0a239a53', '10a89080-de59-5f60-8894-11a9d66cbc03', '0151b94d-c022-54bd-b65a-9dd19064dfc3', '852d9d62-7c3a-566b-a505-e3ae14a556aa', 3, 2),
('81cad8d1-349b-5b73-b5a3-67a47e859571', '10a89080-de59-5f60-8894-11a9d66cbc03', '16d6ec98-3c35-5d2e-a272-6188f028f58b', 'fb57d7f1-80c0-5026-8a32-01cfaae9e0fc', 4, 2),
('ec91eea8-77a8-56c0-a52c-2355e46cdfad', '10a89080-de59-5f60-8894-11a9d66cbc03', '91fafda2-8ce5-5df3-9dcd-7ce2b50dd8fa', 'b9b87123-e4ae-51af-8bb6-2664977d0cd5', 5, 2),
('a9838647-f7ae-577a-8a12-fd5c34f63e57', '10a89080-de59-5f60-8894-11a9d66cbc03', '396c021d-b45f-50ed-a30b-f29d1e4cc806', '2739bfa6-0c28-5700-bcd6-661283b17d06', 6, 3),
('6d8c6ef9-9308-55ed-8b45-64e46a0140fa', '10a89080-de59-5f60-8894-11a9d66cbc03', '64c0a9a2-a8ce-5372-939c-15154794ffd5', 'c17867cb-996f-5dba-959a-0fd1b61bdcd3', 7, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('a9bbee92-e1fd-5232-a35a-bbc6b1b98f5f', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'b9291cb7-99ee-5957-824b-9b8fb8918b66', 'Module Assessment: Design Patterns', 'assessment', 5, 25, '10a89080-de59-5f60-8894-11a9d66cbc03')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Modern Java
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('433a1b55-5834-524a-8f91-c09d34e4b80a', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Modern Java', 15)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6e0ebcd3-6ac6-563a-8c4a-a7b3cb97b22a', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '433a1b55-5834-524a-8f91-c09d34e4b80a', 'var Recap & Text Blocks', 'notes', 0, $md$Java's release cadence sped up dramatically starting with Java 9 (a new version every six months, instead of the old multi-year cycles), and a steady stream of quality-of-life features has landed since. This module tours the ones that show up constantly in modern Java code — and increasingly, in interviews expecting you to know them.

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
$md$, 15, $json$[{"id":"modern-java-var-and-text-blocks-q1","type":"mcq","correct":"b"},{"id":"modern-java-var-and-text-blocks-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b410668f-1e94-5fcc-8169-d73f4f34def3', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '433a1b55-5834-524a-8f91-c09d34e4b80a', 'Records', 'notes', 1, $md$Back in the OOP modules, giving `Task` proper encapsulation meant hand-writing a constructor, private fields, getters, and — if you wanted correct `Set`/`Map` behavior and useful debug output — `equals()`, `hashCode()`, and `toString()` too. For a class that's really just "a fixed bundle of values," that's a lot of boilerplate to write and keep in sync. **Records** (Java 16+) generate all of it for you.

## Declaring a record

```java
public class Main {
    record TaskSummary(String name, int estimateHours, String priority) {}

    public static void main(String[] args) {
        TaskSummary summary = new TaskSummary("Refactor API", 8, "HIGH");

        System.out.println(summary.name());          // accessor, not getName() — no "get" prefix
        System.out.println(summary.estimateHours());
        System.out.println(summary);                  // toString() generated automatically
    }
}
```

One line — `record TaskSummary(String name, int estimateHours, String priority) {}` — gives you:

- A **canonical constructor** taking all three components in order.
- **Accessor methods** named exactly after the components (`name()`, not `getName()`) — a deliberate departure from JavaBean convention.
- `equals()` and `hashCode()` implemented by comparing every component.
- `toString()` printing all components in a readable form (`TaskSummary[name=Refactor API, estimateHours=8, priority=HIGH]`).
- **Implicit immutability** — every component is `private final`; there are no setters, and the fields can never be reassigned after construction.

## Why immutability is the point, not a side effect

A record isn't just "a class with less typing" — it's Java's answer to "this is a value, not an entity with a lifecycle." Once constructed, a `TaskSummary` can never change; if you need an updated version, you construct a new one:

```java
public class Main {
    record TaskSummary(String name, int estimateHours, String priority) {}

    static TaskSummary withUpdatedPriority(TaskSummary original, String newPriority) {
        return new TaskSummary(original.name(), original.estimateHours(), newPriority);
    }

    public static void main(String[] args) {
        TaskSummary original = new TaskSummary("Refactor API", 8, "MEDIUM");
        TaskSummary escalated = withUpdatedPriority(original, "HIGH");

        System.out.println(original);   // unchanged
        System.out.println(escalated);  // a distinct object
    }
}
```

This is exactly the immutability discipline that makes objects safe to share across threads without `synchronized` (recall the concurrency module: most bugs there came from *mutable* shared state) — a record can never be the source of a race condition on its own fields, because there's nothing to mutate.

## Compact constructors — validating without boilerplate

You can still validate input, using a **compact constructor** that omits the parameter list (it's implied) and can only *check or transform* the components, not add new ones:

```java
public class Main {
    record TaskSummary(String name, int estimateHours) {
        TaskSummary {
            if (estimateHours < 0) {
                throw new IllegalArgumentException("estimateHours cannot be negative");
            }
            name = name.trim(); // transforming a component is allowed here
        }
    }

    public static void main(String[] args) {
        TaskSummary valid = new TaskSummary("  Deploy  ", 4);
        System.out.println(valid); // name is trimmed: "Deploy"

        try {
            new TaskSummary("Bad", -1);
        } catch (IllegalArgumentException e) {
            System.out.println("Rejected: " + e.getMessage());
        }
    }
}
```

## When NOT to use a record

Records are for **immutable data**, not every class:

- If instances need to change state over time (a `Task` whose `status` actually transitions through TODO → IN_PROGRESS → DONE as the program runs, mutated in place) — a regular class with controlled setters is the right tool, not a record.
- If the type needs to participate in a class hierarchy as a subclass — records are implicitly `final` and cannot extend another class (though they can implement interfaces).
- If you need field-level encapsulation with custom, differently-named accessors matching an existing API contract (JavaBeans-style `getName()`) — records commit to their `name()`-style accessor naming.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "modern-java-records-q1",
      "type": "mcq",
      "prompt": "What does a record automatically generate that a hand-written equivalent class would require you to write manually?",
      "options": [
        { "id": "a", "text": "A canonical constructor, component accessors, equals(), hashCode(), and toString()" },
        { "id": "b", "text": "Only a toString() method" },
        { "id": "c", "text": "A default no-argument constructor" },
        { "id": "d", "text": "Setter methods for every component" }
      ],
      "correct": "a",
      "explanation": "Records generate the constructor, per-component accessors, and value-based equals/hashCode/toString — but deliberately do NOT generate setters, since records are immutable by design."
    },
    {
      "id": "modern-java-records-q2",
      "type": "mcq",
      "prompt": "What can a compact constructor do that a canonical constructor call itself cannot skip?",
      "options": [
        { "id": "a", "text": "Add brand-new fields not declared in the record header" },
        { "id": "b", "text": "Validate or transform the declared components before they're assigned, without repeating the parameter list" },
        { "id": "c", "text": "Make the record mutable" },
        { "id": "d", "text": "Remove the auto-generated accessors" }
      ],
      "correct": "b",
      "explanation": "A compact constructor (record TaskSummary { TaskSummary { ... } }) can validate or reassign the existing components — it cannot introduce new state, since that would break the record's guarantee that its fields are exactly its declared components."
    },
    {
      "id": "modern-java-records-q3",
      "type": "mcq",
      "prompt": "Which scenario is a poor fit for a record?",
      "options": [
        { "id": "a", "text": "A DTO carrying a fixed set of fields between layers of an application" },
        { "id": "b", "text": "A Task whose status field needs to mutate in place as the task progresses through its lifecycle" },
        { "id": "c", "text": "A simple value type like a Coordinate(double x, double y)" },
        { "id": "d", "text": "A key type used in a HashMap, relying on value-based equals/hashCode" }
      ],
      "correct": "b",
      "explanation": "Records are for immutable values. An entity whose state is meant to change over time is exactly the case a regular mutable class (with controlled setters, as in the encapsulation lesson) is designed for."
    }
  ]
}
```

## What's next

Next: **sealed classes and interfaces** — restricting exactly which types are allowed to extend or implement a type, which pairs directly with the next lesson's pattern matching.
$md$, 20, $json$[{"id":"modern-java-records-q1","type":"mcq","correct":"a"},{"id":"modern-java-records-q2","type":"mcq","correct":"b"},{"id":"modern-java-records-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5131b0a5-b07b-53bd-b53a-13bb41f7cf0c', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '433a1b55-5834-524a-8f91-c09d34e4b80a', 'Sealed Classes & Interfaces', 'notes', 2, $md$An interface like `Notifiable` (from the OOP module) can be implemented by literally any class, anywhere, including ones written years later by someone who's never seen TaskFlow's code. Usually that openness is exactly what you want. Sometimes it isn't: you know, deliberately, the *complete* set of types something can be — and you want the compiler to enforce that, not just document it in a comment.

## Declaring a sealed interface

`sealed` restricts which types are allowed to implement (or extend) it, via a `permits` clause:

```java
public class Main {
    sealed interface TaskEvent permits TaskCreated, TaskCompleted, TaskCancelled {}

    record TaskCreated(String taskName) implements TaskEvent {}
    record TaskCompleted(String taskName, int actualHours) implements TaskEvent {}
    record TaskCancelled(String taskName, String reason) implements TaskEvent {}

    public static void main(String[] args) {
        TaskEvent event = new TaskCompleted("Deploy to prod", 5);
        System.out.println(event);
    }
}
```

`TaskEvent permits TaskCreated, TaskCompleted, TaskCancelled` is a closed, exhaustive list — no other class, anywhere, in any package, can implement `TaskEvent`. Records are a natural fit for the permitted types here: each event variant is just an immutable bundle of data describing what happened.

## Every permitted subtype must declare its own sealing

Each class named in `permits` must itself be exactly one of `final`, `sealed` (with its own further-restricted `permits` list), or `non-sealed` (reopening it to unrestricted extension) — Java forces you to be explicit about every level of the hierarchy rather than leaving it ambiguous:

```java
public class Main {
    sealed interface TaskEvent permits TaskCreated, TaskCompleted, TaskCancelled {}

    // final: TaskCreated cannot be extended further — the hierarchy ends here.
    record TaskCreated(String taskName) implements TaskEvent {}
    record TaskCompleted(String taskName, int actualHours) implements TaskEvent {}
    record TaskCancelled(String taskName, String reason) implements TaskEvent {}
    // (records are implicitly final, so no explicit modifier is needed above)

    public static void main(String[] args) {
        TaskEvent[] events = {
            new TaskCreated("Design schema"),
            new TaskCompleted("Design schema", 4),
            new TaskCancelled("Design schema", "Superseded by new requirements")
        };
        for (TaskEvent e : events) {
            System.out.println(e);
        }
    }
}
```

## Why seal anything? Exhaustiveness

The payoff for sealing a hierarchy shows up the moment you branch on it — covered fully in the next lesson on pattern matching, but the shape is worth previewing here:

```java
public class Main {
    sealed interface TaskEvent permits TaskCreated, TaskCompleted {}
    record TaskCreated(String taskName) implements TaskEvent {}
    record TaskCompleted(String taskName, int actualHours) implements TaskEvent {}

    static String describe(TaskEvent event) {
        // The compiler knows TaskEvent can ONLY be TaskCreated or TaskCompleted —
        // no `default` branch is needed, and if a third permitted type were added
        // later, this switch would fail to COMPILE until handled here too.
        return switch (event) {
            case TaskCreated tc -> tc.taskName() + " was created";
            case TaskCompleted tc2 -> tc2.taskName() + " finished in " + tc2.actualHours() + "h";
        };
    }

    public static void main(String[] args) {
        System.out.println(describe(new TaskCreated("Deploy to prod")));
        System.out.println(describe(new TaskCompleted("Design schema", 4)));
    }
}
```

Contrast this with a plain (unsealed) interface: a `switch` over an open interface either needs a `default` case (papering over "what if it's some type I haven't thought of") or risks a runtime surprise. Sealing turns "did I handle every case?" from a runtime risk into a compile-time guarantee — genuinely valuable for things like event types, API result types, or any "one of exactly these N things" domain concept.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "modern-java-sealed-classes-q1",
      "type": "mcq",
      "prompt": "What does the permits clause on a sealed interface do?",
      "options": [
        { "id": "a", "text": "Grants those types elevated access permissions" },
        { "id": "b", "text": "Declares the complete, closed list of types allowed to implement the interface — nothing else may" },
        { "id": "c", "text": "Lists which methods the interface requires" },
        { "id": "d", "text": "Has no runtime or compile-time effect, it's purely documentation" }
      ],
      "correct": "b",
      "explanation": "permits is enforced by the compiler — any class outside that list attempting to implement the sealed interface fails to compile."
    },
    {
      "id": "modern-java-sealed-classes-q2",
      "type": "mcq",
      "prompt": "Each type listed in a sealed interface's permits clause must itself be declared as one of which three things?",
      "options": [
        { "id": "a", "text": "public, private, or protected" },
        { "id": "b", "text": "final, sealed (with its own permits list), or non-sealed" },
        { "id": "c", "text": "static, abstract, or default" },
        { "id": "d", "text": "There is no such requirement — permitted types can be declared however you like" }
      ],
      "correct": "b",
      "explanation": "Java requires every permitted subtype to explicitly state whether the hierarchy closes there (final), continues in a further-restricted way (sealed), or reopens to unrestricted extension (non-sealed) — no ambiguity is allowed."
    },
    {
      "id": "modern-java-sealed-classes-q3",
      "type": "mcq",
      "prompt": "What compile-time benefit does sealing TaskEvent give a switch expression branching over it?",
      "options": [
        { "id": "a", "text": "The switch runs faster than over an unsealed type" },
        { "id": "b", "text": "The compiler can verify every permitted case is handled, without needing a default branch" },
        { "id": "c", "text": "It allows the switch to use string labels instead of type labels" },
        { "id": "d", "text": "It has no effect on switch expressions specifically" }
      ],
      "correct": "b",
      "explanation": "Because the full set of implementing types is closed and known at compile time, the compiler can prove a switch over all of them is exhaustive — catching a missed case as a compile error instead of a runtime gap."
    }
  ]
}
```

## What's next

The last lesson in this module puts pattern matching front and center — for both `instanceof` and `switch` — including the exhaustive switch-over-a-sealed-hierarchy pattern previewed above.
$md$, 20, $json$[{"id":"modern-java-sealed-classes-q1","type":"mcq","correct":"b"},{"id":"modern-java-sealed-classes-q2","type":"mcq","correct":"b"},{"id":"modern-java-sealed-classes-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('02e51f7b-fe7e-56a3-b5d4-08fa30991b18', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '433a1b55-5834-524a-8f91-c09d34e4b80a', 'Pattern Matching for instanceof and switch', 'notes', 3, $md$The OOP module's polymorphism lesson used `instanceof` with a manual cast to recover a subtype's specific behavior. Modern Java lets you skip the manual cast entirely — the language does it for you, safely, as part of the check itself.

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
$md$, 20, $json$[{"id":"modern-java-pattern-matching-q1","type":"mcq","correct":"b"},{"id":"modern-java-pattern-matching-q2","type":"mcq","correct":"b"},{"id":"modern-java-pattern-matching-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Testing with JUnit
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('3e88fe71-1b9a-5949-ac39-969591085ec3', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Testing with JUnit', 16)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ea814409-93e6-527e-9004-25b0622fb9f5', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3e88fe71-1b9a-5949-ac39-969591085ec3', 'Why Automated Tests Matter & JUnit 5 Basics', 'notes', 0, $md$Every TaskFlow example so far has been verified by eyeballing printed output. That works for a 20-line example. It does not work for a real codebase: once TaskFlow has dozens of classes and someone changes `TaskService`, how do you know they didn't silently break `markComplete()` while fixing something else? **Automated tests** answer that question in seconds, every time, without a human re-checking by hand.

## What a unit test actually is

A unit test calls one small piece of your code with known inputs and asserts the output is what you expect — and it either passes silently or fails loudly, with no manual inspection required. **JUnit 5** is the standard testing framework for Java.

Here's the production code being tested — a small `TaskService`:

```java
public class Main {
    static class Task {
        String name;
        boolean complete;
        Task(String name) { this.name = name; this.complete = false; }
    }

    static class TaskService {
        boolean markComplete(Task task) {
            if (task == null) {
                throw new IllegalArgumentException("task cannot be null");
            }
            task.complete = true;
            return task.complete;
        }
    }

    public static void main(String[] args) {
        Task t = new Task("Deploy to prod");
        TaskService service = new TaskService();
        System.out.println(service.markComplete(t));
        System.out.println(t.complete);
    }
}
```

**Note on this lesson's code:** the block below shows real, idiomatic JUnit 5 test code — the shape you'd actually write in a Maven/Gradle project with the `junit-jupiter` dependency (see the Build Tools module). It is *not* directly executable in this course's plain-`Main`-class code runner, since that requires a JUnit test runner, not `java Main`. Read it for the pattern, not to hit Run on it:

```java
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TaskServiceTest {

    @Test
    void markCompleteSetsTaskAsComplete() {
        Task task = new Task("Deploy to prod");
        TaskService service = new TaskService();

        boolean result = service.markComplete(task);

        assertTrue(result);
        assertTrue(task.complete);
    }

    @Test
    void markCompleteRejectsNullTask() {
        TaskService service = new TaskService();

        assertThrows(IllegalArgumentException.class, () -> service.markComplete(null));
    }
}
```

- `@Test` marks a method as a test case — JUnit discovers and runs every `@Test`-annotated method automatically.
- `assertEquals(expected, actual)`, `assertTrue(condition)`, `assertFalse(condition)` — the core assertion family; a failed assertion throws, which JUnit catches and reports as a test failure with a clear diff.
- `assertThrows(ExceptionType.class, () -> ...)` — asserts that running the given lambda throws exactly that exception type, the standard way to test error-handling paths.

## The same behavior, actually runnable here

So you still get something you can execute directly in this course, here's the identical logic verified by hand — `if` checks and a `PASS`/`FAIL` printout instead of `@Test`/`assertTrue`. This is conceptually what JUnit does under the hood, just without the framework:

```java
public class Main {
    static class Task {
        String name;
        boolean complete;
        Task(String name) { this.name = name; this.complete = false; }
    }

    static class TaskService {
        boolean markComplete(Task task) {
            if (task == null) {
                throw new IllegalArgumentException("task cannot be null");
            }
            task.complete = true;
            return task.complete;
        }
    }

    public static void main(String[] args) {
        int passed = 0, failed = 0;

        // "Test 1": markComplete sets the task as complete
        Task t = new Task("Deploy to prod");
        boolean result = new TaskService().markComplete(t);
        if (result && t.complete) {
            System.out.println("PASS: markCompleteSetsTaskAsComplete");
            passed++;
        } else {
            System.out.println("FAIL: markCompleteSetsTaskAsComplete");
            failed++;
        }

        // "Test 2": markComplete rejects a null task
        boolean threw = false;
        try {
            new TaskService().markComplete(null);
        } catch (IllegalArgumentException e) {
            threw = true;
        }
        if (threw) {
            System.out.println("PASS: markCompleteRejectsNullTask");
            passed++;
        } else {
            System.out.println("FAIL: markCompleteRejectsNullTask");
            failed++;
        }

        System.out.println(passed + " passed, " + failed + " failed");
    }
}
```

Run it — both hand-rolled checks pass. This is exactly the value JUnit automates for you at scale: instead of writing this bookkeeping (`passed++`, printing PASS/FAIL, tracking totals) by hand for every class in a real project, `@Test` + assertions + a test runner does it uniformly, with far better failure output (JUnit tells you the expected vs. actual value on failure, not just "FAIL").

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "testing-junit-junit-basics-q1",
      "type": "mcq",
      "prompt": "What does the @Test annotation do in JUnit 5?",
      "options": [
        { "id": "a", "text": "Marks a method as a test case that JUnit discovers and runs automatically" },
        { "id": "b", "text": "Marks a method as deprecated" },
        { "id": "c", "text": "Tells the compiler to skip the method" },
        { "id": "d", "text": "Runs the method only in production builds" }
      ],
      "correct": "a",
      "explanation": "JUnit scans a test class for @Test-annotated methods and executes each one independently, reporting pass/fail per method."
    },
    {
      "id": "testing-junit-junit-basics-q2",
      "type": "mcq",
      "prompt": "What does assertThrows(IllegalArgumentException.class, () -> service.markComplete(null)) verify?",
      "options": [
        { "id": "a", "text": "That markComplete(null) returns false" },
        { "id": "b", "text": "That calling markComplete(null) throws exactly an IllegalArgumentException" },
        { "id": "c", "text": "That markComplete never throws any exception" },
        { "id": "d", "text": "That the method completes within a time limit" }
      ],
      "correct": "b",
      "explanation": "assertThrows runs the given lambda and asserts it throws the specified exception type — the standard JUnit pattern for testing that error conditions are actually rejected, not silently allowed."
    },
    {
      "id": "testing-junit-junit-basics-q3",
      "type": "mcq",
      "prompt": "Why bother writing automated tests instead of just running a program and eyeballing the printed output?",
      "options": [
        { "id": "a", "text": "Eyeballing output doesn't scale — automated tests catch regressions the moment unrelated code changes, without a human re-checking by hand every time" },
        { "id": "b", "text": "Automated tests are required by the Java compiler" },
        { "id": "c", "text": "There's no real benefit, it's purely a convention" },
        { "id": "d", "text": "Tests replace the need to run the program at all" }
      ],
      "correct": "a",
      "explanation": "The core value of automated tests is repeatability at scale — they re-verify behavior instantly, every time, as a codebase grows far beyond what anyone could manually re-check on every change."
    }
  ]
}
```

## What's next

Next: structuring tests properly — setup/teardown lifecycle hooks, naming conventions, and the Arrange-Act-Assert shape that keeps a large test suite readable.
$md$, 25, $json$[{"id":"testing-junit-junit-basics-q1","type":"mcq","correct":"a"},{"id":"testing-junit-junit-basics-q2","type":"mcq","correct":"b"},{"id":"testing-junit-junit-basics-q3","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0918d80f-e1e4-50f7-a2c2-ca53a57e264c', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3e88fe71-1b9a-5949-ac39-969591085ec3', 'Test Lifecycle & Organization', 'notes', 1, $md$A handful of standalone `@Test` methods works fine for a toy example. A real test suite needs shared setup, a consistent shape per test, and a naming convention that makes a failing test's *purpose* obvious from its name alone — before you even read the assertion that failed.

**Note:** as in the previous lesson, the JUnit-specific code below is real, idiomatic test code you'd run via Maven/Gradle — not directly runnable in this course's plain-`Main` code box. Read it for the pattern.

## `@BeforeEach` and `@AfterEach`

Most test classes need the same fresh setup before every single test — and JUnit gives you a hook to avoid repeating it in every `@Test` method:

```java
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TaskServiceTest {

    private TaskService service;
    private Task task;

    @BeforeEach
    void setUp() {
        // Runs fresh before EVERY @Test method in this class — no test
        // accidentally depends on state left over from a previous one.
        service = new TaskService();
        task = new Task("Deploy to prod");
    }

    @AfterEach
    void tearDown() {
        // Runs after every test — cleanup for resources that need it
        // (closing a connection, deleting a temp file). Often empty for
        // plain in-memory objects like this one.
    }

    @Test
    void markCompleteSetsTaskAsComplete() {
        boolean result = service.markComplete(task);
        assertTrue(result);
    }

    @Test
    void markCompleteRejectsNullTask() {
        assertThrows(IllegalArgumentException.class, () -> service.markComplete(null));
    }
}
```

Without `@BeforeEach`, both tests would need to repeat `service = new TaskService(); task = new Task(...)` in their own bodies — harmless with two tests, unmaintainable with fifty. Critically, `@BeforeEach` runs **fresh for every test**, so `markCompleteSetsTaskAsComplete` mutating `task.complete` can never leak into `markCompleteRejectsNullTask` running afterward — each test gets a clean slate.

## `@DisplayName` — readable failure output

```java
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TaskServiceTest {

    @Test
    @DisplayName("marking a task complete flips its complete flag to true")
    void markCompleteSetsTaskAsComplete() {
        // ...
    }
}
```

`@DisplayName` doesn't change what the test does — it changes what shows up in test reports and IDE output when the test runs (or fails), so a teammate scanning a failing build sees a sentence describing the broken behavior instead of a bare method name.

## Arrange-Act-Assert

The internal shape of a good test, regardless of framework, follows the same three-beat structure:

```java
@Test
void markCompleteSetsTaskAsComplete() {
    // Arrange: set up the exact state this test needs
    Task task = new Task("Deploy to prod");
    TaskService service = new TaskService();

    // Act: perform the one action under test
    boolean result = service.markComplete(task);

    // Assert: verify the outcome
    assertTrue(result);
    assertTrue(task.complete);
}
```

Keeping these three phases visually separated (even just with the comments, or a blank line between them) makes a test's intent obvious at a glance, and makes it easy to spot a test that's secretly doing too much — if "Act" is five lines calling three different methods, that's a sign the test (or the code it's testing) needs to be split up.

## One test class per production class

The convention that scales: `TaskService` gets `TaskServiceTest`, `TaskRepository` gets `TaskRepositoryTest`, and so on — a 1:1 mapping that means anyone can find a class's tests immediately, and a test file never becomes an unfocused grab-bag testing five unrelated classes at once. Individual test method names should read like a sentence describing the specific behavior under test — `markCompleteSetsTaskAsComplete` and `markCompleteRejectsNullTask`, not `test1` and `test2` — since a failing test's *name* is often the first (and sometimes only) thing a teammate reads in a CI failure notification.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "testing-junit-lifecycle-and-organization-q1",
      "type": "mcq",
      "prompt": "Why does @BeforeEach run before EVERY test method, rather than once per class?",
      "options": [
        { "id": "a", "text": "So each test starts from the same clean, predictable state, and no test can accidentally depend on leftover state from a previous test" },
        { "id": "b", "text": "It's a JUnit performance optimization with no behavioral purpose" },
        { "id": "c", "text": "Because JUnit requires it for the test class to compile" },
        { "id": "d", "text": "So all tests share exactly one Task instance" }
      ],
      "correct": "a",
      "explanation": "Fresh setup per test prevents test-order dependencies — a classic source of flaky test suites where a test only passes if another test happened to run first."
    },
    {
      "id": "testing-junit-lifecycle-and-organization-q2",
      "type": "mcq",
      "prompt": "What is the purpose of the Arrange-Act-Assert structure inside a test method?",
      "options": [
        { "id": "a", "text": "It's required syntax that JUnit enforces at compile time" },
        { "id": "b", "text": "It keeps a test's setup, the action under test, and the verification visually and logically separated, making its intent clear at a glance" },
        { "id": "c", "text": "It determines the order tests run in across a class" },
        { "id": "d", "text": "It replaces the need for assertions" }
      ],
      "correct": "b",
      "explanation": "Arrange-Act-Assert is a convention, not a language feature — but a strong one, since it keeps every test readable and makes tests doing 'too much' easy to spot."
    },
    {
      "id": "testing-junit-lifecycle-and-organization-q3",
      "type": "mcq",
      "prompt": "Why prefer a test name like markCompleteRejectsNullTask over test2?",
      "options": [
        { "id": "a", "text": "JUnit runs alphabetically-named tests faster" },
        { "id": "b", "text": "A descriptive name documents the exact behavior under test, which is often the first thing a teammate reads when a test fails in CI" },
        { "id": "c", "text": "There's no real difference — either is equally good practice" },
        { "id": "d", "text": "Numbered test names are required for @BeforeEach to work" }
      ],
      "correct": "b",
      "explanation": "A descriptive test method name is effectively free documentation — it tells a reader (or a CI failure notification) exactly what broke, without needing to open the method body first."
    }
  ]
}
```

## What's next

The last lesson in this module covers **mocking** — what to do when the class you're testing depends on something you don't want a unit test to actually touch, like a real email service.
$md$, 20, $json$[{"id":"testing-junit-lifecycle-and-organization-q1","type":"mcq","correct":"a"},{"id":"testing-junit-lifecycle-and-organization-q2","type":"mcq","correct":"b"},{"id":"testing-junit-lifecycle-and-organization-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1bb1a723-bd72-5b33-8579-bf16b56d4a27', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '3e88fe71-1b9a-5949-ac39-969591085ec3', 'The Idea of Mocking', 'notes', 2, $md$Suppose `TaskService.markComplete(...)` should also send a notification email when a task finishes. Testing that directly means either actually sending an email every time the test suite runs (slow, unreliable, and genuinely emails someone every CI run), or finding another way to verify "the service *tried* to notify" without a real email service in the loop. That's the problem mocking solves.

## The dependency problem

```java
public class Main {
    interface NotificationService {
        void sendTaskCompleteNotification(String taskName);
    }

    static class RealEmailNotificationService implements NotificationService {
        public void sendTaskCompleteNotification(String taskName) {
            // In real code: connects to an SMTP server and sends an actual email.
            System.out.println("Sending real email for: " + taskName);
        }
    }

    static class TaskService {
        private final NotificationService notifications;
        TaskService(NotificationService notifications) {
            this.notifications = notifications;
        }
        void markComplete(String taskName) {
            notifications.sendTaskCompleteNotification(taskName);
        }
    }

    public static void main(String[] args) {
        TaskService service = new TaskService(new RealEmailNotificationService());
        service.markComplete("Deploy to prod"); // would send a real email in production
    }
}
```

`TaskService` depends on `NotificationService` through the **interface**, not a concrete email class directly — this is exactly the "program to an interface" principle from the OOP and design-patterns modules, and it's what makes the dependency swappable at all. A class that directly `new`s a concrete `RealEmailNotificationService` inside itself would have no seam to substitute anything at test time.

## A hand-rolled fake

Because `TaskService` depends on the `NotificationService` interface, a test can hand it a completely different implementation — one that just *records* what it was asked to do instead of actually doing it:

```java
public class Main {
    interface NotificationService {
        void sendTaskCompleteNotification(String taskName);
    }

    static class TaskService {
        private final NotificationService notifications;
        TaskService(NotificationService notifications) {
            this.notifications = notifications;
        }
        void markComplete(String taskName) {
            notifications.sendTaskCompleteNotification(taskName);
        }
    }

    // A fake used only in tests: implements the same interface, but records
    // calls instead of sending anything real. No network, no SMTP, no
    // side effects outside this object's own memory.
    static class FakeNotificationService implements NotificationService {
        java.util.List<String> notifiedTasks = new java.util.ArrayList<>();

        public void sendTaskCompleteNotification(String taskName) {
            notifiedTasks.add(taskName);
        }
    }

    public static void main(String[] args) {
        FakeNotificationService fake = new FakeNotificationService();
        TaskService service = new TaskService(fake);

        service.markComplete("Deploy to prod");

        // Verify the service TRIED to notify, without sending a real email:
        boolean notified = fake.notifiedTasks.contains("Deploy to prod");
        System.out.println("Notified: " + notified);
    }
}
```

Run it — the fake proves `markComplete` reached out to notify, entirely in-memory, in milliseconds, with zero real emails sent. This hand-rolled `FakeNotificationService` *is* a mock, conceptually — it just doesn't use a mocking library to generate itself.

## Why not just use the real thing in tests?

- **Speed**: a real email/network/database call is orders of magnitude slower than an in-memory fake — multiply that by thousands of tests in a CI pipeline.
- **Reliability**: a test that depends on a real external service fails whenever that service is slow, down, or rate-limits you — for reasons that have nothing to do with whether your code is actually correct.
- **Side effects**: you don't want "run the test suite" to mean "send real emails to real people," charge a real payment API, or write to a real production database.
- **Isolation**: a unit test for `TaskService` should fail only when `TaskService`'s own logic is wrong — not when an unrelated email server happens to be down. That's what makes it a *unit* test rather than an integration test.

## Mocking libraries (the concept, not the syntax)

In a real Maven/Gradle project, you'd typically reach for a library like **Mockito** instead of hand-writing a `Fake*` class for every dependency — it generates fakes on the fly and lets you assert things like "was `sendTaskCompleteNotification` called exactly once, with this argument?" without writing a recording list by hand. The library-generated version and the hand-rolled `FakeNotificationService` above solve the *exact same problem*; Mockito is just less boilerplate once you have many dependencies to fake across many tests. Understanding the hand-rolled version first is what makes the library version make sense — it's the same idea with the bookkeeping automated.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "testing-junit-mocking-concept-q1",
      "type": "mcq",
      "prompt": "Why does TaskService depending on a NotificationService interface (rather than a concrete email class) matter for testing?",
      "options": [
        { "id": "a", "text": "It doesn't matter — interfaces have no effect on testability" },
        { "id": "b", "text": "It creates a seam: a test can substitute a fake implementation without changing TaskService's code at all" },
        { "id": "c", "text": "Interfaces make code run faster at runtime" },
        { "id": "d", "text": "It's only relevant for classes with more than one method" }
      ],
      "correct": "b",
      "explanation": "Depending on an interface rather than a concrete class is exactly what allows a test to inject a fake — this is the same 'program to an interface' principle the OOP and design-patterns modules covered, applied specifically to testability."
    },
    {
      "id": "testing-junit-mocking-concept-q2",
      "type": "mcq",
      "prompt": "What is the main reason to avoid hitting a real email/network service inside a unit test?",
      "options": [
        { "id": "a", "text": "Real services are always broken" },
        { "id": "b", "text": "Speed, reliability, avoiding real side effects, and keeping the test's pass/fail tied only to the code actually under test — not an unrelated external system" },
        { "id": "c", "text": "Unit tests are technically forbidden from calling any method at all" },
        { "id": "d", "text": "There's no real reason — it's purely a style preference" }
      ],
      "correct": "b",
      "explanation": "A slow, flaky, or side-effecting dependency in a unit test undermines the whole point of testing: fast, reliable, isolated verification of one unit's own logic."
    },
    {
      "id": "testing-junit-mocking-concept-q3",
      "type": "mcq",
      "prompt": "What does a mocking library like Mockito fundamentally provide, compared to hand-writing a Fake* class?",
      "options": [
        { "id": "a", "text": "A completely different concept unrelated to fakes" },
        { "id": "b", "text": "The same underlying idea — a substitutable implementation for tests — generated automatically instead of hand-written, reducing boilerplate as the number of dependencies grows" },
        { "id": "c", "text": "It removes the need for interfaces" },
        { "id": "d", "text": "It only works with database dependencies" }
      ],
      "correct": "b",
      "explanation": "Mocking libraries automate exactly what a hand-rolled fake does manually: substituting a dependency and recording/verifying how it was used, at scale, without writing a new Fake* class for every dependency in every test."
    }
  ]
}
```

## What's next

That closes out testing. The final content module, **Build Tools**, covers how a real TaskFlow project — with JUnit, and every other dependency this course has touched — actually gets built, packaged, and its dependencies managed via Maven and Gradle.
$md$, 20, $json$[{"id":"testing-junit-mocking-concept-q1","type":"mcq","correct":"b"},{"id":"testing-junit-mocking-concept-q2","type":"mcq","correct":"b"},{"id":"testing-junit-mocking-concept-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Build Tools
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('c4610163-c54b-59ff-b444-e4eeabab4e60', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Build Tools', 17)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('33a657b6-561a-5a7f-a1c7-b617de304e57', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c4610163-c54b-59ff-b444-e4eeabab4e60', 'Maven Basics', 'notes', 0, $md$Every real Java project — including TaskFlow — needs a way to declare its dependencies, compile consistently across machines, run its tests, and package itself into something deployable. So far in this course, every code box has been a single self-contained file with no dependencies. **Maven** is one of the two dominant tools (Gradle is the other, next lesson) that solves the "how do I build a multi-file, multi-dependency Java project the same way every time" problem.

Maven is **declarative**: you describe *what* your project needs — its dependencies, its packaging type, its plugins — in an XML file called `pom.xml` ("Project Object Model"), and Maven figures out *how* to actually run the build by following a fixed, standardized lifecycle.

## The standard directory layout

Maven has a strong opinion about where your files live, and following it means zero configuration is needed to tell Maven where to find anything:

```
taskflow/
├── pom.xml
└── src/
    ├── main/
    │   ├── java/          ← your application source code
    │   │   └── com/taskflow/...
    │   └── resources/     ← non-code files bundled into the build (config, templates)
    └── test/
        ├── java/          ← test source code (JUnit tests, mirrors main/java's package structure)
        └── resources/     ← test-only resources
```

This is often called "convention over configuration." A newcomer to any Maven project — including a future contributor to TaskFlow — already knows where to find the code without reading a build script, because every Maven project everywhere is laid out identically.

## A minimal `pom.xml`

This is a realistic minimal `pom.xml` for TaskFlow. It is **not runnable in this course's Java code runner** — `pom.xml` is a build configuration file, not a Java program; it only means something when the `mvn` command line tool reads it against a real project directory on disk:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                              http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.taskflow</groupId>
    <artifactId>taskflow-core</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>21</maven.compiler.source>
        <maven.compiler.target>21</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>5.10.2</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.13.0</version>
            </plugin>
        </plugins>
    </build>
</project>
```

Breaking down the sections:

- **`groupId` / `artifactId` / `version`** — together, the "GAV coordinates" that uniquely identify this project (or any dependency of it) inside Maven's dependency ecosystem. `groupId` is typically your reversed domain (`com.taskflow`), `artifactId` is the specific module name.
- **`<dependencies>`** — every library the project needs, each identified by its own GAV coordinates. Maven downloads these automatically from a remote repository (Maven Central, by default) into a local cache (`~/.m2/repository`) the first time you build, then reuses the cache afterward.
- **`<build><plugins>`** — plugins extend what the build *does*. The compiler plugin here controls which Java language level `javac` compiles against; other common plugins package a runnable "fat jar," run static analysis, or generate code.

## The build lifecycle

Maven's lifecycle is a fixed, ordered sequence of **phases**. Running any phase runs every phase before it too:

```
validate → compile → test → package → install → deploy
```

| Phase | What happens |
|---|---|
| `validate` | Checks the project structure and `pom.xml` are well-formed |
| `compile` | Compiles `src/main/java` into `.class` files |
| `test` | Compiles and runs `src/test/java` against the compiled main code |
| `package` | Bundles compiled classes and resources into a `.jar` (or `.war`) |
| `install` | Copies the packaged artifact into your local `~/.m2` repository, so other local projects can depend on it |
| `deploy` | Uploads the artifact to a shared remote repository for other teams/machines to use |

Because the phases are ordered and cumulative, running `mvn package` first silently runs `validate`, `compile`, and `test` for you — you never invoke earlier phases separately unless you specifically want to stop there.

## The commands you'll actually type

- **`mvn compile`** — compiles main source only, stops there. Good for a fast "does this even compile" check.
- **`mvn test`** — compiles main and test source, then runs every test. This is what you run constantly while developing.
- **`mvn package`** — runs everything through `test`, then produces the final `.jar` in `target/`.
- **`mvn clean`** — deletes the `target/` directory (Maven's build output folder), often chained as `mvn clean package` to guarantee a fresh build with no stale `.class` files left over from a previous run.

If a TaskFlow contributor changes a class and its tests suddenly fail, `mvn test` is the one command that reproduces exactly what continuous integration will see — that consistency, more than any individual feature, is the real reason teams standardize on a build tool instead of everyone compiling by hand with `javac`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "build-tools-maven-basics-q1",
      "type": "mcq",
      "prompt": "In Maven's standard directory layout, where does application (non-test) source code live?",
      "options": [
        { "id": "a", "text": "src/java" },
        { "id": "b", "text": "src/main/java" },
        { "id": "c", "text": "java/src/main" },
        { "id": "d", "text": "main/src" }
      ],
      "correct": "b",
      "explanation": "Maven's convention-over-configuration layout puts application source under src/main/java, resources under src/main/resources, and test code under the parallel src/test/java and src/test/resources."
    },
    {
      "id": "build-tools-maven-basics-q2",
      "type": "mcq",
      "prompt": "If you run `mvn package`, which lifecycle phases also run before it, in order?",
      "options": [
        { "id": "a", "text": "None — package runs in isolation" },
        { "id": "b", "text": "Only test" },
        { "id": "c", "text": "validate, compile, and test" },
        { "id": "d", "text": "install and deploy, then package last" }
      ],
      "correct": "c",
      "explanation": "Maven's lifecycle phases are ordered and cumulative: validate, compile, test, package, install, deploy. Invoking package runs every phase before it — validate, compile, test — automatically."
    },
    {
      "id": "build-tools-maven-basics-q3",
      "type": "mcq",
      "prompt": "What identifies a specific dependency (or your own project) uniquely within Maven's ecosystem?",
      "options": [
        { "id": "a", "text": "The file name of the pom.xml" },
        { "id": "b", "text": "Its GAV coordinates: groupId, artifactId, and version" },
        { "id": "c", "text": "The order it appears in <dependencies>" },
        { "id": "d", "text": "The plugin section of the pom.xml" }
      ],
      "correct": "b",
      "explanation": "groupId, artifactId, and version together (often shorthanded \"GAV\") uniquely identify an artifact in a Maven repository — this is how Maven knows exactly which jar to fetch and cache."
    }
  ]
}
```

## What's next

Maven isn't the only build tool in wide use — the next lesson covers **Gradle**, which solves the same problems with a different philosophy: a build *script* instead of a declarative XML document.
$md$, 25, $json$[{"id":"build-tools-maven-basics-q1","type":"mcq","correct":"b"},{"id":"build-tools-maven-basics-q2","type":"mcq","correct":"c"},{"id":"build-tools-maven-basics-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1af31567-2a46-5857-92c3-db920145e73a', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c4610163-c54b-59ff-b444-e4eeabab4e60', 'Gradle Basics', 'notes', 1, $md$**Gradle** solves the same problem as Maven — reproducible dependency management, compilation, testing, and packaging — but with a different core idea: instead of a declarative XML document that a fixed engine interprets, a Gradle build script is written in a real programming language (Groovy or Kotlin) and executed directly. This lesson uses the **Groovy DSL** (`build.gradle`), the older and still extremely common option; Gradle also supports a Kotlin DSL (`build.gradle.kts`) with the same structure but Kotlin syntax.

## A minimal `build.gradle`

Same dependency and plugin setup as the Maven `pom.xml` from the previous lesson, expressed as a Gradle build script. Like `pom.xml`, this is **not runnable in this course's Java code runner** — it's a build script meant for the `gradle`/`gradlew` command line tool against a real project on disk, not a Java program:

```groovy
plugins {
    id 'java'
}

group = 'com.taskflow'
version = '1.0.0'

repositories {
    mavenCentral()
}

dependencies {
    testImplementation 'org.junit.jupiter:junit-jupiter:5.10.2'
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

test {
    useJUnitPlatform()
}
```

Compare this to the Maven `pom.xml`: `plugins { id 'java' }` plays the same role as Maven's `<packaging>jar</packaging>` plus the compiler plugin — it tells Gradle "this is a Java project, wire up compile/test/jar tasks automatically." `repositories { mavenCentral() }` says where to fetch dependencies from (Gradle doesn't assume Maven Central by default the way Maven does — you declare it explicitly). `testImplementation` is Gradle's equivalent of Maven's `<scope>test</scope>` — a dependency needed only to compile and run tests, not shipped with the main application.

Gradle also uses the same standard `src/main/java`, `src/main/resources`, `src/test/java` layout as Maven by default (via the `java` plugin) — that convention isn't a Maven-only thing, it's shared enough between the two tools that switching between projects doesn't mean relearning where files live.

## Why teams choose Gradle over Maven (or vice versa)

- **Build script as code vs. declarative XML.** Maven's `pom.xml` can only do what the XML schema and installed plugins allow — anything conditional or dynamic needs a plugin. Gradle's `build.gradle` is Groovy (or Kotlin) code: you can write an `if` statement, a loop, or a custom task directly in the build file. This is a genuine tradeoff, not a strict upgrade — the flexibility that makes complex builds easier also makes a build script easier to make inconsistent or hard to reason about across a large team, which is part of why some organizations deliberately prefer Maven's rigidity.
- **Incremental builds.** Gradle tracks inputs and outputs of every task (compile, test, etc.) and skips a task entirely if nothing relevant changed since the last run — re-running `gradle build` right after a successful build with no code changes finishes almost instantly. Maven's lifecycle model doesn't have this built in the same way; it recompiles more eagerly.
- **Performance at scale.** Gradle's daemon process stays warm between builds (avoiding JVM startup cost every invocation), and it can build independent modules of a multi-module project in parallel. This matters most on large projects with many modules — for a single small project like early TaskFlow, the practical difference is minor.
- **Maven's advantage is convention and predictability.** Because every `pom.xml` follows the same rigid shape, a Maven project is often faster for a newcomer to understand at a glance, and there's less room for one team's build script to diverge in surprising ways from another's.

Neither tool is "correct" — plenty of production Java codebases use each. What matters for you as a developer is recognizing both shapes on sight, since you'll encounter both across different jobs and open-source projects.

## The commands you'll actually type

Gradle projects ship with a **wrapper** — `gradlew` (Linux/macOS) and `gradlew.bat` (Windows) — a small script checked into the project that downloads and runs the exact Gradle version the project was built with, so nobody needs Gradle pre-installed globally or fights a version mismatch. You almost always run the wrapper, not a bare `gradle` command:

- **`./gradlew build`** — compiles, runs tests, and packages the project, roughly the Gradle equivalent of Maven's `mvn package` (it also runs additional checks by default).
- **`./gradlew test`** — compiles and runs tests only, without producing the final package.
- **`./gradlew clean`** — deletes the build output directory (`build/`, Gradle's equivalent of Maven's `target/`), often chained as `./gradlew clean build`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "build-tools-gradle-basics-q1",
      "type": "mcq",
      "prompt": "What is the fundamental difference between a Gradle build.gradle file and a Maven pom.xml?",
      "options": [
        { "id": "a", "text": "There is no real difference — they use identical syntax" },
        { "id": "b", "text": "build.gradle is executable code (Groovy or Kotlin); pom.xml is declarative XML interpreted by a fixed engine" },
        { "id": "c", "text": "pom.xml supports dependencies, build.gradle does not" },
        { "id": "d", "text": "Gradle projects cannot have a src/main/java layout" }
      ],
      "correct": "b",
      "explanation": "Maven's pom.xml is declarative data that Maven's engine interprets; Gradle's build.gradle is an actual script written in Groovy or Kotlin, giving it more programmatic flexibility at the cost of being less uniformly predictable across projects."
    },
    {
      "id": "build-tools-gradle-basics-q2",
      "type": "mcq",
      "prompt": "What does testImplementation in a Gradle build.gradle correspond to in a Maven pom.xml?",
      "options": [
        { "id": "a", "text": "A <plugin> entry" },
        { "id": "b", "text": "A dependency with <scope>test</scope>" },
        { "id": "c", "text": "The <packaging> element" },
        { "id": "d", "text": "The maven-compiler-plugin" }
      ],
      "correct": "b",
      "explanation": "testImplementation marks a dependency as needed only for compiling and running tests, not the main application — the same role Maven's <scope>test</scope> plays."
    },
    {
      "id": "build-tools-gradle-basics-q3",
      "type": "mcq",
      "prompt": "Why do Gradle projects typically run `./gradlew build` rather than a bare `gradle build`?",
      "options": [
        { "id": "a", "text": "gradlew is required because gradle does not exist as a command" },
        { "id": "b", "text": "The wrapper script (gradlew) downloads and runs the exact Gradle version the project expects, so contributors don't need a matching global install" },
        { "id": "c", "text": "gradlew runs faster because it skips tests" },
        { "id": "d", "text": "gradlew is only used on Windows" }
      ],
      "correct": "b",
      "explanation": "The Gradle wrapper is checked into the project and pins the exact Gradle version, avoiding \"works on my machine\" version mismatches — this is why ./gradlew, not a globally installed gradle, is the standard way to build."
    }
  ]
}
```

## What's next

With both major build tools covered, the last lesson in this module looks at what actually goes wrong as a project's dependency list and package structure grow — dependency conflicts, scopes, and how TaskFlow should organize its packages as it scales past a handful of classes.
$md$, 25, $json$[{"id":"build-tools-gradle-basics-q1","type":"mcq","correct":"b"},{"id":"build-tools-gradle-basics-q2","type":"mcq","correct":"b"},{"id":"build-tools-gradle-basics-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('911eacab-3514-5ab4-b3ba-8efb86962521', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c4610163-c54b-59ff-b444-e4eeabab4e60', 'Dependency Management & Project Structure', 'notes', 2, $md$Declaring a dependency in `pom.xml` or `build.gradle` is the easy part. The harder part — the part that actually causes real production incidents — is what happens once a project has dozens of dependencies that depend on *other* dependencies, and two of them disagree about which version of a shared library they need.

## Semantic versioning

Most Java libraries version themselves using **semantic versioning**: `MAJOR.MINOR.PATCH`, e.g. `5.10.2`.

- **MAJOR** bumps signal breaking API changes — upgrading from `4.x` to `5.x` might require code changes on your end.
- **MINOR** bumps add functionality in a backward-compatible way — `5.9.0` to `5.10.0` should be a safe upgrade.
- **PATCH** bumps are bug fixes only, no API changes — `5.10.1` to `5.10.2` should always be safe to take.

This convention is what makes it reasonable to pin a dependency to a specific version in `pom.xml`/`build.gradle` rather than always grabbing "latest": you can reason about the risk of an upgrade just from the version number changing, without reading a changelog line by line every time.

## Transitive dependencies and "dependency hell"

When TaskFlow declares a dependency on some library, it doesn't just get that library — it also gets everything *that* library depends on, recursively. These are **transitive dependencies**, and you never write them down explicitly; the build tool resolves the whole tree for you.

The problem arises when two of your direct dependencies transitively require *different, incompatible* versions of the same shared library — classically nicknamed **"dependency hell" or "diamond dependency conflict."** Picture it as a diamond shape:

```
        TaskFlow
        /      \
   LibraryA   LibraryB
       \        /
     CommonLib
   (A wants 2.x, B wants 3.x)
```

Both Maven and Gradle resolve this automatically rather than failing the build outright, but they do it differently:

- **Maven** uses "nearest wins": whichever version is *closest* to your project in the dependency tree (fewest hops away) is selected. If two versions are the same distance, the one declared first in the `pom.xml` wins.
- **Gradle** uses "highest wins" by default: among all the versions requested anywhere in the tree, the newest one is selected.

Neither strategy guarantees the chosen version is actually compatible with every dependency that wanted a different one — that's the "hell" part. Both tools let you inspect the resolved tree (`mvn dependency:tree`, `./gradlew dependencies`) and force a specific version explicitly when the automatic choice causes a runtime error like `NoSuchMethodError` — a classic symptom of code compiled against one version of a library running against a different, incompatible version actually on the classpath at runtime.

## Separating main and test dependencies

Not every dependency belongs in your shipped application. A testing framework like JUnit, or a mocking library like Mockito, is essential *while developing* but has no business being bundled into the `.jar` that actually runs in production — it would bloat the artifact and could even introduce security-relevant code paths nobody intended to ship.

Both tools model this with a concept that controls which dependencies apply where:

| Concept | Maven | Gradle |
|---|---|---|
| Name | `scope` | `configuration` |
| Main app code | `compile` (the default — no `<scope>` needed) | `implementation` |
| Test-only code | `test` | `testImplementation` |

This is exactly the `<scope>test</scope>` and `testImplementation` you saw in the `pom.xml` and `build.gradle` examples in the previous two lessons — now you know *why* that distinction exists: it's the build tool's way of guaranteeing JUnit never ends up in TaskFlow's production jar.

## Why package structure matters as TaskFlow grows

A build tool resolves *external* dependencies, but a project also needs internal organization — how you split your own code into packages. A single flat package with every class in it works fine for a course exercise; it breaks down fast in a real application, because nothing stops a web-layer class from directly manipulating database internals, and nothing signals to a new contributor where a given piece of logic is supposed to live.

The conventional fix is to organize packages by **architectural layer**, matching how data flows through the application:

```
com.taskflow.core       ← domain objects: Task, User, Project, Team — no framework dependencies
com.taskflow.service     ← business logic: TaskService, ProjectService — orchestrates core objects
com.taskflow.web          ← HTTP layer: controllers/handlers that call into service, never into core directly
```

This is a complete, runnable illustration of the *idea* — a `Task` domain object with no framework dependencies, and a service that operates on it, mirroring how `com.taskflow.core` and `com.taskflow.service` would be split into separate files/packages in a real multi-file project:

```java
public class Main {

    // Represents what would live in com.taskflow.core in a real project
    static class Task {
        private final String name;
        private boolean complete;

        Task(String name) {
            this.name = name;
            this.complete = false;
        }

        String getName() {
            return name;
        }

        boolean isComplete() {
            return complete;
        }

        void markComplete() {
            this.complete = true;
        }
    }

    // Represents what would live in com.taskflow.service in a real project
    static class TaskService {
        void completeTask(Task task) {
            task.markComplete();
            System.out.println("Completed: " + task.getName());
        }
    }

    public static void main(String[] args) {
        Task task = new Task("Set up Maven build");
        TaskService service = new TaskService();

        service.completeTask(task);
        System.out.println("Is complete: " + task.isComplete());
    }
}
```

The value isn't visible in a five-class toy example — it's visible six months and forty classes later, when a new contributor needs to find "where does task-completion logic live" and the package name answers the question before they open a single file. Consistent layering also makes dependency direction enforceable: `core` should never import from `web`, and a codebase that violates that consistently is a strong early signal of design trouble, long before it becomes an unmaintainable mess.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "build-tools-dependency-management-q1",
      "type": "mcq",
      "prompt": "Under semantic versioning (MAJOR.MINOR.PATCH), which kind of version bump signals a breaking API change?",
      "options": [
        { "id": "a", "text": "PATCH" },
        { "id": "b", "text": "MINOR" },
        { "id": "c", "text": "MAJOR" },
        { "id": "d", "text": "None — semantic versioning never signals breaking changes" }
      ],
      "correct": "c",
      "explanation": "MAJOR version bumps indicate breaking changes; MINOR adds backward-compatible functionality; PATCH is bug fixes only with no API changes."
    },
    {
      "id": "build-tools-dependency-management-q2",
      "type": "mcq",
      "prompt": "Two of TaskFlow's dependencies transitively require different versions of the same shared library. How does Maven resolve this by default?",
      "options": [
        { "id": "a", "text": "It fails the build immediately and refuses to compile" },
        { "id": "b", "text": "It selects the version declared nearest to your project in the dependency tree (\"nearest wins\")" },
        { "id": "c", "text": "It always picks the highest version number available" },
        { "id": "d", "text": "It downloads both versions and lets the JVM choose at runtime" }
      ],
      "correct": "b",
      "explanation": "Maven's default conflict resolution is \"nearest wins\" — the version closest to your project in the dependency graph is selected, with declaration order as a tiebreaker at equal distance. Gradle instead defaults to \"highest wins.\""
    },
    {
      "id": "build-tools-dependency-management-q3",
      "type": "mcq",
      "prompt": "Why is JUnit typically declared with test scope (Maven) or as testImplementation (Gradle) rather than a plain/main dependency?",
      "options": [
        { "id": "a", "text": "Test scope dependencies compile faster than main-scope ones" },
        { "id": "b", "text": "It keeps JUnit out of the packaged production artifact, since it's only needed while developing and running tests" },
        { "id": "c", "text": "JUnit cannot be declared as a main dependency at all" },
        { "id": "d", "text": "It has no real effect — scope is purely documentation" }
      ],
      "correct": "b",
      "explanation": "Test-scoped dependencies are available for compiling and running tests but are excluded from the final packaged artifact, keeping testing/mocking libraries out of what actually ships to production."
    }
  ]
}
```

## What's next

That's the full build-tools picture: how Maven and Gradle structure a project, run through their lifecycle, and manage dependencies. From here, the course moves into its final module — **interview-ready** — pulling every topic you've learned across the whole course, including this one, into the kind of theory questions you'll actually be asked.
$md$, 25, $json$[{"id":"build-tools-dependency-management-q1","type":"mcq","correct":"c"},{"id":"build-tools-dependency-management-q2","type":"mcq","correct":"b"},{"id":"build-tools-dependency-management-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Interview Ready
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('c34f1e45-8786-58ed-afcf-af84b44f06c8', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'Interview Ready', 18)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('20004b02-61ea-55cb-b905-a497fea6507c', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c34f1e45-8786-58ed-afcf-af84b44f06c8', 'Core Language & OOP Theory', 'notes', 0, $md$You've written TaskFlow's core objects, wired up inheritance and interfaces, and handled exceptions across earlier modules. This module assumes all of that and does something different with it: it drills the exact questions interviewers ask about those same topics, with the full reasoning behind each answer — not just the one-line fact, but *why* it's true and what follow-up an interviewer typically asks next. Five lessons, one theme each, all still built on TaskFlow.

## "What's the difference between `==` and `.equals()`?"

This is close to the single most-asked Java question there is, and the reason it keeps getting asked is that a shallow answer ("`==` checks equality, `.equals()` also checks equality") misses the actual point.

`==` on object references compares **identity** — are these two variables pointing at the exact same object in memory? `.equals()`, by contrast, is a regular method, inherited from `Object`, and its default implementation *also* just does `==` — unless a class overrides it to compare something else, like field-by-field content.

```java
public class Main {
    static class Task {
        private final String name;

        Task(String name) {
            this.name = name;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) return true;
            if (!(other instanceof Task)) return false;
            Task task = (Task) other;
            return name.equals(task.name);
        }
    }

    public static void main(String[] args) {
        Task a = new Task("Design database schema");
        Task b = new Task("Design database schema");

        System.out.println(a == b);        // false — two different objects on the heap
        System.out.println(a.equals(b));   // true — Task overrides equals() to compare content

        String s1 = "Deploy";
        String s2 = "Deploy";
        System.out.println(s1 == s2);      // true — string literals are interned, same pooled object
    }
}
```

The `String` case at the bottom is the classic trap: `s1 == s2` prints `true` for two `String` **literals** because of string interning (more on that below), which leads beginners to believe `==` works fine on `String`s — until they compare a literal against a `new String("Deploy")` or a value built with concatenation at runtime, where `==` reliably breaks. The rule to say out loud: **always use `.equals()` to compare object content, `==` only when you genuinely mean "is this the same object."**

## "If you override `equals()`, why do you also need to override `hashCode()`?"

This is the natural follow-up, and it trips people up because the connection isn't obvious from the method signatures alone. The contract, straight from `Object`'s Javadoc, is: **if two objects are equal according to `.equals()`, they must return the same value from `.hashCode()`.** Nothing requires the reverse — unequal objects *can* share a hash code (a "collision," which hash-based collections are built to handle) — but equal objects sharing different hash codes breaks things silently.

Here's the concrete failure. `HashSet` and `HashMap` use `hashCode()` first to pick a bucket, then `equals()` only to compare against other entries *already in that bucket*:

```java
import java.util.HashSet;
import java.util.Objects;

public class Main {
    static class Task {
        private final String name;

        Task(String name) {
            this.name = name;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) return true;
            if (!(other instanceof Task)) return false;
            return name.equals(((Task) other).name);
        }

        // Deliberately omitted in the broken version — see the comment below.
        @Override
        public int hashCode() {
            return Objects.hash(name);
        }
    }

    public static void main(String[] args) {
        HashSet<Task> seen = new HashSet<>();
        seen.add(new Task("Design database schema"));

        boolean containsDuplicate = seen.contains(new Task("Design database schema"));
        System.out.println("Duplicate detected: " + containsDuplicate); // true, with hashCode() overridden correctly
    }
}
```

With `hashCode()` overridden consistently with `equals()` (both based on `name`), the second `Task` lands in the *same bucket* as the first, `equals()` confirms they match, and `contains()` correctly reports `true`. Delete the `hashCode()` override and the two logically-equal `Task` objects fall into different (essentially random, identity-based) buckets — `contains()` would report `false` even though `.equals()` would say `true` if you called it directly. That's the bug: silently broken deduplication, with no compiler warning, because nothing *requires* you to override `hashCode()` alongside `equals()` — it's a contract enforced by convention and by every hash-based collection's behavior, not by the compiler.

## Abstract class vs. interface — going deeper

You've seen both in the OOP module; the interview version of this question wants you to articulate the decision, not just the syntax difference. Three angles worth having ready:

1. **State.** An abstract class can hold instance fields and constructors — shared, mutable state that every subclass inherits. An interface (even with default methods) fundamentally cannot hold instance state; it can only declare behavior.
2. **Multiple inheritance.** A Java class can implement any number of interfaces but extend only one class. If TaskFlow needs a `Task` to be both `Comparable<Task>` and `Serializable` and `Auditable`, those must be interfaces — a class literally cannot extend more than one superclass.
3. **The real decision rule:** ask "is this an *is-a* relationship with shared implementation and state?" — use an abstract class (a `RecurringTask extends Task` sharing `name`, `id`, and completion logic). Ask "is this a *capability* that unrelated classes might all support?" — use an interface (`Comparable<Task>`, `Auditable` — a `Task`, a `Project`, and a `User` might all be `Auditable` despite sharing no inheritance relationship at all).

```java
public class Main {
    interface Auditable {
        String auditSummary(); // capability: "can produce an audit trail entry"
    }

    static abstract class Task implements Auditable {
        protected final String name; // shared state

        Task(String name) {
            this.name = name;
        }

        abstract boolean isOverdue(); // subclasses must define this differently

        @Override
        public String auditSummary() { // shared implementation, inherited by every subclass
            return "Task[" + name + "] overdue=" + isOverdue();
        }
    }

    static class RecurringTask extends Task {
        RecurringTask(String name) {
            super(name);
        }

        @Override
        boolean isOverdue() {
            return false; // recurring tasks reset instead of going overdue
        }
    }

    public static void main(String[] args) {
        Task t = new RecurringTask("Weekly status report");
        System.out.println(t.auditSummary());
    }
}
```

`RecurringTask` inherits `name` and the shared `auditSummary()` logic from the abstract class, while `Auditable` describes a capability that any other unrelated class (`Project`, `User`) could implement too, without joining `Task`'s inheritance hierarchy at all.

## How overload resolution actually works

`System.out.println` has a dozen overloads — `println(int)`, `println(String)`, `println(Object)`, and so on — and the compiler picks one **at compile time**, based on the static (declared) types of the arguments, not their runtime values. The resolution order, roughly:

1. **Exact match** — an overload whose parameter types exactly match the argument types.
2. **Widening primitive conversion** — `int` → `long`, `float` → `double`, etc., if no exact match exists.
3. **Autoboxing** — `int` → `Integer`, if no widening match exists either.
4. **Varargs** — `Object...`-style overloads are tried last, only if nothing else matches.

```java
public class Main {
    static void logPriority(int priority) {
        System.out.println("int overload: " + priority);
    }

    static void logPriority(long priority) {
        System.out.println("long overload: " + priority);
    }

    static void logPriority(Object priority) {
        System.out.println("Object overload: " + priority);
    }

    public static void main(String[] args) {
        byte b = 5;
        logPriority(b); // widens byte -> int: picks the int overload, not long or Object
    }
}
```

`byte` has no exact-match overload here, so the compiler widens it — and stops at the *first* widening conversion that produces a match (`byte` → `int`), never considering autoboxing to `Byte`/`Object` at all, because a valid match was already found at the widening stage. This is exactly the kind of thing an interviewer asks to see if you understand it's a **compile-time, static-type decision** — unlike overriding, which resolves at runtime based on the object's actual class.

## Checked vs. unchecked exceptions, the interview framing

You covered the mechanics earlier in the course: checked exceptions (subclasses of `Exception`, not `RuntimeException`) must be caught or declared, unchecked ones don't have to be. The interview-level follow-up is usually "so which should *you* use when you design a new exception type for TaskFlow?" The honest, opinionated answer most experienced Java developers give: prefer unchecked exceptions for your own APIs unless the caller has a genuine, reasonable way to *recover* from the failure at the call site. Checked exceptions that just get caught and rethrown, or swallowed with an empty `catch` block, are worse than no exception handling at all — they add ceremony (`throws` clauses cascading up every method signature) without adding real safety, and empty `catch` blocks are one of the most common ways real bugs get silently hidden.

## Why `String` is immutable, and why that matters

A `String`'s backing character data cannot be changed after construction — every "modifying" method (`substring`, `concat`, `toUpperCase`, ...) returns a **new** `String` rather than mutating the original. Three concrete reasons this matters, all worth having ready in an interview:

- **The string pool.** Because `String`s are immutable, the JVM can safely have many variables share one underlying object for identical literals (`"Deploy"` from two different places in your code is the same pooled object) — that sharing would be unsafe if any one reference could mutate the shared data out from under the others.
- **Thread-safety.** An immutable object can be freely shared across threads with zero synchronization, because there's no mutation to race on. `Task` names, `User` usernames — anything modeled as `String` — never needs a lock just to be read concurrently.
- **Security and reliability.** `String` is used constantly for things like file paths, class names, and network hosts. If `String` were mutable, code that validated a value and then handed it to something else (e.g., a security check followed by a file open) could have the value changed out from under it between the check and the use — immutability closes that entire class of bug.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-core-language-oop-theory-q1",
      "type": "mcq",
      "prompt": "Why does contains() on a HashSet<Task> silently return false for a logically-equal Task if equals() is overridden but hashCode() is not?",
      "options": [
        { "id": "a", "text": "HashSet ignores equals() entirely and only ever uses ==" },
        { "id": "b", "text": "Without a matching hashCode() override, the two equal objects land in different buckets, so equals() is never even called to compare them" },
        { "id": "c", "text": "hashCode() is required by the compiler whenever equals() is overridden, so this scenario cannot compile" },
        { "id": "d", "text": "HashSet always returns false for custom objects regardless of equals()" }
      ],
      "correct": "b",
      "explanation": "HashSet/HashMap use hashCode() to pick a bucket first and only call equals() against objects already in that bucket. If hashCode() isn't overridden consistently with equals(), two equal objects can land in different buckets and never get compared at all."
    },
    {
      "id": "interview-ready-core-language-oop-theory-q2",
      "type": "mcq",
      "prompt": "Which factor most directly forces you to use an interface instead of an abstract class in Java?",
      "options": [
        { "id": "a", "text": "The need for shared instance state across subclasses" },
        { "id": "b", "text": "The need for a constructor" },
        { "id": "c", "text": "The need for one class to inherit multiple unrelated capabilities, since a class can implement many interfaces but extend only one class" },
        { "id": "d", "text": "Interfaces compile faster than abstract classes" }
      ],
      "correct": "c",
      "explanation": "Java allows single inheritance of classes but multiple implementation of interfaces. When a class needs to be Comparable, Auditable, and Serializable simultaneously, those capabilities must be interfaces — an abstract class slot is limited to one."
    },
    {
      "id": "interview-ready-core-language-oop-theory-q3",
      "type": "mcq",
      "prompt": "Overload resolution in Java (choosing between logPriority(int), logPriority(long), logPriority(Object)) happens:",
      "options": [
        { "id": "a", "text": "At runtime, based on the actual value passed in" },
        { "id": "b", "text": "At compile time, based on the static/declared type of the argument, preferring exact match, then widening, then autoboxing, then varargs" },
        { "id": "c", "text": "Randomly, whichever overload is declared first in the file" },
        { "id": "d", "text": "At runtime, based on which overload was called most recently" }
      ],
      "correct": "b",
      "explanation": "Overload resolution is entirely a compile-time decision based on static types, following a fixed preference order: exact match, then widening primitive conversion, then autoboxing, then varargs — unlike overriding, which resolves dynamically at runtime."
    },
    {
      "id": "interview-ready-core-language-oop-theory-q4",
      "type": "mcq",
      "prompt": "Which of these is NOT a direct benefit of String's immutability?",
      "options": [
        { "id": "a", "text": "Multiple references can safely share the same pooled String literal" },
        { "id": "b", "text": "Strings can be shared across threads with no synchronization" },
        { "id": "c", "text": "A value cannot be changed out from under code that already validated it" },
        { "id": "d", "text": "String comparisons with == always work correctly for any two Strings with equal content" }
      ],
      "correct": "d",
      "explanation": "== only reliably matches for interned literals sharing the same pooled object — a String built at runtime (e.g. via concatenation or new String(...)) with identical content can still fail == against a literal. .equals() is still required for correct content comparison; immutability doesn't change that fact."
    }
  ]
}
```

## What's next

Next up: the Collections Framework and generics, at the depth interviewers actually probe — HashMap internals, Big-O tradeoffs, and what type erasure really means at runtime.
$md$, 35, $json$[{"id":"interview-ready-core-language-oop-theory-q1","type":"mcq","correct":"b"},{"id":"interview-ready-core-language-oop-theory-q2","type":"mcq","correct":"c"},{"id":"interview-ready-core-language-oop-theory-q3","type":"mcq","correct":"b"},{"id":"interview-ready-core-language-oop-theory-q4","type":"mcq","correct":"d"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('435a5448-c5eb-529f-a948-97d2b55697e3', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c34f1e45-8786-58ed-afcf-af84b44f06c8', 'Collections & Generics Theory', 'notes', 1, $md$Collections questions are where interviewers separate "I've used `HashMap`" from "I understand what it's doing." This lesson goes underneath the API you already know from the collections module — TaskFlow's `Map<Long, Task>` lookups and `List<Task>` iterations — to the mechanics interviewers actually probe.

## How `HashMap` actually works

A `HashMap<K, V>` stores entries in an internal array of **buckets**. Putting a key through the map roughly does this:

1. Call `key.hashCode()` to get an integer hash, then run it through an internal "spreading" function that mixes the high and low bits together (this reduces collisions that would otherwise occur if many keys produced hash codes differing only in high-order bits).
2. Reduce that spread hash to an index within the current bucket array size, typically via `hash & (capacity - 1)` — bitwise-AND against `capacity - 1` is a fast equivalent of `% capacity` that only works because capacity is always kept a power of two.
3. Store the entry in that bucket. If another entry is already there (a **collision** — two different keys landing in the same bucket), the new entry is appended to a structure hanging off that bucket.

That "structure hanging off the bucket" used to always be a simple **linked list** — walk it entry by entry, comparing `equals()`, until you find a match or reach the end. Since Java 8, if a single bucket's chain grows long enough (8 or more entries, with the table large enough), `HashMap` converts that one bucket's list into a **balanced red-black tree** instead, turning worst-case lookup within a badly-collided bucket from O(n) into O(log n). This only kicks in for pathological collision cases; a healthy `HashMap` never builds a single tree bucket in practice.

```java
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Map<Long, String> taskNamesById = new HashMap<>();
        taskNamesById.put(1001L, "Design database schema");
        taskNamesById.put(1002L, "Build REST API");

        // get() re-runs the same hash -> bucket -> equals() walk that put() did.
        String name = taskNamesById.get(1001L);
        System.out.println(name);
    }
}
```

Average-case `get`/`put` is **O(1)** — one hash computation, one array index, and (in the common case) zero or one `equals()` comparisons in an essentially-empty bucket. That O(1) is an *average*, not a guarantee; it depends entirely on `hashCode()` spreading keys evenly across buckets, which is exactly why overriding `hashCode()` badly (e.g., always returning `0`) silently degrades every `HashMap` built on that key type toward O(n) behavior, even though nothing about the code *looks* wrong.

### Load factor and resizing

A `HashMap` doesn't wait until every bucket is full to grow — it tracks a **load factor** (default `0.75`) and resizes once `size > capacity * loadFactor`. With the default 16-bucket initial capacity, that's a resize once the map holds more than 12 entries. Resizing doubles the bucket array and **rehashes every existing entry** into its new bucket (an entry's bucket index depends on the current capacity, so growing the array changes where almost everything belongs). This is why a `HashMap` you know will hold ~10,000 `Task` entries is faster to construct with an explicit initial capacity (`new HashMap<>(16384)`) — it skips several rounds of doubling-and-rehashing that would otherwise happen automatically as it grows.

## `ArrayList` vs. `LinkedList` — the tradeoffs that actually matter

Both implement `List<T>`, and the interview question is never "which is better" — it's "which is better for *this* access pattern."

| Operation | `ArrayList` | `LinkedList` |
|---|---|---|
| `get(index)` (random access) | O(1) — direct array index | O(n) — must walk the chain from the nearest end |
| `add(element)` at the end | O(1) amortized (occasional resize) | O(1) |
| `add(index, element)` in the middle | O(n) — shifts every later element over | O(n) to find the position, O(1) to link once there |
| `remove(index)` in the middle | O(n) — shifts every later element back | O(n) to find the position, O(1) to unlink once there |
| Memory overhead per element | Low — a contiguous backing array | Higher — each node stores two extra object references (prev/next) |

`ArrayList` is backed by a plain array under the hood, so indexed access is a direct memory offset — O(1). `LinkedList` is backed by doubly-linked nodes, so `get(500)` has to walk 500 links from whichever end is closer — O(n). The real-world answer for TaskFlow: `ArrayList` is the right default almost always. `LinkedList` only wins when the *dominant* operation is inserting/removing at a known position (especially the front or back) on a large collection and you never need indexed access — a genuinely rare pattern in practice, which is why `ArrayList` is what you reach for unless you have a specific, measured reason not to.

## `HashMap` vs. `TreeMap` vs. `LinkedHashMap`

All three implement `Map<K, V>`, and the difference is entirely about **ordering** and the performance cost that ordering carries:

- **`HashMap`** — no ordering guarantee at all; iteration order can even change between runs. O(1) average `get`/`put`. The default choice when you don't care about order.
- **`LinkedHashMap`** — a `HashMap` internally, plus a doubly-linked list threading through the entries in **insertion order** (or, configured differently, access order — useful for building an LRU cache). Same O(1) average `get`/`put` as `HashMap`, with a small extra memory/bookkeeping cost for maintaining the linked list, in exchange for predictable iteration order.
- **`TreeMap`** — keeps keys in **sorted order** (natural ordering via `Comparable`, or a supplied `Comparator`), backed by a red-black tree. `get`/`put` are O(log n), slower than the other two, in exchange for always-sorted iteration and range operations like `firstKey()`, `headMap()`, `tailMap()`.

For TaskFlow: `Map<Long, Task>` for a plain ID lookup is `HashMap`. A "recently viewed tasks" cache that needs to evict the oldest entry is a natural `LinkedHashMap` (access-order mode). A leaderboard that needs tasks sorted by due date at all times is a `TreeMap<LocalDate, Task>`.

## Fail-fast iterators and `ConcurrentModificationException`

Java's standard collection iterators are **fail-fast**: each collection tracks a `modCount` (an internal counter incremented on every structural change — add or remove, not a plain `set`), and the iterator captures that count when created. Every `next()` call checks the live count against the captured one; if they differ, it throws `ConcurrentModificationException` immediately rather than letting you silently iterate over a collection that changed shape underneath you.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>(List.of("Design schema", "Build API", "Write tests"));

        try {
            for (String name : taskNames) {
                if (name.equals("Build API")) {
                    taskNames.remove(name); // structural modification during iteration
                }
            }
        } catch (java.util.ConcurrentModificationException e) {
            System.out.println("Caught: cannot modify a list while iterating it with for-each.");
        }

        // The correct fix: remove through the Iterator itself, or use removeIf().
        taskNames.removeIf(name -> name.equals("Build API"));
        System.out.println(taskNames);
    }
}
```

The for-each loop above desugars to an `Iterator`, and `list.remove(name)` mutates `taskNames` directly, bypassing that iterator entirely — the iterator's next `next()`/`hasNext()` call notices the mismatched `modCount` and throws. The two correct fixes: call `Iterator.remove()` (which updates the tracked count consistently, since it goes through the iterator itself) inside an explicit `while (it.hasNext())` loop, or — simpler, and what you should reach for in real code — `Collection.removeIf(predicate)`, shown above, which handles this safely internally. Worth knowing as a caveat: fail-fast behavior is a **best-effort** safety net for catching bugs during single-threaded misuse, not a real concurrency guarantee — it's explicitly not something to rely on for thread-safety in genuinely concurrent code.

## What type erasure means for generics at runtime

Java generics are a **compile-time-only** feature. The compiler uses type parameters (`Repository<Task>`, `List<String>`) to check your code for type errors, then **erases** them — at runtime, `Repository<Task>` and `Repository<User>` are both literally just `Repository`, backed by the exact same `.class` file, with type parameters replaced by their bound (`Object`, if unbounded) and compiler-inserted casts added wherever a generic value is retrieved.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>();
        List<Integer> taskIds = new ArrayList<>();

        // Both are, at runtime, plain java.util.ArrayList — the <String> and <Integer>
        // information does not exist anymore once the code is compiled and running.
        System.out.println(taskNames.getClass() == taskIds.getClass()); // true
    }
}
```

This has real, interview-tested consequences: you cannot do `new T()` inside a generic class (the JVM has no idea what `T` erased to), you cannot create an array of a generic type directly (`new T[10]` doesn't compile), and `instanceof` cannot check a parameterized type (`obj instanceof List<String>` is a compile error — you can only check the raw `obj instanceof List`). Erasure exists specifically for backward compatibility: it let generics get bolted onto Java 5 without breaking every `.class` file compiled before generics existed.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-collections-generics-theory-q1",
      "type": "mcq",
      "prompt": "A HashMap's default load factor is 0.75 with an initial capacity of 16. At what size does it first trigger a resize?",
      "options": [
        { "id": "a", "text": "At exactly 16 entries" },
        { "id": "b", "text": "Once size exceeds capacity * loadFactor — more than 12 entries" },
        { "id": "c", "text": "It never resizes automatically" },
        { "id": "d", "text": "At 75 entries" }
      ],
      "correct": "b",
      "explanation": "A HashMap resizes (doubling capacity and rehashing every entry) once its size exceeds capacity * loadFactor. With capacity 16 and load factor 0.75, that threshold is 12 entries."
    },
    {
      "id": "interview-ready-collections-generics-theory-q2",
      "type": "mcq",
      "prompt": "Why is get(500) O(1) on an ArrayList but O(n) on a LinkedList?",
      "options": [
        { "id": "a", "text": "LinkedList has a slower CPU implementation for the same array-index operation" },
        { "id": "b", "text": "ArrayList is backed by a contiguous array allowing direct index offset access; LinkedList must walk node-to-node from an end to reach the target index" },
        { "id": "c", "text": "LinkedList does not support get() at all" },
        { "id": "d", "text": "ArrayList caches every previous get() result" }
      ],
      "correct": "b",
      "explanation": "ArrayList's backing array supports direct O(1) offset access. LinkedList has no such array — reaching index 500 requires traversing 500 prev/next links from whichever end is closer, which is O(n)."
    },
    {
      "id": "interview-ready-collections-generics-theory-q3",
      "type": "mcq",
      "prompt": "Which map implementation would you choose for a leaderboard that must always iterate tasks sorted by due date?",
      "options": [
        { "id": "a", "text": "HashMap, since it's fastest" },
        { "id": "b", "text": "LinkedHashMap in insertion-order mode" },
        { "id": "c", "text": "TreeMap, since it maintains keys in sorted order at the cost of O(log n) get/put instead of O(1)" },
        { "id": "d", "text": "Any of the three — they all guarantee sorted iteration" }
      ],
      "correct": "c",
      "explanation": "TreeMap is backed by a red-black tree and keeps keys continuously sorted, trading O(1) average HashMap performance for O(log n) operations in exchange for always-ordered iteration and range queries."
    },
    {
      "id": "interview-ready-collections-generics-theory-q4",
      "type": "mcq",
      "prompt": "Because of type erasure, which of these fails to compile inside a generic class Repository<T>?",
      "options": [
        { "id": "a", "text": "T item = items.get(0);" },
        { "id": "b", "text": "void add(T item) { items.add(item); }" },
        { "id": "c", "text": "T[] array = new T[10];" },
        { "id": "d", "text": "List<T> all() { return items; }" }
      ],
      "correct": "c",
      "explanation": "Generic type parameters are erased at runtime, so the JVM has no concrete type to allocate an array of — new T[10] doesn't compile. The other options work fine because they don't require the JVM to know T's runtime identity."
    }
  ]
}
```

## What's next

Next: concurrency and JVM internals at interview depth — race conditions, deadlock, volatile vs. synchronized, and why the stack/heap split matters more than it first seems.
$md$, 35, $json$[{"id":"interview-ready-collections-generics-theory-q1","type":"mcq","correct":"b"},{"id":"interview-ready-collections-generics-theory-q2","type":"mcq","correct":"b"},{"id":"interview-ready-collections-generics-theory-q3","type":"mcq","correct":"c"},{"id":"interview-ready-collections-generics-theory-q4","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d7893943-7fef-5106-bbe4-3437462d974a', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c34f1e45-8786-58ed-afcf-af84b44f06c8', 'Concurrency & JVM Theory', 'notes', 2, $md$Concurrency and JVM internals questions have a reputation for being the hardest part of a Java interview, mostly because they're the topics people learn by copying a pattern (`synchronized` this, `ExecutorService` that) without ever building the mental model underneath. This lesson builds that model, still grounded in TaskFlow.

## What makes a race condition, restated precisely

You built and fixed a real one in the concurrency module: two threads both running `count++` on TaskFlow's shared completion counter, with one increment silently lost. The precise definition an interviewer wants: a race condition requires **shared mutable state**, **at least one thread writing to it**, and **no synchronization enforcing a consistent order** between the operations — the outcome then depends on timing the program doesn't control or guarantee. All three conditions have to hold; remove any one (make the state immutable, make it thread-local instead of shared, or add synchronization that fixes an order) and the race disappears. Interviewers often follow up with "is reading shared state without writing to it ever a race condition?" — the answer is no by this definition, but it can still be a **visibility** problem, which is the volatile/synchronized distinction below.

## Deadlock: four necessary conditions

A deadlock is what happens when two or more threads each hold a resource the other needs, and neither will ever release what it's holding. Unlike a race condition (wrong *result*), a deadlock is a **complete halt** — the threads involved are stuck forever, not just producing bad data.

Computer science names four conditions that must **all** be true simultaneously for deadlock to be possible (this is the standard interview answer — know all four by name):

1. **Mutual exclusion** — a resource can only be held by one thread at a time (true of any `synchronized` lock).
2. **Hold and wait** — a thread holds at least one resource while waiting to acquire another.
3. **No preemption** — a resource can't be forcibly taken away from the thread holding it; it must be released voluntarily.
4. **Circular wait** — a cycle of threads exists where each is waiting on a resource held by the next one in the cycle.

The classic concrete example — two TaskFlow objects, `Task` and `Project`, each with their own lock, acquired in **opposite order** by two different threads:

```text
Thread A:                          Thread B:
synchronized (task.lock) {         synchronized (project.lock) {
    // ... do work ...                  // ... do work ...
    synchronized (project.lock) {       synchronized (task.lock) {
        // never reached                    // never reached
    }                                   }
}                                   }
```

This is deliberately shown as illustrative pseudocode, not a runnable Java program — actually executing this shape would hang forever by design, which is exactly the bug being demonstrated: Thread A acquires `task.lock` and then waits for `project.lock`; Thread B, running at the same time, has already acquired `project.lock` and is now waiting for `task.lock`. Neither will ever get what it's waiting for — a circular wait, satisfying all four conditions at once.

The standard fix — and the one interviewers want to hear — is breaking the **circular wait** condition, usually the easiest of the four to attack directly: establish a single, consistent global ordering for lock acquisition (e.g., "always lock the object with the lower ID first") so it becomes structurally impossible for two threads to be waiting on each other in a cycle. This runnable example shows that fix using `ReentrantLock.tryLock(timeout)` as a defensive belt-and-suspenders measure on top of consistent ordering — `tryLock` gives up and backs off instead of waiting forever, which is itself a common real-world deadlock-avoidance technique when strict ordering isn't practical to enforce everywhere:

```java
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;

public class Main {
    static final ReentrantLock taskLock = new ReentrantLock();
    static final ReentrantLock projectLock = new ReentrantLock();

    // Both threads acquire in the SAME order (taskLock, then projectLock) —
    // this alone eliminates the circular wait that causes deadlock.
    static boolean linkTaskToProject(String label) throws InterruptedException {
        if (taskLock.tryLock(1, TimeUnit.SECONDS)) {
            try {
                if (projectLock.tryLock(1, TimeUnit.SECONDS)) {
                    try {
                        return true; // both locks acquired safely
                    } finally {
                        projectLock.unlock();
                    }
                }
            } finally {
                taskLock.unlock();
            }
        }
        return false;
    }

    public static void main(String[] args) throws InterruptedException {
        Thread t1 = new Thread(() -> {
            try {
                boolean linked = linkTaskToProject("t1");
                System.out.println("t1 linked: " + linked);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        Thread t2 = new Thread(() -> {
            try {
                boolean linked = linkTaskToProject("t2");
                System.out.println("t2 linked: " + linked);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        t1.start();
        t2.start();
        t1.join();
        t2.join();
        System.out.println("Done — consistent lock ordering avoided deadlock.");
    }
}
```

Both threads always try `taskLock` first and `projectLock` second, so there's no possible interleaving where one thread holds `projectLock` while waiting on `taskLock` — the circular-wait condition simply cannot arise, and the program always finishes.

## `volatile` vs. `synchronized`: visibility vs. atomicity

These solve two genuinely different problems, and confusing them is one of the most common intermediate-level Java mistakes.

- **`volatile`** guarantees **visibility only**: a write to a `volatile` field by one thread is guaranteed to be immediately visible to every other thread's subsequent read, bypassing per-CPU-core caching that could otherwise let one thread keep reading a stale, cached value indefinitely. `volatile` does **not** make compound operations (`count++`, `if (x == null) x = new Thing()`) atomic — a `volatile int` can still lose updates to the exact race condition described above, because `count++` is still three separate steps.
- **`synchronized`** guarantees **both**: mutual exclusion (only one thread executes the block at a time — atomicity for whatever's inside) *and* visibility (entering/exiting a synchronized block also establishes the same kind of memory barrier `volatile` does, so changes made inside are guaranteed visible to the next thread that enters).

The practical rule: use `volatile` for a simple flag or status field that's only ever **read** by other threads and **written** by one (a `stopRequested` flag is the textbook case) — no compound read-modify-write happens on it. Reach for `synchronized` (or `java.util.concurrent` types like `AtomicInteger`) the moment more than one thread needs to both read and write the same field, or when multiple fields need to stay consistent with each other.

```java
public class Main {
    // volatile: writes from main are guaranteed visible to worker without any lock.
    static volatile boolean stopRequested = false;

    public static void main(String[] args) throws InterruptedException {
        Thread worker = new Thread(() -> {
            long iterations = 0;
            // Bounded by a max, as a safety net — but stopRequested being volatile
            // means the loop reliably exits as soon as main sets it, not "eventually maybe."
            while (!stopRequested && iterations < 50_000_000L) {
                iterations++;
            }
            System.out.println("Worker stopped after seeing the flag (iterations bounded).");
        });

        worker.start();
        Thread.sleep(20); // let the worker spin briefly
        stopRequested = true; // this write is guaranteed visible to worker's next read
        worker.join();

        System.out.println("Main done.");
    }
}
```

## Stack vs. heap, revisited at interview depth

You've seen the basic split: primitives and object *references* live on the stack, objects themselves live on the heap. The interview-depth version adds the concurrency angle and the failure modes:

- **The stack is per-thread.** Every thread gets its own stack, holding a frame per active method call — local variables, method parameters, and the return address. This is exactly why thread-local data (a loop counter, a local `Task` reference variable) needs no synchronization: no other thread can even see another thread's stack.
- **The heap is shared across all threads.** Every `new Task(...)` lives on one shared heap, reachable by any thread that has a reference to it — which is precisely why heap-resident, shared, mutable state is where every race condition and visibility bug in this lesson actually happens. Stack-local data can't race with anything.
- **Failure modes differ correspondingly.** Recursing too deeply (or infinitely) exhausts a thread's stack and throws `StackOverflowError`. Allocating too many long-lived objects that can't be garbage collected exhausts the heap and throws `OutOfMemoryError`. Seeing one versus the other in a stack trace immediately tells you which side of the split to investigate.

## What garbage collection roots are

The JVM's garbage collector doesn't ask "is this object unused" — it asks "is this object **reachable**" starting from a fixed set of **GC roots**: references the JVM knows are definitely still "live" without needing to trace anything else first. GC roots typically include:

- Local variables and parameters currently on any thread's stack (an active method's `Task task = ...` local variable).
- Active `Thread` objects themselves.
- `static` fields on loaded classes (they live for the lifetime of the class, effectively always reachable).
- JNI references held by native code.

The collector walks outward from every root, marking everything reachable through a chain of references as **live**. Anything left unmarked afterward — unreachable from any root, by any path — is garbage, regardless of whether it was expensive to build or was "in use" a moment ago. This is why a common memory leak pattern in long-running Java services is an ever-growing `static` collection (a `static Map` that entries get added to but never removed from): every entry stays reachable forever through that static root, so the GC correctly, faithfully never collects any of it — the leak isn't a GC bug, it's a reachability fact the GC is honoring exactly as designed.

## Why String concatenation in a loop is a performance smell

This ties directly back to the immutability lesson: every `+` or `+=` on a `String` doesn't mutate anything — it allocates a **brand-new** `String` containing the combined characters, because the original can't be changed. Do this inside a loop and each iteration allocates a new, slightly-longer string, copying all the previous characters over again:

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design schema", "Build API", "Write tests", "Deploy", "Monitor" };

        // Anti-pattern: each += allocates a whole new String, recopying everything so far.
        String badReport = "";
        for (String name : taskNames) {
            badReport += name + ", "; // O(n) work per iteration -> O(n^2) total for n tasks
        }

        // Fix: StringBuilder mutates an internal, resizable buffer in place.
        StringBuilder goodReport = new StringBuilder();
        for (String name : taskNames) {
            goodReport.append(name).append(", "); // O(1) amortized per append
        }

        System.out.println(badReport);
        System.out.println(goodReport);
    }
}
```

For `n` names, the `+=` version does roughly `1 + 2 + 3 + ... + n` characters worth of copying — O(n²) total — because each new string re-copies every character built so far. `StringBuilder` holds a single mutable, resizable `char`/`byte` buffer internally and only allocates a new backing array when it actually needs to grow, giving O(n) total work for the same loop. For a handful of iterations the difference is invisible; for a report built over thousands of `Task` names, it's the difference between a snappy response and a visible slowdown — and it's a direct, mechanical consequence of `String` immutability, not an unrelated JVM quirk.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-concurrency-jvm-theory-q1",
      "type": "mcq",
      "prompt": "Which four conditions must all hold simultaneously for deadlock to be possible?",
      "options": [
        { "id": "a", "text": "High CPU usage, many threads, large heap, slow disk" },
        { "id": "b", "text": "Mutual exclusion, hold and wait, no preemption, circular wait" },
        { "id": "c", "text": "Race condition, visibility failure, memory leak, stack overflow" },
        { "id": "d", "text": "Atomicity, consistency, isolation, durability" }
      ],
      "correct": "b",
      "explanation": "The four Coffman conditions — mutual exclusion, hold and wait, no preemption, and circular wait — must all be true at once for deadlock to occur. Breaking any single one (most commonly circular wait, via consistent lock ordering) prevents it."
    },
    {
      "id": "interview-ready-concurrency-jvm-theory-q2",
      "type": "mcq",
      "prompt": "Why does making a field volatile NOT fix a race condition on count++?",
      "options": [
        { "id": "a", "text": "volatile only guarantees visibility of writes across threads — it does not make the three-step read-modify-write of ++ atomic" },
        { "id": "b", "text": "volatile fields cannot be incremented at all" },
        { "id": "c", "text": "volatile is identical to synchronized and should fix it, but doesn't due to a JVM bug" },
        { "id": "d", "text": "volatile only works on object references, not primitives like int" }
      ],
      "correct": "a",
      "explanation": "volatile guarantees that writes are immediately visible to other threads' reads, but it does not make compound operations atomic. count++ is still a separate read, modify, and write, so two threads can still interleave and lose an update even with volatile."
    },
    {
      "id": "interview-ready-concurrency-jvm-theory-q3",
      "type": "mcq",
      "prompt": "Which of these is typically considered a GC root?",
      "options": [
        { "id": "a", "text": "Every object ever allocated on the heap" },
        { "id": "b", "text": "A local variable currently on an active thread's stack" },
        { "id": "c", "text": "Any object with a low hashCode()" },
        { "id": "d", "text": "Objects stored in a HashMap" }
      ],
      "correct": "b",
      "explanation": "GC roots are references the JVM treats as inherently live without needing further justification: active threads' stack locals, static fields, active Thread objects, and JNI references. The GC then marks everything transitively reachable from those roots as live."
    },
    {
      "id": "interview-ready-concurrency-jvm-theory-q4",
      "type": "mcq",
      "prompt": "Why is String concatenation with += inside a loop an O(n^2) performance smell?",
      "options": [
        { "id": "a", "text": "Because String is thread-safe and every += acquires a lock" },
        { "id": "b", "text": "Because each += allocates a new String and copies all previously-accumulated characters again, since Strings are immutable" },
        { "id": "c", "text": "Because the JVM interprets += as a method call with high overhead" },
        { "id": "d", "text": "It isn't a real performance concern in modern Java" }
      ],
      "correct": "b",
      "explanation": "Every += on a String produces a brand-new String object holding the combined characters, re-copying everything accumulated so far — n iterations of growing copies sum to O(n^2) total work. StringBuilder avoids this by mutating one resizable buffer in place."
    }
  ]
}
```

## What's next

Next: design principles and modern Java at interview depth — SOLID with concrete violation-and-fix examples, composition vs. inheritance, and when records and functional interfaces are (and aren't) the right tool.
$md$, 35, $json$[{"id":"interview-ready-concurrency-jvm-theory-q1","type":"mcq","correct":"b"},{"id":"interview-ready-concurrency-jvm-theory-q2","type":"mcq","correct":"a"},{"id":"interview-ready-concurrency-jvm-theory-q3","type":"mcq","correct":"b"},{"id":"interview-ready-concurrency-jvm-theory-q4","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2e2505d1-7de6-5528-9f1e-9e45cbbcde4f', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c34f1e45-8786-58ed-afcf-af84b44f06c8', 'Design & Modern Java Theory', 'notes', 3, $md$This lesson pressure-tests design judgment and modern-Java awareness — the questions interviewers ask to see whether you've internalized *why* certain choices are good, not just whether you can define a term.

## "Explain SOLID — and give me a concrete violation and fix"

Naming all five letters gets you nowhere in an interview if you can't back at least two of them with a real example. Two that come up constantly:

**Single Responsibility Principle.** *Violation*: a `TaskService` class that both persists tasks to a database AND formats them into HTML for an email digest. Change the email template, and you risk breaking persistence code in the same file, reviewed by the same diff. *Fix*: split into `TaskRepository` (persistence) and `TaskEmailFormatter` (presentation) — each has exactly one reason to change.

**Open/Closed Principle.** *Violation*: a `calculatePriorityScore(Task task)` method with an `if/else if` chain keyed on `task.getType()`, requiring an edit to this method every time a new task type is added. *Fix*: the Strategy pattern from the design-patterns module — a `PriorityStrategy` interface with one implementation per task type, so adding a new type means adding a new class, never touching the existing ones.

Being ready to state — out loud, unprompted — "here's a violation I've actually reasoned through, and here's the fix" is worth more than reciting all five initials correctly.

```java
public class Main {
    // Violation: mixes calculation logic with formatting, and needs editing
    // for every new priority rule.
    static String badReport(int hours, boolean urgent) {
        String score;
        if (urgent && hours > 8) {
            score = "CRITICAL";
        } else if (urgent) {
            score = "HIGH";
        } else if (hours > 8) {
            score = "MEDIUM";
        } else {
            score = "LOW";
        }
        return "Priority: " + score; // formatting logic mixed in here too
    }

    public static void main(String[] args) {
        System.out.println(badReport(10, true));
    }
}
```

## "Why favor composition over inheritance?"

Inheritance couples a subclass to its superclass's implementation, not just its interface — a change to a base class can silently break every subclass, even ones the base class's author never anticipated (the classic "fragile base class" problem). It also only allows a single line of extension in Java (no multiple inheritance of classes), forcing awkward hierarchies when a class genuinely needs multiple unrelated capabilities.

**Composition** — a class *holding a reference* to another class and delegating to it, rather than extending it — avoids both problems: you can compose as many capabilities as needed, and each collaborator can be swapped independently (this is exactly what made the mocking lesson's `NotificationService` substitutable). The interview-ready answer: "favor composition over inheritance" doesn't mean *never* use inheritance — the OOP module's `Task`/`UrgentTask` relationship is a legitimate is-a relationship — it means reach for inheritance only when the relationship is genuinely "is-a," and reach for composition ("has-a") for everything else, especially cross-cutting capabilities like logging, notification, or persistence strategy.

## "When are records the right tool — and when aren't they?"

Right tool: immutable data carriers — DTOs crossing a service boundary, value objects like a `Coordinate` or `Money` amount, or event types in a sealed hierarchy (`TaskCreated`, `TaskCompleted`). Wrong tool: anything with state that's meant to mutate over its lifetime (a `Task` whose `status` genuinely transitions in place), or anything that needs to participate in an inheritance hierarchy as a subclass of another concrete class (records are implicitly final and cannot extend a class). A sharp interview answer distinguishes "this type represents a value" from "this type represents an entity with a lifecycle" — records are for the former.

## "What is a functional interface, and why do lambdas need one?"

A **functional interface** is any interface with exactly one abstract method (it can have any number of `default`/`static` methods, those don't count). A lambda expression is just syntactic sugar for "an anonymous implementation of a functional interface's single abstract method" — the compiler infers which functional interface a lambda targets from the assignment context. This is *why* `Comparator<T>` (one abstract method: `compare`), `Runnable` (one abstract method: `run`), and your own `@FunctionalInterface`-annotated types can all be implemented with a lambda, while an interface with two abstract methods cannot — there'd be no unambiguous way to know which method the lambda's body is implementing.

```java
public class Main {
    @FunctionalInterface
    interface TaskFilter {
        boolean test(String taskName);
    }

    static void printMatching(String[] tasks, TaskFilter filter) {
        for (String t : tasks) {
            if (filter.test(t)) System.out.println(t);
        }
    }

    public static void main(String[] args) {
        String[] tasks = { "Deploy to prod", "Design schema", "Deprecate old API" };
        // The lambda below IS an implementation of TaskFilter's single abstract method.
        printMatching(tasks, name -> name.startsWith("De"));
    }
}
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-design-modern-q1",
      "type": "mcq",
      "prompt": "What is the 'fragile base class' problem that motivates favoring composition over inheritance?",
      "options": [
        { "id": "a", "text": "Base classes are always slower at runtime than composed objects" },
        { "id": "b", "text": "A change to a base class's implementation can silently break subclasses the base class's author never anticipated, since subclasses are coupled to implementation, not just interface" },
        { "id": "c", "text": "Java forbids more than one level of inheritance" },
        { "id": "d", "text": "Base classes cannot have private fields" }
      ],
      "correct": "b",
      "explanation": "Inheritance couples a subclass to its superclass's internals in ways that aren't always visible at the call site, making base-class changes riskier than changes to a composed, interface-bound collaborator."
    },
    {
      "id": "interview-ready-design-modern-q2",
      "type": "mcq",
      "prompt": "Which scenario is the best fit for a record?",
      "options": [
        { "id": "a", "text": "An immutable event type like TaskCompleted(String taskName, int actualHours) used in a sealed event hierarchy" },
        { "id": "b", "text": "A Task entity whose status field is meant to mutate in place as work progresses" },
        { "id": "c", "text": "A class that must extend another concrete class" },
        { "id": "d", "text": "A class requiring custom getX()-style accessor names for an existing API contract" }
      ],
      "correct": "a",
      "explanation": "Records are for immutable values — an event describing something that already happened is a textbook fit, since it never needs to change after construction."
    },
    {
      "id": "interview-ready-design-modern-q3",
      "type": "mcq",
      "prompt": "Why can an interface with two abstract methods NOT be implemented with a lambda?",
      "options": [
        { "id": "a", "text": "Lambdas can only be used with classes, never interfaces" },
        { "id": "b", "text": "A lambda's body implements exactly one method, so the compiler would have no unambiguous way to know which of the two abstract methods it's implementing" },
        { "id": "c", "text": "Java forbids interfaces from having more than one method entirely" },
        { "id": "d", "text": "It can be — this restriction doesn't actually exist" }
      ],
      "correct": "b",
      "explanation": "A functional interface's single-abstract-method constraint exists precisely so a lambda has one unambiguous target to implement — this is the formal definition behind why Runnable and Comparator work with lambdas and a two-method interface doesn't."
    }
  ]
}
```

## What's next

The final lesson closes the loop: not what to know, but how to *talk through* what you know under interview pressure.
$md$, 35, $json$[{"id":"interview-ready-design-modern-q1","type":"mcq","correct":"b"},{"id":"interview-ready-design-modern-q2","type":"mcq","correct":"a"},{"id":"interview-ready-design-modern-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8188a7c1-ce2a-5c53-9ee7-bc31bd2815c2', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c34f1e45-8786-58ed-afcf-af84b44f06c8', 'How to Talk Through Java Interview Questions', 'notes', 4, $md$Knowing the material and *demonstrating* that you know it under pressure are different skills. This closing lesson is about the second one — how to structure an answer live, in a room (or on a call), where silence reads as uncertainty even when you're actually thinking.

## A reliable answer structure

For almost any "explain X" or "what's the difference between X and Y" question, the same three-beat structure works:

1. **Define the term precisely, in one or two sentences.** Not a synonym, an actual definition. "A HashMap stores key-value pairs using a hash table" is a start; "hashing the key determines which bucket it lands in, and equal keys must produce equal hashes for lookup to work correctly" is the level of precision that signals real understanding.
2. **Give a concrete example — ideally from something you've actually built or studied**, not a generic textbook one. Throughout this course that's meant reaching for TaskFlow: "when I was deduplicating team members assigned to a task, I used a HashSet<String> because—"
3. **Mention a tradeoff or gotcha.** This is the step most candidates skip, and it's the one that most reliably signals depth. For HashMap: "the catch is iteration order isn't guaranteed, so if I need insertion order I'd reach for LinkedHashMap instead" — this single sentence proves you've hit the edge of the concept in practice, not just memorized the definition.

Applied to a real question — **"What's the difference between ArrayList and LinkedList?"**:

> *Define*: "Both implement the List interface, but ArrayList backs itself with a resizable array, while LinkedList uses a doubly-linked list of nodes." \
> *Example*: "For TaskFlow's task list, where I mostly iterate and occasionally look up by index, ArrayList was the right call — LinkedList's node-hopping means indexed access is O(n), not O(1)." \
> *Tradeoff*: "Where LinkedList wins is frequent insertion/removal at the front or middle of the list, since ArrayList has to shift every subsequent element — but in practice, ArrayList is the right default unless you've actually measured that insertion pattern mattering."

## Common follow-up traps

Interviewers routinely push one level deeper than your first answer, specifically to see whether you actually understand the mechanism or just memorized the headline fact. A few patterns worth anticipating:

- **"Why?"** after almost any factual claim. If you say "Strings are immutable," expect "why does that matter?" immediately after — have the *consequence* ready (thread-safety without synchronization, safe use as a HashMap key, the string pool being possible at all), not just the fact.
- **"What if [edge case]?"** — null input, an empty collection, a negative number, two equal elements. If your answer to a sorting question doesn't address what happens with duplicate values, expect to be asked.
- **"How would you test that?"** — a question about production code often pivots into a question about testing it, especially after this course's JUnit module. Having *a* answer, even a rough one, beats visibly not having considered it.
- **Being asked to write the code**, not just describe it. Talking accurately about `HashMap` internals and then fumbling basic syntax when asked to write a small example undermines the verbal answer that came before it — this is exactly why every module in this course paired explanation with a real, runnable code box.

## "I don't know" is a legitimate answer — if it's followed by a real plan

Guessing confidently and being wrong reads worse than admitting a gap — but a bare "I don't know" without more reads as a dead end. The credible version names *what you'd actually do* to find out:

> "I haven't worked with virtual threads directly, but based on how the platform threads model works, I'd expect the core tradeoff to be around blocking I/O — I'd want to check the JEP and run a quick benchmark before I'd trust an answer here."

That response demonstrates the same reasoning skills as a correct answer would have — reaching from what you *do* know toward a plausible hypothesis, and naming a concrete next step — without pretending to certainty you don't have. Most interviewers are evaluating how you think under uncertainty at least as much as what you've memorized; a well-reasoned "I don't know, but here's my approach" often lands better than a shaky guess dressed up as confidence.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-how-to-talk-q1",
      "type": "mcq",
      "prompt": "In the define-example-tradeoff answer structure, what does the 'tradeoff' step most reliably signal to an interviewer?",
      "options": [
        { "id": "a", "text": "That you memorized the textbook definition" },
        { "id": "b", "text": "That you've encountered the concept's edge cases or limits in practice, not just its happy-path definition" },
        { "id": "c", "text": "Nothing — it's optional filler" },
        { "id": "d", "text": "That you disagree with the interviewer's premise" }
      ],
      "correct": "b",
      "explanation": "Naming a real tradeoff or gotcha is the step most candidates skip, which is exactly why it's the strongest signal of depth when you do include it — it proves you've pushed past the definition into where the concept actually gets used."
    },
    {
      "id": "interview-ready-how-to-talk-q2",
      "type": "mcq",
      "prompt": "Why is a confident but wrong guess generally worse than a well-reasoned \"I don't know\"?",
      "options": [
        { "id": "a", "text": "It isn't worse — confidence is always the priority" },
        { "id": "b", "text": "A wrong guess suggests you can't tell what you don't know, while a reasoned \"I don't know, and here's how I'd find out\" still demonstrates real reasoning skill under uncertainty" },
        { "id": "c", "text": "Interviewers are required to fail any candidate who says \"I don't know\"" },
        { "id": "d", "text": "There's no meaningful difference between the two responses" }
      ],
      "correct": "b",
      "explanation": "Most interviewers are evaluating reasoning under uncertainty as much as raw recall — a credible, reasoned admission of a gap often demonstrates more of that skill than a confident wrong answer does."
    }
  ]
}
```

## What's next

Every concept, pattern, and tradeoff from this course converges in the capstone assessment below — mixed questions spanning the entire curriculum, two coding problems, and a final reflection question on where your own confidence is weakest.
$md$, 25, $json$[{"id":"interview-ready-how-to-talk-q1","type":"mcq","correct":"b"},{"id":"interview-ready-how-to-talk-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2ea519ac-dc89-5e1b-b358-f047051691a1', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why does overriding equals() without also overriding hashCode() break HashSet...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('63599b21-429a-5435-a712-0d57d0e960dc', '2ea519ac-dc89-5e1b-b358-f047051691a1', 1, $json${"prompt":"Why does overriding equals() without also overriding hashCode() break HashSet/HashMap behavior?","multiple":false,"options":[{"id":"a","text":"It doesn't — equals() alone is sufficient","is_correct":false},{"id":"b","text":"Two objects considered equal by equals() can still land in different hash buckets if hashCode() wasn't overridden to match, so a HashSet can silently store 'duplicate' entries","is_correct":true},{"id":"c","text":"hashCode() is deprecated and should never be overridden","is_correct":false},{"id":"d","text":"Java throws a compile error if hashCode() is missing","is_correct":false}],"explanation":"The equals/hashCode contract requires equal objects to produce equal hash codes. Breaking that contract means hash-based collections can't reliably detect that two 'equal' objects are the same entry."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('728ab827-74b2-5f71-9671-751ee6b8604e', '00000000-0000-0000-0000-000000000001', 'mcq', 'What can an abstract class provide that a plain interface (pre-Java 8, no def...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c6fde323-546e-53cc-9132-be3618c8465f', '728ab827-74b2-5f71-9671-751ee6b8604e', 1, $json${"prompt":"What can an abstract class provide that a plain interface (pre-Java 8, no default methods) could not?","multiple":false,"options":[{"id":"a","text":"Shared instance state (fields) and partially-implemented behavior subclasses inherit directly","is_correct":true},{"id":"b","text":"The ability to be instantiated directly with new","is_correct":false},{"id":"c","text":"Multiple inheritance of implementation from unrelated types","is_correct":false},{"id":"d","text":"There was never any difference between the two","is_correct":false}],"explanation":"Abstract classes can hold real fields and concrete method bodies that subclasses inherit outright — the core distinction from interfaces, even now that interfaces support default methods for shared behavior."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('26b336e5-c829-5eb0-94db-514eefc152ad', '00000000-0000-0000-0000-000000000001', 'mcq', 'What triggers a HashMap to resize (rehash) its internal bucket array?', 'advanced', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('45c4245a-0fd2-5adb-9d2c-ab3bb9c005ec', '26b336e5-c829-5eb0-94db-514eefc152ad', 1, $json${"prompt":"What triggers a HashMap to resize (rehash) its internal bucket array?","multiple":false,"options":[{"id":"a","text":"It never resizes — the initial capacity is fixed for the object's lifetime","is_correct":false},{"id":"b","text":"The number of entries exceeds capacity * loadFactor (default load factor 0.75), triggering a resize (typically doubling) and a full rehash of existing entries","is_correct":true},{"id":"c","text":"Resizing happens on every single put() call","is_correct":false},{"id":"d","text":"Only calling clear() can change the internal capacity","is_correct":false}],"explanation":"HashMap grows once its entry count crosses capacity times the load factor, to keep the average bucket chain short — this rehash is also why HashMap iteration order can appear to shift as entries are added."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3bee42ee-cc52-51eb-89e2-6d529bf22bb6', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which of these is NOT one of the four necessary conditions for deadlock?', 'advanced', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('30d2171c-ab07-58fd-be2c-28e528980231', '3bee42ee-cc52-51eb-89e2-6d529bf22bb6', 1, $json${"prompt":"Which of these is NOT one of the four necessary conditions for deadlock?","multiple":false,"options":[{"id":"a","text":"Mutual exclusion","is_correct":false},{"id":"b","text":"Hold and wait","is_correct":false},{"id":"c","text":"Garbage collection pause","is_correct":true},{"id":"d","text":"Circular wait","is_correct":false}],"explanation":"The four classic necessary conditions are mutual exclusion, hold-and-wait, no preemption, and circular wait. Garbage collection is unrelated to deadlock formation."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('54fed140-ee78-55d1-8d89-4fc6d0378084', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why can''t you write `if (list instanceof List<String>)` in Java?', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('51e6977e-3206-50b6-ac7d-bd2725bef5c3', '54fed140-ee78-55d1-8d89-4fc6d0378084', 1, $json${"prompt":"Why can't you write `if (list instanceof List\u003cString\u003e)` in Java?","multiple":false,"options":[{"id":"a","text":"instanceof cannot be used with any collection type","is_correct":false},{"id":"b","text":"Generic type information is erased at runtime (type erasure), so the JVM only knows list is a List, not what it's a List of","is_correct":true},{"id":"c","text":"It's valid syntax and works exactly as expected","is_correct":false},{"id":"d","text":"List\u003cString\u003e is not a real type","is_correct":false}],"explanation":"Type erasure removes generic type parameters at compile time — at runtime, all List\u003cT\u003e instances are just List. This is why unchecked wildcard casts and raw-type warnings exist in Java's generics."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dab4d70e-6ecf-54c8-a5c1-83d87178ad88', '00000000-0000-0000-0000-000000000001', 'mcq', 'What problem does Optional primarily address?', 'beginner', 1, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b2350ce0-94b4-5ed2-b3e9-cf0d5e410c53', 'dab4d70e-6ecf-54c8-a5c1-83d87178ad88', 1, $json${"prompt":"What problem does Optional primarily address?","multiple":false,"options":[{"id":"a","text":"Making a method run faster","is_correct":false},{"id":"b","text":"Making the possibility of \"no value\" explicit in a method's return type, instead of relying on a possibly-null reference the caller might forget to check","is_correct":true},{"id":"c","text":"Replacing all collections in Java","is_correct":false},{"id":"d","text":"Enforcing thread safety","is_correct":false}],"explanation":"Optional\u003cT\u003e makes 'this might not have a value' part of the type signature, nudging callers to explicitly handle absence instead of silently risking a NullPointerException."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('fe233cec-4919-5535-bb77-ddb2b8da273a', '00000000-0000-0000-0000-000000000001', 'mcq', 'Beyond thread-safety, why does String immutability matter for the string cons...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1359ad2c-4474-55c7-b8cf-89c51d3d11b0', 'fe233cec-4919-5535-bb77-ddb2b8da273a', 1, $json${"prompt":"Beyond thread-safety, why does String immutability matter for the string constant pool?","multiple":false,"options":[{"id":"a","text":"It doesn't relate to the pool at all","is_correct":false},{"id":"b","text":"Because Strings can't change after creation, the JVM can safely let multiple references share one pooled instance without any reference's mutation affecting another","is_correct":true},{"id":"c","text":"The pool only exists for numeric wrapper types","is_correct":false},{"id":"d","text":"Immutability makes string concatenation faster in all cases","is_correct":false}],"explanation":"String pooling relies entirely on immutability — sharing one object across many references would be unsafe if any one of them could mutate it out from under the others."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('40587d1b-13f4-5684-b2aa-c5b2ff500b61', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why prefer an ExecutorService thread pool over manually creating a new Thread...', 'intermediate', 2, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4890071d-60a0-5d7b-ac99-debbc80187d8', '40587d1b-13f4-5684-b2aa-c5b2ff500b61', 1, $json${"prompt":"Why prefer an ExecutorService thread pool over manually creating a new Thread per task?","multiple":false,"options":[{"id":"a","text":"Thread pools reuse a bounded set of worker threads instead of paying thread-creation cost per task and risking unbounded resource usage under load","is_correct":true},{"id":"b","text":"new Thread() is deprecated and no longer compiles","is_correct":false},{"id":"c","text":"ExecutorService tasks run synchronously, unlike raw threads","is_correct":false},{"id":"d","text":"There is no real difference between the two approaches","is_correct":false}],"explanation":"Unbounded thread creation under load can exhaust memory and CPU scheduling overhead. A pool caps concurrency and reuses threads, which is why it's the production-standard approach over raw Thread management."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9c54d43d-6127-57d3-bbb5-b7a092a5314c', '00000000-0000-0000-0000-000000000001', 'coding', 'Read a single line of space-separated integers (task priority scores) from st...', 'intermediate', 4, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e778de67-8a43-5bab-8fdd-74f2969f080b', '9c54d43d-6127-57d3-bbb5-b7a092a5314c', 1, $json${"prompt":"Read a single line of space-separated integers (task priority scores) from stdin. Using a Stream pipeline, print the count of scores strictly greater than 5, followed by a space, followed by the sum of exactly those scores — on one line, e.g. \"3 27\" (no other text).","languages":["java"],"starter_code":{"java":"import java.util.Arrays;\nimport java.util.Scanner;\nimport java.util.stream.Collectors;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        String line = scanner.nextLine();\n        int[] scores = Arrays.stream(line.trim().split(\"\\\\s+\")).mapToInt(Integer::parseInt).toArray();\n        // Using a stream, count how many scores are \u003e 5, and sum exactly those scores.\n        // Print: \"\u003ccount\u003e \u003csum\u003e\"\n\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"1 6 8 3 9 2","expected":"3 23","hidden":false,"weight":1},{"id":"t2","stdin":"10 10 10","expected":"3 30","hidden":true,"weight":1},{"id":"t3","stdin":"1 2 3 4 5","expected":"0 0","hidden":true,"weight":1},{"id":"t4","stdin":"6","expected":"1 6","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('674ed6ba-133b-5866-8c8f-d20939f2f9bb', '00000000-0000-0000-0000-000000000001', 'coding', 'Complete the Task class below so hoursRemaining() returns estimateHours minus...', 'intermediate', 4, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ce9a787c-f76a-52eb-bb2b-daa81f312fc8', '674ed6ba-133b-5866-8c8f-d20939f2f9bb', 1, $json${"prompt":"Complete the Task class below so hoursRemaining() returns estimateHours minus hoursLogged, but never a negative number (clamp at 0). Read three integers from one line of stdin — estimateHours, hoursLogged, and a third value ignored — and print only the result of calling hoursRemaining() on a Task built from the first two values.","languages":["java"],"starter_code":{"java":"import java.util.Scanner;\n\npublic class Main {\n    static class Task {\n        private final int estimateHours;\n        private final int hoursLogged;\n\n        Task(int estimateHours, int hoursLogged) {\n            this.estimateHours = estimateHours;\n            this.hoursLogged = hoursLogged;\n        }\n\n        int hoursRemaining() {\n            // Return estimateHours - hoursLogged, but never less than 0.\n\n            return 0;\n        }\n    }\n\n    public static void main(String[] args) {\n        Scanner scanner = new Scanner(System.in);\n        int estimateHours = scanner.nextInt();\n        int hoursLogged = scanner.nextInt();\n        scanner.nextInt(); // ignored third value\n        Task task = new Task(estimateHours, hoursLogged);\n        System.out.println(task.hoursRemaining());\n    }\n}\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"10 4 99","expected":"6","hidden":false,"weight":1},{"id":"t2","stdin":"5 5 0","expected":"0","hidden":true,"weight":1},{"id":"t3","stdin":"3 9 1","expected":"0","hidden":true,"weight":1},{"id":"t4","stdin":"20 1 5","expected":"19","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('99c5039f-8eda-56ef-9771-8193682303e3', '00000000-0000-0000-0000-000000000001', 'subjective', 'Looking back across the whole course, which module or concept are you least c...', 'beginner', 3, ARRAY['java','programming','oop','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4c0ac0f3-0cec-5d6f-835c-1adba5bcefd4', '99c5039f-8eda-56ef-9771-8193682303e3', 1, $json${"prompt":"Looking back across the whole course, which module or concept are you least confident you could explain correctly in a live interview right now? Be specific — this is the strongest signal for what should show up in your revision plan.","word_limit":400,"rubric":[{"criterion":"Overall correctness","weight":1,"description":"Graded for genuine, specific self-assessment rather than a single correct answer — the single richest signal this course collects for what deserves focused review."}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('f1447257-630a-5ea2-beba-2f18baed94f2', '00000000-0000-0000-0000-000000000001', 'Capstone Assessment: Java Mastery', 'java-mastery-interview-ready-quiz', 'Quiz covering Interview Ready.', 'mixed', 'published', 'module', '0900d381-5b65-53fa-b3f4-5381da3bf995', 45, 75, 5, 27, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('677694d6-5581-5fdc-a190-08b5c777b02a', 'f1447257-630a-5ea2-beba-2f18baed94f2', '2ea519ac-dc89-5e1b-b358-f047051691a1', '63599b21-429a-5435-a712-0d57d0e960dc', 0, 2),
('dc9440c2-6730-567b-9d08-c02484417b8b', 'f1447257-630a-5ea2-beba-2f18baed94f2', '728ab827-74b2-5f71-9671-751ee6b8604e', 'c6fde323-546e-53cc-9132-be3618c8465f', 1, 2),
('faa06d72-dd79-5826-b86a-67439b3a7705', 'f1447257-630a-5ea2-beba-2f18baed94f2', '26b336e5-c829-5eb0-94db-514eefc152ad', '45c4245a-0fd2-5adb-9d2c-ab3bb9c005ec', 2, 3),
('9f6df386-2f1d-54c3-b9d9-1af14a5655db', 'f1447257-630a-5ea2-beba-2f18baed94f2', '3bee42ee-cc52-51eb-89e2-6d529bf22bb6', '30d2171c-ab07-58fd-be2c-28e528980231', 3, 2),
('a375eec3-32df-5bf8-9868-eec5e7230bc1', 'f1447257-630a-5ea2-beba-2f18baed94f2', '54fed140-ee78-55d1-8d89-4fc6d0378084', '51e6977e-3206-50b6-ac7d-bd2725bef5c3', 4, 2),
('74a82558-2102-5bd9-a97a-0a5e610b1b98', 'f1447257-630a-5ea2-beba-2f18baed94f2', 'dab4d70e-6ecf-54c8-a5c1-83d87178ad88', 'b2350ce0-94b4-5ed2-b3e9-cf0d5e410c53', 5, 1),
('77c1d103-be42-5603-afe4-aa34ef8e95d5', 'f1447257-630a-5ea2-beba-2f18baed94f2', 'fe233cec-4919-5535-bb77-ddb2b8da273a', '1359ad2c-4474-55c7-b8cf-89c51d3d11b0', 6, 2),
('96825a12-45d4-531b-bf8b-22ac409a715a', 'f1447257-630a-5ea2-beba-2f18baed94f2', '40587d1b-13f4-5684-b2aa-c5b2ff500b61', '4890071d-60a0-5d7b-ac99-debbc80187d8', 7, 2),
('3df5c8e9-b093-53bf-a500-288b9f01ec0b', 'f1447257-630a-5ea2-beba-2f18baed94f2', '9c54d43d-6127-57d3-bbb5-b7a092a5314c', 'e778de67-8a43-5bab-8fdd-74f2969f080b', 8, 4),
('8f8427b8-5c9d-5ca6-bc43-b5fcc90cbd79', 'f1447257-630a-5ea2-beba-2f18baed94f2', '674ed6ba-133b-5866-8c8f-d20939f2f9bb', 'ce9a787c-f76a-52eb-bb2b-daa81f312fc8', 9, 4),
('2aa80447-1a73-5d51-a2c9-664b2ad3de1a', 'f1447257-630a-5ea2-beba-2f18baed94f2', '99c5039f-8eda-56ef-9771-8193682303e3', '4c0ac0f3-0cec-5d6f-835c-1adba5bcefd4', 10, 3)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('0900d381-5b65-53fa-b3f4-5381da3bf995', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', 'c34f1e45-8786-58ed-afcf-af84b44f06c8', 'Capstone Assessment: Java Mastery', 'assessment', 5, 45, 'f1447257-630a-5ea2-beba-2f18baed94f2')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('08664d69-976d-587c-b35c-059a9a2c68ef', '00000000-0000-0000-0000-000000000014', '2166677d-878d-5c38-b01b-0ce7d5e4edc7', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

