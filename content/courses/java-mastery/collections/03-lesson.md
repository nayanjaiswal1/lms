---
kind: lesson
id_key: java-mastery/collections/map
course: java-mastery
section: collections
section_title: "Collections Framework"
section_position: 7
title: "Map: HashMap, LinkedHashMap, TreeMap"
position: 2
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
`List` and `Set` both hold single values. TaskFlow constantly needs the other shape of data: looking a `Task` up **by its ID**, instantly, without scanning a whole list. That's what `Map<K, V>` is for — a key-to-value lookup table.

## Basic Map operations

```java
import java.util.HashMap;
import java.util.Map;

public class Main {
    static class Task {
        String id;
        String name;
        double estimateHours;

        Task(String id, String name, double estimateHours) {
            this.id = id;
            this.name = name;
            this.estimateHours = estimateHours;
        }

        @Override
        public String toString() {
            return name + " (" + estimateHours + "h)";
        }
    }

    public static void main(String[] args) {
        Map<String, Task> tasksById = new HashMap<>();

        tasksById.put("T-101", new Task("T-101", "Design schema", 6.0));
        tasksById.put("T-102", new Task("T-102", "Build REST API", 10.5));

        Task lookup = tasksById.get("T-101");
        System.out.println("Found: " + lookup);

        System.out.println("Contains T-999: " + tasksById.containsKey("T-999"));
        System.out.println("Map size: " + tasksById.size());

        tasksById.remove("T-102");
        System.out.println("After removal, size: " + tasksById.size());
    }
}
```

`put(key, value)` inserts or overwrites an entry; `get(key)` returns the value, or `null` if the key isn't present; `containsKey(key)` checks presence without risking a `null`. This replaces having to loop through a `List<Task>` comparing `.id` fields on every lookup — a `Map` gives near-instant lookup by key regardless of how many entries it holds.

## Iterating entries

```java
import java.util.HashMap;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Map<String, Double> hoursByTaskId = new HashMap<>();
        hoursByTaskId.put("T-101", 6.0);
        hoursByTaskId.put("T-102", 10.5);
        hoursByTaskId.put("T-103", 3.0);

        // entrySet() gives both key and value together — the usual iteration style
        for (Map.Entry<String, Double> entry : hoursByTaskId.entrySet()) {
            System.out.println(entry.getKey() + " -> " + entry.getValue() + "h");
        }

        // keySet() / values() when you only need one side
        double total = 0;
        for (double hours : hoursByTaskId.values()) {
            total += hours;
        }
        System.out.println("Total hours: " + total);
    }
}
```

`entrySet()` is the standard way to walk both keys and values together in one pass. `keySet()` and `values()` give you just one side when that's all you need — looping `values()` to sum, as above, avoids the unnecessary overhead of also pulling out keys you won't use.

## `getOrDefault` and `computeIfAbsent`

```java
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Map<String, Integer> taskCountByOwner = new HashMap<>();
        taskCountByOwner.put("Alice", 3);

        // getOrDefault: read a key that might be missing, without a null check
        int bobCount = taskCountByOwner.getOrDefault("Bob", 0);
        System.out.println("Bob's task count: " + bobCount); // 0, not null

        // computeIfAbsent: initialize a value only if the key isn't already there
        Map<String, List<String>> tasksByOwner = new HashMap<>();
        tasksByOwner.computeIfAbsent("Alice", key -> new ArrayList<>()).add("Design schema");
        tasksByOwner.computeIfAbsent("Alice", key -> new ArrayList<>()).add("Write tests");
        tasksByOwner.computeIfAbsent("Bob", key -> new ArrayList<>()).add("Build API");

        System.out.println("Alice's tasks: " + tasksByOwner.get("Alice"));
        System.out.println("Bob's tasks: " + tasksByOwner.get("Bob"));
    }
}
```

`getOrDefault(key, fallback)` avoids a manual `containsKey` + `get` pair, or a `null` slipping through unnoticed. `computeIfAbsent(key, function)` is the idiomatic way to build up a "group by" structure like `Map<String, List<String>>`: the first time a key is seen it creates a new empty list via the given lambda, and every call after that reuses the existing one — no need to manually check "does this key have a list yet?" before every `add`.

## `HashMap` vs. `LinkedHashMap` vs. `TreeMap`

Exactly the same relationship as their `Set` counterparts: `HashMap` gives no ordering guarantee (fastest general case), `LinkedHashMap` preserves insertion order, `TreeMap` keeps entries sorted by key at all times.

```java
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeMap;

public class Main {
    public static void main(String[] args) {
        Map<String, Double> hashMap = new HashMap<>();
        Map<String, Double> linkedHashMap = new LinkedHashMap<>();
        Map<String, Double> treeMap = new TreeMap<>();

        String[] ids = { "T-103", "T-101", "T-102" };
        double[] hours = { 3.0, 6.0, 10.5 };
        for (int i = 0; i < ids.length; i++) {
            hashMap.put(ids[i], hours[i]);
            linkedHashMap.put(ids[i], hours[i]);
            treeMap.put(ids[i], hours[i]);
        }

        System.out.println("LinkedHashMap (insertion order): " + linkedHashMap);
        System.out.println("TreeMap (sorted by key): " + treeMap);
    }
}
```

For TaskFlow, `TreeMap<String, Task>` keyed by task ID is a natural fit whenever a report needs tasks listed in ID order without a separate sort step.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "collections-map-q1",
      "type": "mcq",
      "prompt": "What does map.get(key) return if the key is not present in the map?",
      "options": [
        { "id": "a", "text": "It throws a NoSuchElementException" },
        { "id": "b", "text": "null" },
        { "id": "c", "text": "An empty String" },
        { "id": "d", "text": "0" }
      ],
      "correct": "b",
      "explanation": "get() on a missing key returns null rather than throwing. This is exactly why getOrDefault(key, fallback) exists — to supply a non-null fallback without a manual containsKey check."
    },
    {
      "id": "collections-map-q2",
      "type": "mcq",
      "prompt": "What does tasksByOwner.computeIfAbsent(\"Alice\", key -> new ArrayList<>()) do if \"Alice\" already has a value in the map?",
      "options": [
        { "id": "a", "text": "It overwrites Alice's existing value with a new empty ArrayList" },
        { "id": "b", "text": "It returns the existing value unchanged, without creating a new list" },
        { "id": "c", "text": "It throws an exception because the key already exists" },
        { "id": "d", "text": "It adds a duplicate entry for the same key" }
      ],
      "correct": "b",
      "explanation": "computeIfAbsent only invokes the supplied function and inserts a new value when the key is absent. If the key is already present, it simply returns the existing value — this is what makes it safe to call repeatedly while building up a grouped structure."
    },
    {
      "id": "collections-map-q3",
      "type": "mcq",
      "prompt": "Which Map implementation would you choose to always iterate entries sorted by key?",
      "options": [
        { "id": "a", "text": "HashMap" },
        { "id": "b", "text": "LinkedHashMap" },
        { "id": "c", "text": "TreeMap" },
        { "id": "d", "text": "Any of them produce sorted order" }
      ],
      "correct": "c",
      "explanation": "TreeMap keeps its entries sorted by key at all times (natural ordering or a supplied Comparator). HashMap gives no ordering guarantee, and LinkedHashMap preserves insertion order rather than sorted order."
    }
  ]
}
```

## What's next

The last lesson in this module covers `Queue`/`Deque` for FIFO task processing, `Iterator` for safely removing elements while iterating, and `Comparable`/`Comparator` for sorting a `List<Task>` by priority.
