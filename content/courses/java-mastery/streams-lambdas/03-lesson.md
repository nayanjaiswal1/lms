---
kind: lesson
id_key: java-mastery/streams-lambdas/stream-api
course: java-mastery
section: streams-lambdas
section_title: "Lambdas & the Stream API"
section_position: 10
title: "The Stream API"
position: 2
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
A `Stream` is a pipeline for processing a sequence of elements — filter some out, transform the rest, and collect or reduce the result — expressed declaratively (*what* you want) instead of imperatively (a manual loop describing *how* to get it, step by step). Streams don't store data themselves; they're a view over a source (usually a collection) that you build a pipeline on top of.

## `filter`, `map`, `collect` — the core trio

```java
import java.util.List;
import java.util.stream.Collectors;

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
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Fix prod outage", 2, "HIGH"),
            new Task("Update changelog", 1, "LOW"),
            new Task("Security patch", 4, "HIGH"),
            new Task("Refactor auth module", 8, "MEDIUM")
        );

        // filter() keeps elements matching a Predicate; map() transforms each element;
        // collect() gathers the results back into a concrete collection
        List<String> highPriorityNames = tasks.stream()
            .filter(task -> task.getPriority().equals("HIGH"))
            .map(Task::getName)
            .collect(Collectors.toList());

        System.out.println(highPriorityNames);
    }
}
```

`.stream()` turns the `List<Task>` into a `Stream<Task>`. `.filter(...)` takes a `Predicate<Task>` (a lambda returning `boolean`) and keeps only matching elements. `.map(...)` takes a `Function<Task, String>` (here, the `Task::getName` method reference from the last lesson) and transforms each remaining `Task` into a `String`. `.collect(Collectors.toList())` runs the whole pipeline and gathers the output into a real `List<String>`. Nothing runs until `collect` is called — streams are **lazy**, building up a plan of operations that only executes when a terminal operation like `collect` triggers it.

## `sorted()`

```java
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

class Task {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }

    @Override
    public String toString() { return name + " (" + estimateHours + "h)"; }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Build REST API", 10),
            new Task("Write tests", 4),
            new Task("Design schema", 6)
        );

        List<Task> byHoursAscending = tasks.stream()
            .sorted(Comparator.comparingInt(Task::getEstimateHours))
            .collect(Collectors.toList());

        System.out.println("Ascending: " + byHoursAscending);

        List<Task> byHoursDescending = tasks.stream()
            .sorted(Comparator.comparingInt(Task::getEstimateHours).reversed())
            .collect(Collectors.toList());

        System.out.println("Descending: " + byHoursDescending);
    }
}
```

`sorted()` returns a new sorted stream without mutating the original list — a stream pipeline never touches its source collection, it only reads from it. `Comparator.comparingInt(Task::getEstimateHours)` builds a `Comparator<Task>` from a method reference extracting the value to compare on; `.reversed()` flips any comparator's order.

## `reduce()` — combining everything into one value

```java
import java.util.List;

class Task {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public int getEstimateHours() { return estimateHours; }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Build REST API", 10),
            new Task("Write tests", 4),
            new Task("Design schema", 6)
        );

        // reduce(identity, accumulator): start at 0, combine each element into the running total
        int totalHours = tasks.stream()
            .map(Task::getEstimateHours)
            .reduce(0, (runningTotal, hours) -> runningTotal + hours);

        System.out.println("Total estimated hours: " + totalHours);

        // For plain sums, IntStream's built-in sum() is even more direct:
        int totalHoursAlt = tasks.stream()
            .mapToInt(Task::getEstimateHours) // map() to a primitive int stream
            .sum();

        System.out.println("Total (via mapToInt/sum): " + totalHoursAlt);
    }
}
```

`reduce(identity, accumulator)` folds a stream down to a single value: `identity` (`0`) is the starting point, and `accumulator` combines the running result with each element in turn. It's the general-purpose tool — for the specific, extremely common case of summing numbers, `mapToInt(...)` converts to a primitive `IntStream`, which has a direct `.sum()` (avoiding the overhead of boxing every value to `Integer`, which the `Integer`-based `Stream<Integer>` version would otherwise incur).

## Chaining it all together

```java
import java.util.List;
import java.util.stream.Collectors;

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

    @Override
    public String toString() { return name + " (" + estimateHours + "h)"; }
}

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Fix prod outage", 2, "HIGH"),
            new Task("Update changelog", 1, "LOW"),
            new Task("Security patch", 4, "HIGH"),
            new Task("Refactor auth module", 8, "MEDIUM")
        );

        List<String> report = tasks.stream()
            .filter(task -> task.getPriority().equals("HIGH"))
            .sorted((a, b) -> Integer.compare(a.getEstimateHours(), b.getEstimateHours()))
            .map(Task::toString)
            .collect(Collectors.toList());

        System.out.println("HIGH priority tasks, by hours ascending:");
        report.forEach(System.out::println);
    }
}
```

Each stage — `filter`, `sorted`, `map` — returns a new stream, so calls chain fluently into a single pipeline that reads top to bottom as a description of the transformation, with `collect` as the one terminal operation at the end that actually triggers all of it to run.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "streams-lambdas-stream-api-q1",
      "type": "mcq",
      "prompt": "When does a stream pipeline like tasks.stream().filter(...).map(...) actually execute?",
      "options": [
        { "id": "a", "text": "Immediately, as soon as .stream() is called" },
        { "id": "b", "text": "As soon as .filter() runs" },
        { "id": "c", "text": "Only when a terminal operation like collect() or reduce() is called — streams are lazy until then" },
        { "id": "d", "text": "On a background thread automatically" }
      ],
      "correct": "c",
      "explanation": "filter() and map() are intermediate operations that just build up a pipeline description. Nothing actually runs over the data until a terminal operation (collect, reduce, forEach, sum, etc.) is invoked."
    },
    {
      "id": "streams-lambdas-stream-api-q2",
      "type": "mcq",
      "prompt": "What does tasks.stream().map(Task::getEstimateHours).reduce(0, (total, hours) -> total + hours) compute?",
      "options": [
        { "id": "a", "text": "The average of all estimateHours values" },
        { "id": "b", "text": "The sum of all estimateHours values, starting from 0" },
        { "id": "c", "text": "The maximum estimateHours value" },
        { "id": "d", "text": "The count of tasks" }
      ],
      "correct": "b",
      "explanation": "reduce(0, accumulator) starts with identity value 0 and repeatedly combines it with each stream element using the accumulator function, here effectively summing all the hours values."
    },
    {
      "id": "streams-lambdas-stream-api-q3",
      "type": "mcq",
      "prompt": "Does calling tasks.stream().sorted(...) modify the original tasks list?",
      "options": [
        { "id": "a", "text": "Yes, it sorts the list in place" },
        { "id": "b", "text": "No — sorted() returns a new sorted stream, leaving the original source collection unchanged" },
        { "id": "c", "text": "Only if tasks is declared with var" },
        { "id": "d", "text": "It throws an exception if the list isn't already sorted" }
      ],
      "correct": "b",
      "explanation": "Stream operations never mutate their source. sorted() (like filter and map) produces a new stream; the underlying List<Task> tasks was created from is left exactly as it was."
    }
  ]
}
```

## What's next

Stream pipelines that search for something — like finding a specific task by name — often come up empty. The next lesson covers `Optional`, Java's type-safe alternative to returning `null` for "nothing found."
