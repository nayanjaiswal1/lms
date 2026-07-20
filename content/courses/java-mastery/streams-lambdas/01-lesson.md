---
kind: lesson
id_key: java-mastery/streams-lambdas/functional-interfaces-lambdas
course: java-mastery
section: streams-lambdas
section_title: "Lambdas & the Stream API"
section_position: 10
title: "Functional Interfaces & Lambda Expressions"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Java 8 added the ability to pass a *chunk of behavior* — not just a value — as an argument to a method. That capability is built entirely on top of an existing Java concept: an interface with exactly one abstract method, called a **functional interface**.

## Functional interfaces: an interface with one job

```java
@FunctionalInterface
interface TaskFilter {
    boolean matches(Task task);
}

class Task {
    private final String name;
    private final int estimateHours;
    private final String priority;

    public Task(String name, int estimateHours, String priority) {
        this.name = name;
        this.estimateHours = estimateHours;
        this.priority = priority;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
    public String getPriority() { return priority; }
}

public class Main {
    static void printMatching(Task task, TaskFilter filter) {
        if (filter.matches(task)) {
            System.out.println("Matched: " + task.getName());
        } else {
            System.out.println("No match: " + task.getName());
        }
    }

    public static void main(String[] args) {
        Task urgent = new Task("Fix prod outage", 2, "HIGH");

        // An anonymous inner class implementing TaskFilter — the pre-lambda way
        TaskFilter isHighPriority = new TaskFilter() {
            @Override
            public boolean matches(Task task) {
                return task.getPriority().equals("HIGH");
            }
        };

        printMatching(urgent, isHighPriority);
    }
}
```

`@FunctionalInterface` is an optional but recommended annotation: it tells the compiler "this interface must have exactly one abstract method," and the compiler enforces it, catching a mistake (like accidentally adding a second abstract method) immediately instead of it silently breaking lambda usage elsewhere. `TaskFilter` has exactly one: `matches`. The anonymous inner class above works, but it's seven lines of ceremony to express one line of actual logic (`task.getPriority().equals("HIGH")`).

## The same thing as a lambda

```java
@FunctionalInterface
interface TaskFilter {
    boolean matches(Task task);
}

class Task {
    private final String name;
    private final int estimateHours;
    private final String priority;

    public Task(String name, int estimateHours, String priority) {
        this.name = name;
        this.estimateHours = estimateHours;
        this.priority = priority;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
    public String getPriority() { return priority; }
}

public class Main {
    static void printMatching(Task task, TaskFilter filter) {
        if (filter.matches(task)) {
            System.out.println("Matched: " + task.getName());
        } else {
            System.out.println("No match: " + task.getName());
        }
    }

    public static void main(String[] args) {
        Task urgent = new Task("Fix prod outage", 2, "HIGH");
        Task minor = new Task("Update changelog", 1, "LOW");

        // Same logic, expressed as a lambda: (parameters) -> expression
        TaskFilter isHighPriority = task -> task.getPriority().equals("HIGH");

        printMatching(urgent, isHighPriority);
        printMatching(minor, isHighPriority);
    }
}
```

`task -> task.getPriority().equals("HIGH")` is a **lambda expression**: the parameter (`task`) on the left of `->`, the body (an expression that becomes the return value) on the right. The compiler knows this lambda must implement `TaskFilter.matches(Task)` because of the variable's declared type (`TaskFilter isHighPriority = ...`) — that's how it infers `task`'s type without you writing `Task task` explicitly. No class name, no `@Override`, no boilerplate — just the behavior itself.

## Built-in functional interfaces you already know

Java ships common functional interfaces in `java.lang` and `java.util.function` so you rarely need to declare your own like `TaskFilter` above (it's here for teaching purposes — in real code, `java.util.function.Predicate<Task>` does the identical job):

```java
import java.util.List;
import java.util.Comparator;

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
    public static void main(String[] args) {
        // Runnable — zero args, no return value
        Runnable logStartup = () -> System.out.println("TaskFlow worker starting...");
        logStartup.run();

        // Comparator<Task> — two args, returns an int (a functional interface from java.util)
        Comparator<Task> byHours = (a, b) -> Integer.compare(a.getEstimateHours(), b.getEstimateHours());

        List<Task> tasks = new java.util.ArrayList<>(List.of(
            new Task("Build REST API", 10),
            new Task("Write tests", 4),
            new Task("Design schema", 6)
        ));
        tasks.sort(byHours);

        for (Task t : tasks) {
            System.out.println(t.getName() + " - " + t.getEstimateHours() + "h");
        }
    }
}
```

`Comparator<Task>` is a functional interface (one abstract method: `compare`) that already existed before Java 8 — lambdas just made it dramatically less verbose to implement inline, which is why `.sort(...)` calls with a lambda comparator are everywhere in modern Java code.

## Multi-statement lambda bodies

When a lambda needs more than one expression, wrap the body in `{ }` and use an explicit `return`:

```java
public class Main {
    interface HoursValidator {
        boolean isValid(int hours);
    }

    public static void main(String[] args) {
        HoursValidator validator = hours -> {
            if (hours <= 0) {
                return false;
            }
            return hours <= 40; // no single task should be estimated over a 40-hour work week
        };

        System.out.println(validator.isValid(6));
        System.out.println(validator.isValid(-2));
        System.out.println(validator.isValid(80));
    }
}
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "streams-lambdas-functional-interfaces-lambdas-q1",
      "type": "mcq",
      "prompt": "What makes an interface eligible to be implemented by a lambda expression?",
      "options": [
        { "id": "a", "text": "It must be marked public" },
        { "id": "b", "text": "It must have exactly one abstract method (a functional interface)" },
        { "id": "c", "text": "It must extend Runnable" },
        { "id": "d", "text": "It must contain only static methods" }
      ],
      "correct": "b",
      "explanation": "A lambda expression provides the implementation for exactly one method, so it can only stand in for an interface with exactly one abstract method — a functional interface. Default and static methods on the interface don't count against that limit."
    },
    {
      "id": "streams-lambdas-functional-interfaces-lambdas-q2",
      "type": "mcq",
      "prompt": "In `TaskFilter isHighPriority = task -> task.getPriority().equals(\"HIGH\");`, how does the compiler know the type of `task`?",
      "options": [
        { "id": "a", "text": "It defaults to Object" },
        { "id": "b", "text": "It's inferred from TaskFilter's single abstract method signature, matches(Task task), because the variable is declared as TaskFilter" },
        { "id": "c", "text": "You must always write the type explicitly in a lambda, so this example is actually invalid" },
        { "id": "d", "text": "It's inferred from the return type of the expression" }
      ],
      "correct": "b",
      "explanation": "This is called target typing: the compiler looks at the functional interface the lambda is being assigned to (TaskFilter, whose one method takes a Task) and infers the lambda parameter's type from that method's signature."
    },
    {
      "id": "streams-lambdas-functional-interfaces-lambdas-q3",
      "type": "mcq",
      "prompt": "When must a lambda body use { } with an explicit return statement instead of a bare expression?",
      "options": [
        { "id": "a", "text": "Always — bare expressions are never allowed in lambdas" },
        { "id": "b", "text": "When the lambda's logic requires more than a single expression, e.g. an if/else or multiple statements" },
        { "id": "c", "text": "Only when the lambda has zero parameters" },
        { "id": "d", "text": "Only for lambdas assigned to Comparator" }
      ],
      "correct": "b",
      "explanation": "A single-expression lambda body implicitly returns that expression's value. Once you need multiple statements or branching logic, you switch to a block body with braces and an explicit return."
    }
  ]
}
```

## What's next

Lambdas that just call one existing method — like `task -> task.getName()` — have an even shorter form: method references. The next lesson shows the same logic written both ways, side by side.
