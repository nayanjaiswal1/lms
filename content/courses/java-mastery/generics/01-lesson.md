---
kind: lesson
id_key: java-mastery/generics/generic-classes
course: java-mastery
section: generics
section_title: "Generics"
section_position: 8
title: "Why Generics Exist & Generic Classes"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
TaskFlow needs an in-memory store for `Task` objects. Then it needs one for `User` objects. Then `Project` objects. Writing `TaskRepository`, `UserRepository`, and `ProjectRepository` as three separate, nearly-identical classes is exactly the kind of duplication generics exist to eliminate — one `Repository<T>` class, parameterized by type, replaces all three.

## Life before generics: everything is `Object`

Before Java 5, a reusable container class had only one option for "any type": store everything as `Object`, the root of every class hierarchy, and cast back down when you retrieve it.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        // Pre-generics style: a raw, untyped store
        List rawStore = new ArrayList(); // no type parameter — raw type
        rawStore.add("Design database schema"); // a String
        rawStore.add(42);                        // an int, autoboxed to Integer — compiles fine!

        // The compiler has no idea what's actually in rawStore.
        // This cast looks reasonable but blows up at runtime:
        String taskName = (String) rawStore.get(1); // ClassCastException: Integer cannot be cast to String

        System.out.println(taskName);
    }
}
```

That program compiles cleanly and fails at **runtime** with a `ClassCastException`. This is the exact problem generics were built to solve: the mistake — putting an `Integer` where a `String` was expected — is a *programmer error* that should be caught by the compiler, not discovered when a user hits a crash in production. Notice this example never even reaches `main`'s last line safely; run it and watch it throw.

## `Repository<T>`: one class, any type

A **generic class** declares one or more **type parameters** — placeholder names, conventionally single uppercase letters like `T` (Type), `E` (Element), `K`/`V` (Key/Value) — in angle brackets after the class name. The type parameter stands in for a real type that's supplied when the class is used.

```java
import java.util.ArrayList;
import java.util.List;

public class Repository<T> {
    private final List<T> items = new ArrayList<>();

    public void add(T item) {
        items.add(item);
    }

    public T get(int index) {
        return items.get(index);
    }

    public int size() {
        return items.size();
    }

    public List<T> all() {
        return items;
    }
}
```

`Repository<T>` has no idea what `T` actually is when it's written — it just knows every `T` it stores will come back out as a `T`. The real type gets filled in wherever `Repository` is *used*:

```java
public class Main {
    public static void main(String[] args) {
        Repository<Task> taskRepo = new Repository<>();
        taskRepo.add(new Task("Design database schema", 6));
        taskRepo.add(new Task("Build REST API", 10));

        Repository<User> userRepo = new Repository<>();
        userRepo.add(new User("alice"));
        userRepo.add(new User("bob"));

        // No cast needed — get() already returns a Task, because this repo is Repository<Task>
        Task first = taskRepo.get(0);
        System.out.println("Task: " + first.getName() + " (" + first.getEstimateHours() + "h)");

        User firstUser = userRepo.get(0);
        System.out.println("User: " + firstUser.getUsername());
    }
}

class Task {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }
}

class User {
    private final String username;

    public User(String username) {
        this.username = username;
    }

    public String getUsername() { return username; }
}
```

`Repository<Task>` and `Repository<User>` are both backed by the exact same class file — there's no code duplication — but the compiler treats them as distinct, incompatible types. Trying `taskRepo.add(new User("carol"))` is a **compile error**, not a runtime surprise. That's the whole win: the `ClassCastException` from the raw-type example above becomes impossible to write in the first place, because `taskRepo.get(0)` is statically known to return a `Task`, no cast required.

## Multiple type parameters

A class can declare more than one type parameter when it needs to relate two independent types — a cache keyed by task ID that stores `Task` objects, for instance, looks like `Cache<K, V>` (mirroring `java.util.Map<K, V>`, which is itself a generic class built the same way `Repository<T>` is here).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "generics-generic-classes-q1",
      "type": "mcq",
      "prompt": "What was the main problem with storing everything as Object before generics existed?",
      "options": [
        { "id": "a", "text": "Object-based code ran significantly slower" },
        { "id": "b", "text": "Type mismatches weren't caught until a cast failed at runtime with a ClassCastException" },
        { "id": "c", "text": "Object couldn't be stored in an ArrayList" },
        { "id": "d", "text": "It made the code shorter, which was considered bad practice" }
      ],
      "correct": "b",
      "explanation": "A raw List could hold any mix of types, and the compiler couldn't verify casts back to a specific type. The mistake surfaced as a runtime ClassCastException instead of a compile error."
    },
    {
      "id": "generics-generic-classes-q2",
      "type": "mcq",
      "prompt": "Given Repository<Task> taskRepo = new Repository<>();, what does taskRepo.get(0) return without any cast?",
      "options": [
        { "id": "a", "text": "Object, requiring a manual cast to Task" },
        { "id": "b", "text": "Task directly, because the compiler knows T is Task for this instance" },
        { "id": "c", "text": "A compile error, since get() is untyped" },
        { "id": "d", "text": "null, always" }
      ],
      "correct": "b",
      "explanation": "Once a type parameter is filled in (Repository<Task>), every method using T is treated as if T were literally Task — get() returns Task with no cast needed."
    },
    {
      "id": "generics-generic-classes-q3",
      "type": "mcq",
      "prompt": "Why does taskRepo.add(new User(\"carol\")) fail to compile when taskRepo is a Repository<Task>?",
      "options": [
        { "id": "a", "text": "Repository only allows one add() call total" },
        { "id": "b", "text": "User and Task are unrelated classes with no shared interface" },
        { "id": "c", "text": "The compiler enforces that add()'s parameter must match the concrete type T was bound to (Task), so a User is rejected" },
        { "id": "d", "text": "It doesn't fail — it compiles and throws at runtime instead" }
      ],
      "correct": "c",
      "explanation": "This is the entire point of generics: once Repository<Task> fixes T to Task, every T in the class (including add()'s parameter type) is enforced as Task at compile time, catching the mistake before the program ever runs."
    }
  ]
}
```

## What's next

`Repository<T>` works for storing and retrieving items, but what about operations that need to *compare* the items inside — finding the largest task by hours, for example? The next lesson covers generic methods and bounded type parameters, which let you say "T can be any type, as long as it supports comparison."
