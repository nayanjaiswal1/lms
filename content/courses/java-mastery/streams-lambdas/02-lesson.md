---
kind: lesson
id_key: java-mastery/streams-lambdas/method-references
course: java-mastery
section: streams-lambdas
section_title: "Lambdas & the Stream API"
section_position: 10
title: "Method References"
position: 1
estimated_minutes: 15
source: [java-mastery-curriculum.md]
---
A lot of lambdas do nothing but call one existing method and pass along their arguments — `task -> task.getName()` is just "call `getName()` on whatever's passed in." When a lambda is *that* thin, Java lets you skip writing it out entirely and reference the method directly. That's a **method reference**, written `Type::method`.

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
