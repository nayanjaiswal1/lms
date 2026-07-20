---
kind: lesson
id_key: java-mastery/interview-ready/collections-generics-theory
course: java-mastery
section: interview-ready
section_title: "Interview Ready"
section_position: 18
title: "Collections & Generics Theory"
position: 1
estimated_minutes: 35
source: [java-mastery-curriculum.md]
---
Collections questions are where interviewers separate "I've used `HashMap`" from "I understand what it's doing." This lesson goes underneath the API you already know from the collections module — TaskFlow's `Map<Long, Task>` lookups and `List<Task>` iterations — to the mechanics interviewers actually probe.

## How `HashMap` actually works

A `HashMap<K, V>` stores entries in an internal array of **buckets**. Putting a key through the map roughly does this:

1. Call `key.hashCode()` to get an integer hash, then run it through an internal "spreading" function that mixes the high and low bits together (this reduces collisions that would otherwise occur if many keys produced hash codes differing only in high-order bits).
2. Reduce that spread hash to an index within the current bucket array size, typically via `hash & (capacity - 1)` — bitwise-AND against `capacity - 1` is a fast equivalent of `% capacity` that only works because capacity is always kept a power of two.
3. Store the entry in that bucket. If another entry is already there (a **collision** — two different keys landing in the same bucket), the new entry is appended to a structure hanging off that bucket.

That "structure hanging off the bucket" used to always be a simple **linked list** — walk it entry by entry, comparing `equals()`, until you find a match or reach the end. Since Java 8, if a single bucket's chain grows long enough (8 or more entries, with the table large enough), `HashMap` converts that one bucket's list into a **balanced red-black tree** instead, turning worst-case lookup within a badly-collided bucket from O(n) into O(log n). This only kicks in for pathological collision cases; a healthy `HashMap` never builds a single tree bucket in practice.

```java
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Map<Long, String> taskNamesById = new HashMap<>();
        taskNamesById.put(1001L, "Design database schema");
        taskNamesById.put(1002L, "Build REST API");

        // get() re-runs the same hash -> bucket -> equals() walk that put() did.
        String name = taskNamesById.get(1001L);
        System.out.println(name);
    }
}
```

Average-case `get`/`put` is **O(1)** — one hash computation, one array index, and (in the common case) zero or one `equals()` comparisons in an essentially-empty bucket. That O(1) is an *average*, not a guarantee; it depends entirely on `hashCode()` spreading keys evenly across buckets, which is exactly why overriding `hashCode()` badly (e.g., always returning `0`) silently degrades every `HashMap` built on that key type toward O(n) behavior, even though nothing about the code *looks* wrong.

### Load factor and resizing

A `HashMap` doesn't wait until every bucket is full to grow — it tracks a **load factor** (default `0.75`) and resizes once `size > capacity * loadFactor`. With the default 16-bucket initial capacity, that's a resize once the map holds more than 12 entries. Resizing doubles the bucket array and **rehashes every existing entry** into its new bucket (an entry's bucket index depends on the current capacity, so growing the array changes where almost everything belongs). This is why a `HashMap` you know will hold ~10,000 `Task` entries is faster to construct with an explicit initial capacity (`new HashMap<>(16384)`) — it skips several rounds of doubling-and-rehashing that would otherwise happen automatically as it grows.

## `ArrayList` vs. `LinkedList` — the tradeoffs that actually matter

Both implement `List<T>`, and the interview question is never "which is better" — it's "which is better for *this* access pattern."

| Operation | `ArrayList` | `LinkedList` |
|---|---|---|
| `get(index)` (random access) | O(1) — direct array index | O(n) — must walk the chain from the nearest end |
| `add(element)` at the end | O(1) amortized (occasional resize) | O(1) |
| `add(index, element)` in the middle | O(n) — shifts every later element over | O(n) to find the position, O(1) to link once there |
| `remove(index)` in the middle | O(n) — shifts every later element back | O(n) to find the position, O(1) to unlink once there |
| Memory overhead per element | Low — a contiguous backing array | Higher — each node stores two extra object references (prev/next) |

`ArrayList` is backed by a plain array under the hood, so indexed access is a direct memory offset — O(1). `LinkedList` is backed by doubly-linked nodes, so `get(500)` has to walk 500 links from whichever end is closer — O(n). The real-world answer for TaskFlow: `ArrayList` is the right default almost always. `LinkedList` only wins when the *dominant* operation is inserting/removing at a known position (especially the front or back) on a large collection and you never need indexed access — a genuinely rare pattern in practice, which is why `ArrayList` is what you reach for unless you have a specific, measured reason not to.

## `HashMap` vs. `TreeMap` vs. `LinkedHashMap`

All three implement `Map<K, V>`, and the difference is entirely about **ordering** and the performance cost that ordering carries:

- **`HashMap`** — no ordering guarantee at all; iteration order can even change between runs. O(1) average `get`/`put`. The default choice when you don't care about order.
- **`LinkedHashMap`** — a `HashMap` internally, plus a doubly-linked list threading through the entries in **insertion order** (or, configured differently, access order — useful for building an LRU cache). Same O(1) average `get`/`put` as `HashMap`, with a small extra memory/bookkeeping cost for maintaining the linked list, in exchange for predictable iteration order.
- **`TreeMap`** — keeps keys in **sorted order** (natural ordering via `Comparable`, or a supplied `Comparator`), backed by a red-black tree. `get`/`put` are O(log n), slower than the other two, in exchange for always-sorted iteration and range operations like `firstKey()`, `headMap()`, `tailMap()`.

For TaskFlow: `Map<Long, Task>` for a plain ID lookup is `HashMap`. A "recently viewed tasks" cache that needs to evict the oldest entry is a natural `LinkedHashMap` (access-order mode). A leaderboard that needs tasks sorted by due date at all times is a `TreeMap<LocalDate, Task>`.

## Fail-fast iterators and `ConcurrentModificationException`

Java's standard collection iterators are **fail-fast**: each collection tracks a `modCount` (an internal counter incremented on every structural change — add or remove, not a plain `set`), and the iterator captures that count when created. Every `next()` call checks the live count against the captured one; if they differ, it throws `ConcurrentModificationException` immediately rather than letting you silently iterate over a collection that changed shape underneath you.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>(List.of("Design schema", "Build API", "Write tests"));

        try {
            for (String name : taskNames) {
                if (name.equals("Build API")) {
                    taskNames.remove(name); // structural modification during iteration
                }
            }
        } catch (java.util.ConcurrentModificationException e) {
            System.out.println("Caught: cannot modify a list while iterating it with for-each.");
        }

        // The correct fix: remove through the Iterator itself, or use removeIf().
        taskNames.removeIf(name -> name.equals("Build API"));
        System.out.println(taskNames);
    }
}
```

The for-each loop above desugars to an `Iterator`, and `list.remove(name)` mutates `taskNames` directly, bypassing that iterator entirely — the iterator's next `next()`/`hasNext()` call notices the mismatched `modCount` and throws. The two correct fixes: call `Iterator.remove()` (which updates the tracked count consistently, since it goes through the iterator itself) inside an explicit `while (it.hasNext())` loop, or — simpler, and what you should reach for in real code — `Collection.removeIf(predicate)`, shown above, which handles this safely internally. Worth knowing as a caveat: fail-fast behavior is a **best-effort** safety net for catching bugs during single-threaded misuse, not a real concurrency guarantee — it's explicitly not something to rely on for thread-safety in genuinely concurrent code.

## What type erasure means for generics at runtime

Java generics are a **compile-time-only** feature. The compiler uses type parameters (`Repository<Task>`, `List<String>`) to check your code for type errors, then **erases** them — at runtime, `Repository<Task>` and `Repository<User>` are both literally just `Repository`, backed by the exact same `.class` file, with type parameters replaced by their bound (`Object`, if unbounded) and compiler-inserted casts added wherever a generic value is retrieved.

```java
import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        List<String> taskNames = new ArrayList<>();
        List<Integer> taskIds = new ArrayList<>();

        // Both are, at runtime, plain java.util.ArrayList — the <String> and <Integer>
        // information does not exist anymore once the code is compiled and running.
        System.out.println(taskNames.getClass() == taskIds.getClass()); // true
    }
}
```

This has real, interview-tested consequences: you cannot do `new T()` inside a generic class (the JVM has no idea what `T` erased to), you cannot create an array of a generic type directly (`new T[10]` doesn't compile), and `instanceof` cannot check a parameterized type (`obj instanceof List<String>` is a compile error — you can only check the raw `obj instanceof List`). Erasure exists specifically for backward compatibility: it let generics get bolted onto Java 5 without breaking every `.class` file compiled before generics existed.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-collections-generics-theory-q1",
      "type": "mcq",
      "prompt": "A HashMap's default load factor is 0.75 with an initial capacity of 16. At what size does it first trigger a resize?",
      "options": [
        { "id": "a", "text": "At exactly 16 entries" },
        { "id": "b", "text": "Once size exceeds capacity * loadFactor — more than 12 entries" },
        { "id": "c", "text": "It never resizes automatically" },
        { "id": "d", "text": "At 75 entries" }
      ],
      "correct": "b",
      "explanation": "A HashMap resizes (doubling capacity and rehashing every entry) once its size exceeds capacity * loadFactor. With capacity 16 and load factor 0.75, that threshold is 12 entries."
    },
    {
      "id": "interview-ready-collections-generics-theory-q2",
      "type": "mcq",
      "prompt": "Why is get(500) O(1) on an ArrayList but O(n) on a LinkedList?",
      "options": [
        { "id": "a", "text": "LinkedList has a slower CPU implementation for the same array-index operation" },
        { "id": "b", "text": "ArrayList is backed by a contiguous array allowing direct index offset access; LinkedList must walk node-to-node from an end to reach the target index" },
        { "id": "c", "text": "LinkedList does not support get() at all" },
        { "id": "d", "text": "ArrayList caches every previous get() result" }
      ],
      "correct": "b",
      "explanation": "ArrayList's backing array supports direct O(1) offset access. LinkedList has no such array — reaching index 500 requires traversing 500 prev/next links from whichever end is closer, which is O(n)."
    },
    {
      "id": "interview-ready-collections-generics-theory-q3",
      "type": "mcq",
      "prompt": "Which map implementation would you choose for a leaderboard that must always iterate tasks sorted by due date?",
      "options": [
        { "id": "a", "text": "HashMap, since it's fastest" },
        { "id": "b", "text": "LinkedHashMap in insertion-order mode" },
        { "id": "c", "text": "TreeMap, since it maintains keys in sorted order at the cost of O(log n) get/put instead of O(1)" },
        { "id": "d", "text": "Any of the three — they all guarantee sorted iteration" }
      ],
      "correct": "c",
      "explanation": "TreeMap is backed by a red-black tree and keeps keys continuously sorted, trading O(1) average HashMap performance for O(log n) operations in exchange for always-ordered iteration and range queries."
    },
    {
      "id": "interview-ready-collections-generics-theory-q4",
      "type": "mcq",
      "prompt": "Because of type erasure, which of these fails to compile inside a generic class Repository<T>?",
      "options": [
        { "id": "a", "text": "T item = items.get(0);" },
        { "id": "b", "text": "void add(T item) { items.add(item); }" },
        { "id": "c", "text": "T[] array = new T[10];" },
        { "id": "d", "text": "List<T> all() { return items; }" }
      ],
      "correct": "c",
      "explanation": "Generic type parameters are erased at runtime, so the JVM has no concrete type to allocate an array of — new T[10] doesn't compile. The other options work fine because they don't require the JVM to know T's runtime identity."
    }
  ]
}
```

## What's next

Next: concurrency and JVM internals at interview depth — race conditions, deadlock, volatile vs. synchronized, and why the stack/heap split matters more than it first seems.
