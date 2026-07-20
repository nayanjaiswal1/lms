---
kind: lesson
id_key: java-mastery/oop-basics/encapsulation
course: java-mastery
section: oop-basics
section_title: "OOP Basics"
section_position: 3
title: "Encapsulation"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
The previous lesson's `Task` had public fields — any code, anywhere, could write `task.estimatedHours = -5;` and the class would have no way to stop it. **Encapsulation** means making fields `private` and exposing controlled access through public methods, so the class itself is the only code that can put its fields in an invalid state.

## private fields, public getters and setters

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Refactor auth module", 5);

        task.setEstimatedHours(8);
        System.out.println(task.getName() + ": " + task.getEstimatedHours() + "h");

        task.setEstimatedHours(-3); // invalid — rejected, value stays unchanged
        System.out.println("After invalid update: " + task.getEstimatedHours() + "h");
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        setEstimatedHours(estimatedHours);
    }

    public String getName() {
        return name;
    }

    public int getEstimatedHours() {
        return estimatedHours;
    }

    public void setEstimatedHours(int estimatedHours) {
        if (estimatedHours < 0) {
            System.out.println("Rejected: estimated hours cannot be negative");
            return;
        }
        this.estimatedHours = estimatedHours;
    }
}
```

`private` means only code inside the `Task` class itself can access `name` and `estimatedHours` directly — `task.estimatedHours` from `Main` would no longer even compile. Instead, `getEstimatedHours()` (a **getter**) and `setEstimatedHours(...)` (a **setter**) are the only doors in and out, and the setter can enforce a rule the field alone never could: no negative hours. Notice the constructor calls `setEstimatedHours(estimatedHours)` instead of assigning the field directly, so brand-new objects get the same validation as later updates — one rule, enforced everywhere, instead of duplicated in two places.

This is why direct public field access is considered a design smell: it lets any caller put the object into a state the class never intended to allow, and it means the class can never change how a value is stored or validated later without breaking every piece of code that touched the field directly. A setter is a seam you can add logic to later without changing anyone's calling code.

## Validating on write, not just accepting

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("  ", 4);
        System.out.println("Name was rejected, defaulted to: \"" + task.getName() + "\"");

        task.setName("Write API docs");
        System.out.println("Name updated to: \"" + task.getName() + "\"");
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        setName(name);
        this.estimatedHours = estimatedHours;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        if (name == null || name.trim().isEmpty()) {
            this.name = "Untitled task";
            return;
        }
        this.name = name.trim();
    }
}
```

`setName` rejects blank or `null` names, falling back to a sensible default instead of letting an empty task title slip into the system. This kind of validation is exactly what public fields can't provide — a field assignment (`task.name = "";`) has no way to run a check.

## Read-only fields: a getter with no setter

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task(101, "Migrate database", 6);
        System.out.println("Task #" + task.getId() + ": " + task.getName());
        // task.id = 202; // would not compile: id is private and has no setter
    }
}

class Task {
    private final int id;
    private String name;
    private int estimatedHours;

    Task(int id, String name, int estimatedHours) {
        this.id = id;
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    public int getId() {
        return id;
    }

    public String getName() {
        return name;
    }
}
```

Encapsulation isn't only about validation — it's also about deciding what's mutable at all. `id` is `private final` and set once in the constructor, with only a getter and no setter: it's readable from outside the class but permanently fixed once the object exists, which is exactly right for something like a database-assigned identifier that should never change after creation.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-basics-encapsulation-q1",
      "type": "mcq",
      "prompt": "Why does putting validation logic in a setter (like rejecting negative hours) work better than relying on callers to check values themselves?",
      "options": [
        { "id": "a", "text": "It doesn't — setters and public fields provide identical guarantees" },
        { "id": "b", "text": "The validation runs every time the field changes, from any caller, so the rule can never be bypassed or forgotten" },
        { "id": "c", "text": "Setters are faster to execute than direct field assignment" },
        { "id": "d", "text": "Only setters are allowed to be public in Java" }
      ],
      "correct": "b",
      "explanation": "A setter centralizes the rule inside the class. Every caller, including the constructor, goes through the same check — there's no path to an invalid value that skips validation, unlike relying on each caller to remember to check."
    },
    {
      "id": "oop-basics-encapsulation-q2",
      "type": "mcq",
      "prompt": "A field is declared `private int estimatedHours;` with no direct field access from outside the class. What happens if code outside Task writes `task.estimatedHours = 10;`?",
      "options": [
        { "id": "a", "text": "It works exactly like a public field" },
        { "id": "b", "text": "It compiles but silently does nothing" },
        { "id": "c", "text": "It fails to compile — private fields are only accessible from within the same class" },
        { "id": "d", "text": "It throws a runtime exception" }
      ],
      "correct": "c",
      "explanation": "private restricts access to code inside the declaring class. Any access attempt from outside — including a direct field write — is a compile-time error, not a runtime one."
    },
    {
      "id": "oop-basics-encapsulation-q3",
      "type": "mcq",
      "prompt": "A class exposes getId() but no setId(). What does that design communicate?",
      "options": [
        { "id": "a", "text": "id is a bug and should have a setter added" },
        { "id": "b", "text": "id is intentionally read-only from outside the class — readable, but not meant to change after construction" },
        { "id": "c", "text": "id must be a static field" },
        { "id": "d", "text": "Getters always require a matching setter to compile" }
      ],
      "correct": "b",
      "explanation": "Encapsulation lets a class expose exactly the access it wants — a getter with no setter is a deliberate way to make a value externally readable but immutable once set, which is common for identifiers assigned at creation time."
    }
  ]
}
```

## What's next

The next lesson covers `this` in more depth — including constructor delegation — plus the difference between **static** members (shared across every instance) and **instance** members (one copy per object), using a running count of every `Task` ever created.
