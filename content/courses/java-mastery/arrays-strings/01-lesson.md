---
kind: lesson
id_key: java-mastery/arrays-strings/arrays
course: java-mastery
section: arrays-strings
section_title: "Arrays & Strings"
section_position: 5
title: "Arrays: Fixed-Size Collections"
position: 0
estimated_minutes: 20
source: [java-mastery-curriculum.md]
---
Every TaskFlow feature so far has worked with one value at a time — one task name, one estimate. Real programs need to hold many related values together. An **array** is Java's most basic way to do that: a fixed-size, ordered block of memory holding values of the same type.

## Declaring and creating arrays

```java
public class Main {
    public static void main(String[] args) {
        // Declare and create in one step, with an initializer list
        String[] taskNames = { "Design database schema", "Build REST API", "Write tests" };

        // Declare a fixed size, filled with default values
        double[] estimateHours = new double[3];
        estimateHours[0] = 6.0;
        estimateHours[1] = 10.5;
        estimateHours[2] = 3.0;

        System.out.println("First task: " + taskNames[0]);
        System.out.println("First estimate: " + estimateHours[0] + "h");
    }
}
```

`String[] taskNames` declares an array of `String` — the `[]` can go after the type (`String[] taskNames`, the conventional style) or after the name (`String taskNames[]`, legacy C-style, rarely used in modern Java). `new double[3]` allocates space for exactly 3 `double`s — **array size is fixed at creation time**; you cannot grow or shrink it afterward. Indexing is zero-based: `taskNames[0]` is the first element, `taskNames[2]` is the third and last.

## Default values

When you create an array with `new` but no initializer list, every slot gets a type-appropriate default — not `null` for primitives, an actual zero-equivalent:

```java
public class Main {
    public static void main(String[] args) {
        int[] priorities = new int[4];      // all 0
        boolean[] completed = new boolean[4]; // all false
        double[] hours = new double[4];     // all 0.0
        String[] owners = new String[4];    // all null — String is a reference type

        System.out.println("Default priority: " + priorities[0]);
        System.out.println("Default completed: " + completed[0]);
        System.out.println("Default owner: " + owners[0]);
    }
}
```

Numeric primitive arrays default to `0` (or `0.0`), `boolean` defaults to `false`, and array elements of any **reference type** (`String`, or any object type) default to `null` — there's no "empty" object to fall back to, so the slot simply points at nothing until you assign it.

## `.length` and `ArrayIndexOutOfBoundsException`

```java
public class Main {
    public static void main(String[] args) {
        String[] taskNames = { "Design database schema", "Build REST API", "Write tests" };

        System.out.println("Task count: " + taskNames.length);

        for (int i = 0; i < taskNames.length; i++) {
            System.out.println((i + 1) + ". " + taskNames[i]);
        }

        try {
            System.out.println(taskNames[3]); // valid indices are 0, 1, 2
        } catch (ArrayIndexOutOfBoundsException e) {
            System.out.println("Caught: " + e.getMessage());
        }
    }
}
```

`.length` is a **field**, not a method — no parentheses, unlike `String`'s `.length()`. Valid indices for an array of size `n` run from `0` to `n - 1`; reaching outside that range throws `ArrayIndexOutOfBoundsException` at runtime rather than failing to compile, since the compiler can't generally prove an index stays in bounds. Using `array.length` as the loop bound (rather than a hardcoded number) is the standard way to avoid this bug entirely.

## Arrays hold references, not copies

```java
public class Main {
    public static void main(String[] args) {
        int[] priorities = { 5, 8, 3 };
        int[] alias = priorities; // alias points to the SAME array

        alias[0] = 99;

        System.out.println("priorities[0]: " + priorities[0]); // 99 — same underlying array
    }
}
```

Assigning one array variable to another doesn't copy the elements — both variables reference the same block of memory, so a change through either name is visible through the other. To get an independent copy, use `java.util.Arrays.copyOf(priorities, priorities.length)` — covered when we reach the Collections module's deeper look at references and mutation.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "arrays-strings-arrays-q1",
      "type": "mcq",
      "prompt": "For an array declared as int[] scores = new int[5], what are the valid indices?",
      "options": [
        { "id": "a", "text": "1 through 5" },
        { "id": "b", "text": "0 through 4" },
        { "id": "c", "text": "0 through 5" },
        { "id": "d", "text": "-5 through 5" }
      ],
      "correct": "b",
      "explanation": "An array of size 5 has valid indices 0 through length - 1, i.e. 0 through 4. scores[5] would throw ArrayIndexOutOfBoundsException."
    },
    {
      "id": "arrays-strings-arrays-q2",
      "type": "mcq",
      "prompt": "What is the default value of each element in new String[3]?",
      "options": [
        { "id": "a", "text": "An empty string \"\"" },
        { "id": "b", "text": "null" },
        { "id": "c", "text": "0" },
        { "id": "d", "text": "A compile error, arrays of objects need an initializer" }
      ],
      "correct": "b",
      "explanation": "String is a reference type, so uninitialized array slots default to null, not an empty string. Numeric primitive arrays default to 0/0.0, and boolean defaults to false."
    },
    {
      "id": "arrays-strings-arrays-q3",
      "type": "mcq",
      "prompt": "Given int[] a = {1, 2, 3}; int[] b = a; b[0] = 100;, what is a[0] afterward?",
      "options": [
        { "id": "a", "text": "1, because b is an independent copy" },
        { "id": "b", "text": "100, because a and b reference the same underlying array" },
        { "id": "c", "text": "A runtime exception is thrown" },
        { "id": "d", "text": "0, arrays reset on reassignment" }
      ],
      "correct": "b",
      "explanation": "int[] b = a copies the reference, not the array's contents. Both variable names point at the same memory, so mutating through b is visible through a."
    }
  ]
}
```

## What's next

Arrays don't have to be one-dimensional. The next lesson covers **2D arrays** — grids of values, like a team member's assignment schedule across days of the week.
