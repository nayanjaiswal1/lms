---
kind: lesson
id_key: java-mastery/design-patterns/strategy-pattern
course: java-mastery
section: design-patterns
section_title: "Design Patterns"
section_position: 14
title: "Strategy Pattern"
position: 4
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Strategy encapsulates a family of interchangeable algorithms behind one common interface, so the algorithm in use can be swapped at runtime without touching the code that uses it.

## The problem: hardcoded sorting logic

TaskFlow needs to sort a task list different ways depending on context — sometimes by urgency, sometimes by due date. A natural first attempt bakes the choice into an `if`/`else` inside one method:

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Design schema", 5, 3));
        tasks.add(new Task("Fix login bug", 1, 9));
        tasks.add(new Task("Write docs", 8, 1));

        sortTasks(tasks, "URGENCY");
        printTasks(tasks);

        sortTasks(tasks, "DUE_DATE");
        printTasks(tasks);
    }

    static void sortTasks(List<Task> tasks, String mode) {
        if (mode.equals("URGENCY")) {
            tasks.sort((a, b) -> b.urgency - a.urgency);
        } else if (mode.equals("DUE_DATE")) {
            tasks.sort((a, b) -> a.dueInDays - b.dueInDays);
        }
        // A third sort mode means editing this method again
    }

    static void printTasks(List<Task> tasks) {
        for (Task t : tasks) {
            System.out.println(t.name + " (urgency=" + t.urgency + ", due in " + t.dueInDays + "d)");
        }
        System.out.println("---");
    }
}

class Task {
    String name;
    int dueInDays;
    int urgency;

    Task(String name, int dueInDays, int urgency) {
        this.name = name;
        this.dueInDays = dueInDays;
        this.urgency = urgency;
    }
}
```

This is the same Open/Closed problem from the SOLID lesson, applied to sorting: every new sort mode means editing `sortTasks` and risking the existing branches.

## The Strategy fix: pluggable PriorityStrategy

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Design schema", 5, 3));
        tasks.add(new Task("Fix login bug", 1, 9));
        tasks.add(new Task("Write docs", 8, 1));

        TaskSorter sorter = new TaskSorter(new ByUrgency());
        sorter.sort(tasks);
        printTasks(tasks);

        sorter.setStrategy(new ByDueDate());
        sorter.sort(tasks);
        printTasks(tasks);
    }

    static void printTasks(List<Task> tasks) {
        for (Task t : tasks) {
            System.out.println(t.name + " (urgency=" + t.urgency + ", due in " + t.dueInDays + "d)");
        }
        System.out.println("---");
    }
}

interface PriorityStrategy {
    void sort(List<Task> tasks);
}

class ByUrgency implements PriorityStrategy {
    @Override
    public void sort(List<Task> tasks) {
        tasks.sort((a, b) -> b.urgency - a.urgency);
    }
}

class ByDueDate implements PriorityStrategy {
    @Override
    public void sort(List<Task> tasks) {
        tasks.sort((a, b) -> a.dueInDays - b.dueInDays);
    }
}

class TaskSorter {
    private PriorityStrategy strategy;

    TaskSorter(PriorityStrategy strategy) {
        this.strategy = strategy;
    }

    public void setStrategy(PriorityStrategy strategy) {
        this.strategy = strategy;
    }

    public void sort(List<Task> tasks) {
        strategy.sort(tasks);
    }
}

class Task {
    String name;
    int dueInDays;
    int urgency;

    Task(String name, int dueInDays, int urgency) {
        this.name = name;
        this.dueInDays = dueInDays;
        this.urgency = urgency;
    }
}
```

`TaskSorter` never encodes any sorting logic itself — it just delegates to whichever `PriorityStrategy` it currently holds. Swapping behavior at runtime is a `setStrategy(...)` call, not a code change. A later `ByEstimateHours` strategy is a new class; `ByUrgency` and `ByDueDate` are never touched — Open/Closed again.

## Strategy is already in the standard library

`List.sort(Comparator)` *is* the Strategy pattern: `Comparator<T>` is the strategy interface, and every lambda you pass to `.sort(...)` is an inline strategy implementation.

```java
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Design schema", 5, 3));
        tasks.add(new Task("Fix login bug", 1, 9));
        tasks.add(new Task("Write docs", 5, 1));

        // Comparator IS the Strategy interface from the standard library.
        tasks.sort(Comparator.comparingInt((Task t) -> t.dueInDays)
                .thenComparingInt(t -> -t.urgency));

        for (Task t : tasks) {
            System.out.println(t.name + " (due in " + t.dueInDays + "d, urgency=" + t.urgency + ")");
        }
    }
}

class Task {
    String name;
    int dueInDays;
    int urgency;

    Task(String name, int dueInDays, int urgency) {
        this.name = name;
        this.dueInDays = dueInDays;
        this.urgency = urgency;
    }
}
```

`Comparator.comparing(...)` and `.thenComparing(...)` compose two strategies (sort by due date, break ties by urgency) without writing a `PriorityStrategy` hierarchy at all. It's worth recognizing the pattern when the standard library already implements it for you — reaching for `Comparator` composition is usually simpler than hand-rolling your own strategy interface, and it's the same idea underneath.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-strategy-pattern-q1",
      "type": "mcq",
      "prompt": "What is the core idea of the Strategy pattern?",
      "options": [
        { "id": "a", "text": "Encapsulate interchangeable algorithms behind a common interface so they can be swapped at runtime" },
        { "id": "b", "text": "Ensure a class has only one instance" },
        { "id": "c", "text": "Notify a list of subscribers whenever state changes" },
        { "id": "d", "text": "Centralize object construction behind a factory method" }
      ],
      "correct": "a",
      "explanation": "Strategy is about swappable behavior: a context class (like TaskSorter) holds a reference to an interface (PriorityStrategy) and delegates to whichever concrete implementation is currently plugged in."
    },
    {
      "id": "design-patterns-strategy-pattern-q2",
      "type": "mcq",
      "prompt": "In the TaskSorter example, how do you change from sorting by urgency to sorting by due date at runtime?",
      "options": [
        { "id": "a", "text": "Edit the sort() method to add an else-if branch" },
        { "id": "b", "text": "Call sorter.setStrategy(new ByDueDate())" },
        { "id": "c", "text": "Create a brand-new Task class" },
        { "id": "d", "text": "Recompile the program with a different sort mode constant" }
      ],
      "correct": "b",
      "explanation": "setStrategy swaps which PriorityStrategy object TaskSorter delegates to — no source code changes needed, which is the whole point of the pattern."
    },
    {
      "id": "design-patterns-strategy-pattern-q3",
      "type": "mcq",
      "prompt": "Which standard library type is described in this lesson as an existing implementation of the Strategy pattern?",
      "options": [
        { "id": "a", "text": "Comparator<T>" },
        { "id": "b", "text": "Scanner" },
        { "id": "c", "text": "ArrayList<T>" },
        { "id": "d", "text": "Optional<T>" }
      ],
      "correct": "a",
      "explanation": "Comparator<T> is the strategy interface, and every lambda or Comparator.comparing(...) call you pass to List.sort() is a concrete, swappable strategy implementation."
    }
  ]
}
```

## What's next

The module wraps up with a graded quiz covering SOLID, Singleton, Factory, Builder, Observer, and Strategy.
