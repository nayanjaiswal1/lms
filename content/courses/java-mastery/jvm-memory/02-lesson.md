---
kind: lesson
id_key: java-mastery/jvm-memory/stack-vs-heap
course: java-mastery
section: jvm-memory
section_title: "JVM & Memory Internals"
section_position: 12
title: "Stack vs. Heap"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every time TaskFlow code calls a method or creates an object, that data has to live somewhere in memory. Java splits that "somewhere" into two very differently-behaved regions: the **stack** and the **heap**. Knowing which one a piece of data lives in explains a lot of Java's behavior that otherwise looks mysterious — why passing an object to a method lets you mutate it, why a `NullPointerException` doesn't mean the variable itself vanished, and why deeply recursive methods eventually blow up with `StackOverflowError`.

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
