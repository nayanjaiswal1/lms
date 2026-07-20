---
kind: lesson
id_key: java-mastery/modern-java/records
course: java-mastery
section: modern-java
section_title: "Modern Java"
section_position: 15
title: "Records"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Back in the OOP modules, giving `Task` proper encapsulation meant hand-writing a constructor, private fields, getters, and — if you wanted correct `Set`/`Map` behavior and useful debug output — `equals()`, `hashCode()`, and `toString()` too. For a class that's really just "a fixed bundle of values," that's a lot of boilerplate to write and keep in sync. **Records** (Java 16+) generate all of it for you.

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
