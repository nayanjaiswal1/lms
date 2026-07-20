---
kind: lesson
id_key: java-mastery/oop-advanced/equals-hashcode-enums
course: java-mastery
section: oop-advanced
section_title: "Advanced OOP"
section_position: 4
title: "equals, hashCode, toString, and Enums"
position: 3
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Every class implicitly extends `Object`, which provides default `equals()` (identity comparison, same as `==`), `hashCode()` (an identity-based number), and `toString()` (an unhelpful `ClassName@hexhash`). Overriding these correctly — together — is one of the most consequential things a class can get right or wrong, because collections like `HashSet` and `HashMap` depend on them working as a pair.

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
