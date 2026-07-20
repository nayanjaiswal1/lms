---
kind: lesson
id_key: java-mastery/oop-advanced/inheritance-and-super
course: java-mastery
section: oop-advanced
section_title: "Advanced OOP"
section_position: 4
title: "Inheritance and super"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every `Task` so far has been the same shape. Real TaskFlow tasks aren't uniform — an urgent task needs an escalation contact that a normal task doesn't. **Inheritance** lets one class (a subclass) build on another (a superclass), reusing its fields and methods and adding its own on top, instead of copy-pasting `Task` and modifying the copy.

## extends and super(...)

```java
public class Main {
    public static void main(String[] args) {
        Task normalTask = new Task("Update changelog", 2);
        UrgentTask urgentTask = new UrgentTask("Fix production outage", 1, "oncall@taskflow.dev");

        System.out.println(normalTask.getName() + " — " + normalTask.getEstimatedHours() + "h");
        System.out.println(urgentTask.getName() + " — " + urgentTask.getEstimatedHours()
                + "h, escalate to " + urgentTask.getEscalationContact());
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    public String getName() {
        return name;
    }

    public int getEstimatedHours() {
        return estimatedHours;
    }
}

class UrgentTask extends Task {
    private String escalationContact;

    UrgentTask(String name, int estimatedHours, String escalationContact) {
        super(name, estimatedHours); // must be the first statement in the subclass constructor
        this.escalationContact = escalationContact;
    }

    public String getEscalationContact() {
        return escalationContact;
    }
}
```

`class UrgentTask extends Task` declares an **is-a** relationship: every `UrgentTask` is a `Task`, plus something extra. `Task`'s fields are `private`, so `UrgentTask` can't touch `name` or `estimatedHours` directly — instead, `super(name, estimatedHours)` calls `Task`'s constructor to initialize the inherited part of the object. `super(...)` must be the **first statement** in the subclass constructor, because the superclass portion of the object has to be fully constructed before the subclass adds anything on top of it — the compiler enforces this with a hard error, not a warning.

## Inherited methods, used for free

```java
public class Main {
    public static void main(String[] args) {
        UrgentTask task = new UrgentTask("Database failover", 1, "oncall@taskflow.dev");
        task.notifyOnCall();
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    public String getName() {
        return name;
    }
}

class UrgentTask extends Task {
    private String escalationContact;

    UrgentTask(String name, int estimatedHours, String escalationContact) {
        super(name, estimatedHours);
        this.escalationContact = escalationContact;
    }

    void notifyOnCall() {
        // getName() is inherited from Task — UrgentTask never had to redefine it
        System.out.println("Paging " + escalationContact + " about: " + getName());
    }
}
```

`UrgentTask` never declares `getName()` — it doesn't need to. Every `public` (and `protected`) method on `Task` is automatically available on `UrgentTask` too, called exactly as if it had been declared there. This is the payoff of inheritance: shared behavior is written once, in the superclass, and every subclass gets it without repetition.

## super.method(): reaching the parent's version

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Renew SSL cert", 1);
        UrgentTask urgent = new UrgentTask("Payment gateway down", 1, "oncall@taskflow.dev");

        System.out.println(task.describe());
        System.out.println(urgent.describe());
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    String describe() {
        return name + " (" + estimatedHours + "h)";
    }
}

class UrgentTask extends Task {
    private String escalationContact;

    UrgentTask(String name, int estimatedHours, String escalationContact) {
        super(name, estimatedHours);
        this.escalationContact = escalationContact;
    }

    @Override
    String describe() {
        return super.describe() + " [URGENT — escalate to " + escalationContact + "]";
    }
}
```

`UrgentTask` **overrides** `describe()` here — redefining a method it inherited, rather than adding a new one. `super.describe()` inside the override calls `Task`'s original version explicitly, so `UrgentTask` can build on the parent's output instead of duplicating it. `@Override` is optional but strongly recommended: it tells the compiler "I intend to override an inherited method," and the compiler will flag an error if the signature doesn't actually match anything in the superclass — catching typos that would otherwise silently create an unrelated new method instead of overriding.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-advanced-inheritance-and-super-q1",
      "type": "mcq",
      "prompt": "Where must a call to super(...) appear in a subclass constructor?",
      "options": [
        { "id": "a", "text": "Anywhere, order doesn't matter" },
        { "id": "b", "text": "As the first statement — the superclass portion of the object must be initialized before the subclass adds to it" },
        { "id": "c", "text": "As the last statement" },
        { "id": "d", "text": "It's optional and can be omitted even when the superclass has no no-argument constructor" }
      ],
      "correct": "b",
      "explanation": "The compiler requires super(...) to be the first statement in a subclass constructor, since the inherited part of the object has to exist before subclass-specific initialization runs on top of it."
    },
    {
      "id": "oop-advanced-inheritance-and-super-q2",
      "type": "mcq",
      "prompt": "class UrgentTask extends Task declares what kind of relationship?",
      "options": [
        { "id": "a", "text": "A has-a relationship — UrgentTask contains a Task" },
        { "id": "b", "text": "An is-a relationship — every UrgentTask is also a Task, plus additional behavior" },
        { "id": "c", "text": "No relationship; extends only affects imports" },
        { "id": "d", "text": "UrgentTask replaces Task entirely at compile time" }
      ],
      "correct": "b",
      "explanation": "extends establishes inheritance, an is-a relationship: a UrgentTask object is also a valid Task — it inherits Task's public and protected members and can be used anywhere a Task is expected."
    },
    {
      "id": "oop-advanced-inheritance-and-super-q3",
      "type": "mcq",
      "prompt": "Inside an overriding method, what does super.describe() do?",
      "options": [
        { "id": "a", "text": "Calls the overriding method's own version again, causing infinite recursion" },
        { "id": "b", "text": "Calls the superclass's original implementation of describe(), rather than the override" },
        { "id": "c", "text": "It's a compile error to call super inside an override" },
        { "id": "d", "text": "Creates a new Task object" }
      ],
      "correct": "b",
      "explanation": "super.method() explicitly invokes the superclass's version of a method from within an override, letting the subclass build on the parent's behavior instead of duplicating or completely replacing it."
    }
  ]
}
```

## What's next

The next lesson goes deeper into overriding — plus its easily-confused cousin, **overloading** — and shows how a `Task[]` holding a mix of `Task` and `UrgentTask` objects can call one overridden method and get different behavior depending on each object's actual runtime type.
