---
kind: lesson
id_key: java-mastery/design-patterns/singleton-factory
course: java-mastery
section: design-patterns
section_title: "Design Patterns"
section_position: 14
title: "Singleton and Factory Patterns"
position: 2
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
Singleton and Factory are both **creational** patterns — they're about controlling *how* objects come into existence, rather than what they do once they exist.

## The Singleton pattern

A Singleton guarantees a class has exactly one instance, accessible globally. TaskFlow needs this for a `TaskIdGenerator`: if two instances existed, they could hand out the same ID to two different tasks, corrupting data. Only one generator should ever exist for the whole running application.

```java
public class Main {
    public static void main(String[] args) {
        TaskIdGenerator gen1 = TaskIdGenerator.getInstance();
        TaskIdGenerator gen2 = TaskIdGenerator.getInstance();

        System.out.println("Same instance? " + (gen1 == gen2));
        System.out.println("Next ID: " + gen1.nextId());
        System.out.println("Next ID: " + gen2.nextId());
    }
}

class TaskIdGenerator {
    private static TaskIdGenerator instance;
    private int counter = 0;

    private TaskIdGenerator() {
        // private constructor prevents `new TaskIdGenerator()` from outside
    }

    public static TaskIdGenerator getInstance() {
        if (instance == null) {
            instance = new TaskIdGenerator();
        }
        return instance;
    }

    public synchronized int nextId() {
        counter++;
        return counter;
    }
}
```

This works fine in a single-threaded example like this one, but `getInstance()` itself is **not thread-safe**. Two threads can both pass the `instance == null` check before either finishes assigning it, and each ends up constructing its own separate `TaskIdGenerator` — silently breaking the "exactly one instance" guarantee. It's a bug that only shows up under real concurrent load, never in a simple demo like this.

A clean, thread-safe fix is the **static holder idiom**:

```java
public class Main {
    public static void main(String[] args) {
        TaskIdGenerator gen1 = TaskIdGenerator.getInstance();
        TaskIdGenerator gen2 = TaskIdGenerator.getInstance();

        System.out.println("Same instance? " + (gen1 == gen2));
        System.out.println("Next ID: " + gen1.nextId());
        System.out.println("Next ID: " + gen2.nextId());
    }
}

class TaskIdGenerator {
    private int counter = 0;

    private TaskIdGenerator() {
    }

    // The JVM guarantees a class is loaded (and its static fields
    // initialized) lazily, on first access, and exactly once — even
    // under concurrent access. No synchronized keyword needed here.
    private static class Holder {
        private static final TaskIdGenerator INSTANCE = new TaskIdGenerator();
    }

    public static TaskIdGenerator getInstance() {
        return Holder.INSTANCE;
    }

    public synchronized int nextId() {
        counter++;
        return counter;
    }
}
```

`Holder` isn't loaded until `getInstance()` is first called, so construction is still lazy — but class loading itself is synchronized by the JVM's classloader, so the instance gets built exactly once no matter how many threads call `getInstance()` concurrently, with no explicit `synchronized` on the getter and no double-checked-locking subtlety to get wrong. If construction is cheap and laziness doesn't matter, an even simpler fix is eager initialization — `private static final TaskIdGenerator INSTANCE = new TaskIdGenerator();` directly on the field — which is thread-safe by that same class-loading guarantee, just less lazy.

## The Factory pattern

A Factory centralizes object-creation logic, especially useful when the concrete type to build depends on runtime input. TaskFlow has `BugTask`, `FeatureTask`, and `ChoreTask` — all `Task` subtypes with different default behavior — and a `TaskFactory` picks the right one based on a type string.

```java
public class Main {
    public static void main(String[] args) {
        Task bug = TaskFactory.createTask("BUG", "Fix login crash", 3);
        Task feature = TaskFactory.createTask("FEATURE", "Add dark mode", 8);
        Task chore = TaskFactory.createTask("CHORE", "Update dependencies", 1);

        for (Task t : new Task[] { bug, feature, chore }) {
            System.out.println(t.describe());
        }
    }
}

abstract class Task {
    protected final String name;
    protected final int estimateHours;

    protected Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public abstract String describe();
}

class BugTask extends Task {
    BugTask(String name, int estimateHours) {
        super(name, estimateHours);
    }

    @Override
    public String describe() {
        return "[BUG, P0 by default] " + name + " (" + estimateHours + "h)";
    }
}

class FeatureTask extends Task {
    FeatureTask(String name, int estimateHours) {
        super(name, estimateHours);
    }

    @Override
    public String describe() {
        return "[FEATURE] " + name + " (" + estimateHours + "h)";
    }
}

class ChoreTask extends Task {
    ChoreTask(String name, int estimateHours) {
        super(name, estimateHours);
    }

    @Override
    public String describe() {
        return "[CHORE, low priority] " + name + " (" + estimateHours + "h)";
    }
}

class TaskFactory {
    public static Task createTask(String type, String name, int estimateHours) {
        switch (type) {
            case "BUG":
                return new BugTask(name, estimateHours);
            case "FEATURE":
                return new FeatureTask(name, estimateHours);
            case "CHORE":
                return new ChoreTask(name, estimateHours);
            default:
                throw new IllegalArgumentException("Unknown task type: " + type);
        }
    }
}
```

Callers never call `new BugTask(...)` directly — they ask the factory for a `Task` by type and get back the right concrete subtype, already correctly configured. This decouples "what kind of task am I creating" from "how does the rest of the app use a `Task`" — callers only ever depend on the `Task` abstraction, which is Dependency Inversion in action. Notice the `switch` inside the factory is the one place OCP is deliberately relaxed: the factory itself *does* need editing when a new task type is added, but that's a single, contained location instead of `instanceof` checks and `new` calls scattered across the codebase.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "design-patterns-singleton-factory-q1",
      "type": "mcq",
      "prompt": "Why is the naive lazy Singleton's getInstance() method not thread-safe?",
      "options": [
        { "id": "a", "text": "It never actually creates an instance" },
        { "id": "b", "text": "Two threads can both see instance == null before either finishes assigning it, creating two separate instances" },
        { "id": "c", "text": "The private constructor throws an exception under concurrency" },
        { "id": "d", "text": "Static fields cannot be read by more than one thread" }
      ],
      "correct": "b",
      "explanation": "Without synchronization, the null-check and the assignment aren't atomic together — two threads can race through the check before either one finishes construction, breaking the single-instance guarantee."
    },
    {
      "id": "design-patterns-singleton-factory-q2",
      "type": "mcq",
      "prompt": "Why does TaskIdGenerator's constructor need to be private?",
      "options": [
        { "id": "a", "text": "Private constructors compile faster" },
        { "id": "b", "text": "It prevents any code outside the class from calling `new TaskIdGenerator()` and creating additional instances" },
        { "id": "c", "text": "Java requires all Singleton constructors to be private by law" },
        { "id": "d", "text": "It has no real effect — it's just a convention" }
      ],
      "correct": "b",
      "explanation": "The whole point of a Singleton is that the only way to obtain an instance is through getInstance(). A public constructor would let any caller bypass that and create extra instances."
    },
    {
      "id": "design-patterns-singleton-factory-q3",
      "type": "mcq",
      "prompt": "What does the static holder idiom rely on to be thread-safe without an explicit synchronized keyword?",
      "options": [
        { "id": "a", "text": "The JVM's guarantee that a class's static fields are initialized lazily and exactly once, even under concurrent access" },
        { "id": "b", "text": "The garbage collector pausing all other threads during initialization" },
        { "id": "c", "text": "Random chance — it isn't actually guaranteed to be safe" },
        { "id": "d", "text": "The final keyword on the outer class" }
      ],
      "correct": "a",
      "explanation": "The JVM's classloader synchronizes class initialization internally, so the nested Holder class's static field is set up exactly once no matter how many threads call getInstance() at the same time."
    },
    {
      "id": "design-patterns-singleton-factory-q4",
      "type": "mcq",
      "prompt": "What's the main benefit of routing Task creation through TaskFactory.createTask(...) instead of calling `new BugTask(...)`, `new FeatureTask(...)`, etc. directly throughout the codebase?",
      "options": [
        { "id": "a", "text": "It makes the Task subclasses run faster" },
        { "id": "b", "text": "It centralizes the type-to-subclass decision in one place, so callers only depend on the Task abstraction" },
        { "id": "c", "text": "It removes the need for inheritance entirely" },
        { "id": "d", "text": "It automatically makes Task thread-safe" }
      ],
      "correct": "b",
      "explanation": "Callers ask for a Task by type and never need to know which concrete subclass they got. If a new task type is added, only the factory changes — call sites elsewhere in the app stay untouched."
    }
  ]
}
```

## What's next

Next: **Builder** and **Observer** — a fluent way to construct a `Task` with many optional fields, and a way for other parts of TaskFlow to react when a task's status changes.
