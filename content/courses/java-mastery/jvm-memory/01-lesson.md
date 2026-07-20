---
kind: lesson
id_key: java-mastery/jvm-memory/jvm-architecture-and-class-loading
course: java-mastery
section: jvm-memory
section_title: "JVM & Memory Internals"
section_position: 12
title: "JVM Architecture and Class Loading"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
You've been running `.java` files all course without thinking much about what happens between "hit Run" and "output appears." Every TaskFlow program you write goes through the same pipeline: source code becomes bytecode, bytecode gets loaded into the JVM, and only then does anything actually execute. Understanding that pipeline is genuinely useful — it explains real errors you'll hit (`NoClassDefFoundError`, `OutOfMemoryError`) and is a near-guaranteed interview topic.

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
