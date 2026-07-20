---
kind: lesson
id_key: java-mastery/oop-basics/packages
course: java-mastery
section: oop-basics
section_title: "OOP Basics"
section_position: 3
title: "Packages and Project Structure"
position: 3
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every class in this course so far has lived in Java's unnamed **default package** — fine for a single-file example, but untenable for a real project. A **package** is a namespace: a way of grouping related classes together, avoiding name collisions, and controlling which classes are visible to which other classes as a codebase grows past a handful of files.

## The package declaration

A package is declared with a `package` statement as the very first non-comment line of a `.java` file — before any `import` or class definition:

```
package com.taskflow.core;

public class Task {
    // fields, constructor, methods...
}
```

`com.taskflow.core` is just a dotted name — by convention, reversed-domain-style (`com.taskflow`) followed by a module name (`core`). Once declared, every class in that file belongs to the `com.taskflow.core` package, and any other class that wants to use it either needs an `import com.taskflow.core.Task;` statement, or must refer to it by its **fully-qualified name**, `com.taskflow.core.Task`, directly:

```java
public class Main {
    public static void main(String[] args) {
        // Without an import, a class can still be referenced by its fully-qualified
        // name — this is exactly what import java.util.Scanner; saves you from typing:
        java.util.Scanner scanner = new java.util.Scanner(System.in);
        System.out.println("Scanner ready via its fully-qualified name — no import needed");
        scanner.close();
    }
}
```

This is the same mechanism you've been using every time you wrote `import java.util.Scanner;` — `Scanner` lives in the `java.util` package, and the import is just a shorthand so you can write `Scanner` instead of `java.util.Scanner` everywhere in the file.

## Folder structure mirrors the package name exactly

A package isn't just a label — the compiler and `java` command expect the **folder structure on disk to match the package name**, with dots replaced by path separators:

```
src/
└── com/
    └── taskflow/
        ├── core/
        │   ├── Task.java        → package com.taskflow.core;
        │   └── User.java        → package com.taskflow.core;
        ├── service/
        │   └── TaskValidator.java → package com.taskflow.service;
        │                             (imports com.taskflow.core.Task)
        └── util/
            └── DateHelper.java   → package com.taskflow.util;
```

`Task.java`, declaring `package com.taskflow.core;`, must live at `src/com/taskflow/core/Task.java` — not anywhere else. This isn't a style convention the compiler is lenient about; a mismatched folder path is a build error. Classes within the same package can reference each other directly with no `import` needed at all; classes in different packages need an explicit `import` (or a fully-qualified name), and the referenced class needs at least package-visible (or `public`) access.

## Why organize TaskFlow into packages at all

```java
public class Main {
    public static void main(String[] args) {
        Task task = new Task("Ship release notes", 2);
        TaskValidator validator = new TaskValidator();

        System.out.println("Valid: " + validator.isValid(task));
    }
}

// In a real multi-file TaskFlow project, Task would live in com.taskflow.core —
// the fundamental domain objects with no dependencies on the rest of the app.
class Task {
    String name;
    int estimatedHours;

    Task(String name, int estimatedHours) {
        this.name = name;
        this.estimatedHours = estimatedHours;
    }
}

// ...and TaskValidator would live in com.taskflow.service, importing
// com.taskflow.core.Task — service classes depend on core, never the reverse.
class TaskValidator {
    boolean isValid(Task task) {
        return task.estimatedHours > 0 && !task.name.isBlank();
    }
}
```

A handful of classes in one file is manageable without packages — this course's examples have gotten away with it so far. Real TaskFlow has dozens of classes: `Task`, `User`, `Project`, `Team` as core domain objects; `TaskValidator`, `NotificationService`, `AssignmentService` as business logic; `DateHelper`, `StringFormatter` as shared utilities. Splitting these into `core`, `service`, and `util` packages does three concrete things as the codebase grows: it prevents name collisions (two unrelated `Validator` classes in different packages don't conflict), it documents intent (a `core` class with no imports from `service` signals "this doesn't depend on business logic"), and it lets you restrict visibility — a class or method left without an access modifier is package-private, visible only inside its own package, which is a real tool for hiding internal helper classes from the rest of the app.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-basics-packages-q1",
      "type": "mcq",
      "prompt": "Where must the package declaration appear in a .java file?",
      "options": [
        { "id": "a", "text": "Anywhere in the file, order doesn't matter" },
        { "id": "b", "text": "As the first non-comment line, before any import or class definition" },
        { "id": "c", "text": "Only inside the class body" },
        { "id": "d", "text": "After all import statements" }
      ],
      "correct": "b",
      "explanation": "The package statement, when present, must be the first non-comment line in the file — it declares which namespace every class in that file belongs to before anything else is defined."
    },
    {
      "id": "oop-basics-packages-q2",
      "type": "mcq",
      "prompt": "A class declares `package com.taskflow.core;`. Where must its source file live on disk, relative to the source root?",
      "options": [
        { "id": "a", "text": "Anywhere — the package statement is purely documentation" },
        { "id": "b", "text": "At com/taskflow/core/, mirroring the package name with dots replaced by path separators" },
        { "id": "c", "text": "In a single flat folder named com.taskflow.core" },
        { "id": "d", "text": "In a folder named core only" }
      ],
      "correct": "b",
      "explanation": "The compiler and the java launcher require the folder structure to mirror the package name exactly, dots becoming path separators — a mismatch is a build error, not a warning."
    },
    {
      "id": "oop-basics-packages-q3",
      "type": "mcq",
      "prompt": "As TaskFlow grows to dozens of classes, what's a concrete benefit of splitting them into core/service/util packages instead of leaving everything in one namespace?",
      "options": [
        { "id": "a", "text": "It makes the code run faster at execution time" },
        { "id": "b", "text": "It prevents name collisions, documents intent, and lets package-private visibility hide internal helpers from the rest of the app" },
        { "id": "c", "text": "It's required — Java refuses to compile more than 10 classes in one package" },
        { "id": "d", "text": "It removes the need for constructors" }
      ],
      "correct": "b",
      "explanation": "Packages are an organizational and visibility tool, not a performance one: they avoid naming conflicts between unrelated classes, signal dependency direction (core has no business-logic imports), and let package-private classes stay hidden outside their own package."
    }
  ]
}
```

## What's next

With classes, encapsulation, this/static, and packages in hand, you've built real TaskFlow objects for the first time — but every `Task` so far has stood alone. The next module, **advanced OOP**, covers inheritance, polymorphism, abstract classes and interfaces, and the equals/hashCode/toString contract — the tools for building a family of related task types instead of one flat class.
