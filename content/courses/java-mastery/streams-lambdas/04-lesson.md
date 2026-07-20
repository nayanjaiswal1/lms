---
kind: lesson
id_key: java-mastery/streams-lambdas/optional
course: java-mastery
section: streams-lambdas
section_title: "Lambdas & the Stream API"
section_position: 10
title: "Optional"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
"Find the task named X" is a search that might fail — the task might not exist. The traditional Java answer is to return `null` when nothing's found, but `null` is a landmine: nothing in a method's signature warns a caller that it might come back, so a missed `null` check surfaces later as a `NullPointerException`, often far from where the actual problem originated. `Optional<T>` makes "this might have nothing in it" part of the type itself, impossible to ignore silently.

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
