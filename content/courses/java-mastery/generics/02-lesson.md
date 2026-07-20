---
kind: lesson
id_key: java-mastery/generics/generic-methods-bounds
course: java-mastery
section: generics
section_title: "Generics"
section_position: 8
title: "Generic Methods & Bounded Type Parameters"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
A generic *class* like last lesson's `Repository<T>` fixes its type parameter for the whole object's lifetime. A generic **method** is narrower and more common in practice: a single method that introduces its own type parameter, usable with any type, independent of what class it lives in — even a plain `static` utility method.

## A generic method: finding the max

Suppose TaskFlow needs a utility that finds the highest-priority task in a list, or the user with the most tasks assigned, or the longest project name — the same "find the biggest one" logic, over and over, for different types. A generic method captures that once:

```java
import java.util.List;

public class Main {
    // <T extends Comparable<T>> declares the type parameter right before the return type
    public static <T extends Comparable<T>> T max(List<T> items) {
        T largest = items.get(0);
        for (T item : items) {
            if (item.compareTo(largest) > 0) {
                largest = item;
            }
        }
        return largest;
    }

    public static void main(String[] args) {
        List<Integer> hours = List.of(6, 10, 3, 8);
        System.out.println("Max hours: " + max(hours));

        List<String> taskNames = List.of("Design schema", "Build API", "Zebra sprint cleanup");
        System.out.println("Max name (alphabetically last): " + max(taskNames));
    }
}
```

`<T extends Comparable<T>>` is a **bounded type parameter**: it says "`T` can be any type, as long as that type implements `Comparable<T>`." Without the bound, `max` couldn't call `item.compareTo(largest)` at all — a plain `<T>` only guarantees `T` is *some* type, and the compiler has no way to know every possible type supports comparison. The bound is what unlocks calling comparison methods inside the generic code.

## Why the bound matters: what breaks without it

```java
import java.util.List;

public class Main {
    // No bound at all — T could be absolutely anything, even Object
    public static <T> T firstOf(List<T> items) {
        return items.get(0); // fine — no methods on T are called
    }

    // <T extends Comparable<T>> — the bound this lesson is about
    public static <T extends Comparable<T>> T max(List<T> items) {
        T largest = items.get(0);
        for (T item : items) {
            if (item.compareTo(largest) > 0) { // requires compareTo() to exist on T
                largest = item;
            }
        }
        return largest;
    }

    public static void main(String[] args) {
        List<String> priorities = List.of("LOW", "HIGH", "MEDIUM");
        System.out.println("First: " + firstOf(priorities));
        System.out.println("Max: " + max(priorities)); // String implements Comparable<String>
    }
}
```

`firstOf` needs no bound because it never calls a method on `T` — it just passes values through. `max` needs the bound because `compareTo` isn't a method every `Object` has; it only exists on types that declare `implements Comparable<T>`. Try removing `extends Comparable<T>` from `max`'s declaration and `item.compareTo(largest)` becomes a compile error: the compiler refuses to call a method it can't guarantee exists on an unbounded `T`.

## Applying `max` to TaskFlow's `Task` type

To make a custom class like `Task` usable with `max`, it needs to implement `Comparable<Task>` itself, defining what "bigger" means for a task:

```java
import java.util.List;

class Task implements Comparable<Task> {
    private final String name;
    private final int estimateHours;

    public Task(String name, int estimateHours) {
        this.name = name;
        this.estimateHours = estimateHours;
    }

    public String getName() { return name; }
    public int getEstimateHours() { return estimateHours; }

    @Override
    public int compareTo(Task other) {
        return Integer.compare(this.estimateHours, other.estimateHours);
    }
}

public class Main {
    public static <T extends Comparable<T>> T max(List<T> items) {
        T largest = items.get(0);
        for (T item : items) {
            if (item.compareTo(largest) > 0) {
                largest = item;
            }
        }
        return largest;
    }

    public static void main(String[] args) {
        List<Task> tasks = List.of(
            new Task("Design schema", 6),
            new Task("Build REST API", 10),
            new Task("Write tests", 4)
        );

        Task longest = max(tasks);
        System.out.println("Longest task: " + longest.getName() + " (" + longest.getEstimateHours() + "h)");
    }
}
```

Because `Task implements Comparable<Task>`, it satisfies `<T extends Comparable<T>>`, so `max(tasks)` compiles and runs correctly — the same generic method works for `Integer`, `String`, and now `Task`, with zero duplicated logic.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "generics-generic-methods-bounds-q1",
      "type": "mcq",
      "prompt": "What does <T extends Comparable<T>> guarantee about T inside the method body?",
      "options": [
        { "id": "a", "text": "T must be a subclass of a class literally named Comparable" },
        { "id": "b", "text": "T is guaranteed to have a compareTo(T) method available, because it implements Comparable<T>" },
        { "id": "c", "text": "T must be one of the primitive wrapper types like Integer" },
        { "id": "d", "text": "T is restricted to a maximum of one instance per method call" }
      ],
      "correct": "b",
      "explanation": "extends here means implements (Java uses extends for both class and interface bounds on type parameters). Bounding T by Comparable<T> guarantees compareTo() exists and can be called safely."
    },
    {
      "id": "generics-generic-methods-bounds-q2",
      "type": "mcq",
      "prompt": "Why would <T> max(List<T> items) fail to compile if it calls item.compareTo(largest) without a bound?",
      "options": [
        { "id": "a", "text": "compareTo is a static method and can't be called on instances" },
        { "id": "b", "text": "An unbounded T is only guaranteed to have the methods every Object has, and compareTo isn't one of them" },
        { "id": "c", "text": "List<T> cannot hold comparable types" },
        { "id": "d", "text": "It wouldn't fail — unbounded generics can call any method" }
      ],
      "correct": "b",
      "explanation": "Without a bound, the compiler only knows T is some type — it can't assume methods beyond what Object provides (toString, equals, hashCode, etc.). compareTo requires the Comparable bound to be callable."
    },
    {
      "id": "generics-generic-methods-bounds-q3",
      "type": "mcq",
      "prompt": "What must a custom class like Task do to be usable with a <T extends Comparable<T>> method?",
      "options": [
        { "id": "a", "text": "Nothing — all classes are Comparable by default" },
        { "id": "b", "text": "Override toString() only" },
        { "id": "c", "text": "Implement Comparable<Task> and define compareTo(Task other)" },
        { "id": "d", "text": "Mark all its fields as public" }
      ],
      "correct": "c",
      "explanation": "Comparable isn't automatic. A class opts in by declaring implements Comparable<Task> and providing a compareTo(Task) implementation that defines its natural ordering."
    }
  ]
}
```

## What's next

Generic methods handle "any type that supports X." The next lesson covers wildcards — `? extends` and `? super` — for when you're working with generic *collections* whose exact type parameter you don't need to know, only whether you're reading from or writing into them. It also covers type erasure, the runtime reality behind everything generics do at compile time.
