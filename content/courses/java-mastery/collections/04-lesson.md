---
kind: lesson
id_key: java-mastery/collections/queue-iterator-comparator
course: java-mastery
section: collections
section_title: "Collections Framework"
section_position: 7
title: "Queue/Deque, Iterator, and Comparable vs. Comparator"
position: 3
estimated_minutes: 25
source: [java-mastery-curriculum.md]
---
This last lesson covers three remaining tools that come up constantly once TaskFlow has real collections of tasks to manage: processing them in order with a `Queue`, safely removing while iterating, and sorting by priority.

## `Queue` and `Deque` with `ArrayDeque`

```java
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Queue;

public class Main {
    public static void main(String[] args) {
        // Queue: FIFO — first in, first out
        Queue<String> taskQueue = new ArrayDeque<>();
        taskQueue.offer("Design schema");  // enqueue (add to the back)
        taskQueue.offer("Build API");
        taskQueue.offer("Write tests");

        System.out.println("Next up: " + taskQueue.peek()); // look without removing
        while (!taskQueue.isEmpty()) {
            System.out.println("Processing: " + taskQueue.poll()); // dequeue (remove from the front)
        }

        // Deque: double-ended — push/pop from either end
        Deque<String> urgentStack = new ArrayDeque<>();
        urgentStack.push("Design schema");     // pushes to the front
        urgentStack.push("URGENT: Fix outage"); // most recent urgent item goes first
        System.out.println("Handle first: " + urgentStack.pop()); // LIFO — last in, first out
    }
}
```

`Queue` models FIFO processing: `offer()` adds to the back, `poll()` removes and returns from the front, `peek()` looks at the front without removing it. `ArrayDeque` is the standard modern choice backing both `Queue` and `Deque` — it's faster than the older `LinkedList` for this purpose and doesn't carry `LinkedList`'s extra per-node overhead. `Deque` ("double-ended queue") adds `push`/`pop` for stack-like LIFO behavior at the front, useful for TaskFlow modeling an "urgent tasks jump the line" stack layered on top of the normal FIFO queue.

## Safely removing while iterating: `Iterator.remove()`

```java
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>();
        taskNames.add("Design schema");
        taskNames.add("Build API");
        taskNames.add("Cancelled: old spec");
        taskNames.add("Write tests");

        // BAD (would throw ConcurrentModificationException):
        // for (String name : taskNames) {
        //     if (name.startsWith("Cancelled")) taskNames.remove(name);
        // }

        // GOOD: use the Iterator directly and call its own remove()
        Iterator<String> it = taskNames.iterator();
        while (it.hasNext()) {
            String name = it.next();
            if (name.startsWith("Cancelled")) {
                it.remove(); // safe — the iterator knows how to adjust itself
            }
        }

        System.out.println("After cleanup: " + taskNames);
    }
}
```

Modifying a `List` directly with `.remove()` while inside an enhanced for-loop (or otherwise iterating it) throws `ConcurrentModificationException` at runtime — the loop's internal iterator detects the list changed underneath it and refuses to continue with potentially corrupted state. `Iterator.remove()` is the safe alternative: it's a method on the iterator itself, so it can adjust its own internal position as part of the removal, instead of invalidating the iteration it's driving.

## `Comparable`: a type's natural ordering

```java
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Main {
    static class Task implements Comparable<Task> {
        String name;
        int priority; // higher number = higher priority

        Task(String name, int priority) {
            this.name = name;
            this.priority = priority;
        }

        @Override
        public int compareTo(Task other) {
            return Integer.compare(this.priority, other.priority); // ascending by priority
        }

        @Override
        public String toString() {
            return name + " (priority " + priority + ")";
        }
    }

    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Write tests", 4));
        tasks.add(new Task("Fix outage", 9));
        tasks.add(new Task("Design schema", 6));

        Collections.sort(tasks); // uses compareTo — Task's own "natural" ordering
        System.out.println("Sorted by natural order: " + tasks);
    }
}
```

Implementing `Comparable<Task>` gives a type a single, built-in "natural" ordering via `compareTo` — `Collections.sort(list)` (with no second argument) uses exactly that. `compareTo` returns negative if `this` sorts before `other`, positive if after, zero if equal; `Integer.compare(a, b)` is the standard safe way to compare two `int`s for this purpose instead of hand-rolling `a - b` (which can silently overflow for large values).

## `Comparator`: sorting a different way, without changing the class

```java
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class Main {
    static class Task {
        String name;
        int priority;
        double estimateHours;

        Task(String name, int priority, double estimateHours) {
            this.name = name;
            this.priority = priority;
            this.estimateHours = estimateHours;
        }

        @Override
        public String toString() {
            return name + " (priority " + priority + ", " + estimateHours + "h)";
        }
    }

    public static void main(String[] args) {
        List<Task> tasks = new ArrayList<>();
        tasks.add(new Task("Write tests", 4, 3.0));
        tasks.add(new Task("Fix outage", 9, 1.5));
        tasks.add(new Task("Design schema", 6, 6.0));

        // Sort by priority, descending — highest priority first
        tasks.sort(Comparator.comparing((Task t) -> t.priority).reversed());
        System.out.println("By priority (desc): " + tasks);

        // Sort by estimate hours, ascending, with priority as a tiebreaker
        tasks.sort(Comparator.comparingDouble((Task t) -> t.estimateHours)
                              .thenComparing(t -> t.priority));
        System.out.println("By hours, then priority: " + tasks);
    }
}
```

`Comparator` defines an ordering **externally**, without the class needing to implement anything — essential when `Task` has no single "natural" order, or when you need several different orderings for different reports. `Comparator.comparing(keyExtractor)` builds a comparator from a lambda that pulls out the field to sort by; `.reversed()` flips it; `.thenComparing(...)` adds a tiebreaker for when the primary key is equal. `list.sort(comparator)` sorts in place using it — this is the idiomatic modern way to sort by priority, by hours, or by any other field, all without touching the `Task` class itself.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "collections-queue-iterator-comparator-q1",
      "type": "mcq",
      "prompt": "In a Queue, what does poll() do?",
      "options": [
        { "id": "a", "text": "Adds an element to the back" },
        { "id": "b", "text": "Removes and returns the element at the front (FIFO order)" },
        { "id": "c", "text": "Looks at the front element without removing it" },
        { "id": "d", "text": "Removes and returns the element at the back" }
      ],
      "correct": "b",
      "explanation": "poll() removes and returns the head of the queue, implementing first-in-first-out processing. peek() looks at the head without removing it, and offer() adds to the tail."
    },
    {
      "id": "collections-queue-iterator-comparator-q2",
      "type": "mcq",
      "prompt": "Why does calling list.remove(x) directly inside an enhanced for-loop over that same list throw ConcurrentModificationException?",
      "options": [
        { "id": "a", "text": "It doesn't — this is always safe" },
        { "id": "b", "text": "The enhanced for-loop's internal iterator detects the list was structurally modified outside its own remove() method and refuses to continue" },
        { "id": "c", "text": "It only happens when the list has fewer than two elements" },
        { "id": "d", "text": "remove(x) is not a valid method on List" }
      ],
      "correct": "b",
      "explanation": "The enhanced for-loop uses an Iterator under the hood. Modifying the list directly changes its structure in a way the iterator didn't perform itself, so it throws rather than risk continuing over corrupted state. Iterator.remove() is safe because the iterator adjusts its own position as part of the removal."
    },
    {
      "id": "collections-queue-iterator-comparator-q3",
      "type": "mcq",
      "prompt": "What is the key difference between Comparable and Comparator?",
      "options": [
        { "id": "a", "text": "They are identical, just different names for the same interface" },
        { "id": "b", "text": "Comparable defines a class's own single natural ordering via compareTo; Comparator defines an ordering externally, and you can have as many different Comparators as needed" },
        { "id": "c", "text": "Comparator can only sort numbers, Comparable can sort anything" },
        { "id": "d", "text": "Comparable is only used for Lists, Comparator only for Sets" }
      ],
      "correct": "b",
      "explanation": "A class implements Comparable once to define its single natural ordering. Comparator lives outside the class entirely, so you can define multiple different orderings (by priority, by hours, etc.) without modifying the class at all."
    }
  ]
}
```

## What's next

That's the full Collections Framework toolkit — List, Set, Map, Queue/Deque, Iterator, and sorting. The module quiz below checks your understanding across all four lessons before you continue deeper into the course.
