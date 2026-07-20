---
kind: lesson
id_key: java-mastery/modern-java/sealed-classes
course: java-mastery
section: modern-java
section_title: "Modern Java"
section_position: 15
title: "Sealed Classes & Interfaces"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
An interface like `Notifiable` (from the OOP module) can be implemented by literally any class, anywhere, including ones written years later by someone who's never seen TaskFlow's code. Usually that openness is exactly what you want. Sometimes it isn't: you know, deliberately, the *complete* set of types something can be — and you want the compiler to enforce that, not just document it in a comment.

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
