---
kind: lesson
id_key: java-mastery/oop-basics/this-and-static
course: java-mastery
section: oop-basics
section_title: "OOP Basics"
section_position: 3
title: "this, plus static vs. Instance Members"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every field and method you've written so far has been an **instance** member — it belongs to a specific object, and each object gets its own copy. `static` members belong to the *class itself*, shared by every instance. `this` is the keyword that refers to "the current object" from inside an instance method or constructor — you've already seen it disambiguate a constructor parameter from a same-named field; there's more to both ideas.

## A static counter shared across every instance

```java
public class Main {
    public static void main(String[] args) {
        Task task1 = new Task("Design schema");
        Task task2 = new Task("Build API");
        Task task3 = new Task("Write tests");

        System.out.println("Tasks created so far: " + Task.getTaskCount());
    }
}

class Task {
    private static int taskCount = 0;

    private String name;

    Task(String name) {
        this.name = name; // this.name is the field; name is the parameter
        taskCount++;
    }

    public static int getTaskCount() {
        return taskCount;
    }
}
```

`taskCount` is `static`, so there is exactly **one** copy of it, shared by every `Task` object — not one per instance. Each constructor call increments the same shared counter, which is why `getTaskCount()` correctly reports `3` after three objects are created. `getTaskCount()` is also `static`: it's called as `Task.getTaskCount()`, through the class name, not through any particular object — it doesn't need `this` because it doesn't operate on any single instance's data.

## `this(...)`: one constructor calling another

```java
public class Main {
    public static void main(String[] args) {
        Task defaultTask = new Task("Untitled");
        Task fullTask = new Task("Deploy to prod", 3);

        System.out.println(defaultTask.describe());
        System.out.println(fullTask.describe());
    }
}

class Task {
    private String name;
    private int estimatedHours;

    Task(String name) {
        this(name, 1); // delegates to the other constructor with a default estimate
    }

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    String describe() {
        return name + " (" + estimatedHours + "h)";
    }
}
```

`this(name, 1)` — called as the *first statement* of a constructor — invokes another constructor of the same class instead of duplicating its logic. This is **constructor chaining**: `Task(String name)` doesn't repeat the field assignments; it just supplies a default `estimatedHours` and hands off to the two-argument constructor that already knows how to do the real setup. This keeps validation and initialization logic in one place, the same principle the encapsulation lesson applied to setters.

## static methods vs. instance methods

```java
public class Main {
    public static void main(String[] args) {
        double average = Task.averageHours(6, 4, 9);
        System.out.println("Average estimate: " + average + "h");
    }
}

class Task {
    static double averageHours(int a, int b, int c) {
        return (a + b + c) / 3.0;
    }
}
```

`averageHours` doesn't read or write any particular `Task` object's fields — it's a pure calculation that only depends on its arguments, so it's declared `static` and called through the class name, `Task.averageHours(...)`, with no object required at all. This is the litmus test for `static`: if a method or field's value doesn't depend on which object you're looking at, it belongs on the class, not the instance. `this` is never available inside a `static` method, precisely because there's no guaranteed "current object" to refer to.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-basics-this-and-static-q1",
      "type": "mcq",
      "prompt": "A class has `private static int taskCount = 0;` incremented in every constructor call. After creating 5 Task objects, what does Task.getTaskCount() return, assuming getTaskCount() just returns taskCount?",
      "options": [
        { "id": "a", "text": "0, because static fields never change" },
        { "id": "b", "text": "5 — every instance shares the same single copy of a static field" },
        { "id": "c", "text": "It depends on which Task instance calls it" },
        { "id": "d", "text": "1, because each new object resets the counter" }
      ],
      "correct": "b",
      "explanation": "A static field has exactly one copy, shared across every instance of the class. Each constructor call increments that single shared value, so after 5 objects it correctly reflects 5."
    },
    {
      "id": "oop-basics-this-and-static-q2",
      "type": "mcq",
      "prompt": "What does `this(name, 1);` as the first line of a constructor do?",
      "options": [
        { "id": "a", "text": "Creates a brand-new, separate Task object" },
        { "id": "b", "text": "Calls another constructor of the same class, passing name and 1 as its arguments" },
        { "id": "c", "text": "Assigns 1 to a field named this" },
        { "id": "d", "text": "It's a syntax error — this cannot be called like a method" }
      ],
      "correct": "b",
      "explanation": "this(...) as a constructor's first statement delegates to another constructor overload in the same class, letting one constructor reuse another's initialization logic instead of duplicating it."
    },
    {
      "id": "oop-basics-this-and-static-q3",
      "type": "mcq",
      "prompt": "Why can't a static method use `this`?",
      "options": [
        { "id": "a", "text": "this is only a naming convention with no real meaning" },
        { "id": "b", "text": "A static method belongs to the class, not to any particular object, so there's no 'current instance' for this to refer to" },
        { "id": "c", "text": "this can be used in static methods, this is a trick question" },
        { "id": "d", "text": "static methods can't access any fields at all" }
      ],
      "correct": "b",
      "explanation": "this always refers to the object a method was called on. static methods are invoked through the class itself, with no associated instance, so there is nothing for this to point to."
    }
  ]
}
```

## What's next

The final lesson in this module steps back from any single class to look at **packages** — how Java organizes classes into namespaces, and why splitting TaskFlow's growing codebase into packages like `core`, `service`, and `util` starts to matter well before it feels necessary.
