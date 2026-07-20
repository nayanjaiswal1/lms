---
kind: lesson
id_key: java-mastery/generics/wildcards-type-erasure
course: java-mastery
section: generics
section_title: "Generics"
section_position: 8
title: "Wildcards & Type Erasure"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
So far every generic has used a concrete type parameter: `Repository<Task>`, `List<Task>`. Sometimes a method doesn't care about the *exact* type parameter — it just needs "a list of tasks, or anything more specific" to read from, or "a list I can dump tasks into." That's what wildcards (`?`) are for.

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
