---
kind: lesson
id_key: java-mastery/oop-basics/classes-and-objects
course: java-mastery
section: oop-basics
section_title: "OOP Basics"
section_position: 3
title: "Classes and Objects"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every TaskFlow task so far has been loose data — a `String` here, an `int` there, passed around independently. A **class** bundles related data (fields) and behavior (methods) into one reusable blueprint. An **object** is a specific instance created from that blueprint, with its own copy of the fields. This is the shift from "a bunch of variables that happen to describe a task" to "an actual `Task`."

## Defining a class

```java
public class Main {
    public static void main(String[] args) {
        Task schemaTask = new Task("Design database schema", 6);
        Task testTask = new Task("Write integration tests", 4);

        System.out.println(schemaTask.name + " — " + schemaTask.estimatedHours + "h");
        System.out.println(testTask.name + " — " + testTask.estimatedHours + "h");
    }
}

class Task {
    String name;
    int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }
}
```

`class Task { ... }` defines the blueprint: two fields (`name`, `estimatedHours`) and a **constructor** — a special method with the same name as the class and no return type, called automatically by `new` to set up a fresh object. Inside the constructor, `this.name` refers to the field, while plain `name` refers to the constructor's parameter; `this` is what disambiguates them when the names collide, which they usually do on purpose for readability.

A Java source file can hold more than one top-level class, but only one of them may be `public`, and it must match the filename — that's why `Main` is `public` here and `Task` isn't. This is exactly the pattern you'll use throughout this module: one runnable `Main` alongside the class or classes it's demonstrating, all in a single file.

`new Task("Design database schema", 6)` does three things: allocates memory for a new `Task` object, runs the constructor to initialize its fields, and returns a reference to that object, which gets stored in `schemaTask`.

## Objects have both state and behavior

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Deploy to production", 3);
        task.printSummary();
    }
}

class Task {
    String name;
    int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }

    void printSummary() {
        System.out.println("[" + estimatedHours + "h] " + name);
    }
}
```

`printSummary()` is an **instance method** — it operates on the fields of whichever `Task` object it's called on (`task.printSummary()` uses `task`'s own `name` and `estimatedHours`). This is the core idea of OOP: instead of writing a free-standing function that takes a task's data as parameters, the behavior lives *with* the data it acts on.

## Each object has its own independent state

```java
public class Main {
    public static void main(String[] args) {
        Task task1 = new Task("Design schema", 6);
        Task task2 = new Task("Design schema", 6);

        task1.estimatedHours = 8; // mutate task1 only

        System.out.println("task1 hours: " + task1.estimatedHours);
        System.out.println("task2 hours: " + task2.estimatedHours);
        System.out.println("Same object? " + (task1 == task2));
    }
}

class Task {
    String name;
    int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }
}
```

`task1` and `task2` were built from identical arguments, but they are two separate objects with two separate copies of `name` and `estimatedHours` — changing `task1.estimatedHours` has no effect on `task2`. `task1 == task2` prints `false`: for objects, `==` compares **identity** (are these two variables pointing at the same object?), not the content of their fields. That's a preview of a distinction the encapsulation lesson builds on directly.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-basics-classes-and-objects-q1",
      "type": "mcq",
      "prompt": "What is the relationship between a class and an object?",
      "options": [
        { "id": "a", "text": "They are the same thing, just different names" },
        { "id": "b", "text": "A class is the blueprint; an object is a specific instance created from that blueprint" },
        { "id": "c", "text": "An object defines the structure, and a class is a copy of it" },
        { "id": "d", "text": "A class can only ever produce one object" }
      ],
      "correct": "b",
      "explanation": "A class describes what fields and methods every instance will have. Each call to new creates a distinct object — an instance — with its own independent copy of those fields."
    },
    {
      "id": "oop-basics-classes-and-objects-q2",
      "type": "mcq",
      "prompt": "What does `new Task(\"Design schema\", 6)` actually do?",
      "options": [
        { "id": "a", "text": "Only calls the constructor; no memory is allocated" },
        { "id": "b", "text": "Allocates memory for a new object, runs the constructor to initialize its fields, and returns a reference to it" },
        { "id": "c", "text": "Copies an existing Task object's fields into a new variable" },
        { "id": "d", "text": "Declares the Task class for the first time" }
      ],
      "correct": "b",
      "explanation": "new is the operator that creates an object: it allocates space for the new instance, invokes the matching constructor to set up its initial state, and hands back a reference you can store in a variable."
    },
    {
      "id": "oop-basics-classes-and-objects-q3",
      "type": "mcq",
      "prompt": "task1 and task2 are two separate Task objects created with identical constructor arguments. What does task1 == task2 evaluate to?",
      "options": [
        { "id": "a", "text": "true, because their field values are identical" },
        { "id": "b", "text": "false, because == compares object identity, not field content, and they are two distinct objects" },
        { "id": "c", "text": "It causes a compile error" },
        { "id": "d", "text": "It depends on the order the objects were created" }
      ],
      "correct": "b",
      "explanation": "For objects, == checks whether two references point to the exact same object in memory. Two separately-constructed objects are never == to each other, even with identical field values."
    }
  ]
}
```

## What's next

`name` and `estimatedHours` are currently plain public fields — any code anywhere can set `estimatedHours` to a negative number with no pushback. The next lesson covers **encapsulation**: making fields private and controlling access through methods, so a class can protect its own invariants.
