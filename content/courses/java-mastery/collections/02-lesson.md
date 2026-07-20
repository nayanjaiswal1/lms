---
kind: lesson
id_key: java-mastery/collections/set
course: java-mastery
section: collections
section_title: "Collections Framework"
section_position: 7
title: "Set: HashSet, LinkedHashSet, TreeSet"
position: 1
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
A `List` happily holds duplicates. Sometimes that's wrong — if TaskFlow collects the names of every team member assigned across a project's tasks, the same person appears on multiple tasks, but the "who's on this project" view should list each name exactly once. That's exactly what `Set` guarantees.

## The core guarantee: no duplicates

```java
import java.util.HashSet;
import java.util.Set;

public class Main {
    public static void main(String[] args) {
        Set<String> assignedMembers = new HashSet<>();

        assignedMembers.add("Alice");
        assignedMembers.add("Bob");
        assignedMembers.add("Alice"); // duplicate — silently ignored
        assignedMembers.add("Carla");

        System.out.println("Unique members: " + assignedMembers.size()); // 3, not 4
        System.out.println("Contains Bob: " + assignedMembers.contains("Bob"));
    }
}
```

Calling `add()` with a value already in the `Set` is a no-op — it returns `false` (which you can check if you care whether the add actually happened) and the set's contents don't change. This is the whole point: dedup happens automatically, without you writing a manual "already in there?" check yourself.

## Three implementations, three ordering guarantees

```java
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.TreeSet;

public class Main {
    public static void main(String[] args) {
        Set<String> hashSet = new HashSet<>();       // no ordering guarantee
        Set<String> linkedHashSet = new LinkedHashSet<>(); // insertion order preserved
        Set<String> treeSet = new TreeSet<>();        // sorted order (natural ordering)

        String[] members = { "Carla", "Alice", "Bob", "Alice" };
        for (String m : members) {
            hashSet.add(m);
            linkedHashSet.add(m);
            treeSet.add(m);
        }

        System.out.println("HashSet (order not guaranteed): " + hashSet);
        System.out.println("LinkedHashSet (insertion order): " + linkedHashSet);
        System.out.println("TreeSet (sorted order): " + treeSet);
    }
}
```

`HashSet` gives no ordering guarantee at all — it's organized around hash codes for fast lookup, and iteration order can look arbitrary (and isn't guaranteed stable across JVM versions). `LinkedHashSet` adds a linked list alongside the hash table specifically to preserve insertion order — use it when you want dedup **and** a predictable iteration order matching how elements were added. `TreeSet` keeps elements sorted (using natural ordering via `Comparable`, or a custom `Comparator`) — here, alphabetically: `Alice, Bob, Carla`, regardless of insertion order.

## Choosing between them

```java
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.TreeSet;

public class Main {
    public static void main(String[] args) {
        // HashSet: fastest general-purpose choice when order truly doesn't matter.
        Set<String> tags = new HashSet<>();
        tags.add("backend");
        tags.add("urgent");

        // LinkedHashSet: dedup while preserving the order members were first seen.
        Set<String> firstSeenOrder = new LinkedHashSet<>();
        firstSeenOrder.add("Carla");
        firstSeenOrder.add("Alice");
        firstSeenOrder.add("Carla"); // already present, position doesn't move

        // TreeSet: dedup AND always-sorted output, e.g. an alphabetical roster.
        Set<String> roster = new TreeSet<>();
        roster.add("Zoe");
        roster.add("Amir");

        System.out.println("Tags: " + tags);
        System.out.println("First-seen order: " + firstSeenOrder);
        System.out.println("Sorted roster: " + roster);
    }
}
```

Rule of thumb: default to `HashSet` for raw performance when order is irrelevant; reach for `LinkedHashSet` when you need dedup plus a stable, predictable iteration order; reach for `TreeSet` when you need the contents sorted at all times, which also comes with useful range operations like `first()`, `last()`, and `headSet(...)` that plain `HashSet`/`LinkedHashSet` don't offer.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "collections-set-q1",
      "type": "mcq",
      "prompt": "What happens when you call add() on a Set with a value that's already present?",
      "options": [
        { "id": "a", "text": "It throws an exception" },
        { "id": "b", "text": "It's a no-op — the set's contents are unchanged, and add() returns false" },
        { "id": "c", "text": "It replaces the existing element and moves it to the end" },
        { "id": "d", "text": "It adds the value again, resulting in a duplicate" }
      ],
      "correct": "b",
      "explanation": "Set's defining guarantee is no duplicates. Adding an already-present element is silently ignored (add() returns false to signal nothing changed), rather than throwing or creating a duplicate entry."
    },
    {
      "id": "collections-set-q2",
      "type": "mcq",
      "prompt": "Which Set implementation guarantees iteration in the order elements were first inserted?",
      "options": [
        { "id": "a", "text": "HashSet" },
        { "id": "b", "text": "LinkedHashSet" },
        { "id": "c", "text": "TreeSet" },
        { "id": "d", "text": "None of them guarantee any order" }
      ],
      "correct": "b",
      "explanation": "LinkedHashSet maintains a linked list alongside its hash table specifically to preserve insertion order during iteration. HashSet gives no ordering guarantee, and TreeSet iterates in sorted order instead of insertion order."
    },
    {
      "id": "collections-set-q3",
      "type": "mcq",
      "prompt": "Which Set implementation would you choose to always iterate a roster of names in alphabetical order?",
      "options": [
        { "id": "a", "text": "HashSet" },
        { "id": "b", "text": "LinkedHashSet" },
        { "id": "c", "text": "TreeSet" },
        { "id": "d", "text": "Any of them work identically for this" }
      ],
      "correct": "c",
      "explanation": "TreeSet keeps its elements sorted at all times (by natural ordering or a supplied Comparator), so iterating it always yields sorted order — exactly what's needed for an alphabetical roster."
    }
  ]
}
```

## What's next

`Set` answers "is this value present." The next lesson covers `Map` — for when you need to associate a **key** with a **value**, like looking up a full `Task` by its ID.
