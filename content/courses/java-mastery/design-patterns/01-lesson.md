---
kind: lesson
id_key: java-mastery/design-patterns/solid-principles
course: java-mastery
section: design-patterns
section_title: "Design Patterns"
section_position: 14
title: "SOLID Principles"
position: 0
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Design patterns are named, reusable solutions to problems that show up again and again in object-oriented code. Before you can recognize a pattern, though, it helps to know the five principles that patterns are usually solving for — collectively nicknamed **SOLID**. As TaskFlow has grown across this course, some of its classes have started to strain in predictable ways: one class doing too much, a method that needs editing every time a new task type shows up, a subclass that quietly breaks what callers expect. SOLID names those problems precisely enough that you can spot them before they cause a bug.

## Single Responsibility Principle (SRP)

A class should have **one reason to change**. When a class bundles together unrelated responsibilities, a change to any one of them risks breaking (or forces a re-test of) all the others.

```java
public class Main {
    public static void main(String[] args) {
        TaskManager manager = new TaskManager();
        manager.addTask("Design database schema");
        manager.addTask("Build REST API");
        manager.printReport();
        manager.emailReport("lead@taskflow.dev");
    }
}

class TaskManager {
    private final java.util.List<String> tasks = new java.util.ArrayList<>();

    public void addTask(String name) {
        tasks.add(name);
    }

    public void printReport() {
        System.out.println("=== Task Report ===");
        for (String task : tasks) {
            System.out.println("- " + task);
        }
    }

    public void emailReport(String address) {
        // Pretend this opens a network connection and sends mail
        System.out.println("Emailing report to " + address + "...");
    }
}
```

`TaskManager` has three reasons to change: how tasks are stored, how a report is formatted, and how mail gets sent. A change to the email provider now risks a merge conflict with, and a re-test of, code that has nothing to do with email. Splitting it fixes that:

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        TaskManager manager = new TaskManager();
        manager.addTask("Design database schema");
        manager.addTask("Build REST API");

        TaskReportFormatter formatter = new TaskReportFormatter();
        String report = formatter.format(manager.getTasks());
        System.out.println(report);

        TaskReportMailer mailer = new TaskReportMailer();
        mailer.send(report, "lead@taskflow.dev");
    }
}

class TaskManager {
    private final List<String> tasks = new ArrayList<>();

    public void addTask(String name) {
        tasks.add(name);
    }

    public List<String> getTasks() {
        return tasks;
    }
}

class TaskReportFormatter {
    public String format(List<String> tasks) {
        StringBuilder sb = new StringBuilder("=== Task Report ===\n");
        for (String task : tasks) {
            sb.append("- ").append(task).append("\n");
        }
        return sb.toString();
    }
}

class TaskReportMailer {
    public void send(String report, String address) {
        // Pretend this opens a network connection and sends mail
        System.out.println("Emailing report to " + address + "...");
    }
}
```

Each class now has exactly one reason to change: `TaskManager` for storage rules, `TaskReportFormatter` for report layout, `TaskReportMailer` for how mail gets delivered. None of them needs to know about the other two's internals.

## Open/Closed Principle (OCP)

A class should be **open for extension, closed for modification** — you should be able to add new behavior without editing, and re-testing, code that already works.

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("Bug score: " + priorityScore("BUG"));
        System.out.println("Feature score: " + priorityScore("FEATURE"));
    }

    static int priorityScore(String taskType) {
        if (taskType.equals("BUG")) {
            return 90;
        } else if (taskType.equals("FEATURE")) {
            return 50;
        } else if (taskType.equals("CHORE")) {
            return 20;
        }
        // Every new task type means editing this method again
        return 0;
    }
}
```

Every new task type means opening `priorityScore` and adding another `else if` — touching code that was already working, with the risk of breaking an existing branch by accident. An OCP-friendly version pushes each rule into its own class:

```java
public class Main {
    public static void main(String[] args) {
        PriorityRule bugRule = new BugPriorityRule();
        PriorityRule featureRule = new FeaturePriorityRule();

        System.out.println("Bug score: " + bugRule.score());
        System.out.println("Feature score: " + featureRule.score());
    }
}

interface PriorityRule {
    int score();
}

class BugPriorityRule implements PriorityRule {
    @Override
    public int score() {
        return 90;
    }
}

class FeaturePriorityRule implements PriorityRule {
    @Override
    public int score() {
        return 50;
    }
}

// Adding a new task type is a new class — BugPriorityRule and
// FeaturePriorityRule are never touched again.
class ChorePriorityRule implements PriorityRule {
    @Override
    public int score() {
        return 20;
    }
}
```

Adding a `SecurityPriorityRule` later needs zero changes to `BugPriorityRule` or `FeaturePriorityRule` — only a new file. That's what "closed for modification" buys you: existing, tested behavior can't regress from a change made somewhere else.

## Liskov Substitution Principle (LSP)

Any subtype must be usable anywhere its base type is expected, without breaking the caller's reasonable assumptions. If `RecurringTask extends Task` overrides `markComplete()` to throw an exception because "recurring tasks never complete," any code that loops over a `List<Task>` calling `markComplete()` polymorphically now breaks the moment it happens to hit a `RecurringTask` — the subtype silently violates a contract the base type promised. LSP says: don't override a method to do less than, or something incompatible with, what callers of the base type reasonably expect it to do.

## Interface Segregation Principle (ISP)

Many small, focused interfaces beat one fat interface that forces implementers to stub out methods they'll never use. A single `TaskOperations` interface with `assign()`, `archive()`, `exportToPdf()`, and `syncToCalendar()` forces a minimal `ReadOnlyTaskView` implementation to provide dummy, do-nothing bodies for three methods it will never call. Splitting it into `Assignable`, `Archivable`, `Exportable`, and `CalendarSyncable` lets each class implement only the capabilities it genuinely has.

## Dependency Inversion Principle (DIP)

High-level modules shouldn't depend directly on low-level modules — both should depend on abstractions. A `TaskService` that directly `new`s up a `PostgresTaskRepository` is welded to Postgres. A `TaskService` that instead depends on a `TaskRepository` interface (with `PostgresTaskRepository` as one implementation) can be tested against an in-memory fake and swapped to a different database without touching a single line of `TaskService`. This is the principle the Factory and Strategy patterns later in this module lean on directly.

## Why this matters beyond the acronym

SOLID is the theory; the rest of this module is concrete patterns that put it into practice. Singleton and Factory (next lesson) are about controlling *how* objects get created. Builder and Observer are about constructing complex objects cleanly and reacting to their changes without tight coupling. Strategy — the module's last lesson — is Open/Closed applied directly to swappable algorithms. Recognizing SOLID violations is what tells you *when* to reach for one of these patterns in the first place.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-solid-principles-q1",
      "type": "mcq",
      "prompt": "A TaskManager class handles task storage, formats printable reports, AND sends emails. Which SOLID principle does this violate?",
      "options": [
        { "id": "a", "text": "Liskov Substitution Principle" },
        { "id": "b", "text": "Single Responsibility Principle" },
        { "id": "c", "text": "Interface Segregation Principle" },
        { "id": "d", "text": "Dependency Inversion Principle" }
      ],
      "correct": "b",
      "explanation": "SRP says a class should have one reason to change. Storage, report formatting, and emailing are three unrelated reasons to change, bundled into one class."
    },
    {
      "id": "design-patterns-solid-principles-q2",
      "type": "mcq",
      "prompt": "What does it concretely mean for a priorityScore(String taskType) method with an if/else-if chain to violate the Open/Closed Principle?",
      "options": [
        { "id": "a", "text": "It runs slower than a switch statement" },
        { "id": "b", "text": "Adding a new task type requires editing and re-testing the existing method rather than adding new code" },
        { "id": "c", "text": "It cannot be called from more than one place" },
        { "id": "d", "text": "It uses String comparison instead of an enum" }
      ],
      "correct": "b",
      "explanation": "OCP wants classes open for extension but closed for modification. Every new task type forces you back into the same method, risking regressions in branches that already worked."
    },
    {
      "id": "design-patterns-solid-principles-q3",
      "type": "mcq",
      "prompt": "A RecurringTask subclass overrides markComplete() to throw an exception, since recurring tasks conceptually never finish. Code elsewhere loops over a List<Task> calling markComplete() on each one polymorphically and now crashes on any RecurringTask. Which principle is being violated?",
      "options": [
        { "id": "a", "text": "Liskov Substitution Principle — the subtype isn't safely substitutable for its base type" },
        { "id": "b", "text": "Single Responsibility Principle" },
        { "id": "c", "text": "Open/Closed Principle" },
        { "id": "d", "text": "None — this is normal polymorphism" }
      ],
      "correct": "a",
      "explanation": "LSP requires that a subtype behave in a way that doesn't break reasonable assumptions callers make about the base type. Throwing from an overridden method that callers expect to succeed is a classic LSP violation."
    },
    {
      "id": "design-patterns-solid-principles-q4",
      "type": "mcq",
      "prompt": "A TaskService class calls `new PostgresTaskRepository()` directly inside its own constructor. Which principle would fix this, and how?",
      "options": [
        { "id": "a", "text": "Interface Segregation — split TaskService into smaller interfaces" },
        { "id": "b", "text": "Dependency Inversion — have TaskService depend on a TaskRepository interface instead of the concrete Postgres class" },
        { "id": "c", "text": "Single Responsibility — rename the class" },
        { "id": "d", "text": "Liskov Substitution — make PostgresTaskRepository final" }
      ],
      "correct": "b",
      "explanation": "DIP says high-level code (TaskService) should depend on an abstraction (TaskRepository), not a concrete low-level implementation. That's what makes it possible to test TaskService against an in-memory fake or swap databases later."
    }
  ]
}
```

## What's next

Next up: the **DRY** principle — the companion rule to SOLID that governs duplication *between* classes, and the last piece of theory before this module turns to concrete patterns.
