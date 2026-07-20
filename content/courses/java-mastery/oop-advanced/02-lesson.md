---
kind: lesson
id_key: java-mastery/oop-advanced/overriding-overloading-polymorphism
course: java-mastery
section: oop-advanced
section_title: "Advanced OOP"
section_position: 4
title: "Overriding vs. Overloading, and Polymorphism"
position: 1
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
"Overriding" and "overloading" sound alike and get confused constantly, but they're different mechanisms solving different problems. Overriding is what makes **polymorphism** work — the ability to call one method through a supertype reference and get behavior that depends on the object's real, runtime type.

## Overriding: redefining an inherited method

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Write release notes", 2);
        System.out.println(task); // implicitly calls toString()
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    @Override
    public String toString() {
        return "Task{name='" + name + "', estimatedHours=" + estimatedHours + "}";
    }
}
```

Every class in Java implicitly extends `Object`, which defines a default `toString()` that produces something unhelpful like `Task@1b6d3586`. **Overriding** replaces that inherited implementation with your own — same method name, same parameter list, same return type, just a new body. `System.out.println(task)` calls `task.toString()` automatically whenever an object is used where a `String` is expected, which is why overriding `toString()` pays off immediately: every place that prints a `Task` gets the readable version for free.

## Overloading: same name, different parameters

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Fix login bug", 3);

        task.reassign("Priya");
        task.reassign("Priya", "Backend Team");

        System.out.println(task);
    }
}

class Task {
    private String name;
    private int estimatedHours;
    private String assignee;
    private String team;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    void reassign(String assignee) {
        this.assignee = assignee;
        this.team = null;
        System.out.println("Reassigned to " + assignee);
    }

    void reassign(String assignee, String team) {
        this.assignee = assignee;
        this.team = team;
        System.out.println("Reassigned to " + assignee + " on " + team);
    }

    @Override
    public String toString() {
        return "Task{name='" + name + "', assignee='" + assignee + "', team='" + team + "'}";
    }
}
```

**Overloading** is defining multiple methods with the *same name* but *different parameter lists* in the same class — here, two versions of `reassign`, one taking just an assignee, one taking an assignee and a team. The compiler picks which one to call based on the arguments you pass at the call site, resolved entirely at **compile time**. This is fundamentally different from overriding: overloading is about giving one class several ways to call a similarly-named operation; overriding is about a subclass replacing a method it inherited.

| | Overloading | Overriding |
|---|---|---|
| Where | Same class (or subclass adding a new signature) | Subclass redefining an inherited method |
| Signature | Must differ (parameters) | Must match exactly |
| Resolved | Compile time, by argument types | Runtime, by the object's actual type |

## Polymorphism: one call, type-dependent behavior

```java
public class Main {
    public static void main(String[] args) {
        Task[] tasks = {
            new Task("Update dependencies", 2),
            new UrgentTask("Payment gateway down", 1, "oncall@taskflow.dev"),
            new Task("Write onboarding docs", 4)
        };

        for (Task t : tasks) {
            System.out.println(t.describe()); // dispatches to the actual runtime type's version
        }
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
        return super.describe() + " [URGENT]";
    }
}
```

`Task[] tasks` holds a mix of `Task` and `UrgentTask` objects — legal because `UrgentTask` **is a** `Task`. The loop calls `t.describe()` through the `Task` type of the array, but at each iteration, Java dispatches to whichever `describe()` actually belongs to that object's **real** runtime type: the plain `Task` entries print without `[URGENT]`, the `UrgentTask` entry prints with it, even though every element in the loop is typed as `Task`. This is polymorphism: the same line of code, `t.describe()`, produces different behavior depending on what `t` actually points to — decided at runtime, not compile time. It's what lets you write one loop that correctly handles every kind of task TaskFlow will ever add, without an `instanceof` check for each one.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-advanced-overriding-overloading-polymorphism-q1",
      "type": "mcq",
      "prompt": "What distinguishes method overloading from method overriding?",
      "options": [
        { "id": "a", "text": "They are the same thing" },
        { "id": "b", "text": "Overloading is multiple methods with the same name but different parameters in one class; overriding is a subclass redefining an inherited method with the exact same signature" },
        { "id": "c", "text": "Overloading only works with static methods" },
        { "id": "d", "text": "Overriding requires different parameter lists, just like overloading" }
      ],
      "correct": "b",
      "explanation": "Overloading differentiates methods by parameter list within the same class. Overriding requires an identical signature, and only happens across an inheritance relationship, replacing the superclass's behavior."
    },
    {
      "id": "oop-advanced-overriding-overloading-polymorphism-q2",
      "type": "mcq",
      "prompt": "When is it decided which overloaded reassign(...) method a call like task.reassign(\"Priya\") invokes?",
      "options": [
        { "id": "a", "text": "At runtime, based on the object's actual type" },
        { "id": "b", "text": "At compile time, based on the number and types of arguments passed" },
        { "id": "c", "text": "Randomly, whichever overload is declared first" },
        { "id": "d", "text": "It's ambiguous and always a compile error" }
      ],
      "correct": "b",
      "explanation": "Overload resolution happens at compile time: the compiler matches the call site's argument types and count against the available overloads and picks the matching one before the program ever runs."
    },
    {
      "id": "oop-advanced-overriding-overloading-polymorphism-q3",
      "type": "mcq",
      "prompt": "A Task[] array holds a mix of Task and UrgentTask objects. Calling t.describe() inside a loop over that array prints different output for the UrgentTask entries than the plain Task entries. Why?",
      "options": [
        { "id": "a", "text": "The array type is checked at compile time only; describe() always runs Task's version" },
        { "id": "b", "text": "Java dispatches describe() based on each object's actual runtime type, not its declared array type — this is polymorphism" },
        { "id": "c", "text": "It's undefined behavior and shouldn't be relied on" },
        { "id": "d", "text": "UrgentTask objects can't be stored in a Task[] array" }
      ],
      "correct": "b",
      "explanation": "Even though the array and loop variable are typed as Task, method calls on overridden methods are dispatched based on the object's real, runtime type — each element runs its own version of describe()."
    }
  ]
}
```

## What's next

The next lesson covers **abstract classes and interfaces** — two different ways to define a contract that multiple classes can share, tied to how TaskFlow sends notifications through different channels.
