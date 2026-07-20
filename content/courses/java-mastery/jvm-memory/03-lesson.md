---
kind: lesson
id_key: java-mastery/jvm-memory/garbage-collection-basics
course: java-mastery
section: jvm-memory
section_title: "JVM & Memory Internals"
section_position: 12
title: "Garbage Collection Basics"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
In C or C++, you're responsible for manually freeing every object you allocate — forget to, and the program leaks memory forever; free it too early or twice, and you get corruption or a crash. Java sidesteps that entire category of bug with **garbage collection (GC)**: a background process built into the JVM that automatically finds objects nothing can reach anymore and reclaims their heap memory, without you ever calling `free()`.

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
