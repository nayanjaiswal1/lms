---
kind: lesson
id_key: java-mastery/collections/list
course: java-mastery
section: collections
section_title: "Collections Framework"
section_position: 7
title: "The Collections Framework & List"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Arrays have a hard limit: fixed size, set once at creation. TaskFlow's real task list grows and shrinks constantly as tasks are created and completed. The **Collections Framework** — `java.util`'s family of `List`, `Set`, `Map`, and `Queue` — is Java's answer: resizable, richly-featured containers that replace hand-rolled array management.

## From a fixed array to a resizable List

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>();

        taskNames.add("Design database schema");
        taskNames.add("Build REST API");
        taskNames.add("Write tests");

        System.out.println("Task count: " + taskNames.size());
        System.out.println("First task: " + taskNames.get(0));

        taskNames.remove("Build REST API"); // removes by value
        System.out.println("After removal: " + taskNames);
    }
}
```

`List<String>` is an **interface** — the type you should declare variables as. `new ArrayList<>()` is the concrete implementation actually created; the `<>` (diamond operator) lets the compiler infer the generic type from the left side instead of repeating `<String>` twice. `add`, `get`, `remove`, and `size()` replace an array's fixed indexing and `.length` — and unlike an array, the list genuinely grows as you `add()` more elements. Printing a `List` directly (as in the last line) calls its built-in `toString()`, giving readable bracketed output like `[Design database schema, Write tests]`.

## `ArrayList` vs. `LinkedList`

Both implement `List` and support the exact same interface — the choice between them is about **performance characteristics**, not behavior:

| | `ArrayList` | `LinkedList` |
|---|---|---|
| Backed by | A resizable array | A doubly-linked chain of nodes |
| Random access (`get(i)`) | Fast — O(1) | Slow — O(n), must walk from an end |
| Insert/remove at the **start or middle** | Slow — O(n), must shift elements | Fast — O(1), if you already have the node |
| Insert/remove at the **end** | Fast (amortized) O(1) | Fast O(1) |
| Typical choice | The default for almost everything | Rare — only when you truly do frequent start/middle inserts and never need indexed access |

```java
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskQueueArray = new ArrayList<>();
        List<String> taskQueueLinked = new LinkedList<>();

        taskQueueArray.add("Design schema");
        taskQueueArray.add("Build API");
        taskQueueLinked.add("Design schema");
        taskQueueLinked.add("Build API");

        // Both support the same List operations — same interface, different internals.
        System.out.println("ArrayList get(0): " + taskQueueArray.get(0));
        System.out.println("LinkedList get(0): " + taskQueueLinked.get(0));

        taskQueueArray.add(0, "URGENT: Fix outage"); // insert at front — O(n) shift
        taskQueueLinked.add(0, "URGENT: Fix outage"); // insert at front — O(1) for LinkedList

        System.out.println("ArrayList after insert: " + taskQueueArray);
        System.out.println("LinkedList after insert: " + taskQueueLinked);
    }
}
```

In practice, **default to `ArrayList`** — it has better cache locality and faster indexed access, which covers the vast majority of real use cases including TaskFlow's task lists. Reach for `LinkedList` only when profiling shows you specifically need cheap insert/remove at arbitrary positions and rarely index by position.

## Iterating a List

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>();
        taskNames.add("Design schema");
        taskNames.add("Build API");
        taskNames.add("Write tests");

        // Enhanced for-loop: cleanest when you don't need the index
        for (String name : taskNames) {
            System.out.println("- " + name);
        }

        // Indexed loop: use when you need the position too
        for (int i = 0; i < taskNames.size(); i++) {
            System.out.println((i + 1) + ". " + taskNames.get(i));
        }
    }
}
```

The enhanced for-loop works on any `List` (and any `Collection`) exactly like it does on arrays. Reach for the indexed form only when the position itself matters — printing a numbered list, or needing to compare adjacent elements.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "collections-list-q1",
      "type": "mcq",
      "prompt": "What is the key advantage of List<String> over a plain String[] array?",
      "options": [
        { "id": "a", "text": "List elements can never be null" },
        { "id": "b", "text": "A List can grow and shrink dynamically; an array's size is fixed at creation" },
        { "id": "c", "text": "List indexing starts at 1 instead of 0" },
        { "id": "d", "text": "There is no real difference" }
      ],
      "correct": "b",
      "explanation": "Arrays are fixed-size once created. List implementations like ArrayList resize automatically as elements are added or removed — the core reason to reach for a List over a raw array for growing collections."
    },
    {
      "id": "collections-list-q2",
      "type": "mcq",
      "prompt": "Why should ArrayList be the default List choice for most use cases, over LinkedList?",
      "options": [
        { "id": "a", "text": "LinkedList doesn't implement the List interface" },
        { "id": "b", "text": "ArrayList offers fast O(1) indexed access and generally better performance for typical access patterns; LinkedList only wins for frequent insert/remove at arbitrary positions without indexed access" },
        { "id": "c", "text": "LinkedList cannot hold more than a fixed number of elements" },
        { "id": "d", "text": "ArrayList is always faster at every single operation" }
      ],
      "correct": "b",
      "explanation": "ArrayList's array-backed storage gives O(1) get(i) and good cache locality, covering most real workloads. LinkedList only pays off when you specifically need cheap insert/remove in the middle and rarely access by index."
    },
    {
      "id": "collections-list-q3",
      "type": "mcq",
      "prompt": "What does the diamond operator <> do in new ArrayList<>()?",
      "options": [
        { "id": "a", "text": "It's required syntax with no functional purpose" },
        { "id": "b", "text": "It lets the compiler infer the generic type argument from context (e.g. the declared variable type), avoiding repeating it" },
        { "id": "c", "text": "It marks the list as immutable" },
        { "id": "d", "text": "It sets the list's initial capacity to zero" }
      ],
      "correct": "b",
      "explanation": "The diamond operator (Java 7+) lets you write List<String> names = new ArrayList<>(); instead of repeating new ArrayList<String>() — the compiler infers String from the left-hand declaration."
    }
  ]
}
```

## What's next

`List` allows duplicates and preserves insertion order (mostly). The next lesson covers `Set` — for when you specifically need to guarantee no duplicates, like a list of unique team members assigned across tasks.
