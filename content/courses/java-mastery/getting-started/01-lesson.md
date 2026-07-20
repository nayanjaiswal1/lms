---
kind: lesson
id_key: java-mastery/getting-started/what-is-java
course: java-mastery
section: getting-started
section_title: "Getting Started"
section_position: 1
title: "What Java Is, and Your First Program"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Java is a **compiled, statically-typed, object-oriented** language that runs on the **JVM** (Java Virtual Machine) instead of talking to your CPU directly. That one design decision — compile to an intermediate format, run it on a virtual machine — is why "write once, run anywhere" became Java's slogan: the same compiled output runs unmodified on Windows, Linux, or macOS, as long as a JVM is installed.

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
